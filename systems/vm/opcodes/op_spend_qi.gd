# ============================================================
# 大周天 — OpSpendQi (VM 消耗灵气指令)
# ============================================================
class_name OpSpendQi
extends EffectInstruction


func _do_execute(ctx: EffectContext) -> void:
	ctx.qi.spend_qi(value)
	ctx.trace("SPEND_QI -%d" % value)


func _after(ctx: EffectContext) -> void:
	if ctx.events:
		ctx.events.emit(ctx.current_tick * 0.05, "qi_consumed",
			"player", "player", ctx.current_card_id,
			{"amount": value},
			ctx.current_ip, "SPEND_QI",
			ctx.current_card_id)
