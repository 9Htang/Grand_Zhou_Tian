# ============================================================
# 大周天 — ReplayController (回放控制器)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 回放控制中枢 — 管理 ReplayCursor 的生命周期 + 事件分发。
# Cursor = 时间机器，Controller = 播放器/控制台/调试中枢。
#
# 职责:
#   1. 控制 ReplayCursor（play / pause / seek / step）
#   2. 驱动事件输出（通过 signal 或直接推送到 renderer）
#   3. 管理播放速度（time scale）
#   4. 提供统一 API（给按钮 / UI / 快捷键调用）
#
# 红线:
#   - 不改 simulation state
#   - 不做 UI 渲染
#   - 不做逻辑判断
# ============================================================
class_name ReplayController
extends Node


# ============================================================
# Signals
# ============================================================

## 事件被消费时发射（UI 层监听此信号更新显示）
signal event_emitted(event: SimulationEvent)

## tick 变化时发射
signal tick_changed(tick: int)

## 播放状态变化
signal play_state_changed(playing: bool)

## 回放结束
signal replay_finished()

## 回放开始
signal replay_started()


# ============================================================
# State
# ============================================================

## 时间轴游标
var cursor: ReplayCursor = null

## 绑定的渲染器（可选 — 也可以纯 signal 驱动）
var renderer: Node = null

## 是否正在播放
var playing: bool = false

## 播放速度倍率: 1.0 = 实时, 2.0 = 双倍速, 0.5 = 半速
var speed: float = 1.0

## 事件间时间累加器（秒）
var _tick_accumulator: float = 0.0

## 基础 tick 间隔（秒）— 对应实时播放时每事件的最小间隔
## 默认 0.05s = 仿真内核 DEFAULT_TICK
var base_tick_interval: float = 0.05

## 是否启用逐 tick 播放模式（true = step_tick, false = step_forward）
var tick_mode: bool = true

## 是否循环播放
var loop: bool = false


# ============================================================
# Public — Bind
# ============================================================

## 绑定 SimulationRun 数据
func bind(run: SimulationRun) -> void:
	cursor = ReplayCursor.new()
	cursor.bind(run)
	if run.config and run.config.tick_rate > 0.0:
		base_tick_interval = run.config.tick_rate
	playing = false
	_tick_accumulator = 0.0


## 绑定渲染器节点
func bind_renderer(node: Node) -> void:
	renderer = node


# ============================================================
# Public — Playback Control
# ============================================================

## 开始/恢复播放
func play() -> void:
	if cursor == null:
		return
	if cursor.is_finished():
		cursor.reset()
	playing = true
	play_state_changed.emit(true)
	replay_started.emit()


## 暂停播放
func pause() -> void:
	playing = false
	play_state_changed.emit(false)


## 切换播放/暂停
func toggle_play() -> void:
	if playing:
		pause()
	else:
		play()


## 停止并重置到开头
func stop() -> void:
	pause()
	if cursor:
		cursor.reset()
	tick_changed.emit(0)


# ============================================================
# Public — Seek
# ============================================================

## 跳转到指定 tick
func seek(tick: int) -> void:
	if cursor == null:
		return
	cursor.seek(tick)
	tick_changed.emit(cursor.get_current_tick())


## 跳转到指定事件索引
func seek_event(index: int) -> void:
	if cursor == null:
		return
	cursor.seek_event(index)
	tick_changed.emit(cursor.get_current_tick())


## 跳转到开头
func seek_start() -> void:
	if cursor:
		cursor.seek_start()
		tick_changed.emit(0)


## 跳转到末尾
func seek_end() -> void:
	if cursor:
		cursor.seek_end()
		tick_changed.emit(cursor.get_current_tick())


# ============================================================
# Public — Step
# ============================================================

## 前进一步（事件级或 tick 级，取决于 tick_mode）
func step() -> void:
	if cursor == null or cursor.is_finished():
		return

	if tick_mode:
		_step_tick()
	else:
		_step_event()


## 后退一步
func step_back() -> void:
	if cursor == null or cursor.is_at_start():
		return

	if tick_mode:
		var events: Array[SimulationEvent] = cursor.step_tick_backward()
		for e in events:
			_dispatch_event(e)
	else:
		var e: SimulationEvent = cursor.step_backward()
		if e:
			_dispatch_event(e)

	tick_changed.emit(cursor.get_current_tick())


# ============================================================
# Public — Speed
# ============================================================

## 设置播放速度倍率
func set_speed(s: float) -> void:
	speed = clampf(s, 0.1, 20.0)


## 获取当前速度
func get_speed() -> float:
	return speed


# ============================================================
# Public — Mode
# ============================================================

## 切换逐 tick / 逐事件模式
func set_tick_mode(enabled: bool) -> void:
	tick_mode = enabled


# ============================================================
# Public — Query
# ============================================================

## 当前 tick
func get_current_tick() -> int:
	return cursor.get_current_tick() if cursor else 0


## 当前事件索引
func get_current_event_index() -> int:
	return cursor.get_current_event_index() if cursor else 0


## 总 tick 数
func get_tick_count() -> int:
	return cursor.tick_count() if cursor else 0


## 总事件数
func get_event_count() -> int:
	return cursor.event_count() if cursor else 0


## 全局进度 [0.0, 1.0]
func get_progress() -> float:
	return cursor.global_progress() if cursor else 0.0


## tick 内进度 [0.0, 1.0]
func get_tick_progress() -> float:
	return cursor.tick_progress() if cursor else 0.0


## 是否播放完毕
func is_finished() -> bool:
	return cursor.is_finished() if cursor else true


## 是否正在播放
func is_playing() -> bool:
	return playing


# ============================================================
# Godot — Process
# ============================================================

func _process(delta: float) -> void:
	if not playing or cursor == null:
		return

	_tick_accumulator += delta * speed

	while _tick_accumulator >= base_tick_interval:
		_tick_accumulator -= base_tick_interval

		if cursor.is_finished():
			if loop:
				cursor.reset()
				tick_changed.emit(0)
			else:
				playing = false
				play_state_changed.emit(false)
				replay_finished.emit()
				return

		if tick_mode:
			_step_tick()
		else:
			_step_event()


# ============================================================
# Internal — Step Dispatch
# ============================================================

## 前进一个事件
func _step_event() -> void:
	var e: SimulationEvent = cursor.step_forward()
	if e == null:
		return
	_dispatch_event(e)


## 前进一个 tick
func _step_tick() -> void:
	var events: Array[SimulationEvent] = cursor.step_tick()
	for e in events:
		_dispatch_event(e)

	if not events.is_empty():
		tick_changed.emit(cursor.get_current_tick())


## 分发事件到 signal + renderer
func _dispatch_event(event: SimulationEvent) -> void:
	event_emitted.emit(event)

	if renderer and renderer.has_method("apply_event"):
		renderer.apply_event(event)
