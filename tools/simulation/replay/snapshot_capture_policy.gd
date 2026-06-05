# ============================================================
# 大周天 — SnapshotCapturePolicy (快照时机验证)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 保证快照只在语义合法的时间点捕获。
# 禁止在 mid-effect / mid-chain / VM half-step 时捕获。
#
# 合法 capture 边界:
#   - end of action execution
#   - end of tick processing
#   - post-event commit point
# ============================================================
class_name SnapshotCapturePolicy
extends RefCounted


## kernel 当前是否处于可捕获快照的状态
static func can_capture(kernel: SimulationKernel) -> bool:
	return kernel.is_idle() and kernel.is_at_action_boundary()


## 给出当前不可捕获的原因（调试用）
static func reject_reason(kernel: SimulationKernel) -> String:
	if not kernel.is_idle():
		return "effect queue not idle"
	if not kernel.is_at_action_boundary():
		return "not at action boundary"
	return ""
