# ============================================================
# 大周天 — EffectNode
# 卡牌效果图中的最小效果节点 (v4: 纯 AST 数据节点)
# 不再包含执行逻辑 — 执行已迁移至 EffectVM
# 不再包含描述生成 — 描述由 CardData.description 字段承载
# ============================================================
@tool
class_name EffectNode
extends Resource


## 节点唯一标识，如 "n1", "n2"
@export var id: String = ""

## 效果类型字符串: "damage" / "block" / "heal" / "burn" / "stun" / "vulnerable" /
##   "weak" / "draw" / "qi_gather" / "qi_restore" / "buff" / "debuff" / "cleanse" /
##   "dantian_up" / "pathway_capacity_up" / ...
## v4: 保留用于 .tres 可读性和向后兼容；编译器优先使用 opcode
@export var type: String = "damage"

## 效果操作码 — EffectOpcode.Code 枚举值
## 非 0 时编译器直接使用；为 0 时编译器通过 type 字符串推导
## 0=DAMAGE 1=BLOCK 2=HEAL 3=DRAW 4=APPLY_STATUS 5=QI_GATHER 6=QI_RESTORE 7=DANTIAN_UP 8=PATHWAY_UP
@export var opcode: int = 0

## 效果基础数值，具体含义由 opcode 决定:
##   DAMAGE → 伤害量, BLOCK → 格挡量, HEAL → 治疗量
##   DRAW → 抽牌数, QI_GATHER → 聚气量, QI_RESTORE → 恢复量
##   APPLY_STATUS → 层数/强度
@export var value: int = 0

## 额外参数（如 burn 的持续回合: {"turns": 3, "status_type": "burn"}）
@export var meta: Dictionary = {}

## 目标选择器声明，空字典=无需选择（直接执行）
## 格式: {"type": "path", "count": 1}
##   type: "enemy"/"card"/"field"/"node"/"path"/"effect_node"/"technique"
##   count: 选择数量, 默认1
@export var selector: Dictionary = {}

## 统一目标规格 — 编译时由 CardData.target_type 构建，运行时替代 selector
var target: TargetSpec = null


func duplicate_node() -> EffectNode:
	var n: EffectNode = EffectNode.new()
	n.id = id
	n.type = type
	n.opcode = opcode
	n.value = value
	n.meta = meta.duplicate()
	n.selector = selector.duplicate()
	if target:
		n.target = target.duplicate_spec()
	return n
