# ============================================================
# 大周天 — StateCanonicalBuilder (CanonicalState 构造器)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# CanonicalState 的唯一构造入口。
# 构造时完成规范化 + 预计算 hash。
# ============================================================
class_name StateCanonicalBuilder
extends RefCounted


static func from_dict(d: Dictionary) -> CanonicalState:
	var cs := CanonicalState.new()
	cs._data = _canonicalize(d)
	cs.canonical_hash = cs.to_stable_string().hash()
	return cs


static func from_state(state: KernelState) -> CanonicalState:
	return from_dict(state.to_dict())


static func _canonicalize(value) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			var keys: Array = value.keys()
			keys.sort()
			for k in keys:
				out[k] = _canonicalize(value[k])
			return out
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY:
			var out: Array = []
			for v in value:
				out.append(_canonicalize(v))
			return out
		_:
			return value
