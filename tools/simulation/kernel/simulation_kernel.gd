# ============================================================
# 大周天 — SimulationKernel (确定性仿真内核)
# ============================================================
# 工具层: tools/simulation/kernel/ — 不属于四层运行时架构
#
# 工业级仿真核心 — 三个模式的统一入口:
#   1. Deterministic Run: 同 seed 同结果，CI 回归
#   2. Replay Run: ScriptedPolicy 回放，验证一致性
#   3. Policy Run: AI/Heuristic 决策，训练数据生成
#
# 核心约束:
#   - Kernel is Thin: 不碰战斗规则
#   - RNG is Stream: 全局唯一 RNG 实例
#   - EventStream = Truth: 唯一输出源
#   - Policy is External: 决策与模拟分离
# ============================================================
class_name SimulationKernel
extends RefCounted


# ============================================================
# Constants
# ============================================================

const DEFAULT_TICK: float = 0.05
const INITIAL_HAND_SIZE: int = 5
const LOG_INTERVAL: int = 20


# ============================================================
# State
# ============================================================

var _rng: DeterministicRNG = null
var _events: EventStream = null
var _trajectory: TrajectoryRecorder = null
var _metrics: MetricsEngine = null
var _player: PlayerActor = null
var _tick_number: int = 0
var _current_time: float = 0.0
var _battle_ended: bool = false

## 动作账本 — 纯追加日志，ID 分配 + 录制
var _ledger: ActionLedger = null

## 当前 BootResult 引用（供 save_state / restore_state / is_idle 等跨方法访问）
var _boot_result = null  # BattleBootstrapper.BootResult

## 当前敌人引用（供 restore_state / _apply_restore 使用）
var _enemies: Array = []

## 抽牌节奏确定性快照（replay 用）
var _speed_snapshot: float = 1.0
var _draw_timer_snapshot: float = 0.0
var _draw_interval_snapshot: float = 3.0


# ============================================================
# Public API
# ============================================================


## 运行模拟
## input: SimulationInput (seed + config + policy)
## 返回 SimulationRun
func run(input: SimulationInput) -> SimulationRun:
	# 0. 从 SimulationConfig 同步字段到顶层（种子/tick/时长/自动出牌）
	if input.config != null:
		input.apply_config(input.config)

	_rng = DeterministicRNG.new(input.seed)
	_events = EventStream.new()
	_trajectory = TrajectoryRecorder.new() if input.record_trajectory else null
	_metrics = MetricsEngine.new()
	_tick_number = 0
	_current_time = 0.0
	_battle_ended = false

	_boot_result = null
	_enemies.clear()

	# 0. 初始化动作账本
	_ledger = ActionLedger.new()

	# 1. 创建 MockScreen
	var screen := MockScreen.new()

	# 2. PlayerActor — 必须通过 set_player() 注入
	if _player == null:
		push_error("SimulationKernel.run(): no player set. Call set_player() before run().")
		return null
	var player: PlayerActor = _player

	# 3. Bootstrap — 注入 RNG
	var fsm := BattleStateMachine.new()
	var enc_override: String = input.config.encounter_id if input.config else ""
	var br: BattleBootstrapper.BootResult = BattleBootstrapper.bootstrap(screen, player, fsm, 0.0, _rng, enc_override)
	if br == null:
		return SimulationRun.create(input, _events, [], _trajectory if _trajectory else TrajectoryRecorder.new(), _metrics.build(), _rng.call_count, player, [], _ledger.entries)

	# 从 config 配置自动抽牌参数
	if input.draw_interval > 0.0:
		br.auto_draw_system.draw_interval = input.draw_interval
	br.auto_draw_system.draw_count = input.draw_count if input.draw_count > 0 else 1

	# 4. 从 Encounter 创建敌人
	var enemies: Array[EnemyActor] = _spawn_enemies(br)

	# 5. 注入敌人到服务
	br.context_factory.enemies = enemies
	br.snapshot_service.enemies = enemies
	br.win_loss_monitor.set_enemies(enemies)
	_boot_result = br
	_enemies = enemies

	# 6. 注册敌人计时器
	for i in enemies.size():
		if br.encounter and i < br.encounter.enemy_ids.size():
			var enemy_data: EnemyData = EnemyDatabase.get_enemy(br.encounter.enemy_ids[i])
			if enemy_data:
				br.enemy_timer_system.add_enemy(enemies[i], enemy_data)

	# 7. 初始抽牌
	br.deck_manager.draw_cards(INITIAL_HAND_SIZE)

	# 8. 接线胜负信号
	if not br.win_loss_monitor.battle_ended.is_connected(_on_battle_ended):
		br.win_loss_monitor.battle_ended.connect(_on_battle_ended)

	var hashes: Array[int] = []
	var tick_rate: float = input.tick_rate if input.tick_rate > 0.0 else DEFAULT_TICK

	# 9. 主循环 — 五相 Tick 模型
	while _tick_number < input.max_ticks:
		# === PHASE 0: Snapshot Capture（冻结 tick 起点的决策输入）===
		var snap: Dictionary = _capture_snapshot(br)

		# === PHASE 1: Input Collection（纯函数，只读 snapshot）===
		var pending: SimulationAction = null

		var use_policy: bool = input.policy != null and _needs_decision(snap)
		var use_auto: bool = _wants_auto_play(input)

		if use_policy:
			var obs := SimulationObservation.from_battle(player, enemies, br.deck_manager, _tick_number)
			var legal := _legal_actions_from_snapshot(snap)
			pending = input.policy.select_action(obs, legal)
			# ScriptedPolicy 耗尽时返回 SKIP — 降级到 auto_play
			if pending.type == SimulationAction.Type.SKIP and use_auto:
				pending = _auto_play_decision(snap)
		elif use_auto:
			pending = _auto_play_decision(snap)

		# === PHASE 2: Action Execution（唯一写入 world state 的点）===
		if pending != null:
			_apply_action(pending, br)

		# === PHASE 3: World Tick ===
		br.battle_clock.advance(tick_rate)
		_tick_systems(player, enemies, br, tick_rate)

		# === PHASE 4: Hash ===
		var h := StateHasher.hash_tick(player, enemies, br.deck_manager, _rng)
		hashes.append(h)

		# 轨迹记录
		if _trajectory:
			_trajectory.record(_tick_number, player, enemies, br.deck_manager, _rng)

		_current_time += tick_rate
		_tick_number += 1

		# 终止检测
		if _battle_ended or player.hp <= 0 or _all_enemies_dead(enemies):
			break

	return SimulationRun.create(input, _events, hashes, _trajectory if _trajectory else TrajectoryRecorder.new(), _metrics.build(), _rng.call_count, player, enemies, _ledger.entries)


## 设置玩家引用（由外部测试夹具调用）
func set_player(player: PlayerActor) -> void:
	_player = player


# ============================================================

# ============================================================
# Save / Restore — KernelState
# ============================================================


## 捕获当前游戏状态为可恢复快照
func get_recorded_action_count() -> int:
	return _ledger.entries.size()


func is_idle() -> bool:
	if _boot_result and _boot_result.effect_queue:
		return _boot_result.effect_queue.is_idle
	return true


func is_at_action_boundary() -> bool:
	return _ledger.entries.size() > 0


func save_state(p_vm_ip: int, p_vm_stack: Array, p_event_queue: Array, p_pending: Array, p_trigger_stack: Array) -> KernelState:
	return KernelState.capture(_player, _enemies, _boot_result.deck_manager, _rng, p_vm_ip, p_vm_stack, p_event_queue, p_pending, p_trigger_stack)


## 从快照恢复游戏状态
## 从 Snapshot 数据恢复（直接接受 Dictionary，无需构造 KernelState）
func restore_from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	var state := KernelState.new()
	state.rng = d.get("rng", {})
	state.player = d.get("player", {})
	state.enemies = d.get("enemies", [])
	state.deck = d.get("deck", {})
	state.vm = d.get("vm", {})
	_apply_restore(state)


func restore_state(state: KernelState) -> void:
	_apply_restore(state)


func _apply_restore(state: KernelState) -> void:
	# 1. RNG
	if state.rng.has("state"):
		_rng.restore_state(state.rng)

	# 2. Player
	_restore_actor(_player, state.player)

	# 3. Enemies
	for i in range(min(_enemies.size(), state.enemies.size())):
		var e: EnemyActor = _enemies[i]
		var d: Dictionary = state.enemies[i]
		if e and not d.is_empty():
			_restore_actor(e, d)

	# 4. Deck — 从序列化数据重建牌堆
	if _boot_result and _boot_result.deck_manager:
		_restore_deck(_boot_result.deck_manager, state.deck)


func _restore_actor(actor, d: Dictionary) -> void:
	if actor == null or d.is_empty():
		return
	actor.hp = d.get("hp", actor.hp)
	actor.max_hp = d.get("max_hp", actor.max_hp)
	actor.dantian_qi = d.get("qi", actor.dantian_qi)
	actor.dantian_capacity = d.get("capacity", actor.dantian_capacity)
	actor.current_block = d.get("block", actor.current_block)
	if d.has("realm") and actor.get("realm") != null:
		actor.realm = d.get("realm", actor.realm)
	if d.has("talent") and actor.get("talent") != null:
		actor.talent = d.get("talent", actor.talent)


func _restore_deck(dm, deck_state: Dictionary) -> void:
	dm.draw_pile = _rebuild_cards(deck_state.get("draw", []))
	dm.hand = _rebuild_cards(deck_state.get("hand", []))
	dm.discard_pile = _rebuild_cards(deck_state.get("discard", []))
	dm.exhaust_pile = _rebuild_cards(deck_state.get("exhaust", []))


func _rebuild_cards(data: Array) -> Array[CardData]:
	var result: Array[CardData] = []
	for d in data:
		if d.is_empty():
			continue
		var card_id: String = d.get("id", "")
		if card_id.is_empty():
			continue
		var card: CardData = CardDatabase.get_card(card_id)
		if card:
			var copy: CardData = card.duplicate()
			if d.has("cost"):
				copy.cost = d.get("cost", copy.cost)
			result.append(copy)
	return result

# Tick Dispatch
# ============================================================

func _tick_systems(player: PlayerActor, enemies: Array[EnemyActor], br: BattleBootstrapper.BootResult, delta: float) -> void:
	# 1. 灵气连续回复
	QiRegenSystem.tick_actor(player, delta)
	QiRegenSystem.tick_enemies(enemies, delta)

	# 2. 灵气流动
	if br.qi_circulation:
		br.qi_circulation.run_one_tick(player)
		for enemy in enemies:
			if enemy and enemy.hp > 0 and enemy.active_techniques.size() > 0:
				br.qi_circulation.run_one_tick(enemy)

	# 3. 卡牌冷却递减
	if br.cooldown_manager:
		var expired: Array[String] = br.cooldown_manager.tick(delta)
		br.deck_manager.process_expired_cooldowns(expired)

	# 4. 敌人计时器递减
	if br.enemy_timer_system:
		br.enemy_timer_system.tick(delta)

	# 5. Buff 实时衰减
	if _tick_number % BattleClock.TICKS_PER_SECOND == 0:
		var clock_delta: float = delta * float(BattleClock.TICKS_PER_SECOND)
		RealtimeBuffSystem.tick_player_buffs(player, clock_delta)
		RealtimeBuffSystem.tick_enemy_statuses(enemies, clock_delta)

	# 6. 效果队列推进
	if br.effect_queue:
		br.effect_queue.execute_next(delta)

	# 7. 每秒慢速检测
	if _tick_number > 0 and _tick_number % int(1.0 / max(delta, 0.001)) == 0:
		ArtifactManager.poll_passive(player, _tick_number)
		ArtifactManager.charge_artifacts(player, player.qi_gather_rate)
		br.win_loss_monitor.check()


# ============================================================
# Phase 0: Snapshot Capture
# ============================================================

## 捕获决策所需的最小状态（浅拷贝 hand 的 card_id 列表）
func _capture_snapshot(br: BattleBootstrapper.BootResult) -> Dictionary:
	var hand_info: Array[Dictionary] = []
	for i in br.deck_manager.hand.size():
		var card: CardData = br.deck_manager.hand[i]
		if card:
			hand_info.append({"index": i, "card_id": card.id})
	return {
		"hand": hand_info,
		"hand_size": br.deck_manager.hand.size(),
		"tick": _tick_number,
	}


# ============================================================
# Phase 1: Input Collection（纯函数，只读 snapshot）
# ============================================================

## 是否启用 auto_play
func _wants_auto_play(input: SimulationInput) -> bool:
	return input.execution_mode != SimulationInput.ExecutionMode.REPLAY \
	   and not input.policy \
	   and input.auto_play_enabled


## 从 snapshot 判断是否需要决策
func _needs_decision(snap: Dictionary) -> bool:
	return snap.get("hand_size", 0) > 0


## 从 snapshot 构建合法动作列表（纯函数）
func _legal_actions_from_snapshot(snap: Dictionary) -> Array[SimulationAction]:
	var actions: Array[SimulationAction] = []
	var hand_info: Array = snap.get("hand", [])
	for entry in hand_info:
		actions.append(SimulationAction.play_card(entry.get("index", 0), entry.get("card_id", "")))
	actions.append(SimulationAction.skip())
	return actions


## Auto-play 决策 — 从 snapshot 选取第一张可出牌（纯函数，不读 live world state）
func _auto_play_decision(snap: Dictionary) -> SimulationAction:
	var hand_info: Array = snap.get("hand", [])
	if hand_info.is_empty():
		return null
	var first: Dictionary = hand_info[0]
	return SimulationAction.play_card(first.get("index", 0), first.get("card_id", ""))


# ============================================================
# Phase 2: Action Execution（唯一写入 world state 的点）
# ============================================================

func _apply_action(action: SimulationAction, br: BattleBootstrapper.BootResult) -> void:
	_ledger.stamp(action)

	if action.type == SimulationAction.Type.SKIP:
		_ledger.record(action)
		return
	if action.card_index < 0 or action.card_index >= br.deck_manager.hand.size():
		return
	var card: CardData = br.deck_manager.hand[action.card_index]
	if card == null:
		return

	_ledger.record(action)

	var result: BattleFlowOrchestrator.FlowResult = br.flow_orchestrator.play_card(card, _current_time)
	if result.flow_type == "pathway":
		_auto_complete_pathway(br.flow_orchestrator.player, br)
	if result.played:
		_events.emit(_current_time, "card_played", "player", "", card.id, {
			"card_name": card.display_name, "cost": card.cost,
			"hand_index": action.card_index, "target_index": action.target_index,
			"source_type": "INPUT"
		}, -1, "", card.id, 0, 0, 0, "", "", action.id)
		_metrics.feed(SimulationEvent.new(_current_time, "card_played", "player", "", card.id, {"amount": 1}))
func _auto_complete_pathway(player: PlayerActor, br: BattleBootstrapper.BootResult) -> void:
	var adjacent: Array = player.get_dantian_adjacent_nodes()
	if adjacent.is_empty():
		br.pathway_service.cancel()
		return

	var from_idx: int = adjacent[0]
	br.pathway_service.select_node(from_idx)

	var mer: MeridianMapData = player.base_meridian
	if mer:
		for node in mer.nodes:
			if node and node.unlocked and node.id != from_idx:
				br.pathway_service.select_node(node.id)
				return

	br.pathway_service.cancel()


# ============================================================
# Enemy Spawning
# ============================================================

func _spawn_enemies(br: BattleBootstrapper.BootResult) -> Array[EnemyActor]:
	var enemies: Array[EnemyActor] = []
	if br.encounter == null:
		return enemies

	for enemy_id in br.encounter.enemy_ids:
		var enemy_data: EnemyData = EnemyDatabase.get_enemy(enemy_id)
		if enemy_data == null:
			push_warning("SimulationKernel: enemy not found — %s" % enemy_id)
			continue
		var enemy := EnemyActor.new()
		enemy.name = "EnemyActor_" + enemy_data.display_name
		enemy.initialize_from_data(enemy_data)
		enemies.append(enemy)

	return enemies


# ============================================================
# Helpers
# ============================================================

func _on_battle_ended(_outcome: int) -> void:
	_battle_ended = true


func _all_enemies_dead(enemies: Array[EnemyActor]) -> bool:
	for enemy in enemies:
		if enemy and enemy.hp > 0:
			return false
	return enemies.size() > 0
