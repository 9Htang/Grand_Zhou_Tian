# ============================================================
# 大周天 — TargetResolver
# 统一目标解析 — TargetSpec → Array[Node]
# 纯函数，不涉及 UI 选择逻辑
# SINGLE_ENEMY 返回空数组，由 TargetManager 接管 UI
# ============================================================
class_name TargetResolver
extends RefCounted


## 将 TargetSpec 解析为实际目标节点列表
## SINGLE_ENEMY 返回 [] — 需要 UI 选择，不在本层处理
static func resolve(spec: TargetSpec, ctx: BattleContext, rng: DeterministicRNG = null) -> Array[Node]:
	if spec == null or spec.is_empty():
		return []

	match spec.type:
		TargetSpec.Type.SELF:
			if ctx.actor:
				return [ctx.actor]
			return []

		TargetSpec.Type.ALL_ENEMIES:
			return _alive_enemies(ctx)

		TargetSpec.Type.RANDOM_ENEMY:
			var enemies: Array[Node] = _alive_enemies(ctx)
			if not enemies.is_empty():
				return [enemies[(rng.randi() if rng else randi()) % enemies.size()]]
			return []

		TargetSpec.Type.SINGLE_ENEMY:
			# 需要 UI 选择 — 返回空，让调用方走 TargetManager
			return []

	return []


# ============================================================
# Internal
# ============================================================


## 获取所有存活敌人
static func _alive_enemies(ctx: BattleContext) -> Array[Node]:
	var out: Array[Node] = []
	for e in ctx.enemies:
		if e == null:
			continue
		var hp = e.get("hp") if e.get("hp") != null else 0
		if hp > 0:
			out.append(e)
	return out
