# ============================================================
# 大周天 — BattleController (战斗流程编排器 — L1, 即时制)
# ============================================================
# 四层定位: L1 Systems Layer — 纯 FSM 运行时 + 服务委托
#
# 即时制改造:
#   -  _setup_realtime_systems() 接线 BattleClock → 各子系统
#   - enemy_timer_system
#   - 胜负检测委托给 WinLossMonitor
#   - 状态衰减委托给 RealtimeBuffSystem (buff 衰减) + QiRegenSystem (灵气回复)
#
# === 红线 ===
#   ❌ 不做服务创建 (DI)     → BattleBootstrapper
#   ❌ 不做信号接线           → BattleBootstrapper
#   ❌ 不做 domain 计算       → L2 Service
#   ❌ 不做决策               → BattleFlowOrchestrator
#   ❌ 不调 UI 方法           → signal 转发
# ============================================================
class_name BattleController
extends RefCounted


# === Injected by BattleScreen ===
var screen: Node = null
var player: PlayerActor = null
var fsm: BattleStateMachine = null

# === 原有服务 (Injected by BootResult) ===
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
var current_encounter: EncounterData = null

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

# === v4.0 战斗录制器 ===
var battle_recorder: BattleRecorder = null
var _trigger_ctx: BattleContext = null

# === Runtime State ===
var enemies: Array[EnemyActor] = []


# ============================================================
# Initialization
# ============================================================

func initialize(p_screen: Node, p_player: PlayerActor, p_fsm: BattleStateMachine) -> void:
	screen = p_screen
	player = p_player
	fsm = p_fsm


func inject_boot_result(br: BattleBootstrapper.BootResult) -> void:
	# 原有服务
	deck_manager = br.deck_manager
	card_repo = br.card_repo
	target_manager = br.target_manager
	card_trigger_router = br.card_trigger_router
	context_factory = br.context_factory
	snapshot_service = br.snapshot_service
	qi_circulation = br.qi_circulation
	forge_service = br.forge_service
	card_play_service = br.card_play_service
	pathway_service = br.pathway_service
	selection_dispatcher = br.selection_dispatcher
	flow_orchestrator = br.flow_orchestrator
	current_encounter = br.encounter

	# 即时制新服务
	battle_clock = br.battle_clock
	effect_queue = br.effect_queue
	cooldown_manager = br.cooldown_manager
	enemy_timer_system = br.enemy_timer_system
	qi_regen_system = br.qi_regen_system
	realtime_buff_system = br.realtime_buff_system
	auto_draw_system = br.auto_draw_system
	win_loss_monitor = br.win_loss_monitor
	card_pacing_system = br.card_pacing_system

	# --- BattleRecorder ---
	if br.event_stream:
		battle_recorder = BattleRecorder.new()
		battle_recorder.event_stream = br.event_stream
		battle_recorder.started = true
	_trigger_ctx = br.trigger_ctx

	# 同步敌人引用
	context_factory.enemies = enemies
	snapshot_service.enemies = enemies
	win_loss_monitor.set_enemies(enemies)

	# 接线实时系统
	_setup_realtime_systems()


# ============================================================
# Battle Start
# ============================================================

func start_battle() -> bool:
	var br: BattleBootstrapper.BootResult = BattleBootstrapper.bootstrap(screen, player, fsm, GameManager.elapsed_seconds)
	if br == null:
		return false
	inject_boot_result(br)

	# 初始抽牌 (L1 持有"何时抽牌"的编排权)
	var hand_size: int = BattleRules.get_initial_hand_size()
	deck_manager.draw_cards(hand_size)

	# FSM 初始状态已是 PLAYING, 直接开始时钟
	battle_clock.reset()
	return true


# ============================================================
# Real-Time System Wiring (L1 纯接线)
# ============================================================

func _setup_realtime_systems() -> void:
	# BattleClock.tick → 各子系统 (0.25s)
	battle_clock.tick.connect(_on_clock_tick)

	# BattleClock.delta_tick → 每帧轻量更新 (Phase 4)
	battle_clock.delta_tick.connect(_on_delta_tick)

	# BattleClock.battle_second → 慢速检测 (1s)
	battle_clock.battle_second.connect(_on_battle_second)

	# EnemyTimerSystem 信号
	enemy_timer_system.enemy_action_ready.connect(_on_enemy_action_ready)
	enemy_timer_system.enemy_qi_circulation_ready.connect(_on_enemy_qi_ready)

	# WinLossMonitor 信号
	win_loss_monitor.battle_ended.connect(_on_battle_ended)

	# EffectQueue 信号 (Phase 4)
	effect_queue.queue_drained.connect(_on_queue_drained)
	effect_queue.notable_event.connect(_on_notable_event)

	# FSM 暂停/恢复 → BattleClock
	fsm.playing.connect(func(): battle_clock.paused = false)
	fsm.paused.connect(func(): battle_clock.paused = true)


# ============================================================
# Clock Tick Handler — 每 0.25s 分发到各子系统
# ============================================================

func _on_clock_tick(tick_number: int, delta: float) -> void:
	# BattleRecorder: tick
	if battle_recorder and battle_recorder.started:
		battle_recorder.advance_tick(delta)
	if _trigger_ctx:
		_trigger_ctx.current_tick = tick_number
	if context_factory:
		context_factory.current_tick = tick_number

	if fsm.is_terminal():
		return

	# 1. 灵气连续回复
	QiRegenSystem.tick_actor(player, delta)
	QiRegenSystem.tick_enemies(enemies, delta)

	# 2. 灵气流动 (单步 tick)
	qi_circulation.run_one_tick(player)
	for enemy in enemies:
		if enemy and enemy.hp > 0 and enemy.active_techniques.size() > 0:
			qi_circulation.run_one_tick(enemy)

	# 3. 卡牌冷却递减 → 过期卡牌进入弃牌堆
	var expired: Array[String] = cooldown_manager.tick(delta)
	deck_manager.process_expired_cooldowns(expired)

	# 4. 敌人计时器递减
	enemy_timer_system.tick(delta)

	# 5. Buff 实时衰减 (每 4 ticks ≈ 1s 执行一次, 减少开销)
	if tick_number % BattleClock.TICKS_PER_SECOND == 0:
		RealtimeBuffSystem.tick_player_buffs(player, delta * BattleClock.TICKS_PER_SECOND)
		RealtimeBuffSystem.tick_enemy_statuses(enemies, delta * BattleClock.TICKS_PER_SECOND)

	# 6. 效果队列推进
	effect_queue.execute_next(delta)

	# 7. FSM: 队列非空闲 → RESOLVING
	if not effect_queue.is_idle and fsm.current_state == BattleStateMachine.BattleState.PLAYING:
		fsm.transition_to(BattleStateMachine.BattleState.RESOLVING)


# ============================================================
# Delta Tick Handler — 每帧轻量更新 (Phase 4)
# ============================================================

func _on_delta_tick(delta: float) -> void:
	if fsm.is_terminal():
		return
	# 每帧: 灵气流动可视化 + 回路检测 (轻量, 不做重量计算)
	# 重计算仍在 _on_clock_tick 中执行
	pass  # 预留, UI 驱动层可监听此信号做动画


# ============================================================
# Battle Second Handler — 每 1s 慢速检测
# ============================================================

func _on_battle_second(tick_number: int) -> void:
	if fsm.is_terminal():
		return

	# 法宝被动轮询
	ArtifactManager.poll_passive(player, tick_number)

	# 法宝充能
	ArtifactManager.charge_artifacts(player, player.qi_gather_rate)

	# 胜负检测
	win_loss_monitor.check()


# ============================================================
# Enemy Signal Handlers
# ============================================================

func _on_enemy_action_ready(enemy: EnemyActor, action: EnemyActionData) -> void:
	var intent_ctx: BattleContext = BattleContext.new()
	intent_ctx.actor = player
	var ectx: EffectContext = EffectContext.new()
	var targets: Array[Node] = [enemy]
	ectx.init_battle(player, enemy, targets, intent_ctx, null)
	EnemyIntents.execute_intent(action, ectx)


func _on_enemy_qi_ready(enemy: EnemyActor) -> void:
	if enemy.erosion_targets.is_empty():
		EnemyAI.select_erosion_targets(enemy)
	qi_circulation.run_one_tick(enemy)


# ============================================================
# Battle End Handler
# ============================================================

func _on_battle_ended(outcome: int) -> void:
	match outcome:
		WinLossMonitor.BattleOutcome.WON:
			fsm.transition_to(BattleStateMachine.BattleState.BATTLE_WON)
		WinLossMonitor.BattleOutcome.LOST:
			fsm.transition_to(BattleStateMachine.BattleState.BATTLE_LOST)


# ============================================================
# Queue Signal Handlers (Phase 4)
# ============================================================

## 效果队列全部消化 → 回到 PLAYING
func _on_queue_drained() -> void:
	if fsm.current_state == BattleStateMachine.BattleState.RESOLVING:
		fsm.transition_to(BattleStateMachine.BattleState.PLAYING)


## 显著事件 (法宝触发/回路完成) → DIGEST 慢动作窗口
func _on_notable_event(_description: String) -> void:
	if fsm.current_state in [BattleStateMachine.BattleState.PLAYING, BattleStateMachine.BattleState.RESOLVING]:
		fsm.transition_to(BattleStateMachine.BattleState.DIGEST)
		Engine.time_scale = 0.15
		# 真实时间 0.4s 后恢复 (不受 time_scale 影响)
		battle_clock.get_tree().create_timer(0.4, true, false, true).timeout.connect(_on_digest_end)


func _on_digest_end() -> void:
	Engine.time_scale = 1.0
	if fsm.current_state == BattleStateMachine.BattleState.DIGEST:
		if effect_queue.is_idle:
			fsm.transition_to(BattleStateMachine.BattleState.PLAYING)
		else:
			fsm.transition_to(BattleStateMachine.BattleState.RESOLVING)


# ============================================================
# Pause / Resume (Phase 6) — 通用暂停：手动暂停 + 交互暂停
# ============================================================
# 两层暂停模型:
#   _manual_pause      — 暂停按钮切换，持久直到玩家手动恢复
#   _interaction_depth — 交互操作嵌套计数 (拖拽/查看/选择/冲穴)
#   实际暂停 = _manual_pause OR _interaction_depth > 0
# ============================================================

## 手动暂停标志 (暂停按钮切换)
var _manual_pause: bool = false
## 交互操作嵌套深度 (>0 表示有交互在进行)
var _interaction_depth: int = 0


## 交互操作开始 — 拖拽/查看/选择/冲穴等需要思考时间的操作
func begin_interaction() -> void:
	_interaction_depth += 1
	_apply_pause_state()


## 交互操作结束 — 所有嵌套交互都结束后才可能恢复
func end_interaction() -> void:
	if _interaction_depth > 0:
		_interaction_depth -= 1
	_apply_pause_state()


## 手动暂停切换 — 由暂停按钮调用
func toggle_manual_pause() -> void:
	if fsm.is_terminal():
		return
	_manual_pause = not _manual_pause
	_apply_pause_state()


## 根据 _manual_pause 和 _interaction_depth 决定实际暂停状态
func _apply_pause_state() -> void:
	var should_pause: bool = _manual_pause or _interaction_depth > 0
	if should_pause:
		if fsm.current_state != BattleStateMachine.BattleState.PAUSED:
			request_pause()
	else:
		if fsm.current_state == BattleStateMachine.BattleState.PAUSED:
			request_resume()


## 请求暂停 — 在 EffectProgram 完成后生效
func request_pause() -> void:
	if effect_queue.is_idle:
		_do_pause()
	else:
		effect_queue.pause_requested = true


## 恢复 — 解除暂停并恢复时钟
func request_resume() -> void:
	Engine.time_scale = 1.0
	battle_clock.paused = false
	enemy_timer_system.paused = false
	## 清除效果队列的延迟暂停请求（交互已在队列空闲前结束）
	effect_queue.pause_requested = false
	if fsm.current_state == BattleStateMachine.BattleState.PAUSED:
		fsm.transition_to(BattleStateMachine.BattleState.PLAYING)
	effect_queue.resume()


func _do_pause() -> void:
	battle_clock.paused = true
	enemy_timer_system.paused = true
	fsm.transition_to(BattleStateMachine.BattleState.PAUSED)


# ============================================================
# Battle End Actions
# ============================================================

func execute_battle_won() -> Dictionary:
	# BattleRecorder: finish
	if battle_recorder and battle_recorder.started:
		battle_recorder.finish(true)

	if card_repo:
		player.set("card_instance_registry", card_repo.save_to_dict())
	player.save_to_gm()

	var ectx: EffectContext = EffectContext.new()
	ectx.init_map(GameManager)
	ectx.progression.add_cultivation(current_encounter.cultivation_reward)
	ectx.progression.add_gold(current_encounter.gold_reward)

	return {"is_boss": _is_boss_encounter()}


func execute_battle_lost() -> void:
	# BattleRecorder: finish
	if battle_recorder and battle_recorder.started:
		battle_recorder.finish(false)

	if card_repo:
		player.set("card_instance_registry", card_repo.save_to_dict())
	player.save_to_gm()


func _is_boss_encounter() -> bool:
	var chapter: ChapterData = GameManager.current_chapter_data
	if chapter == null:
		return false
	var idx: int = GameManager.current_map_node_index
	if idx < 0 or idx >= chapter.map_nodes.size():
		return false
	return CombatService.is_boss_encounter(chapter.map_nodes[idx].node_type)


## 战斗结束检测 (委托 WinLossMonitor, 保留给 DragInputHandler 调用)
func check_battle_end() -> int:
	if win_loss_monitor:
		return win_loss_monitor.check()
	return CombatService.check_battle_end(player.hp, enemies)


# ============================================================
# Card Play — L1 纯分发
# ============================================================

func play_card(card_data: CardData) -> Dictionary:
	# BattleRecorder: record
	if battle_recorder and battle_recorder.started and card_data:
		battle_recorder.record_card_played(card_data.id, -1, -1)

	return flow_orchestrator.play_card(card_data, GameManager.elapsed_seconds).to_dict()


func activate_technique_via_card(card_data: CardData) -> Dictionary:
	if card_data.behavior != CardData.CardBehavior.TECHNIQUE:
		return {"success": false}
	return flow_orchestrator.play_card(card_data, GameManager.elapsed_seconds).to_dict()


func cancel_technique(tech: TechniqueData) -> bool:
	player.deactivate_technique(tech)
	var card: CardData = CardDatabase.get_card("technique_" + tech.id)
	if card:
		deck_manager.return_to_hand(card)
	return true


func discard_card(card_data: CardData) -> void:
	deck_manager.discard_single(card_data)


# ============================================================
# Pathway / Forge — L1 委托
# ============================================================

func start_pathway_selection(card_data: CardData) -> void:  pathway_service.start_selection(card_data)
func select_pathway_node(node_idx: int) -> int:              return pathway_service.select_node(node_idx)
func cancel_pathway_selection() -> void:                     pathway_service.cancel()
func is_pathway_selection_active() -> bool:                  return pathway_service.is_active()
func get_pathway_selection_from() -> int:                    return pathway_service.get_selection_from()

func is_forge_active() -> bool:  return forge_service.is_active()


# ============================================================
# Cancel / Query / Enemy
# ============================================================

func cancel_current_operation() -> bool:
	if forge_service.is_active():
		forge_service.cancel()
		if target_manager and target_manager.is_selecting():
			target_manager.cancel()
		effect_queue.cancel_all()
		return true
	if pathway_service.is_active():
		pathway_service.cancel()
		return true
	if target_manager and target_manager.is_selecting():
		target_manager.cancel()
		return true
	return false


func is_card_playable(card_data: CardData) -> bool:
	# 灵气是唯一制衡 — 无冷却门控
	return QiPoolManager.can_afford(player, card_data.cost)


func get_selection_type() -> String:
	if target_manager and target_manager.is_selecting():
		return target_manager.pending_selector.get("type", "")
	return ""


func is_selecting_cards() -> bool:
	return target_manager != null and target_manager.is_selecting() and target_manager.pending_selector.get("type", "") == "card"


func is_input_blocked() -> bool:
	if fsm == null:
		return true
	return not fsm.is_playing()


func get_enemies() -> Array[EnemyActor]:          return enemies
func get_current_encounter() -> EncounterData:    return current_encounter


func get_encounter_enemy_ids() -> Array[String]:
	if current_encounter:
		return current_encounter.enemy_ids
	return []


func add_enemy(actor: EnemyActor, data: EnemyData = null) -> void:
	enemies.append(actor)
	if data and enemy_timer_system:
		enemy_timer_system.add_enemy(actor, data)


func clear_enemies() -> void:
	enemies.clear()
	if enemy_timer_system:
		enemy_timer_system.clear_all()


# ============================================================
# Snapshot — L1 组装
# ============================================================

func build_snapshot() -> BattleSnapshot:
	var snap: BattleSnapshot = snapshot_service.build()
	snap.collision_data = qi_circulation.last_collision if qi_circulation else null
	snap.is_selecting_cards = is_selecting_cards()
	snap.is_input_blocked = is_input_blocked()
	return snap


# ============================================================
# Replay — SimulationRun 构建 + 导出
# ============================================================

func get_simulation_run() -> SimulationRun:
	if battle_recorder == null or not battle_recorder.finished:
		push_warning("BattleController: no finished recorder — cannot build SimulationRun")
		return null
	return battle_recorder.build_simulation_run()

func save_replay(path: String) -> bool:
	var run := get_simulation_run()
	if run == null:
		return false
	return ReplayExporter.save_to_file(ReplayExporter.export(run), path)
