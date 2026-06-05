# ============================================================
# 大周天 — QiService (灵气域)
# 职责: 灵气聚集/消耗/恢复/聚气速率
# ============================================================
class_name QiService
extends RefCounted


var _ctx: EffectContext = null


## 聚集灵气 (被动累积 — 仅记录)
func gather_qi(value: int) -> void:
	if _ctx.result:
		_ctx.result.qi_gathered += value
	_ctx.trace("QI_GATHER %d" % value)


## 立即获得灵气
func add_qi(value: int) -> void:
	var target: Node = _ctx.actor
	if target and target.has_method("add_qi"):
		target.add_qi(value)
	if _ctx.result:
		_ctx.result.qi_gathered += value
	_ctx.trace("QI_RESTORE %d" % value)


## 消耗灵气
func spend_qi(value: int) -> bool:
	var target: Node = _ctx.actor
	if target and target.has_method("spend_qi"):
		return target.spend_qi(value)
	return false


## 提升聚气速率加成
func add_gather_bonus(value: int) -> void:
	var target: Node = _ctx.actor
	if target and target.has_method("add_qi_gather_bonus"):
		target.add_qi_gather_bonus("effect", value)
