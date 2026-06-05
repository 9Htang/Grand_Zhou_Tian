# ============================================================
# 大周天 — SnapshotStore (快照存储 — 唯一 capture 收敛点)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 系统中所有状态快照的唯一来源。
# 所有消费者（Verifier / Diff / Timeline）只从 SnapshotStore 读取。
#
# 保证:
#   - 同一个 action_index → 同一个 CanonicalState
#   - diff 和 hash 共享同一个 capture instance
#   - 不存在多源头分裂
# ============================================================
class_name SnapshotStore
extends RefCounted


## action_index → ReplaySnapshot
var _snapshots: Dictionary = {}


## 尝试从 Kernel 捕获快照 — 非法时机（mid-effect/mid-chain）会被拒绝
func try_capture(kernel: SimulationKernel, p_vm_ip: int, p_vm_stack: Array,
		p_event_queue: Array, p_pending: Array, p_trigger_stack: Array,
		p_event_idx: int) -> ReplaySnapshot:
	if not SnapshotCapturePolicy.can_capture(kernel):
		push_warning("SnapshotStore: rejected capture — %s" % SnapshotCapturePolicy.reject_reason(kernel))
		return null

	var state: KernelState = kernel.save_state(p_vm_ip, p_vm_stack, p_event_queue, p_pending, p_trigger_stack)
	var action_idx: int = kernel.get_recorded_action_count()
	var snap := ReplaySnapshot.capture(action_idx, p_event_idx, state)
	_snapshots[action_idx] = snap
	return snap


## 强制捕获（跳过策略检查 — 仅测试/调试用）
func force_capture(kernel: SimulationKernel, p_vm_ip: int, p_vm_stack: Array,
		p_event_queue: Array, p_pending: Array, p_trigger_stack: Array,
		p_event_idx: int) -> ReplaySnapshot:
	var state: KernelState = kernel.save_state(p_vm_ip, p_vm_stack, p_event_queue, p_pending, p_trigger_stack)
	var action_idx: int = kernel.get_recorded_action_count()
	var snap := ReplaySnapshot.capture(action_idx, p_event_idx, state)
	_snapshots[action_idx] = snap
	return snap


## O(1) 按 action_index 获取快照
func get_snapshot(action_idx: int) -> ReplaySnapshot:
	if _snapshots.has(action_idx):
		return _snapshots[action_idx]
	return null


## 获取最近的快照 ≤ action_idx
func get_nearest(action_idx: int) -> ReplaySnapshot:
	var best: ReplaySnapshot = null
	for idx in _snapshots.keys():
		if idx <= action_idx and (best == null or idx > best.action_index):
			best = _snapshots[idx]
	return best


## 比较两个 action_index 的状态是否一致
func compare(idx_a: int, idx_b: int) -> bool:
	var a: ReplaySnapshot = get_snapshot(idx_a)
	var b: ReplaySnapshot = get_snapshot(idx_b)
	if a == null or b == null:
		return a == b
	return a.state_equals(b)


## 生成两个 action_index 之间的状态差异
## diff 和 hash 共享同一个 CanonicalState capture — 不会出现假不一致
func diff(idx_a: int, idx_b: int) -> StateDiff.DiffResult:
	var a: ReplaySnapshot = get_snapshot(idx_a)
	var b: ReplaySnapshot = get_snapshot(idx_b)
	if a == null or b == null:
		return StateDiff.DiffResult.new()
	var ca := StateCanonicalBuilder.from_dict(a.kernel_state_data)
	var cb := StateCanonicalBuilder.from_dict(b.kernel_state_data)
	return StateDiff.compare(ca, cb)


## 快照总数
func size() -> int:
	return _snapshots.size()


func has(action_idx: int) -> bool:
	return _snapshots.has(action_idx)


## 删除快照（仅 SnapshotIndex rollback 使用）
func remove(action_idx: int) -> void:
	_snapshots.erase(action_idx)


## 清空
func clear() -> void:
	_snapshots.clear()
