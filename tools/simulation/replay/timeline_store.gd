# ============================================================
# 大周天 — TimelineStore (时间轴存储 — 时间结构)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 将 action_index 映射到时间阶段（phase-tagged snapshots）。
# 每个 action 有三个合法 capture 阶段:
#   PRE_ACTION   — 执行前（rollback 目标）
#   POST_EFFECT  — 效果结算后（调试用）
#   POST_ACTION  — 执行完成（正常前进点）
#
# snapshot = {action_index, phase, event_index, canonical_state}
# 同一个 action_index 可存储多个 phase 的快照。
# ============================================================
class_name TimelineStore
extends RefCounted


enum SnapshotPhase { PRE_ACTION = 0, POST_EFFECT = 1, POST_ACTION = 2 }


class Entry:
	var action_index: int = 0
	var phase: int = SnapshotPhase.PRE_ACTION
	var event_index: int = 0
	var snapshot: ReplaySnapshot = null

	func key() -> String:
		return "%d_%d" % [action_index, phase]


## action_index → {phase → Entry}
var entries: Dictionary = {}


## 在指定阶段捕获快照
func capture(store: SnapshotStore, kernel: SimulationKernel,
		phase: int, p_vm_ip: int, p_vm_stack: Array,
		p_event_queue: Array, p_pending: Array, p_trigger_stack: Array,
		p_event_idx: int) -> bool:
	var snap: ReplaySnapshot = store.try_capture(kernel, p_vm_ip, p_vm_stack, p_event_queue, p_pending, p_trigger_stack, p_event_idx)
	if snap == null:
		return false

	var entry := Entry.new()
	entry.action_index = snap.action_index
	entry.phase = phase
	entry.event_index = p_event_idx
	entry.snapshot = snap

	var k: String = entry.key()
	entries[k] = entry
	return true


## 获取指定 action + phase 的快照
func get_snapshot(action_idx: int, phase: int = SnapshotPhase.POST_ACTION) -> ReplaySnapshot:
	var k: String = "%d_%d" % [action_idx, phase]
	if not entries.has(k):
		return null
	var entry: Entry = entries[k]
	return entry.snapshot if entry else null
## 获取 rollback 目标 — 指定 action 的 PRE_ACTION 状态
func get_rollback_target(action_idx: int) -> ReplaySnapshot:
	return get_snapshot(action_idx, SnapshotPhase.PRE_ACTION)


## 获取最近的 POST_ACTION 快照（正常前进点）
func get_latest() -> ReplaySnapshot:
	var best: ReplaySnapshot = null
	for k in entries.keys():
		var entry: Entry = entries[k]
		if entry.phase == SnapshotPhase.POST_ACTION and (best == null or entry.action_index > best.action_index):
			best = entry.snapshot
	return best


## rollback 到指定 action 的 PRE_ACTION 状态
func rollback_to(kernel: SimulationKernel, action_idx: int) -> bool:
	var snap: ReplaySnapshot = get_rollback_target(action_idx)
	if snap == null:
		return false
	kernel.restore_from_dict(snap.kernel_state_data)
	return true


func size() -> int:
	return entries.size()


func clear() -> void:
	entries.clear()
