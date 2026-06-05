# ============================================================
# 大周天 — ProgressionService (成长域)
# 职责: 修炼/境界/突破/天资/金币
# ============================================================
class_name ProgressionService
extends RefCounted


var _ctx: EffectContext = null


func add_cultivation(value: int) -> void:
	var target: Node = _ctx.actor
	if target and target.has_method("add_cultivation"):
		target.add_cultivation(value)


func add_gold(value: int) -> void:
	var target: Node = _ctx.actor
	if target and target.get("gold") != null:
		target.gold += value


func increase_talent(value: int) -> void:
	var target: Node = _ctx.actor
	if target and target.get("talent") != null:
		target.talent += value


func get_realm() -> int:
	var target: Node = _ctx.actor
	if target:
		return target.get("realm") if target.get("realm") != null else 1
	return 1


func get_talent() -> int:
	var target: Node = _ctx.actor
	if target:
		return target.get("talent") if target.get("talent") != null else 2
	return 2
