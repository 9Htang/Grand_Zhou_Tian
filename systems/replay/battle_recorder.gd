# ============================================================
# 大周天 — BattleRecorder (战斗录制器)
# ============================================================
# 四层定位: L1 Systems Layer — systems/replay/
#
# 战斗事件采集器 — 监听战斗运行过程，把"真实战斗"转成可回放事件流。
# 不是战斗逻辑、不是 UI、不是规则执行者 — 纯粹的事件采集层。
#
# 职责:
#   1. 收集 VM 事件 (damage/heal/block/qi/status)
#   2. 收集输入事件 (card_played)
#   3. 记录 tick 推进
#   4. 生成 SimulationRun
#
# 使用:
#   recorder.start()
#   ... 战斗进行中，自动通过 init_battle / VM opcode 推送事件 ...
#   recorder.finish(win, player, enemies)
#   var run = recorder.build_simulation_run(adapter)
#   ReplayExporter.export_to_file(run, "battle_001.replay", adapter)
# ============================================================
class_name BattleRecorder
extends RefCounted


# ============================================================
# State
# ============================================================

## 事件流 — VM opcode / card_played 事件写入此流
var event_stream: EventStream = null

## 输入动作序列（用于 replay 的 ScriptedPolicy）
var actions: Array[Dictionary] = []

## 当前 tick（由外部 battle loop 推进）
var current_tick: int = 0

## 当前时间（秒）
var current_time: float = 0.0

## tick_rate
var tick_rate: float = 0.05

## 是否已启动
var started: bool = false

## 是否已结束
var finished: bool = false

## 战斗结果
var win: bool = false

## 下一个 action ID
var _next_action_id: int = 0


# ============================================================
# Lifecycle
# ============================================================

## 启动录制
func start(p_tick_rate: float = 0.05) -> void:
	event_stream = EventStream.new()
	actions.clear()
	current_tick = 0
	current_time = 0.0
	tick_rate = p_tick_rate
	_next_action_id = 0
	started = true
	finished = false
	win = false


## 结束录制
func finish(p_win: bool) -> void:
	win = p_win
	finished = true
	started = false

	# 发射 battle_end 事件
	event_stream.emit(current_time, "battle_end", "system", "", "recorder",
		{"win": win, "total_ticks": current_tick, "total_actions": actions.size()})


# ============================================================
# Tick Tracking
# ============================================================

## 推进 tick（由 battle clock / controller 调用）
func advance_tick(delta: float) -> void:
	if not started:
		return
	current_time += delta
	current_tick += 1


# ============================================================
# Input Events
# ============================================================

## 记录玩家出牌
func record_card_played(card_id: String, hand_index: int, target_index: int = -1) -> void:
	if not started:
		return
	if card_id.is_empty():
		return

	var action_id: int = _next_action_id
	_next_action_id += 1

	# 写入事件流
	event_stream.emit(current_time, "card_played", "player", "", card_id, {
		"card_id": card_id,
		"card_name": card_id,
		"hand_index": hand_index,
		"target_index": target_index,
		"cost": 0,
	}, -1, "", card_id, 0, 0, 0, "", "", action_id)

	# 写入动作账本
	actions.append({
		"id": action_id,
		"tick": current_tick,
		"type": "PLAY_CARD",
		"card_id": card_id,
		"card_index": hand_index,
		"target_index": target_index,
	})


## 记录跳过回合
func record_skip() -> void:
	if not started:
		return

	var action_id: int = _next_action_id
	_next_action_id += 1

	actions.append({
		"id": action_id,
		"tick": current_tick,
		"type": "SKIP",
		"card_id": "",
		"card_index": -1,
		"target_index": -1,
	})


# ============================================================
# VM Events — 由 EffectContext.event_stream 路径自动写入
# （op_damage / op_heal / op_block 等 opcode 的 if ctx.events: 分支）
#
# 无需手动调用 — 只需在 init_battle 时将 event_stream 注入 EffectContext。
# 本节保留手动记录方法，供非 VM 路径使用。
# ============================================================

## 手动记录 VM 事件（非 VM opcode 路径使用）
func record_vm_event(op_type: String, actor_id: String, target_id: String, payload: Dictionary, source: String = "") -> void:
	if not started:
		return

	event_stream.emit(current_time, op_type, actor_id, target_id, source, payload)


# ============================================================
# Build SimulationRun
# ============================================================

## 从录制数据构建 SimulationRun
func build_simulation_run() -> SimulationRun:
	var run := SimulationRun.new()
	run.seed = 0  # live battle 无确定性种子
	run.replay_version = SimulationRun.REPLAY_VERSION
	run.events = event_stream
	run.actions = actions.duplicate(true)
	run.total_ticks = max(1, current_tick)
	run.win = win
	run.rng_call_count = 0

	# 用最小配置
	var config := SimulationConfig.new()
	config.tick_rate = tick_rate
	run.config = config

	return run


# ============================================================
# Query
# ============================================================

func get_event_count() -> int:
	return event_stream.size() if event_stream else 0


func get_action_count() -> int:
	return actions.size()
