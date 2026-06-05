# ============================================================
# 大周天 — ReplayCursor (回放时间轴游标)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 增强版事件游标 — tick 感知 + O(1) seek + 逐帧/逐事件双模式。
# EventCursor 只做 index 导航；ReplayCursor 在此基础上增加:
#   - tick ↔ event_index 双向映射
#   - step_tick() 逐帧播放（同一 tick 内全部事件批量返回）
#   - current_tick_events 缓存（UI 可直接获取"当前帧发生了什么"）
#   - O(1) seek（预建 tick→first_event_index 索引）
#
# 核心原则:
#   - 只读数据，不改 simulation state
#   - 不调用 kernel / 不做逻辑计算
#   - tick 由 event.time / tick_rate 推导
# ============================================================
class_name ReplayCursor
extends RefCounted


# ============================================================
# State
# ============================================================

## 绑定的仿真运行数据（不可变，只读）
var data: SimulationRun = null

## 当前 tick 位置
var tick: int = 0

## 当前事件索引（指向"下一个待消费"事件）
var event_index: int = 0

## 当前 tick 内已缓存的事件列表（UI 用）
var current_tick_events: Array[SimulationEvent] = []

## 每 tick 的事件数 — tick_count_cache[tick] = count
var _tick_event_counts: Array[int] = []

## tick → 首个事件索引的映射 — _tick_index_map[tick] = first_event_index
var _tick_index_map: Array[int] = []

## tick_rate — 从 config 或默认值读取
var tick_rate: float = 0.05

## 事件总数（缓存）
var _event_count: int = 0


# ============================================================
# Public — Bind / Reset
# ============================================================

## 绑定 SimulationRun 并构建索引
func bind(run: SimulationRun) -> void:
	data = run
	tick_rate = run.config.tick_rate if run.config and run.config.tick_rate > 0.0 else 0.05
	_build_index()
	reset()


## 重置游标到起始位置
func reset() -> void:
	tick = 0
	event_index = 0
	current_tick_events.clear()
	_refresh_tick_events()


# ============================================================
# Internal — Index Building
# ============================================================

## 构建 tick→event_index 索引（O(n) 单次扫描）
func _build_index() -> void:
	_tick_index_map.clear()
	_tick_event_counts.clear()

	if data == null or data.events == null:
		_event_count = 0
		return

	var events: Array[SimulationEvent] = data.events.all()
	_event_count = events.size()

	if _event_count == 0:
		return

	var current_tick := -1
	for i in range(_event_count):
		var e: SimulationEvent = events[i]
		var e_tick: int = int(e.time / tick_rate)

		if e_tick != current_tick:
			# 新 tick — 记录首事件索引，补齐中间空隙
			while _tick_index_map.size() <= e_tick:
				_tick_index_map.append(i)
				_tick_event_counts.append(0)
			current_tick = e_tick

		_tick_event_counts[current_tick] += 1


# ============================================================
# Public — Navigation: Event-Level
# ============================================================

## 前进一步（一个事件）— 返回该事件，流结束时返回 null
func step_forward() -> SimulationEvent:
	if data == null or event_index >= _event_count:
		return null

	var events: Array[SimulationEvent] = data.events.all()
	var e: SimulationEvent = events[event_index]
	event_index += 1

	# 更新 tick（事件 time → tick）
	var new_tick: int = int(e.time / tick_rate)
	if new_tick != tick:
		tick = new_tick
		_refresh_tick_events()

	return e


## 后退一步（一个事件）— 返回该事件，已在起点时返回 null
func step_backward() -> SimulationEvent:
	if data == null or event_index <= 0:
		return null

	event_index -= 1
	var events: Array[SimulationEvent] = data.events.all()
	var e: SimulationEvent = events[event_index]

	# 更新 tick
	var new_tick: int = int(e.time / tick_rate)
	if new_tick != tick:
		tick = new_tick
		_refresh_tick_events()

	return e


# ============================================================
# Public — Navigation: Tick-Level
# ============================================================

## 前进一整帧 — 返回该 tick 内全部事件，流结束时返回空数组
func step_tick() -> Array[SimulationEvent]:
	if data == null or event_index >= _event_count:
		return []

	var result: Array[SimulationEvent] = []
	var events: Array[SimulationEvent] = data.events.all()
	var target_tick: int = int(events[event_index].time / tick_rate)

	while event_index < _event_count:
		var e: SimulationEvent = events[event_index]
		var e_tick: int = int(e.time / tick_rate)
		if e_tick != target_tick:
			break
		result.append(e)
		event_index += 1

	tick = target_tick + 1  # 推进到下一 tick
	_refresh_tick_events()
	return result


## 后退一整帧 — 返回该 tick 内全部事件，已在起点时返回空数组
func step_tick_backward() -> Array[SimulationEvent]:
	if data == null or event_index <= 0:
		return []

	# 先退到当前 tick 的起点
	var events: Array[SimulationEvent] = data.events.all()
	var current_front_tick: int = int(events[event_index - 1].time / tick_rate)

	while event_index > 0:
		var prev: SimulationEvent = events[event_index - 1]
		if int(prev.time / tick_rate) != current_front_tick:
			break
		event_index -= 1

	# 再退到上一个 tick
	if event_index == 0:
		tick = 0
		_refresh_tick_events()
		return []

	var prev_tick: int = int(events[event_index - 1].time / tick_rate)
	var result: Array[SimulationEvent] = []

	while event_index > 0:
		var prev: SimulationEvent = events[event_index - 1]
		if int(prev.time / tick_rate) != prev_tick:
			break
		event_index -= 1
		result.push_front(prev)

	tick = prev_tick
	_refresh_tick_events()
	return result


# ============================================================
# Public — Navigation: Seek
# ============================================================

## 跳转到指定 tick
func seek(target_tick: int) -> void:
	if data == null:
		return

	tick = clampi(target_tick, 0, _max_tick())

	# 用预建索引 O(1) 定位首个事件
	if tick < _tick_index_map.size():
		event_index = _tick_index_map[tick]
	else:
		# 目标 tick 超出索引范围 — 直接跳到末尾
		event_index = _event_count

	_refresh_tick_events()


## 跳转到指定事件索引
func seek_event(target_index: int) -> void:
	if data == null:
		return

	event_index = clampi(target_index, 0, _event_count)
	if event_index > 0 and event_index <= _event_count:
		var events: Array[SimulationEvent] = data.events.all()
		tick = int(events[event_index - 1].time / tick_rate)
	else:
		tick = 0

	_refresh_tick_events()


## 跳转到第一个事件
func seek_start() -> void:
	reset()


## 跳转到最后一个事件
func seek_end() -> void:
	if data == null:
		return
	event_index = _event_count
	tick = _max_tick()
	_refresh_tick_events()


# ============================================================
# Public — Query
# ============================================================

## 当前 tick 编号
func get_current_tick() -> int:
	return tick


## 当前事件索引
func get_current_event_index() -> int:
	return event_index


## 预览下一个事件（不推进游标）
func peek_next() -> SimulationEvent:
	if data == null or event_index >= _event_count:
		return null
	return data.events.all()[event_index]


## 预览上一个事件（不推进游标）
func peek_previous() -> SimulationEvent:
	if data == null or event_index <= 0:
		return null
	return data.events.all()[event_index - 1]


## 是否已到达事件流末尾
func is_finished() -> bool:
	return event_index >= _event_count


## 是否在事件流起点
func is_at_start() -> bool:
	return event_index <= 0


## 总 tick 数
func tick_count() -> int:
	return _max_tick() + 1


## 总事件数
func event_count() -> int:
	return _event_count


## 当前 tick 的进度 — [0.0, 1.0]，表示在该 tick 内消费了多少事件
func tick_progress() -> float:
	if _tick_event_counts.size() <= tick or tick < 0:
		return 1.0
	var total_in_tick: int = _tick_event_counts[tick]
	if total_in_tick <= 0:
		return 1.0

	var consumed_in_tick: int = 0
	if tick < _tick_index_map.size():
		var tick_start: int = _tick_index_map[tick]
		consumed_in_tick = max(0, event_index - tick_start)

	return clampf(float(consumed_in_tick) / float(total_in_tick), 0.0, 1.0)


## 全局进度 — [0.0, 1.0]
func global_progress() -> float:
	if _event_count <= 0:
		return 1.0
	return clampf(float(event_index) / float(_event_count), 0.0, 1.0)


# ============================================================
# Internal — Helpers
# ============================================================

## 刷新当前 tick 事件缓存
func _refresh_tick_events() -> void:
	current_tick_events.clear()
	if data == null or event_index <= 0:
		return

	var events: Array[SimulationEvent] = data.events.all()
	# 从 event_index-1 向前回溯，收集当前 tick 的全部事件
	var i: int = event_index - 1
	while i >= 0:
		var e: SimulationEvent = events[i]
		if int(e.time / tick_rate) != tick:
			break
		current_tick_events.push_front(e)
		i -= 1


## 最大 tick 编号
func _max_tick() -> int:
	if data == null:
		return 0
	# 优先用 state_hashes 数量
	if data.state_hashes.size() > 0:
		return data.state_hashes.size() - 1
	# 降级: 扫描最后一个事件
	var events: Array[SimulationEvent] = data.events.all()
	if events.is_empty():
		return 0
	return int(events[events.size() - 1].time / tick_rate)
