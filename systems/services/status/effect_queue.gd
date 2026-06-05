# ============================================================
# 大周天 — EffectQueue (效果串行执行队列 — L2)
# ============================================================
class_name EffectQueue
extends RefCounted


class QueuedEffect:
	var runtime: CardRuntime
	var ctx: BattleContext
	var position: int
	var user_data: Dictionary = {}

	func _init(p_runtime: CardRuntime, p_ctx: BattleContext, p_pos: int) -> void:
		runtime = p_runtime
		ctx = p_ctx
		position = p_pos


enum State {
	IDLE,
	EXECUTING,
	WAITING_SELECTION,
}


var state: int = State.IDLE

signal effect_finished(card_key: String, result: Dictionary, user_data: Dictionary)
signal queue_empty()

# === 即时制新增信号 (Phase 2) ===
## 发射: 队列全部消化完毕 (替代 queue_empty 的语义增强版)
signal queue_drained()
## 发射: 显著事件 (法宝触发/回路完成), 供 controller 触发 DIGEST 窗口
signal notable_event(description: String)


var _queue: Array[QueuedEffect] = []
var _current: QueuedEffect = null
var _position_counter: int = 0

var resolver: RefCounted = null
var target_manager: RefCounted = null

# === 即时制新增字段 (Phase 2) ===
## 暂停请求标志 — 在下一个 Program 边界消费
var pause_requested: bool = false
## 队列是否空闲 (无排队 + 无当前执行)
var is_idle: bool :
	get: return _queue.is_empty() and _current == null


func enqueue(runtime: CardRuntime, ctx: BattleContext, user_data: Dictionary = {}) -> void:
	var qe := QueuedEffect.new(runtime, ctx, _position_counter)
	_position_counter += 1
	qe.user_data = user_data
	_queue.append(qe)
	if state == State.IDLE:
		_begin_next()


func execute_next(_delta: float) -> void:
	if state == State.IDLE:
		return
	if state == State.WAITING_SELECTION:
		return

	if _current == null:
		_begin_next()
		return

	if resolver == null:
		push_warning("EffectQueue: resolver not set")
		_finish_current({"error": "no resolver"})
		return

	var step_result: BattleResult = resolver.step(_current.runtime, _current.ctx)

	if step_result.waiting:
		state = State.WAITING_SELECTION
		if target_manager:
			target_manager.request(step_result.selector, _current.ctx)
		return

	if step_result.completed:
		_finish_current({"played": true})
		return


func on_selection_completed(selector: Dictionary, selected: Array) -> bool:
	if state != State.WAITING_SELECTION:
		return false
	if _current == null:
		return false

	var plan = _current.runtime.execution_plan
	if plan and _current.runtime.step_pc >= 0 and _current.runtime.step_pc < plan.order.size():
		var node_id: String = plan.order[_current.runtime.step_pc]
		_current.runtime.selected_targets[node_id] = selected

	state = State.EXECUTING
	return true


func cancel_all() -> void:
	_queue.clear()
	_current = null
	state = State.IDLE


func get_queue_length() -> int:
	return _queue.size()


func _begin_next() -> void:
	if _queue.is_empty():
		_current = null
		state = State.IDLE
		queue_empty.emit()
		return

	_current = _queue.pop_front()
	state = State.EXECUTING

	if resolver == null:
		_finish_current({"error": "no resolver"})
		return

	# Resolver.begin 返回 BattleResult, 检查 executed 字段
	var begin_result: BattleResult = resolver.begin(_current.runtime, _current.ctx)
	if not begin_result.executed:
		_finish_current({"played": false, "error": "resolver begin failed"})
		return


func _finish_current(result: Dictionary) -> void:
	if _current == null:
		return
	var card_key: String = ""
	if _current.runtime and _current.runtime.instance:
		card_key = _current.runtime.instance.resource_path
	var data: Dictionary = _current.user_data
	effect_finished.emit(card_key, result, data)
	_current = null

	# === 即时制: 原子边界暂停检查 (Phase 2) ===
	if pause_requested:
		pause_requested = false
		# 不调用 _begin_next(), 队列暂停在当前边界
		# 等待外部调用 resume() 继续
		return

	if _queue.is_empty():
		state = State.IDLE
		queue_empty.emit()
		queue_drained.emit()          # 即时制: 通知 controller
		return

	_begin_next()


## 即时制: 优先级入队 (Phase 2)
## priority 越大越先执行, 默认 0=普通
func enqueue_priority(runtime: CardRuntime, ctx: BattleContext, priority: int = 0, user_data: Dictionary = {}) -> void:
	var qe := QueuedEffect.new(runtime, ctx, priority)
	_position_counter += 1
	qe.user_data = user_data
	_queue.append(qe)
	# 优先级降序排列
	_queue.sort_custom(func(a: QueuedEffect, b: QueuedEffect): return a.position > b.position)
	if state == State.IDLE and not pause_requested:
		_begin_next()


## 即时制: 暂停恢复 (Phase 2)
## 在外部调用 request_resume() 后, 如果队列非空则继续执行
func resume() -> void:
	if _current == null and not _queue.is_empty():
		_begin_next.call_deferred()
