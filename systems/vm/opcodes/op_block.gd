# ============================================================
# 大周天 — OpBlock (VM 格挡指令)
# ============================================================
class_name OpBlock
extends EffectInstruction


func _do_execute(ctx: EffectContext) -> void:
	ctx.combat.add_block(value)
	ctx.trace("BLOCK +%d" % value)


func _after(ctx: EffectContext) -> void:
	if ctx.events:
		ctx.events.emit(ctx.current_tick * 0.05, "block_gained",
			"player", "player", ctx.current_card_id,
			{"amount": value},
			ctx.current_ip, "BLOCK",
			ctx.current_card_id)
