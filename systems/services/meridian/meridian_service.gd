# ============================================================
# 大周天 — MeridianService (经脉域)
# 职责: 丹田容量/经脉路径/穴位解锁/修复/封穴/断脉/吸灵
# ============================================================
class_name MeridianService
extends RefCounted


var _ctx: EffectContext = null


## 提升丹田容量
func increase_dantian(value: int) -> void:
	var target: Node = _ctx.actor
	if target and target.get("dantian_capacity") != null:
		target.dantian_capacity += value
	if _ctx.result:
		_ctx.result.qi_gathered += value
	_ctx.trace("DANTIAN_UP +%d" % value)


## 增加经脉路径容量
func modify_pathway(from_idx: int, to_idx: int, delta: int) -> bool:
	var actor: Node = _ctx.actor
	if actor == null:
		return false
	var mer: MeridianMapData = actor.get("base_meridian") if actor.get("base_meridian") != null else null
	if mer == null:
		return false
	var pw: MeridianPathwayData = mer.find_pathway(from_idx, to_idx)
	if pw == null:
		_ctx.trace("PATHWAY_UP %d→%d not found" % [from_idx, to_idx])
		return false
	pw.capacity_bonus += float(delta)
	_ctx.trace("PATHWAY_UP %d→%d +%d" % [from_idx, to_idx, delta])
	return true


## 解锁穴位
func unlock_node(node_arg: String) -> void:
	var target: Node = _ctx.actor
	if target and target.has_method("unlock_meridian_node"):
		target.unlock_meridian_node(node_arg)


## 修复经脉路径
func repair_pathway(repair_arg: String) -> void:
	var target: Node = _ctx.actor
	if target == null:
		return
	if repair_arg == "random" and target.has_method("repair_random_pathway"):
		target.repair_random_pathway()
	elif repair_arg == "all" and target.has_method("repair_all_pathways"):
		target.repair_all_pathways()
	elif target.has_method("repair_pathway"):
		target.repair_pathway(repair_arg)


## 封穴: 阻塞玩家经脉上的随机活跃穴位
func seal_random_node() -> String:
	var actor: Node = _ctx.actor
	if actor == null:
		return ""
	var mer: MeridianMapData = actor.get("base_meridian") if actor.get("base_meridian") != null else null
	if mer == null:
		return ""
	var candidates: Array[int] = []
	for i: int in mer.nodes.size():
		var n: MeridianNodeData = mer.get_node(i)
		if n and n.unlocked and not n.blocked and n.current_qi > 0:
			candidates.append(i)
	if candidates.is_empty():
		return ""
	var _rng = _ctx.rng if _ctx and _ctx.rng else null
	var target_idx: int = candidates[(_rng.randi() if _rng else randi()) % candidates.size()]
	var mn: MeridianNodeData = mer.get_node(target_idx)
	MeridianDamageSystem.block_node(actor, mn.name)
	return mn.name


## 断脉: 损伤随机通路
func damage_random_pathway() -> Dictionary:
	var actor: Node = _ctx.actor
	if actor == null:
		return {}
	var mer: MeridianMapData = actor.get("base_meridian") if actor.get("base_meridian") != null else null
	if mer == null or mer.pathways.is_empty():
		return {}
	var _rng = _ctx.rng if _ctx and _ctx.rng else null
	var pw = mer.pathways[(_rng.randi() if _rng else randi()) % mer.pathways.size()]
	MeridianDamageSystem.damage_pathway(actor, pw.from_node, pw.to_node)
	return {"from": pw.from_node, "to": pw.to_node}


## 吸灵: 从经脉抽取灵气
func drain_qi(amount: float) -> float:
	var actor: Node = _ctx.actor
	if actor == null:
		return 0.0
	return QiFlowSystem.draw_from_meridian(actor, amount)
