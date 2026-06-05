# ============================================================
# 大周天 — SnapshotIndex (Write-Ahead Log — atomic commit)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 🔒 所有快照写入的唯一入口。使用 WAL 模式:
#   intent → apply(store) → apply(timeline) → commit
#   任何一步失败 → discard intent，两者都不写入。
#
# 不变约束:
#   store.has(action) ⇔ timeline.has(action, phase)
#   异或状态不存在 — 原子提交保证
# ============================================================
class_name SnapshotIndex
extends RefCounted


var _store: SnapshotStore = null
var _timeline: TimelineStore = null
## 可选 — 持久日志（null = 不需要 recovery）
var _log: SnapshotLog = null

## Write-Ahead Log — 提交前暂存
var _pending_snap: ReplaySnapshot = null
var _pending_action: int = -1


func _init() -> void:
	_store = SnapshotStore.new()
	_timeline = TimelineStore.new()


# ============================================================
# Core API — commit / rollback / validate
# ============================================================

## 原子提交 — 唯一写入入口
func commit(kernel: SimulationKernel, phase: int,
		p_vm_ip: int, p_vm_stack: Array,
		p_event_queue: Array, p_pending: Array, p_trigger_stack: Array,
		p_event_idx: int) -> bool:
	return _register(kernel, phase, p_vm_ip, p_vm_stack, p_event_queue, p_pending, p_trigger_stack, p_event_idx)


func rollback(_action_idx: int) -> void:
	_discard_pending()


func validate() -> bool:
	if _pending_snap != null:
		push_error("SnapshotIndex: uncommitted pending snapshot")
		return false
	for k in _timeline.entries.keys():
		var entry: TimelineStore.Entry = _timeline.entries[k]
		if not _store.has(entry.action_index):
			return false
	return true


# ============================================================
# Internal — WAL
# ============================================================


func _register(kernel: SimulationKernel, phase: int,
		p_vm_ip: int, p_vm_stack: Array,
		p_event_queue: Array, p_pending: Array, p_trigger_stack: Array,
		p_event_idx: int) -> bool:
	_discard_pending()

	# Phase 1: Write-Ahead — create intent + log
	_pending_snap = _store.force_capture(kernel, p_vm_ip, p_vm_stack, p_event_queue, p_pending, p_trigger_stack, p_event_idx)
	if _pending_snap == null:
		return false
	_pending_action = _pending_snap.action_index

	if _log: _log.log_intent(_pending_action, phase, _pending_snap.kernel_state_data, p_event_idx)

	# Phase 2: Apply to timeline
	if not _timeline.capture(_store, kernel, phase, p_vm_ip, p_vm_stack, p_event_queue, p_pending, p_trigger_stack, p_event_idx):
		if _log: _log.log_rollback(_pending_action)
		_discard_pending()
		return false

	# Phase 3: Commit
	if _log: _log.log_commit(_pending_action)
	_pending_snap = null
	_pending_action = -1
	return true


## Crash recovery — 从日志重建索引
func recover(kernel: SimulationKernel) -> bool:
	return _log.rebuild(self, kernel)


func log_entries() -> Array:
	return _log.entries


func validate_log() -> bool:
	return _log.validate()


func _discard_pending() -> void:
	if _pending_snap != null:
		_store.remove(_pending_action)
		_pending_snap = null
		_pending_action = -1


# ============================================================
# Read API
# ============================================================


func get_snapshot(action_idx: int, phase: int = TimelineStore.SnapshotPhase.POST_ACTION) -> ReplaySnapshot:
	return _timeline.get_snapshot(action_idx, phase)


func get_rollback_target(action_idx: int) -> ReplaySnapshot:
	return _timeline.get_rollback_target(action_idx)


func rollback_to(kernel: SimulationKernel, action_idx: int) -> bool:
	return _timeline.rollback_to(kernel, action_idx)


func get_latest() -> ReplaySnapshot:
	return _timeline.get_latest()


func diff(idx_a: int, idx_b: int) -> StateDiff.DiffResult:
	return _store.diff(idx_a, idx_b)


func _validate_stores() -> bool:
	if _pending_snap != null:
		push_error("SnapshotIndex: INTEGRITY BREACH — uncommitted pending snapshot")
		return false
	for k in _timeline.entries.keys():
		var entry: TimelineStore.Entry = _timeline.entries[k]
		if not _store.has(entry.action_index):
			push_error("SnapshotIndex: INTEGRITY BREACH — timeline has %d but store does not" % entry.action_index)
			return false
	return true


func size() -> int:        return _timeline.size()
## 启用持久日志（可选 — 用于 crash recovery / debug audit）
func enable_logging() -> void:
	_log = SnapshotLog.new()


func clear() -> void:
	_discard_pending()
	_store.clear()
	_timeline.clear()
	if _log: _log.clear()
