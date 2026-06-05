# ============================================================
# 大周天 — CausalGraph (因果图查询器)
# ============================================================
# 工具层: tools/simulation/causal/ — 不属于四层运行时架构
#
# 从 EventStream 构建因果链:
#   每张卡 → 每条 opcode → 每个 event → 每个状态变化
#
# 回答:
#   - "这次 damage 是哪张卡 / 哪条 opcode 导致的？"
#   - "卡牌 A 打出了，触发了什么连锁反应？"
# ============================================================
class_name CausalGraph
extends RefCounted


var _events: EventStream = null


func _init(events: EventStream) -> void:
	_events = events


## 查询某个事件的所有因果后代
func descendants(event_id: String) -> Array[SimulationEvent]:
	var result: Array[SimulationEvent] = []
	for e in _events.all():
		if e.parent_event_id == event_id:
			result.append(e)
			result.append_array(descendants(e.event_id))
	return result


## 查询一张卡牌触发的完整因果链
func chain_for_card(card_id: String) -> Array[SimulationEvent]:
	var result: Array[SimulationEvent] = []
	for e in _events.all():
		if e.source_card_id == card_id:
			result.append(e)
			result.append_array(descendants(e.event_id))
	return result


## 导出可读的因果树
func to_tree_text(root_event_id: String = "", indent: String = "") -> String:
	var lines: Array[String] = []
	for e in _events.all():
		if root_event_id.is_empty() or e.parent_event_id == root_event_id:
			lines.append("%s├─ [t%.1f] %s (card=%s, op=%s, %s→%s)" % [
				indent, e.time, e.type,
				e.source_card_id, e.opcode,
				e.actor_id, e.target_id,
			])
			if not e.event_id.is_empty():
				lines.append(to_tree_text(e.event_id, indent + "   "))
	return "\n".join(lines)
