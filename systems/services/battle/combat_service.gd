# ============================================================
# 大周天 — CombatService (战斗域)
# 职责: 伤害/治疗/格挡/抽牌/最大HP
# ============================================================
class_name CombatService
extends RefCounted


## EffectContext 回引用（由 EffectContext._init_services 设置）
var _ctx: EffectContext = null


## 对指定目标造成伤害 (显式目标, 由 EffectVM 遍历 ctx.targets 调用)
func damage_to(value: int, target: Node) -> void:
	if target and target.has_method("take_damage"):
		target.take_damage(value)
	if _ctx.result:
		_ctx.result.damage_dealt += value
	_ctx.trace("DAMAGE %d -> %s" % [value, target.name if target else "null"])


## 对自身造成伤害 (丹药副作用 / 敌人反击)
func damage_actor(value: int) -> void:
	var act: Node = _ctx.actor
	if act and act.has_method("take_damage"):
		act.take_damage(value)
	_ctx.trace("SELF_DAMAGE %d" % value)


## 为 actor 恢复生命
func heal_actor(value: int) -> void:
	if _ctx.is_battle():
		var act: Node = _ctx.actor
		if act and act.has_method("heal"):
			act.heal(value)
		if _ctx.result:
			_ctx.result.heal_done += value
	else:
		var gm: Node = _ctx.actor
		if gm and gm.has_method("heal"):
			gm.heal(value)
	_ctx.trace("HEAL %d" % value)


## 为 actor 添加格挡
func add_block(value: int) -> void:
	if _ctx.is_battle():
		var act: Node = _ctx.actor
		if act and act.get("current_block") != null:
			act.current_block += value
		if _ctx.result:
			_ctx.result.block_gained += value
	elif _ctx.actor:
		_ctx.actor.current_block += value
	_ctx.trace("BLOCK %d" % value)


## 增加最大生命值
func increase_max_hp(value: int) -> void:
	var act: Node = _ctx.actor
	if act and act.has_method("increase_max_hp"):
		act.increase_max_hp(value)


## 为 actor 抽牌
func draw_cards(value: int) -> void:
	if _ctx.is_battle():
		var act: Node = _ctx.actor
		if act and act.has_method("draw_cards"):
			act.draw_cards(value)
		if _ctx.result:
			_ctx.result.cards_drawn += value
	else:
		_add_pending("draw_card", "", value)
	_ctx.trace("DRAW %d" % value)


## 检查战斗是否结束: 0=继续 1=胜利 2=失败
static func check_battle_end(player_hp: int, enemies: Array) -> int:
	if player_hp <= 0:
		return 2  # lost
	for enemy in enemies:
		if enemy.hp > 0:
			return 0  # continue
	return 1  # won


## 判断是否为 Boss 遭遇节点
static func is_boss_encounter(node_type: int) -> bool:
	return node_type == 5  # N_BOSS


# ============================================================
# Internal
# ============================================================


func _add_pending(type_str: String, subtype: String, value: int) -> void:
	var target: Node = _ctx.actor
	if target == null:
		return
	if not target.has_meta("pending_effects"):
		target.set_meta("pending_effects", [])
	var pe: Array = target.get_meta("pending_effects")
	pe.append({"type": type_str, "subtype": subtype, "value": value})
