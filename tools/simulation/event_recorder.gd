# ============================================================
# 大周天 — EventRecorder (事件采集器)
# ============================================================
# 工具层: tools/simulation/ — 不属于四层运行时架构
#
# 纯收集层 — 不做聚合/统计/分类。
# 聚合逻辑属于 SimulationReport (from_recorder) 或专用 Analyzer。
# ============================================================
class_name EventRecorder
extends RefCounted


## 全部事件 (按时间顺序)
var events: Array[SimulationEvent] = []


## 记录一条事件
func record(time: float, type: String, actor_id: String, target_id: String, source: String, payload: Dictionary) -> void:
	events.append(SimulationEvent.new(time, type, actor_id, target_id, source, payload))


## 按事件类型过滤
func of_type(type: String) -> Array[SimulationEvent]:
	var result: Array[SimulationEvent] = []
	for e in events:
		if e.type == type:
			result.append(e)
	return result


## 按 actor 过滤
func for_actor(actor_id: String) -> Array[SimulationEvent]:
	var result: Array[SimulationEvent] = []
	for e in events:
		if e.actor_id == actor_id:
			result.append(e)
	return result


## 按时间窗口过滤
func in_window(start: float, end: float) -> Array[SimulationEvent]:
	var result: Array[SimulationEvent] = []
	for e in events:
		if e.time >= start and e.time <= end:
			result.append(e)
	return result


## 清空全部事件
func clear() -> void:
	events.clear()
