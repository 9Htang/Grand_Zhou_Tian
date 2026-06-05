# ============================================================
# 大周天 — EnemyService (敌人行动域)
# 职责: 敌人攻击/防御/强化/削弱时的状态修改
# BattleContext 为玩家中心: ctx.actor=玩家(受击), ctx.primary_target=敌人(行动方)
# ============================================================
class_name EnemyService
extends RefCounted


var _ctx: EffectContext = null


## 敌人对玩家造成伤害
func damage_player(value: int) -> void:
	_ctx.combat.damage_actor(value)


## 敌人获得格挡
func add_block(value: int) -> void:
	var opp: Node = _ctx.primary_target
	if opp:
		var current: int = opp.get("current_block") if opp.get("current_block") != null else 0
		opp.set("current_block", current + value)


## 敌人增加力量
func add_strength(value: int) -> void:
	var opp: Node = _ctx.primary_target
	if opp:
		var current: int = opp.get("strength") if opp.get("strength") != null else 0
		opp.set("strength", current + value)


## 获取敌人力量
func get_strength() -> int:
	var opp: Node = _ctx.primary_target
	if opp:
		return opp.get("strength") if opp.get("strength") != null else 0
	return 0


## 获取敌人 HP
func get_hp() -> int:
	var opp: Node = _ctx.primary_target
	if opp:
		return opp.get("hp") if opp.get("hp") != null else 0
	return 0


## 设置敌人 HP
func set_hp(value: int) -> void:
	var opp: Node = _ctx.primary_target
	if opp:
		opp.set("hp", max(0, value))


## 获取敌人展示名称
func get_display_name() -> String:
	var opp: Node = _ctx.primary_target
	if opp:
		return opp.get("display_name") if opp.get("display_name") != null else "?"
	return "?"


## 敌人是否有指定状态 (EnemyActor.statuses)
func has_status(status_name: String) -> bool:
	var opp: Node = _ctx.primary_target
	if opp == null:
		return false
	var statuses: Dictionary = opp.get("statuses") if opp.get("statuses") != null else {}
	return statuses.has(status_name)


## 获取敌人状态值
func get_status_amount(status_name: String) -> int:
	var opp: Node = _ctx.primary_target
	if opp == null:
		return 0
	var statuses: Dictionary = opp.get("statuses") if opp.get("statuses") != null else {}
	var s = statuses.get(status_name, {})
	return s.get("amount", 0) if typeof(s) == TYPE_DICTIONARY else 0


## 扣减玩家灵气
func drain_player_qi(value: int) -> bool:
	return _ctx.qi.spend_qi(value)


## 封穴: 阻塞玩家随机活跃穴位, 返回穴位名
func seal_meridian_node() -> String:
	return _ctx.meridian.seal_random_node()


## 断脉: 损伤玩家随机通路, 返回 {from, to}
func damage_meridian_pathway() -> Dictionary:
	return _ctx.meridian.damage_random_pathway()


## 吸灵: 从玩家经脉抽取灵气
func drain_qi(amount: float) -> float:
	return _ctx.meridian.drain_qi(amount)
