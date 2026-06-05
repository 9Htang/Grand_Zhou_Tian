# ============================================================
# 大周天 — OpHeal (VM 治疗指令)
# ============================================================
class_name OpHeal
extends EffectInstruction


func _do_execute(ctx: EffectContext) -> void:
	ctx.combat.heal_actor(value)
	ctx.trace("HEAL +%d" % value)


func _after(ctx: EffectContext) -> void:
	if ctx.events:
		ctx.events.emit(ctx.current_tick * 0.05, "heal_received",
			"player", "player", ctx.current_card_id,
			{"amount": value},
			ctx.current_ip, "HEAL",
			ctx.current_card_id)
