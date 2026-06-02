# ============================================================
# 大周天 — BattleController (战斗流程编排器)
# ============================================================
# 职责: FSM驱动、回合流程、系统调度
# 不负责: UI构建/刷新、场景跳转、输入事件
# 所有方法均无 await — 异步延迟由 BattleScreen 处理
# ============================================================
class_name BattleController
extends RefCounted


# === References (set by BattleScreen after creation) ===
var screen: Node = null                       # BattleScreen (CanvasLayer)
var player: PlayerActor = null
var enemies: Array[EnemyActor] = []
var deck_manager: DeckManager = null
var fsm: BattleStateMachine = null
var current_encounter: EncounterData = null
var current_target: int = 0
var _last_collision = null                    # QiCollisionResolver.CollisionResult


# ============================================================
# Initialization
# ============================================================

func initialize(p_screen: Node, p_player: PlayerActor, p_fsm: BattleStateMachine) -> void:
	screen = p_screen
	player = p_player
	fsm = p_fsm


# ============================================================
# Pathway Selection (功法经脉路径选择)
# ============================================================

## 进入路径选择模式 — 功法卡暂不激活，等待玩家点击穴位
func start_pathway_selection(card_data: CardData) -> void:
	pending_technique_card = card_data
	pathway_selection_from = -1


## 玩家点击穴位 — 第一次选起点，第二次选终点
## 返回: -1=无效点击, 0=已选起点等待终点, 1=完成绑定
func select_pathway_node(node_idx: int) -> int:
	if pending_technique_card == null:
		return -1

	if pathway_selection_from < 0:
		# 第一次点击：必须是丹田邻接穴位
		var adjacent: Array = player.get_dantian_adjacent_nodes()
		if not adjacent.has(node_idx):
			return -1
		pathway_selection_from = node_idx
		return 0  # 等待终点选择

	# 第二次点击：终点穴位（不能和起点相同）
	if node_idx == pathway_selection_from:
		return -1
	var card: CardData = pending_technique_card
	bind_technique_to_pathway(card, pathway_selection_from, node_idx)
	pending_technique_card = null
	pathway_selection_from = -1
	return 1  # 完成


## 取消路径选择 — 功法卡回手牌
func cancel_pathway_selection() -> void:
	if pending_technique_card == null:
		return
	deck_manager.cancel_technique(pending_technique_card)
	pending_technique_card = null
	pathway_selection_from = -1


## 绑定功法到路径并激活 + 消耗卡牌
func bind_technique_to_pathway(card: CardData, from_idx: int, to_idx: int) -> void:
	var tech: TechniqueData = TechniqueDatabase.get_technique(card.technique_id)
	if tech == null:
		return
	player.bind_technique_to_pathway(tech.id, from_idx, to_idx)
	player.activate_technique(tech)
	deck_manager.exhaust_card(card)


# ============================================================
# Battle Start / End
# ============================================================

## 加载 encounter 并初始化牌库，踢 FSM 进入 PRE_BATTLE
## 返回: encounter 是否加载成功
func start_battle() -> bool:
	current_encounter = _load_encounter()
	if current_encounter == null:
		return false

	deck_manager = DeckManager.new()
	deck_manager.initialize(player.master_deck.duplicate())

	fsm.transition_to(BattleStateMachine.BattleState.PRE_BATTLE)
	return true


## 从当前地图节点读取 encounter_id 并加载 EncounterData
func _load_encounter() -> EncounterData:
	var chapter: ChapterData = GameManager.current_chapter_data
	var enc_id: String = "ch1_encounter_1"  # fallback
	if chapter != null:
		var node_idx: int = GameManager.current_map_node_index
		if node_idx >= 0 and node_idx < chapter.map_nodes.size():
			var node = chapter.map_nodes[node_idx]
			if not node.encounter_id.is_empty():
				enc_id = node.encounter_id
	var path: String = "res://resources/encounter_data/" + enc_id + ".tres"
	if ResourceLoader.exists(path):
		return load(path) as EncounterData
	return null


# ============================================================
# Turn Flow (FSM Handlers)
# ============================================================

## TURN_START → PLAYER_TURN
## 聚气 + 法宝被动轮询
func execute_turn_start() -> void:
	QiPoolManager.gather_passive(player)
	ArtifactManager.poll_passive(player, GameManager.turn_count)
	ArtifactManager.on_turn_start(player, GameManager.turn_count)
	ArtifactManager.charge_artifacts(player, player.qi_gather_rate)
	fsm.transition_to(BattleStateMachine.BattleState.PLAYER_TURN)


## PLAYER_TURN → PLAYER_ACTION
## 抽牌（含抽牌惩罚 + 额外抽牌）
func execute_player_turn() -> void:
	var effective_draw: int = deck_manager.get_effective_draw_count(5)
	deck_manager.draw_to_hand_size(effective_draw)
	deck_manager.clear_draw_penalty()

	var extra_draw: float = NodePropertyResolver.get_active_property_total(player, "extra_draw")
	if extra_draw > 0:
		deck_manager.draw_cards(int(extra_draw))

	fsm.transition_to(BattleStateMachine.BattleState.PLAYER_ACTION)


## QI_CIRCULATION → ENEMY_TURN
## 运行玩家灵气循环，返回碰撞描述文本
func execute_qi_circulation() -> String:
	run_qi_circulation()
	var log_text: String = ""
	if _last_collision and not _last_collision.descriptions.is_empty():
		log_text = "碰撞: " + ", ".join(_last_collision.descriptions)
	fsm.transition_to(BattleStateMachine.BattleState.ENEMY_TURN)
	return log_text


## ENEMY_TURN → ENEMY_ACTION
## 执行所有敌人行动，返回 log 文本
func execute_enemy_turn() -> String:
	var log_entries: Array[String] = []
	for enemy in enemies:
		var actor: EnemyActor = enemy
		if actor == null:
			continue

		# Find EnemyData from the screen's enemy_container
		var data: EnemyData = _find_enemy_data(actor)
		if data == null:
			continue

		var action: EnemyActionData = EnemyAI.select_action(actor, player, data)
		if action == null:
			continue

		log_entries.append(EnemyAI.describe_decision(actor, action))

		# Execute intent via EnemyIntents
		var result_logs: Array[String] = EnemyIntents.execute_intent(action, actor, player)
		log_entries.append_array(result_logs)

	if log_entries.is_empty():
		return "无"
	return ", ".join(log_entries)


## 从 screen 的 enemy_container 中查找敌人对应的 EnemyData
func _find_enemy_data(actor: EnemyActor) -> EnemyData:
	if screen == null:
		return null
	var container: Node = screen.get("enemy_container")
	if container == null:
		return null
	for child in container.get_children():
		var panel_data: EnemyData = child.get_meta("enemy_data")
		if panel_data and child.get_meta("actor") == actor:
			return panel_data
	return null


## ENEMY_QI_CIRCULATION → TURN_END
## 运行敌人灵气循环
func execute_enemy_qi_circulation() -> void:
	for enemy in enemies:
		var actor: EnemyActor = enemy
		if actor == null:
			continue
		if actor.active_techniques.is_empty() or actor.base_meridian == null:
			continue
		if actor.erosion_targets.is_empty():
			EnemyAI.select_erosion_targets(actor)
		run_qi_circulation_for_actor(actor)
	fsm.transition_to(BattleStateMachine.BattleState.TURN_END)


## TURN_END → TURN_START (或 BATTLE_WON/BATTLE_LOST)
## 检查胜负、tick 经脉损伤、清 buff、处理状态、弃牌
func execute_turn_end() -> Dictionary:
	# Check battle end first
	if player.hp <= 0:
		fsm.transition_to(BattleStateMachine.BattleState.BATTLE_LOST)
		return {"state": "lost"}

	var all_dead := true
	for enemy in enemies:
		if enemy.hp > 0:
			all_dead = false
			break
	if all_dead:
		fsm.transition_to(BattleStateMachine.BattleState.BATTLE_WON)
		return {"state": "won"}

	# Tick meridian damage timers
	MeridianDamageSystem.tick_damage_timers(player)
	for enemy in enemies:
		MeridianDamageSystem.tick_damage_timers(enemy)

	# Clear card buffs, reset block
	player.clear_card_buffs()
	player.current_block = 0

	# Process enemy statuses (burn tick / debuff countdown) — handled by screen
	# Consume pending effects
	var pending: Array = player.get_meta("pending_effects", [])
	var pending_log: String = ""
	for effect in pending:
		match effect["type"]:
			"burn":
				pending_log += "灼烧" + str(effect.get("value", 0))
			"draw_card":
				deck_manager.draw_cards(effect["value"])
	player.set_meta("pending_effects", [])

	deck_manager.discard_hand()
	# NOTE: FSM transition to TURN_START happens in BattleScreen after status processing

	return {"state": "continue", "pending_log": pending_log, "pending_effects": pending}


## 战斗胜利 — 同步状态、发奖励、返回跳转目标
func execute_battle_won() -> Dictionary:
	player.save_to_gm()
	GameManager.add_cultivation(current_encounter.cultivation_reward)
	GameManager.gold += current_encounter.gold_reward

	# Check if boss node → go to reward, else → map
	var chapter: ChapterData = GameManager.current_chapter_data
	var is_boss: bool = false
	if chapter != null:
		var current_idx: int = GameManager.current_map_node_index
		if current_idx >= 0 and current_idx < chapter.map_nodes.size():
			var node = chapter.map_nodes[current_idx]
			if node.node_type == 5:  # MapNodeData.NodeType.BOSS
				is_boss = true

	return {"is_boss": is_boss}


## 战斗失败 — 同步状态
func execute_battle_lost() -> void:
	player.save_to_gm()


## 检查胜负条件（卡牌打出后调用）
func check_battle_end() -> int:  # Returns: 0=continue, 1=won, 2=lost
	var all_dead := true
	for enemy in enemies:
		if enemy.hp > 0:
			all_dead = false
			break
	if all_dead:
		fsm.transition_to(BattleStateMachine.BattleState.BATTLE_WON)
		return 1

	if player.hp <= 0:
		fsm.transition_to(BattleStateMachine.BattleState.BATTLE_LOST)
		return 2

	return 0


# ============================================================
# Card Play
# ============================================================

## 打出一张卡牌，返回结果供 UI 处理
func play_card(card_data: CardData) -> Dictionary:
	var result: Dictionary = CardEffects.apply(player, card_data, screen)

	if not result.get("success", false):
		return {"played": false}

	# 功法卡需要选择经脉路径 → 进入两阶段选择
	if result.get("awaiting_pathway", false):
		start_pathway_selection(card_data)
		return {"played": true, "awaiting_pathway": true}

	# 根据行为标记路由卡牌去向
	var destination: String = result.get("destination", "discard")
	match destination:
		"discard":
			deck_manager.play_card(card_data)
		"exhaust":
			deck_manager.exhaust_card(card_data)
		_:
			pass

	# 容器展开：内容物卡牌加入手牌
	var container_cards: Array = result.get("container_cards", [])
	for cc: CardData in container_cards:
		deck_manager.hand.append(cc)

	return {"played": true, "container_cards": container_cards}


## 处理卡牌拖放到功法区
func activate_technique_via_card(card_data: CardData) -> Dictionary:
	if card_data.card_type != CardData.CardType.TECHNIQUE:
		return {"success": false}

	var result: Dictionary = CardEffects.apply(player, card_data, screen)
	if result.get("success", false):
		var dest: String = result.get("destination", "discard")
		if dest == "exhaust":
			deck_manager.exhaust_card(card_data)
		else:
			deck_manager.play_card(card_data)
		return {"success": true}
	return {"success": false}


## 取消功法，返回卡牌到手牌
func cancel_technique(tech: TechniqueData) -> bool:
	if not deck_manager.can_cancel(5):
		return false
	player.deactivate_technique(tech)
	var card_id: String = "technique_" + tech.id
	var card: CardData = CardDatabase.get_card(card_id)
	if card:
		deck_manager.cancel_technique(card)
	return true


# ============================================================
# Qi Circulation
# ============================================================

## 对玩家运行完整灵气循环
func run_qi_circulation() -> void:
	run_qi_circulation_for_actor(player)


## 通用灵气循环（玩家或敌人都可用）
func run_qi_circulation_for_actor(actor: CombatActor) -> void:
	var meridian: MeridianMapData = actor.base_meridian
	if meridian == null:
		return

	var techniques: Array = actor.active_techniques

	# 灵气持久流动 — 不清零！回路中的灵气跨回合保持
	# 只清理断流无回路时的微量残留
	if actor.active_circuits.is_empty() and actor.dantian_qi <= 0:
		QiFlowSystem.clear_flow_state(actor)

	# 流量追踪：累积每个穴位本回合流经的灵气量，用于 buff 生成
	var flow_tracker: Dictionary = {}

	# Fluid tick loop: inject -> propagate -> erode -> deliver
	const MAX_TICKS: int = 20
	for _i in range(MAX_TICKS):
		var tick_result: Dictionary = QiFlowSystem.tick(actor, flow_tracker)
		var new_circuits: Array = tick_result.get("circuits_formed", [])
		if not new_circuits.is_empty():
			for circuit in new_circuits:
				actor.circuit_formed.emit(circuit)
		# Unlock feedback — BattleScreen handles UI via screen reference
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

	# Collect active nodes
	var active_nodes: Array[int] = []
	for i: int in meridian.nodes.size():
		var node: MeridianNodeData = meridian.get_node(i)
		if node and node.current_qi > 0 and node.unlocked and not node.blocked:
			active_nodes.append(i)

	# Collision resolution
	var collision = null
	if techniques.size() >= 2 and not active_nodes.is_empty():
		collision = QiCollisionResolver.resolve_all(techniques, active_nodes, meridian)
		for dmg in collision.damaged_pathways:
			MeridianDamageSystem.damage_pathway(actor, dmg["from"], dmg["to"], dmg.get("turns", 3))

	# Save collision for meridian view (player only)
	if actor is PlayerActor:
		_last_collision = collision

	# Buff generation (linear scaling)
	actor.clear_technique_buffs()
	var all_buffs: Array = TechniqueResolver.resolve_network_buffs(
		techniques, meridian, actor.node_base_buffs, collision, flow_tracker
	)
	actor.active_buffs = all_buffs

	# Consume generated buffs
	_consume_buffs(actor, all_buffs)

	ArtifactManager.on_qi_circulate(actor)


## 消费运环生成的 buff
func _consume_buffs(actor: CombatActor, buffs: Array) -> void:
	for buff in buffs:
		match buff.name:
			"burn":
				# Player-originated burn applies to enemies
				if actor is PlayerActor:
					for enemy in enemies:
						EnemyStatusSystem.apply(enemy, "burn:" + str(buff.value) + ":2")
			"draw_card":
				if actor is PlayerActor:
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


# ============================================================
# Target Selection
# ============================================================

## 获取当前目标的 EnemyActor（供 CardEffects 调用）
func get_target_enemy() -> EnemyActor:
	if enemies.is_empty():
		return null
	if current_target >= enemies.size():
		current_target = 0
	return enemies[current_target]
