# ============================================================
# 大周天 — StateView (统一查询层 — single read model)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 系统中所有状态查询的 **唯一读取入口**。
# Verifier / Diff / Timeline 消费者只通过 StateView 读取，
# 不直接访问 SnapshotStore / TimelineStore / SnapshotIndex。
#
# write path:  SnapshotIndex.register()  ← single gate
# read path:   StateView.*()             ← single query layer
# ============================================================
class_name StateView
extends RefCounted


var _index: SnapshotIndex = null


func _init(p_index: SnapshotIndex) -> void:
	_index = p_index


## 按主键获取快照
func get_snapshot(action_idx: int, phase: int = TimelineStore.SnapshotPhase.POST_ACTION) -> ReplaySnapshot:
	return _index.get_snapshot(action_idx, phase)


## 获取规范状态（CanonicalState）
func get_canonical_state(action_idx: int, phase: int = TimelineStore.SnapshotPhase.POST_ACTION) -> CanonicalState:
	var snap: ReplaySnapshot = get_snapshot(action_idx, phase)
	if snap == null:
		return null
	return StateCanonicalBuilder.from_dict(snap.kernel_state_data)


## 比较两个时间点状态是否一致
func compare(idx_a: int, idx_b: int) -> bool:
	return _index.diff(idx_a, idx_b).is_empty()


## 生成两个时间点的结构差异
func diff(idx_a: int, idx_b: int) -> StateDiff.DiffResult:
	return _index.diff(idx_a, idx_b)


## Rollback 目标状态
func get_rollback_state(action_idx: int) -> ReplaySnapshot:
	return _index.get_rollback_target(action_idx)


## Rollback 内核到指定 action
func rollback_to(kernel: SimulationKernel, action_idx: int) -> bool:
	return _index.rollback_to(kernel, action_idx)


## 最近快照
func get_latest() -> ReplaySnapshot:
	return _index.get_latest()


## 总快照数
func size() -> int:
	return _index.size()
