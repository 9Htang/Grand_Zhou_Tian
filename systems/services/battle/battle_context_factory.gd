# ============================================================
# 大周天 — BattleContextFactory (战斗上下文工厂 — L2)
# 职责: 组装 BattleContext + 编译 Modifier (Tech→EffectOperator 翻译)
# 红线: 不访问 autoload, 不做 UI, 纯数据变换
# ============================================================
class_name BattleContextFactory
extends RefCounted


# === Injected References (set by BattleController) ===
var player: PlayerActor = null
var enemies: Array[EnemyActor] = []
var deck_manager: DeckManager = null

## 确定性 RNG（由 Bootstrapper 注入）
var rng: DeterministicRNG = null

## 事件流 — 由 Bootstrapper 注入，build() 时复制到每个 BattleContext
var event_stream: EventStream = null
var current_tick: int = 0


# ============================================================
# Public API
# ============================================================


## 构建完整战斗上下文 (含 run_modifiers)
## elapsed_seconds: 即时制战斗经过秒数, 由调用方从 GameManager 读取后传入
func build(elapsed_seconds: float) -> BattleContext:
	var ctx: BattleContext = BattleContext.new()
	ctx.actor = player
	ctx.elapsed_seconds = elapsed_seconds
	ctx.realm = player.realm
	ctx.talent = player.talent

	# 活跃功法 ID
	for tech in player.active_techniques:
		var td: TechniqueData = tech as TechniqueData
		if td:
			ctx.active_technique_ids.append(td.id)

	# 多敌人列表 (供 Provider 枚举)
	ctx.enemies.assign(enemies)

	# 编译 Run Modifiers
	ctx.run_modifiers = ModifierCompiler.compile_run_modifiers(player.active_techniques)
	ctx.deck = deck_manager
	ctx.rng = rng
	ctx.event_stream = event_stream
	ctx.current_tick = current_tick
	return ctx


## 构建最小上下文 (仅 actor + deck, 供目标选择使用)
func build_minimal() -> BattleContext:
	var ctx: BattleContext = BattleContext.new()
	ctx.actor = player
	ctx.deck = deck_manager
	ctx.enemies.assign(enemies)
	ctx.rng = rng
	ctx.event_stream = event_stream
	ctx.current_tick = current_tick
	return ctx
