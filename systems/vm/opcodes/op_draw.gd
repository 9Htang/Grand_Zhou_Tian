# ============================================================
# 大周天 — OpDraw (VM 抽牌指令)
# ============================================================
class_name OpDraw
extends EffectInstruction


func _do_execute(ctx: EffectContext) -> void:
	ctx.combat.draw_cards(value)
	ctx.trace("DRAW %d" % value)


func _after(ctx: EffectContext) -> void:
	if ctx.events:
		ctx.events.emit(ctx.current_tick * 0.05, "cards_drawn",
			"player", "player", ctx.current_card_id,
			{"count": value},
			ctx.current_ip, "DRAW",
			ctx.current_card_id)
