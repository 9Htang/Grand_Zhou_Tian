# ============================================================
# 大周天 — OpSelectTarget (VM 目标选择指令)
# ============================================================
# 将目标列表推入 VM Stack，供后续 OpDamage/OpHeal 等指令 pop 使用。
#
# 支持三种模式:
#   - SINGLE_ENEMY: 如果有明确目标则用，否则需要 UI 选择
#   - ALL_ENEMIES: 所有存活敌人
#   - RANDOM_ENEMY: 随机选择一个敌人（通过 ctx.rng）
#
# RNG 入口: RANDOM_ENEMY 模式 → ctx.rng.randi() % enemies.size()
# ============================================================
class_name OpSelectTarget
extends EffectInstruction


func _do_execute(ctx: EffectContext) -> void:
	var enemies: Array[Node] = []
	if ctx.battle_ctx:
		enemies = _alive_enemies(ctx)

	# 优先使用 ctx.targets（由 Resolver 预先解析）
	if not ctx.targets.is_empty():
		ctx.stack.push(ctx.targets)
		ctx.trace("SELECT_TARGET push %d targets (pre-resolved)" % ctx.targets.size())
		return

	# 通过 TargetSpec 解析
	if target == null or target.is_empty():
		# 无 target spec: fallback 到 primary_target
		if ctx.primary_target:
			ctx.stack.push([ctx.primary_target])
		else:
			ctx.stack.push([])
		return

	var ttype: int = target.type
	match ttype:
		TargetSpec.Type.RANDOM_ENEMY:
			if enemies.is_empty():
				ctx.stack.push([])
				return
			var idx: int = 0
			if ctx.rng:
				idx = ctx.rng.randi() % enemies.size()
			else:
				idx = randi() % enemies.size()
			ctx.stack.push([enemies[idx]])
			ctx.trace("SELECT_TARGET RANDOM_ENEMY → enemy[%d]" % idx)

		TargetSpec.Type.ALL_ENEMIES:
			ctx.stack.push(enemies)
			ctx.trace("SELECT_TARGET ALL_ENEMIES → %d enemies" % enemies.size())

		TargetSpec.Type.SELF:
			ctx.stack.push([ctx.actor])
			ctx.trace("SELECT_TARGET SELF")

		_:
			ctx.stack.push([])


func _alive_enemies(ctx: EffectContext) -> Array[Node]:
	var result: Array[Node] = []
	if ctx.battle_ctx and ctx.battle_ctx.enemies:
		for e in ctx.battle_ctx.enemies:
			if e and e.get("hp") != null and e.hp > 0:
				result.append(e)
	return result
