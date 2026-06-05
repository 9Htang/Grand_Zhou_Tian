# ============================================================
# 大周天 — ExecutionPlan
# 卡牌效果的执行顺序计划
# 从 EffectGraph 构建，决定节点执行先后
# ============================================================
class_name ExecutionPlan
extends RefCounted


## 默认效果类型优先级 — 值越小越先执行
## 设计原则: 增益先于伤害, 清debuff先于debuff
const DEFAULT_PRIORITY: Dictionary = {
	"cleanse": 0,
	"block": 1,
	"heal": 2,
	"buff": 3,
	"qi_gather": 4,
	"draw": 5,
	"debuff": 6,
	"vulnerable": 7,
	"weak": 8,
	"burn": 9,
	"stun": 10,
	"damage": 11,
}


## 执行顺序: [node_id, ...]
var order: Array[String] = []


# ============================================================
# 构建
# ============================================================


## 从 EffectGraph 构建执行计划
## 按 DEFAULT_PRIORITY 排序，同优先级按图中顺序
static func build_from(graph: EffectGraph) -> ExecutionPlan:
	var plan: ExecutionPlan = ExecutionPlan.new()
	if graph.is_empty():
		return plan

	# 复制节点并按优先级排序
	var sorted: Array[EffectNode] = graph.nodes.duplicate()
	sorted.sort_custom(func(a: EffectNode, b: EffectNode) -> bool:
		var pa: int = _priority(a.type)
		var pb: int = _priority(b.type)
		if pa != pb:
			return pa < pb
		# 同优先级保持原序
		return graph.nodes.find(a) < graph.nodes.find(b)
	)

	for node: EffectNode in sorted:
		plan.order.append(node.id)

	return plan


## 从节点 ID 数组直接构建执行计划（编译后同步计划与指令数）
## 用于 compile_with_mods 后重建计划，确保 plan.order.size() == program.size()
static func from_node_ids(ids: Array[String]) -> ExecutionPlan:
	var plan: ExecutionPlan = ExecutionPlan.new()
	plan.order = ids.duplicate()
	return plan


# ============================================================
# Internal
# ============================================================


static func _priority(type: String) -> int:
	return DEFAULT_PRIORITY.get(type, 100)
