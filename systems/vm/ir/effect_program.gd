# ============================================================
# 大周天 — EffectProgram
# 字节码程序 — EffectCompiler 的输出，EffectVM 的输入
# 不可变的执行序列，支持控制流 (jump)
# ============================================================
class_name EffectProgram
extends Resource


## 指令序列 — 按执行顺序排列
var instructions: Array[EffectInstruction] = []

## 即时制: 队列优先级 (越大越先执行, 默认0=普通)
var queue_priority: int = 0


## 从 EffectInstruction 数组构建
static func from_array(arr: Array[EffectInstruction]) -> EffectProgram:
	var prog: EffectProgram = EffectProgram.new()
	prog.instructions = arr
	return prog


## 指令数量
func size() -> int:
	return instructions.size()


## 是否为空
func is_empty() -> bool:
	return instructions.is_empty()


## 获取指定索引的指令，越界返回 null
func get_instruction(index: int) -> EffectInstruction:
	if index < 0 or index >= instructions.size():
		return null
	return instructions[index]
