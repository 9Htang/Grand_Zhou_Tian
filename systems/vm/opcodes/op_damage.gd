# ============================================================
# 大周天 — OpDamage (VM 伤害指令)
# ============================================================
# L2 定位: systems/vm/opcodes/ — VM 指令子类
#
# 从栈顶 pop 目标列表，对其造成伤害。
# 若栈为空，fallback 到 ctx.targets / ctx.primary_target。
# ============================================================
class_name OpDamage
extends EffectInstruction


func _do_execute(ctx: EffectContext) -> void:
	# 从栈取目标（如果栈有数据）
	var targets: Array[Node] = []
	if ctx.stack and not ctx.stack.is_empty():
		targets = ctx.stack.pop()

	# fallback: 使用 ctx.targets 或 ctx.primary_target
	if targets == null or targets.is_empty():
		targets = ctx.targets
	if targets.is_empty() and ctx.primary_target:
		targets = [ctx.primary_target]

	for t in targets:
		if t == null:
			continue
		ctx.combat.damage_to(value, t)

	ctx.trace("DAMAGE %d → %d targets" % [value, targets.size()])


func _after(ctx: EffectContext) -> void:
	if ctx.events and ctx.primary_target:
		ctx.events.emit(ctx.current_tick * 0.05, "damage_dealt",
			"player", str(ctx.primary_target), ctx.current_card_id,
			{"amount": value},
			ctx.current_ip, "DAMAGE",
			ctx.current_card_id)
