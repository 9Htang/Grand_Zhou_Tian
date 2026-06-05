# ============================================================
# 大周天 — BattleBootstrapper (战斗启动器 — L2, 即时制)
# ============================================================
# 四层定位: L2 Domain Layer
#
# 职责: 一次性创建全部服务 + 注入依赖 + 接线所有信号
# 红线: 不做运行时调度, 不做 FSM, 生命周期仅限 setup 阶段
#
# v3.0: 新增 deterministic RNG 注入
#   bootstrap() 接受可选 rng 参数，注入到 DeckManager / EnemyTimerSystem / ContextFactory
# ============================================================
class_name BattleBootstrapper
extends RefCounted


# ============================================================
# BootResult — 一次性交付全部已接线服务
# ============================================================

class BootResult:
	# === 原有服务 ===
	var deck_manager: DeckManager = null
	var card_repo: CardRepository = null
	var target_manager: TargetManager = null
	var card_trigger_router: CardTriggerRouter = null
	var context_factory: BattleContextFactory = null
	var snapshot_service: SnapshotService = null
	var qi_circulation: QiCirculationService = null
	var forge_service: ForgeService = null
	var card_play_service: CardPlayService = null
	var pathway_service: PathwayService = null
	var selection_dispatcher: SelectionDispatcher = null
	var flow_orchestrator: BattleFlowOrchestrator = null
	var encounter: EncounterData = null

	# === 即时制新服务 ===
	var battle_clock: BattleClock = null
	var effect_queue: EffectQueue = null
	var cooldown_manager: CooldownManager = null
	var enemy_timer_system: EnemyTimerSystem = null
	var qi_regen_system: QiRegenSystem = null
	var realtime_buff_system: RealtimeBuffSystem = null
	var auto_draw_system: AutoDrawSystem = null
	var win_loss_monitor: WinLossMonitor = null
	var card_pacing_system: CardPacingSystem = null

	# === v3.0 确定性 RNG ===
	var rng: DeterministicRNG = null

	# === v4.0 事件流 — live battle 录制 ===
	var event_stream: EventStream = null
	var trigger_ctx: BattleContext = null


# ============================================================
# Bootstrap
# ============================================================


## bootstrap 入口
## rng: 确定性 RNG（null = 默认 RNG(0) 兜底）
static func bootstrap(screen: Node, player: PlayerActor, fsm: BattleStateMachine, elapsed_seconds: float, rng: DeterministicRNG = null, encounter_id_override: String = "") -> BootResult:
	var result := BootResult.new()

	# 默认 RNG（生产环境兜底，SimulationKernel 会显式传入）
	var _rng: DeterministicRNG = rng if rng else DeterministicRNG.new(0)
	result.rng = _rng


	# --- Encounter ---
	result.encounter = _load_encounter(encounter_id_override)
	if result.encounter == null:
		return null

	# 守卫: 空牌组进入战斗为非法状态
	if player.master_deck.is_empty():
		push_error("BattleBootstrapper: player.master_deck is empty — 拒绝初始化战斗")
		return null

	# --- Core Systems ---
	result.deck_manager = DeckManager.new()
	result.deck_manager.rng = _rng
	result.deck_manager.initialize(player.master_deck.duplicate())

	var trigger_ctx: BattleContext = BattleContext.new()
	trigger_ctx.actor = player
	trigger_ctx.elapsed_seconds = elapsed_seconds

	# --- EventStream — 录制 VM opcode 事件 ---
	var _event_stream := EventStream.new()
	result.event_stream = _event_stream
	trigger_ctx.event_stream = _event_stream
	result.trigger_ctx = trigger_ctx
	result.card_trigger_router = CardTriggerRouter.new(trigger_ctx)
	result.deck_manager.trigger_router = result.card_trigger_router

	QiFlowSystem.init_pathway_capacities(player)

	result.card_repo = CardRepository.new()
	if player.get("card_instance_registry") != null:
		result.card_repo.load_from_dict(player.card_instance_registry)

	# --- Context Factory ---
	result.context_factory = BattleContextFactory.new()
	result.context_factory.player = player
	result.context_factory.deck_manager = result.deck_manager
	result.context_factory.rng = _rng
	result.context_factory.event_stream = _event_stream

	# --- Snapshot Service ---
	result.snapshot_service = SnapshotService.new()
	result.snapshot_service.player = player
	result.snapshot_service.deck_manager = result.deck_manager

	# --- Target Manager ---
	result.target_manager = TargetManager.new()

	# === 即时制新服务 ===

	# BattleClock (Node, 挂载到 scene tree, 默认暂停)
	result.battle_clock = BattleClock.new()
	result.battle_clock.name = "BattleClock"
	result.battle_clock.paused = true
	screen.add_child(result.battle_clock)

	# CooldownManager
	result.cooldown_manager = CooldownManager.new()

	# DeckManager 接入 CooldownManager
	result.deck_manager.cooldown_manager = result.cooldown_manager

	# EffectQueue
	result.effect_queue = EffectQueue.new()
	result.effect_queue.resolver = Resolver
	result.effect_queue.target_manager = result.target_manager

	# QiRegenSystem
	result.qi_regen_system = QiRegenSystem.new()

	# EnemyTimerSystem — 注入 RNG
	result.enemy_timer_system = EnemyTimerSystem.new()
	result.enemy_timer_system.player = player
	result.enemy_timer_system.rng = _rng
	result.enemy_timer_system.qi_circulation = null  # 后面设置

	# RealtimeBuffSystem (纯静态, 无需注入)
	result.realtime_buff_system = RealtimeBuffSystem.new()

	# AutoDrawSystem
	result.auto_draw_system = AutoDrawSystem.new()
	result.auto_draw_system.deck_manager = result.deck_manager
	result.auto_draw_system.cooldown_manager = result.cooldown_manager

	# CardPacingSystem — 根据玩家速度计算抽牌间隔
	result.card_pacing_system = CardPacingSystem.new()
	result.auto_draw_system.pacing_system = result.card_pacing_system
	result.auto_draw_system.apply_pacing(player.speed, 0.0)

	# 接线 speed 变更 — 走中间层 request_pacing_update（语义稳定 API）
	if not player.speed_changed.is_connected(result.auto_draw_system.request_pacing_update):
		player.speed_changed.connect(result.auto_draw_system.request_pacing_update)

	# WinLossMonitor
	result.win_loss_monitor = WinLossMonitor.new()
	result.win_loss_monitor.player = player

	# === 填充 BattleContext 即时制引用 (Phase 3) ===
	trigger_ctx.effect_queue = result.effect_queue
	trigger_ctx.cooldown_mgr = result.cooldown_manager
	trigger_ctx.enemy_timer = result.enemy_timer_system

	# --- Qi Circulation ---
	result.qi_circulation = QiCirculationService.new()
	result.qi_circulation.screen = screen
	result.qi_circulation.deck_manager = result.deck_manager

	# EnemyTimerSystem 现在有了 qi_circulation 引用
	result.enemy_timer_system.qi_circulation = result.qi_circulation

	# --- Forge Service ---
	result.forge_service = ForgeService.new()
	result.forge_service.player = player
	result.forge_service.deck_manager = result.deck_manager
	result.forge_service.card_repo = result.card_repo
	result.forge_service.target_manager = result.target_manager
	result.forge_service.context_factory = result.context_factory
	_wire_forge_signals(result.forge_service, screen)

	# --- Card Play Service ---
	result.card_play_service = CardPlayService.new()
	result.card_play_service.player = player
	result.card_play_service.deck_manager = result.deck_manager
	result.card_play_service.card_repo = result.card_repo
	result.card_play_service.target_manager = result.target_manager
	result.card_play_service.context_factory = result.context_factory
	# 接入 EffectQueue
	result.card_play_service.effect_queue = result.effect_queue

	# --- Pathway Service ---
	result.pathway_service = PathwayService.new()
	result.pathway_service.player = player
	result.pathway_service.deck_manager = result.deck_manager

	# --- Battle Flow Orchestrator ---
	result.flow_orchestrator = BattleFlowOrchestrator.new()
	result.flow_orchestrator.player = player
	result.flow_orchestrator.screen = screen
	result.flow_orchestrator.deck_manager = result.deck_manager
	result.flow_orchestrator.forge_service = result.forge_service
	result.flow_orchestrator.pathway_service = result.pathway_service
	result.flow_orchestrator.card_play_service = result.card_play_service
	result.flow_orchestrator.context_factory = result.context_factory

	# --- Selection Dispatcher ---
	result.selection_dispatcher = SelectionDispatcher.new()
	result.selection_dispatcher.register(result.forge_service, "on_selection_completed", "on_selection_cancelled")
	result.selection_dispatcher.register(result.effect_queue, "on_selection_completed", "")
	result.selection_dispatcher.effect_execution_done.connect(
		func(d: Dictionary):
			if screen.has_method("notify_effect_execution_done"):
				screen.notify_effect_execution_done(d)
	)
	# EffectQueue.effect_finished → CardPlayService.on_effect_finished (路由卡牌)
	result.effect_queue.effect_finished.connect(result.card_play_service.on_effect_finished)
	# CardPlayService.execution_done → screen (通知 UI)
	result.card_play_service.execution_done.connect(
		func(d: Dictionary):
			if screen.has_method("notify_effect_execution_done"):
				screen.notify_effect_execution_done(d)
	)

	result.target_manager.selection_completed.connect(result.selection_dispatcher.dispatch_completed)
	result.target_manager.selection_cancelled.connect(result.selection_dispatcher.dispatch_cancelled)

	# === 实时系统信号接线 ===

	# BattleClock.tick → AutoDrawSystem
	result.battle_clock.tick.connect(
		func(_tick_num: int, delta: float):
			result.auto_draw_system.tick(delta)
	)

	# BattleClock.battle_second → ArtifactManager (由 controller 处理)
	# BattleClock.battle_second → WinLossMonitor (由 controller 处理)

	return result


# ============================================================
# Internal — Signal Wiring
# ============================================================


static func _wire_forge_signals(forge: ForgeService, sc: Node) -> void:
	if sc.has_method("show_forge_result"):
		forge.forge_result_ready.connect(sc.show_forge_result)
	if sc.has_method("show_forge_hint"):
		forge.forge_hint_changed.connect(sc.show_forge_hint)
	if sc.has_method("notify_effect_execution_done"):
		forge.forge_finished.connect(sc.notify_effect_execution_done)
	if sc.has_method("clear_forge_ui"):
		forge.forge_cancelled.connect(sc.clear_forge_ui)


# ============================================================
# Internal — Encounter Loading
# ============================================================


static func _load_encounter(override_id: String = "") -> EncounterData:
	if not override_id.is_empty():
		var ov_path: String = "res://resources/encounter_data/" + override_id + ".tres"
		if ResourceLoader.exists(ov_path):
			return load(ov_path) as EncounterData
		return null
	var chapter: ChapterData = GameManager.current_chapter_data
	var enc_id: String = "ch1_encounter_1"
	if chapter != null:
		var node_idx: int = GameManager.current_map_node_index
		if node_idx >= 0 and node_idx < chapter.map_nodes.size():
			var node = chapter.map_nodes[node_idx]
			if not node.encounter_id.is_empty():
				enc_id = node.encounter_id
	var path: String = "res://resources/encounter_data/" + enc_id + ".tres"
	if ResourceLoader.exists(path):
		return load(path) as EncounterData
	return null
