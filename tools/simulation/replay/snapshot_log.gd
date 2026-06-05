# ============================================================
# 大周天 — SnapshotLog (持久事件日志 — crash recovery)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 记录 SnapshotIndex 的每一次写入操作。
# 支持: crash recovery / session rebuild / debug audit trail。
#
# 日志条目:
#   INTENT  — intent recorded, apply pending
#   COMMIT  — both store + timeline applied
#   ROLLBACK — apply failed, intent discarded
#
# 恢复流程:
#   log.rebuild(index, kernel) → replay all COMMIT entries → rebuild index
# ============================================================
class_name SnapshotLog
extends RefCounted


enum Op { INTENT, COMMIT, ROLLBACK }

class Entry:
	var op: int = Op.INTENT
	var action_index: int = -1
	var phase: int = 0
	var event_index: int = 0
	var state_data: Dictionary = {}    # only INTENT entries carry state

	func is_committed() -> bool:
		return op == Op.COMMIT


var entries: Array[Entry] = []


## 记录 intent（apply 前调用）
func log_intent(p_action_idx: int, p_phase: int, p_state: Dictionary, p_event_idx: int) -> void:
	var e := Entry.new()
	e.op = Op.INTENT
	e.action_index = p_action_idx
	e.phase = p_phase
	e.event_index = p_event_idx
	e.state_data = p_state
	entries.append(e)


## 记录 commit（apply 成功后调用）
func log_commit(p_action_idx: int) -> void:
	var e := Entry.new()
	e.op = Op.COMMIT
	e.action_index = p_action_idx
	entries.append(e)


## 记录 rollback（apply 失败后调用）
func log_rollback(p_action_idx: int) -> void:
	var e := Entry.new()
	e.op = Op.ROLLBACK
	e.action_index = p_action_idx
	entries.append(e)


## 从日志重建索引 — crash recovery
func rebuild(index: SnapshotIndex, kernel: SimulationKernel) -> bool:
	# 只回放已提交的 intent
	var intent_stack: Array[Entry] = []

	for e in entries:
		match e.op:
			Op.INTENT:
				intent_stack.append(e)
			Op.COMMIT:
				if intent_stack.is_empty():
					push_error("SnapshotLog: COMMIT without INTENT at action %d" % e.action_index)
					return false
				var intent: Entry = intent_stack.pop_back()
				# 重新应用已提交的 intent
				var ok: bool = index.register(kernel, intent.phase, 0, [], [], [], [], intent.event_index)
				if not ok:
					push_error("SnapshotLog: rebuild failed at action %d" % intent.action_index)
					return false
			Op.ROLLBACK:
				if not intent_stack.is_empty():
					intent_stack.pop_back()

	# 如果有未提交的 intent — 丢弃（crash 前未完成）
	if not intent_stack.is_empty():
		push_warning("SnapshotLog: %d uncommitted intents discarded during recovery" % intent_stack.size())
		intent_stack.clear()

	return true


## 日志完整性验证
func validate() -> bool:
	var pending: int = 0
	for e in entries:
		match e.op:
			Op.INTENT:   pending += 1
			Op.COMMIT:   pending -= 1
			Op.ROLLBACK: pending -= 1
		if pending < 0:
			push_error("SnapshotLog: COMMIT/ROLLBACK without INTENT")
			return false
	return pending == 0  # no orphan intents


func size() -> int:     return entries.size()
func clear() -> void:   entries.clear()
