# ============================================================
# 大周天 — QiCirculationService (灵气循环域 — L2, 即时制)
# ============================================================
# 即时制改造:
#   + run_one_tick() — 单步 tick (BattleClock 每 tick 驱动)
#   run() 保留用于 burst 场景 (功法激活/丹药)
# ============================================================
class_name QiCirculationService
extends RefCounted


var screen: Node = null
var enemies: Array[EnemyActor] = []
var deck_manager: Object = null

var last_collision = null


## 即时制: 运行单步灵气 tick (由 BattleClock.tick 驱动)
func run_one_tick(actor: CombatActor) -> void:
	var meridian: MeridianMapData = actor.base_meridian
	if meridian == null:
		return
	if actor.active_circuits.is_empty() and actor.dantian_qi <= 0:
		return

	var flow_tracker: Dictionary = {}
	var tick_result: Dictionary = QiFlowSystem.tick(actor, flow_tracker)

	var new_circuits: Array = tick_result.get("circuits_formed", [])
	for circuit in new_circuits:
		actor.circuit_formed.emit(circuit)

	var unlocked_names: Array = tick_result.get("nodes_unlocked", [])
	if not unlocked_names.is_empty() and actor is PlayerActor:
		for node_name in unlocked_names:
			for j: int in meridian.nodes.size():
				var mn: MeridianNodeData = meridian.nodes[j]
				if mn and mn.name == node_name:
					if screen and screen.has_method("notify_node_unlocked"):
						screen.notify_node_unlocked(j)
					break


## Burst 模式: 运行完整灵气循环 (功法激活/丹药/手动触发)
func run(actor: CombatActor) -> void:
	var meridian: MeridianMapData = actor.base_meridian
	if meridian == null:
		return

	var techniques: Array = actor.active_techniques

	if actor.active_circuits.is_empty() and actor.dantian_qi <= 0:
		QiFlowSystem.clear_flow_state(actor)

	var flow_tracker: Dictionary = {}

	const MAX_TICKS: int = 20
	for _i in range(MAX_TICKS):
		var tick_result: Dictionary = QiFlowSystem.tick(actor, flow_tracker)
		var new_circuits: Array = tick_result.get("circuits_formed", [])
		if not new_circuits.is_empty():
			for circuit in new_circuits:
				actor.circuit_formed.emit(circuit)
		var unlocked_names: Array = tick_result.get("nodes_unlocked", [])
		if not unlocked_names.is_empty() and actor is PlayerActor:
			for node_name in unlocked_names:
				for j: int in meridian.nodes.size():
					var mn: MeridianNodeData = meridian.nodes[j]
					if mn and mn.name == node_name:
						if screen and screen.has_method("notify_node_unlocked"):
							screen.notify_node_unlocked(j)
						break
		if tick_result.get("is_dry", false):
			break
		if not tick_result.get("flow_moved", false):
			break

	actor.is_flow_dry = QiPoolManager.get_remaining(actor) <= 0

	var active_nodes: Array[int] = []
	for i: int in meridian.nodes.size():
		var node: MeridianNodeData = meridian.get_node(i)
		if node and node.current_qi > 0 and node.unlocked and not node.blocked:
			active_nodes.append(i)

	var collision = null
	if techniques.size() >= 2 and not active_nodes.is_empty():
		collision = QiCollisionResolver.resolve_all(techniques, active_nodes, meridian)
		for dmg in collision.damaged_pathways:
			MeridianDamageSystem.damage_pathway(actor, dmg["from"], dmg["to"], dmg.get("turns", 3))

	if actor is PlayerActor:
		last_collision = collision

	actor.clear_technique_buffs()

	var card_buffs: Array = []
	for buff in actor.active_buffs:
		card_buffs.append(buff)

	var tech_buffs: Array = TechniqueResolver.resolve_network_buffs(
		techniques, meridian, actor.node_base_buffs, collision, flow_tracker
	)
	tech_buffs.append_array(card_buffs)
	actor.active_buffs = tech_buffs

	consume_buffs(actor, tech_buffs)

	ArtifactManager.on_qi_circulate(actor)


func consume_buffs(actor: CombatActor, buffs: Array) -> void:
	for buff in buffs:
		match buff.name:
			"burn":
				if actor is PlayerActor:
					for enemy in enemies:
						EnemyStatusSystem.apply(enemy, "burn:" + str(buff.value) + ":2")
			"draw_card":
				if actor is PlayerActor and deck_manager:
					deck_manager.draw_cards(buff.value)
			"heal":
				actor.heal(buff.value)
			"block":
				actor.current_block += buff.value
			"energy_up":
				actor.add_qi(buff.value)
			"energy_down":
				actor.spend_qi(buff.value)
			"self_damage":
				actor.take_damage(buff.value)
