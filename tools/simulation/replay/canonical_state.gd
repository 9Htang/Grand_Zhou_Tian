# ============================================================
# 大周天 — CanonicalState (规范状态 — 不可变 Value Object)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 纯数据容器 — 不负责构造（构造由 StateCanonicalBuilder 完成）。
# 构造时预计算 hash，后续比较为 O(1)。
# ============================================================
class_name CanonicalState
extends RefCounted


var _data: Dictionary = {}

## 构造时预计算的 hash — 后续所有比较为 O(1)
var canonical_hash: int = 0


func to_stable_string() -> String:
	return StableSerializer.serialize(_data)


func exact_equals(other: CanonicalState) -> bool:
	if other == null:
		return false
	return canonical_hash == other.canonical_hash


func semantic_equals(other: CanonicalState) -> bool:
	return exact_equals(other)


## 获取内部数据 dict（只读，供 StateDiff 使用）
func data() -> Dictionary:
	return _data


func debug_equals(other: CanonicalState) -> bool:
	if other == null:
		return false
	return _data.hash() == other._data.hash()
