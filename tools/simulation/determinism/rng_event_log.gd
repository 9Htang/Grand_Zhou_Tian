# ============================================================
# 大周天 — RNGEventLog (RNG 调用日志)
# ============================================================
# 工具层: tools/simulation/determinism/ — 不属于四层运行时架构
#
# 记录每次 RNG 调用的上下文，使 RNG 完全可观测。
#
# 用途:
#   - 复现 "哪个随机调用导致了 divergence" — 比较两次运行的 RNG log
#   - CI diff: 同 seed 两次运行的 RNG log 必须逐条一致
#   - Balance analysis: 统计某张卡牌的 RNG 调用分布
# ============================================================
class_name RNGEventLog
extends RefCounted


# ============================================================
# RNGEntry — 单条 RNG 调用记录
# ============================================================

class RNGEntry:
	## 全局第几次 RNG 调用
	var call_index: int = 0

	## 发生在哪个 tick
	var tick: int = 0

	## 调用上下文: "OpSelectTarget", "DeckManager.shuffle", "EnemyAI.select_action"
	var context: String = ""

	## 调用方法: "randi", "randf", "randi_range", "shuffle"
	var rng_function: String = ""

	## 调用参数: {modulo: 3, array_size: 10, min: 1, max: 100}
	var params: Dictionary = {}

	## 原始返回值
	var result: Variant = null

	func _init(p_call_index: int, p_tick: int, p_context: String, p_function: String, p_params: Dictionary, p_result: Variant) -> void:
		call_index = p_call_index
		tick = p_tick
		context = p_context
		rng_function = p_function
		params = p_params
		result = p_result

	func to_dict() -> Dictionary:
		return {
			"call_index": call_index,
			"tick": tick,
			"context": context,
			"rng_function": rng_function,
			"params": params,
			"result": result,
		}


# ============================================================
# State
# ============================================================

var entries: Array[RNGEntry] = []


# ============================================================
# Public
# ============================================================

func record(call_index: int, tick: int, context: String, rng_function: String, params: Dictionary, result: Variant) -> void:
	entries.append(RNGEntry.new(call_index, tick, context, rng_function, params, result))


func all() -> Array[RNGEntry]:
	return entries


func size() -> int:
	return entries.size()


func clear() -> void:
	entries.clear()


## 导出为可读文本，用于 diff 比对
func to_debug_text() -> String:
	var lines: Array[String] = []
	for e in entries:
		lines.append("[#%d][tick %d] %s.%s(%s) → %s" % [
			e.call_index, e.tick, e.context, e.rng_function,
			str(e.params), str(e.result)
		])
	return "\n".join(lines)


## 比较两次 RNG log 是否完全一致
static func compare(a: RNGEventLog, b: RNGEventLog) -> Dictionary:
	if a.size() != b.size():
		return {"match": false, "reason": "count_mismatch", "a_count": a.size(), "b_count": b.size()}

	for i in a.entries.size():
		var ea: RNGEntry = a.entries[i]
		var eb: RNGEntry = b.entries[i]
		if ea.call_index != eb.call_index or ea.tick != eb.tick or ea.context != eb.context or ea.rng_function != eb.rng_function or ea.result != eb.result:
			return {"match": false, "reason": "entry_mismatch", "index": i, "a": ea.to_dict(), "b": eb.to_dict()}

	return {"match": true}
