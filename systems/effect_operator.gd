# ============================================================
# 大周天 — EffectOperator
# 统一卡牌效果操作语言
# 所有 swap/remove/reorder/transform 都走这套操作
# ============================================================
class_name EffectOperator
extends RefCounted


# === 操作类型枚举 ===

enum OpType {
	# ① SCOPE (最先 — 确定操作范围)
	SELECT_ALL = 0,
	SELECT_FIRST = 1,
	SELECT_LAST = 2,
	SELECT_RANDOM = 3,
	SELECT_BY_TYPE = 4,
	SELECT_BY_TAG = 5,

	# ② CREATE (再创建)
	ADD_NODE = 10,
	COPY_NODE = 11,

	# ③ MODIFY (再修改)
	MODIFY_VALUE = 20,
	TRANSFORM = 21,

	# ④ DESTROY (再删除/替换)
	REMOVE_NODE = 30,
	SWAP_NODE = 31,

	# ⑤ ORDER (最后 — 排序)
	REORDER = 40,
	PRIORITY_SET = 41,
	DELAY = 42,
}


## 操作类型
var type: int = OpType.ADD_NODE

## 目标: node_id / type / tag
var target: String = ""

## 操作参数，按 type 不同含义不同:
##   ADD_NODE: {type: "burn", value: 3, meta: {turns: 2}}
##   REMOVE_NODE: {} (按 target 删除)
##   MODIFY_VALUE: {delta: 3} 或 {multiplier: 1.5}
##   TRANSFORM: {to_type: "stun"}
##   SWAP_NODE: {with: "n2"}
##   COPY_NODE: {new_id: "n5"}
##   REORDER: {position: 0}  # 移到位置
##   PRIORITY_SET: {priority: 999}
##   DELAY: {turns: 2}
var params: Dictionary = {}


# ============================================================
# 工厂方法
# ============================================================


static func add(type: String, value: int, meta: Dictionary = {}, target_id: String = "") -> EffectOperator:
	var op: EffectOperator = EffectOperator.new()
	op.type = OpType.ADD_NODE
	op.target = target_id
	op.params = {"type": type, "value": value, "meta": meta}
	return op


static func remove(target: String) -> EffectOperator:
	var op: EffectOperator = EffectOperator.new()
	op.type = OpType.REMOVE_NODE
	op.target = target
	return op


static func swap_node(a: String, b: String) -> EffectOperator:
	var op: EffectOperator = EffectOperator.new()
	op.type = OpType.SWAP_NODE
	op.target = a
	op.params = {"with": b}
	return op


static func copy_node(source_id: String) -> EffectOperator:
	var op: EffectOperator = EffectOperator.new()
	op.type = OpType.COPY_NODE
	op.target = source_id
	return op


static func modify_value(target: String, delta: int = 0, multiplier: float = 1.0) -> EffectOperator:
	var op: EffectOperator = EffectOperator.new()
	op.type = OpType.MODIFY_VALUE
	op.target = target
	op.params = {"delta": delta, "multiplier": multiplier}
	return op


static func transform(target: String, to_type: String) -> EffectOperator:
	var op: EffectOperator = EffectOperator.new()
	op.type = OpType.TRANSFORM
	op.target = target
	op.params = {"to_type": to_type}
	return op


static func select_all() -> EffectOperator:
	var op: EffectOperator = EffectOperator.new()
	op.type = OpType.SELECT_ALL
	return op


static func select_first() -> EffectOperator:
	var op: EffectOperator = EffectOperator.new()
	op.type = OpType.SELECT_FIRST
	return op


static func select_last() -> EffectOperator:
	var op: EffectOperator = EffectOperator.new()
	op.type = OpType.SELECT_LAST
	return op


static func select_random() -> EffectOperator:
	var op: EffectOperator = EffectOperator.new()
	op.type = OpType.SELECT_RANDOM
	return op


static func select_by_type(type: String) -> EffectOperator:
	var op: EffectOperator = EffectOperator.new()
	op.type = OpType.SELECT_BY_TYPE
	op.target = type
	return op


static func select_by_tag(tag: String) -> EffectOperator:
	var op: EffectOperator = EffectOperator.new()
	op.type = OpType.SELECT_BY_TAG
	op.target = tag
	return op


static func reorder(target: String, position: int) -> EffectOperator:
	var op: EffectOperator = EffectOperator.new()
	op.type = OpType.REORDER
	op.target = target
	op.params = {"position": position}
	return op


static func set_priority(target: String, priority: int) -> EffectOperator:
	var op: EffectOperator = EffectOperator.new()
	op.type = OpType.PRIORITY_SET
	op.target = target
	op.params = {"priority": priority}
	return op


static func delay_effect(target: String, turns: int) -> EffectOperator:
	var op: EffectOperator = EffectOperator.new()
	op.type = OpType.DELAY
	op.target = target
	op.params = {"turns": turns}
	return op


# ============================================================
# 批量应用 — 核心入口
# ============================================================


## 对 EffectGraph 应用一组 Operator
## 内部按类别优先级排序 → 逐个应用 → 返回修改后的 graph
static func apply_all(graph: EffectGraph, ops: Array) -> EffectGraph:
	if ops.is_empty():
		return graph

	# 按优先级排序 (类别内保持原序 = stable sort)
	var sorted: Array = _sort_by_priority(ops)
	var selected_ids: Array[String] = []  # 当前 scope 选中的节点 id

	for op: EffectOperator in sorted:
		match op.type:
			OpType.SELECT_ALL:
				selected_ids = graph.all_ids()
			OpType.SELECT_FIRST:
				selected_ids = _select_first(graph)
			OpType.SELECT_LAST:
				selected_ids = _select_last(graph)
			OpType.SELECT_RANDOM:
				selected_ids = _select_random(graph)
			OpType.SELECT_BY_TYPE:
				selected_ids = _ids_of(graph.find_by_type(op.target))
			OpType.SELECT_BY_TAG:
				selected_ids = _ids_of(graph.find_by_tag(op.target))

			OpType.ADD_NODE:
				_apply_add(graph, op)
			OpType.COPY_NODE:
				_apply_copy(graph, op)

			OpType.MODIFY_VALUE:
				_apply_modify(graph, op, selected_ids)
			OpType.TRANSFORM:
				_apply_transform(graph, op, selected_ids)

			OpType.REMOVE_NODE:
				_apply_remove(graph, op, selected_ids)
			OpType.SWAP_NODE:
				_apply_swap(graph, op)

			OpType.REORDER, OpType.PRIORITY_SET, OpType.DELAY:
				# Order 类操作不修改 graph 结构，标记在 params 中
				# 由 ExecutionPlan 构建时消费
				pass

	return graph


# ============================================================
# Internal — 优先级排序
# ============================================================


static func _sort_by_priority(ops: Array) -> Array:
	var result: Array = ops.duplicate()
	result.sort_custom(func(a: EffectOperator, b: EffectOperator) -> bool:
		return _category(a.type) < _category(b.type)
	)
	return result


static func _category(op_type: int) -> int:
	if op_type <= 5:   return 1   # SCOPE
	if op_type <= 11:  return 2   # CREATE
	if op_type <= 21:  return 3   # MODIFY
	if op_type <= 31:  return 4   # DESTROY
	if op_type <= 42:  return 5   # ORDER
	return 99


# ============================================================
# Internal — 操作实现
# ============================================================


static func _apply_add(graph: EffectGraph, op: EffectOperator) -> void:
	var n: EffectNode = EffectNode.new()
	n.id = op.target
	n.type = op.params.get("type", "")
	n.value = op.params.get("value", 0)
	n.meta = op.params.get("meta", {})
	graph.add_node(n)


static func _apply_copy(graph: EffectGraph, op: EffectOperator) -> void:
	var src: EffectNode = graph.get_node(op.target)
	if src == null:
		return
	var n: EffectNode = src.duplicate_node()
	n.id = op.params.get("new_id", "")
	graph.add_node(n)


static func _apply_modify(graph: EffectGraph, op: EffectOperator, target_ids: Array[String]) -> void:
	var ids: Array[String] = _resolve_targets(graph, op.target, target_ids)
	var delta: int = op.params.get("delta", 0)
	var mult: float = op.params.get("multiplier", 1.0)
	for id: String in ids:
		var node: EffectNode = graph.get_node(id)
		if node:
			node.value = maxi(0, int(float(node.value + delta) * mult))


static func _apply_transform(graph: EffectGraph, op: EffectOperator, target_ids: Array[String]) -> void:
	var ids: Array[String] = _resolve_targets(graph, op.target, target_ids)
	var to_type: String = op.params.get("to_type", "")
	for id: String in ids:
		var node: EffectNode = graph.get_node(id)
		if node:
			node.type = to_type


static func _apply_remove(graph: EffectGraph, op: EffectOperator, target_ids: Array[String]) -> void:
	var ids: Array[String] = _resolve_targets(graph, op.target, target_ids)
	for id: String in ids:
		graph.remove_node(id)


static func _apply_swap(graph: EffectGraph, op: EffectOperator) -> void:
	var a_id: String = op.target
	var b_id: String = op.params.get("with", "")
	var a: EffectNode = graph.get_node(a_id)
	var b: EffectNode = graph.get_node(b_id)
	if a == null or b == null:
		return
	# 交换 type 和 value (保留各自的 id 和 meta)
	var tmp_type: String = a.type
	var tmp_value: int = a.value
	a.type = b.type
	a.value = b.value
	b.type = tmp_type
	b.value = tmp_value


# ============================================================
# Internal — 辅助
# ============================================================


## 解析目标: 如果 target 非空则用 target，否则用 selected_ids
static func _resolve_targets(graph: EffectGraph, target: String, selected_ids: Array[String]) -> Array[String]:
	if not target.is_empty():
		# 按 type 批量匹配
		var by_type: Array[EffectNode] = graph.find_by_type(target)
		if not by_type.is_empty():
			return _ids_of(by_type)
		# 按 id 精确匹配
		if graph.get_node(target):
			return [target]
		return []
	# 无指定 target → 用 scope 选中的
	if not selected_ids.is_empty():
		return selected_ids
	# 都没 → 操作全部节点
	return graph.all_ids()


static func _ids_of(nodes: Array) -> Array[String]:
	var result: Array[String] = []
	for node: EffectNode in nodes:
		result.append(node.id)
	return result


static func _select_first(graph: EffectGraph) -> Array[String]:
	if graph.is_empty():
		return []
	return [graph.nodes[0].id]


static func _select_last(graph: EffectGraph) -> Array[String]:
	if graph.is_empty():
		return []
	return [graph.nodes[graph.nodes.size() - 1].id]


static func _select_random(graph: EffectGraph) -> Array[String]:
	if graph.is_empty():
		return []
	var idx: int = randi() % graph.nodes.size()
	return [graph.nodes[idx].id]
