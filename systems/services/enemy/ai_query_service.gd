# ============================================================
# 大周天 — AIQueryService (AI 只读查询域)
# ❗ 只读 — 绝不修改游戏状态
# 职责: 为 AI / 条件判断提供状态查询
# ============================================================
class_name AIQueryService
extends RefCounted


var _ctx: EffectContext = null


## 获取玩家境界
func get_actor_realm() -> int:
	var act: Node = _ctx.actor
	if act:
		return act.get("realm") if act.get("realm") != null else 1
	return 1


## 获取敌人境界
func get_opponent_realm() -> int:
	var opp: Node = _ctx.primary_target
	if opp:
		return opp.get("realm") if opp.get("realm") != null else 1
	return 1


## 玩家是否有指定 buff
func actor_has_buff(buff_name: String) -> bool:
	var act: Node = _ctx.actor
	if act == null:
		return false
	var buffs: Array = act.get("active_buffs") if act.get("active_buffs") != null else []
	for buff in buffs:
		var n: String = buff.get("name") if typeof(buff) == TYPE_DICTIONARY else buff.name
		if n == buff_name:
			return true
	return false


## 获取玩家 buff 值
func actor_get_buff_value(buff_name: String) -> int:
	var act: Node = _ctx.actor
	if act == null:
		return 0
	var buffs: Array = act.get("active_buffs") if act.get("active_buffs") != null else []
	for buff in buffs:
		var n: String = buff.get("name") if typeof(buff) == TYPE_DICTIONARY else buff.name
		var v = buff.get("value") if typeof(buff) == TYPE_DICTIONARY else buff.value
		if n == buff_name:
			return int(v)
	return 0


## 获取玩家穴位属性值
func get_actor_node_property(prop_name: String) -> float:
	var act: Node = _ctx.actor
	if act:
		return NodePropertyResolver.get_active_property_total(act, prop_name)
	return 0.0


## 给玩家添加 buff (写入操作 — 用于 AI 决策副作用)
func add_buff_to_actor(buff_name: String, value: int, source: String) -> void:
	var act: Node = _ctx.actor
	if act == null:
		return
	var rb := TechniqueResolver.ResolvedBuff.new()
	rb.name = buff_name
	rb.value = value
	rb.source = source
	var buffs: Array = act.get("active_buffs") if act.get("active_buffs") != null else []
	buffs.append(rb)
	act.set("active_buffs", buffs)
	if act.has_signal("buffs_updated"):
		act.buffs_updated.emit(buffs)
