# ============================================================
# 大周天 — StateCanonical (规范状态入口)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 委托层 — 构造由 StateCanonicalBuilder 完成。
# 外部代码通过此入口或直接使用 Builder。
# ============================================================
class_name StateCanonical
extends RefCounted


static func from_dict(d: Dictionary) -> CanonicalState:
	return StateCanonicalBuilder.from_dict(d)


static func from_state(state: KernelState) -> CanonicalState:
	return StateCanonicalBuilder.from_state(state)


static func are_equal(a: Dictionary, b: Dictionary) -> bool:
	return StateCanonicalBuilder.from_dict(a).exact_equals(StateCanonicalBuilder.from_dict(b))
