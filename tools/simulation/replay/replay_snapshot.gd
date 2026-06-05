# ============================================================
# 大周天 — ReplaySnapshot (回放快照 — 不可变数据容器)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 存储序列化后的 KernelState 数据（Dictionary），不是对象引用。
# 保证快照不可变 — capture 后不受后续游戏状态修改影响。
# ============================================================
class_name ReplaySnapshot
extends RefCounted


var action_index: int = 0
var event_index: int = 0

## 序列化后的状态数据（不可变）
var kernel_state_data: Dictionary = {}

## capture 时预计算的 canonical hash — O(1) 比较
var canonical_hash: int = 0


static func capture(p_action_idx: int, p_event_idx: int, p_state: KernelState) -> ReplaySnapshot:
	var snap := ReplaySnapshot.new()
	snap.action_index = p_action_idx
	snap.event_index = p_event_idx
	snap.kernel_state_data = p_state.to_dict()
	snap.canonical_hash = StateCanonicalBuilder.from_dict(snap.kernel_state_data).canonical_hash
	return snap


## O(1) 比较 — 使用预计算的 canonical_hash
func state_equals(other: ReplaySnapshot) -> bool:
	if other == null:
		return false
	return canonical_hash == other.canonical_hash


## 完整比较（状态 + 定位锚点）
func full_equals(other: ReplaySnapshot) -> bool:
	if action_index != other.action_index:
		return false
	if event_index != other.event_index:
		return false
	return state_equals(other)
