# ============================================================
# 大周天 — OpApplyStatus (VM 状态效果指令)
# ============================================================
# 支持: burn / vulnerable / weak / stun / buff / debuff / cleanse
# 通过 meta["status_type"] 区分具体类型。
# ============================================================
class_name OpApplyStatus
extends EffectInstruction


func _do_execute(ctx: EffectContext) -> void:
	var status_type: String = meta.get("status_type", "")
	var turns: int = meta.get("turns", 2)
	var status_name: String = meta.get("name", "")
	var subtype: String = meta.get("subtype", "")

	match status_type:
		"burn", "vulnerable", "weak", "stun":
			if ctx.is_battle():
				ctx.status.apply_battle_status(status_type, value, turns)
			else:
				ctx.status.add_pending(status_type, "", value)
			ctx.trace("APPLY_STATUS %s x%d (%d turns)" % [status_type, value, turns])

		"buff":
			if ctx.is_battle():
				ctx.status.apply_buff(status_name, value, turns)
			else:
				ctx.status.add_permanent_buff(status_name, value, turns)
			ctx.trace("APPLY_STATUS buff: %s x%d (%d turns)" % [status_name, value, turns])

		"debuff":
			if ctx.is_battle():
				ctx.status.apply_debuff(status_name, value, turns)
			else:
				ctx.status.add_pending("debuff", status_name, value)
			ctx.trace("APPLY_STATUS debuff: %s x%d (%d turns)" % [status_name, value, turns])

		"cleanse":
			if ctx.is_battle():
				ctx.status.apply_cleanse(value)
			ctx.trace("APPLY_STATUS cleanse x%d" % value)

		_:
			if subtype == "burn":
				ctx.status.add_pending("burn", "", value)
			elif subtype == "debuff":
				ctx.status.add_pending("debuff", status_name, value)
			elif subtype == "buff":
				ctx.status.add_permanent_buff(status_name, value, turns)
			else:
				ctx.trace("APPLY_STATUS unknown subtype '%s' — skip" % status_type)


func _after(ctx: EffectContext) -> void:
	if ctx.events:
		var status_type: String = meta.get("status_type", "")
		var status_name: String = meta.get("name", "")
		if status_name.is_empty():
			status_name = status_type
		ctx.events.emit(ctx.current_tick * 0.05, "status_applied",
			"player", str(ctx.primary_target) if ctx.primary_target else "player",
			ctx.current_card_id,
			{"status_type": status_type, "name": status_name, "value": value, "turns": meta.get("turns", 2)},
			ctx.current_ip, "APPLY_STATUS",
			ctx.current_card_id)
