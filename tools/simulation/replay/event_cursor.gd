# ============================================================
# 大周天 — EventCursor (回放游标)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 轻量级事件游标 — seek / step_forward / step_backward。
# 仅做 index 导航，不恢复 VM 状态。
#
# 未来升级路径:
#   Kernel.save_state() + restore_state() 完成后
#   → ReplayTimeline（含快照缓存的真正时间轴）
# ============================================================
class_name EventCursor
extends RefCounted


var events: Array[SimulationEvent] = []
var current_index: int = 0
var _original_run: SimulationRun = null
var _engine: ReplayEngine = null


func load(run: SimulationRun) -> void:
	_original_run = run
	_engine = ReplayEngine.new()
	events = run.events.all()
	current_index = 0


func seek(target_index: int) -> void:
	current_index = clampi(target_index, 0, max(0, events.size() - 1))


func step_forward() -> SimulationEvent:
	if current_index + 1 < events.size():
		current_index += 1
		return events[current_index]
	return null


func step_backward() -> SimulationEvent:
	if current_index > 0:
		current_index -= 1
		return events[current_index]
	return null


func replay_until(target_index: int) -> ReplayEngine.ReplayResult:
	return _engine.replay(_original_run)
