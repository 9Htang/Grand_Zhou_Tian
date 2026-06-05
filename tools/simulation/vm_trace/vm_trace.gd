# ============================================================
# 大周天 — VMTrace (VM 执行轨迹)
# ============================================================
# 工具层: tools/simulation/vm_trace/ — 不属于四层运行时架构
#
# 记录每条 VM 指令的执行过程: 栈变化、RNG 调用、目标解析、事件发出。
# 用于 debug viewer、AI explanation、divergence analysis。
#
# 用法:
#   - 回答 "为什么 AI 选了这个目标？" → 看 OpSelectTarget 轨迹
#   - 回答 "这次伤害为什么是 8 点？" → 看 OpDamage 轨迹
#   - 比较两次运行 → VMTrace entries 逐条一致 = 确定性验证通过
# ============================================================
class_name VMTrace
extends RefCounted


# ============================================================
# VMTraceEntry — 单条指令执行记录
# ============================================================

class VMTraceEntry:
	## 所在 tick
	var tick: int = 0

	## 在 VMProgram 中的指令索引
	var instruction_index: int = 0

	## 操作码名称
	var opcode: String = ""

	## 操作码枚举值
	var opcode_value: int = 0

	## 来源卡牌 ID
	var source_card_id: String = ""

	## 执行前栈内容（浅拷贝）
	var stack_before: Array = []

	## 执行后栈内容（浅拷贝）
	var stack_after: Array = []

	## 执行前 RNG call_count
	var rng_call_before: int = 0

	## 执行后 RNG call_count
	var rng_call_after: int = 0

	## 解析到的目标列表
	var targets_resolved: Array = []

	## 应用的数值变化 {target_id: delta}
	var values_applied: Dictionary = {}

	## 执行前状态哈希
	var state_hash_before: int = 0

	## 执行后状态哈希
	var state_hash_after: int = 0

	## 是否发出了事件
	var event_emitted: bool = false

	## 发出的事件类型
	var event_type: String = ""


# ============================================================
# State
# ============================================================

var entries: Array[VMTraceEntry] = []


# ============================================================
# Public
# ============================================================

func record(entry: VMTraceEntry) -> void:
	entries.append(entry)


## 查询某个 tick 执行了哪些指令
func at_tick(tick: int) -> Array[VMTraceEntry]:
	var result: Array[VMTraceEntry] = []
	for e in entries:
		if e.tick == tick:
			result.append(e)
	return result


## 查询某张卡牌产生了哪些指令
func for_card(card_id: String) -> Array[VMTraceEntry]:
	var result: Array[VMTraceEntry] = []
	for e in entries:
		if e.source_card_id == card_id:
			result.append(e)
	return result


func size() -> int:
	return entries.size()


func clear() -> void:
	entries.clear()


## 导出可读文本（供 debug viewer）
func to_debug_text() -> String:
	var lines: Array[String] = []
	for e in entries:
		lines.append("[tick %d][ip %d] %s | rng#%d→#%d | stack[%d]→[%d] | targets=%s | event=%s" % [
			e.tick, e.instruction_index, e.opcode,
			e.rng_call_before, e.rng_call_after,
			e.stack_before.size(), e.stack_after.size(),
			str(e.targets_resolved), e.event_type if e.event_emitted else "-"
		])
	return "\n".join(lines)
