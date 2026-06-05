# ============================================================
# 大周天 — OpQiGather (VM 聚气指令)
# ============================================================
class_name OpQiGather
extends EffectInstruction


func _do_execute(ctx: EffectContext) -> void:
	ctx.qi.gather_qi(value)
	ctx.trace("QI_GATHER +%d" % value)


func _after(ctx: EffectContext) -> void:
	if ctx.events:
		ctx.events.emit(ctx.current_tick * 0.05, "qi_generated",
			"player", "player", ctx.current_card_id,
			{"amount": value},
			ctx.current_ip, "QI_GATHER",
			ctx.current_card_id)
