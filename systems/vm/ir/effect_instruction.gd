# ============================================================
# 大周天 — EffectInstruction
# 单条字节码指令 — EffectVM 的最小执行单元
# 由 EffectCompiler 从 EffectNode (AST) 编译生成
#
# v3.0 升级: 指令对象化
#   每个 EffectInstruction 现在负责执行自己的行为。
#   子类重写 _do_execute() 实现具体 opcode 逻辑。
#   _before() / _after() 用于 trace + event + hash 记录。
# ============================================================
class_name EffectInstruction
extends RefCounted


## 操作码 — EffectOpcode.Code 枚举值
var opcode: int = 0

## 效果数值 — 含义由 opcode 决定
##   DAMAGE → 伤害量, BLOCK → 格挡量, HEAL → 治疗量
##   DRAW → 抽牌数, QI_GATHER → 聚气量, QI_RESTORE → 恢复量
##   DANTIAN_UP → 丹田增量, PATHWAY_UP → 容量增量
##   APPLY_STATUS → 层数/强度
var value: int = 0

## 额外参数 — 由 opcode 决定
##   APPLY_STATUS: {"status_type": "burn", "turns": 3, "name": "灼烧"}
##   BUFF/DEBUFF:  {"name": "attack_up", "turns": 2}
##   PATHWAY_UP:   {"selected": [{from: 0, to: 1}, ...]}
var meta: Dictionary = {}

## 目标选择器 — 空字典 = 无需选择，直接执行（旧版，逐步迁移至 target）
var selector: Dictionary = {}

## 统一目标规格 — 由 EffectInstruction.from_node() 从 EffectNode.target 拷贝
var target: TargetSpec = null

## 控制流 — 跳转目标指令索引，-1 = 顺序执行下一条
var jump: int = -1


# ============================================================
# v3.0 — 指令对象化: 每个指令负责自己的执行行为
# ============================================================

## 执行本指令（模板方法）
## 子类可重写 _before / _do_execute / _after
func execute(ctx: EffectContext) -> void:
	_before(ctx)
	_do_execute(ctx)
	_after(ctx)


## 执行前钩子 — 子类重写: 记录 trace / state_hash_before / rng_call_index
func _before(ctx: EffectContext) -> void:
	pass


## 实际执行逻辑 — 子类必须重写
func _do_execute(ctx: EffectContext) -> void:
	# 兜底: 如果子类没重写，走旧版 EffectVM 静态 match
	EffectVM.execute_instruction(self, ctx)


## 执行后钩子 — 子类重写: emit event / state_hash_after
func _after(ctx: EffectContext) -> void:
	pass


# ============================================================
# Factory — 编译时使用
# ============================================================


## 从 EffectNode 构造指令（编译时使用，返回基类实例）
## 注意: EffectCompiler.compile_node() 会按 opcode 创建子类实例，此方法仅作兜底
static func from_node(node: EffectNode) -> EffectInstruction:
	var ins: EffectInstruction = EffectInstruction.new()
	ins.opcode = _resolve_opcode(node)
	ins.value = node.value
	ins.meta = node.meta.duplicate()
	ins.selector = node.selector.duplicate()
	if node.target:
		ins.target = node.target.duplicate_spec()
	return ins


## 解析 opcode：优先使用 node.opcode，为 0 时通过 type 字符串推导
static func _resolve_opcode(node: EffectNode) -> int:
	if node.opcode != 0:
		return node.opcode
	return EffectOpcode.from_type(node.type)


## opcode 可读名称（用于 trace/debug）
func opcode_name() -> String:
	return EffectOpcode.name_of(opcode)
