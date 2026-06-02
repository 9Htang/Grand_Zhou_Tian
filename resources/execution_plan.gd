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


## 根据自定义优先级覆盖构建
static func build_custom(graph: EffectGraph, priority_overrides: Dictionary) -> ExecutionPlan:
	var plan: ExecutionPlan = ExecutionPlan.new()
	if graph.is_empty():
		return plan

	var sorted: Array[EffectNode] = graph.nodes.duplicate()
	sorted.sort_custom(func(a: EffectNode, b: EffectNode) -> bool:
		var pa: int = priority_overrides.get(a.type, _priority(a.type))
		var pb: int = priority_overrides.get(b.type, _priority(b.type))
		if pa != pb:
			return pa < pb
		return graph.nodes.find(a) < graph.nodes.find(b)
	)

	for node: EffectNode in sorted:
		plan.order.append(node.id)

	return plan


## 重新排序 — 将指定 id 移到指定位置
func move_to(id: String, position: int) -> void:
	var idx: int = order.find(id)
	if idx < 0:
		return
	var clamped_pos: int = clampi(position, 0, order.size() - 1)
	order.remove_at(idx)
	order.insert(clamped_pos, id)


## 将指定 id 移到最前
func move_to_front(id: String) -> void:
	move_to(id, 0)


## 将指定 id 移到末尾
func move_to_end(id: String) -> void:
	move_to(id, order.size() - 1)


## 交换两个 id 的位置
func swap(a_id: String, b_id: String) -> void:
	var ia: int = order.find(a_id)
	var ib: int = order.find(b_id)
	if ia < 0 or ib < 0:
		return
	var tmp: String = order[ia]
	order[ia] = order[ib]
	order[ib] = tmp


# ============================================================
# Internal
# ============================================================


static func _priority(type: String) -> int:
	return DEFAULT_PRIORITY.get(type, 100)
