# ============================================================
# 大周天 — EffectGraph
# 卡牌效果的图结构，EffectNode 的有序集合
# CardRuntime 持有的可变效果图，所有 Operator 的操作目标
# ============================================================
class_name EffectGraph
extends RefCounted


## 效果节点列表
var nodes: Array[EffectNode] = []

## 边列表 [{from: "n1", to: "n2"}] — 用于效果依赖关系
var edges: Array[Dictionary] = []


# ============================================================
# 工厂
# ============================================================


## 从 EffectNode 数组构建图 — 深拷贝节点，防止 modifier 污染原始 CardData
static func from_array(arr: Array) -> EffectGraph:
	var g: EffectGraph = EffectGraph.new()
	for node: EffectNode in arr:
		g.add_node(node.duplicate_node())
	return g


# ============================================================
# CRUD
# ============================================================


## 添加节点，自动生成 id（如果为空）
func add_node(node: EffectNode) -> void:
	if node.id.is_empty():
		node.id = "n%d" % nodes.size()
	nodes.append(node)


## 按 id 移除节点
func remove_node(id: String) -> bool:
	for i in range(nodes.size()):
		if nodes[i].id == id:
			nodes.remove_at(i)
			return true
	return false


## 按 id 查找节点
func get_node(id: String) -> EffectNode:
	for node: EffectNode in nodes:
		if node.id == id:
			return node
	return null


## 按 type 查找所有匹配节点
func find_by_type(type: String) -> Array[EffectNode]:
	var result: Array[EffectNode] = []
	for node: EffectNode in nodes:
		if node.type == type:
			result.append(node)
	return result


## 按 tag 查找 — 通过 meta.tags
func find_by_tag(tag: String) -> Array[EffectNode]:
	var result: Array[EffectNode] = []
	for node: EffectNode in nodes:
		var tags: Array = node.meta.get("tags", [])
		if tag in tags:
			result.append(node)
	return result


## 深拷贝整个图
func duplicate_graph() -> EffectGraph:
	var g: EffectGraph = EffectGraph.new()
	for node: EffectNode in nodes:
		g.add_node(node.duplicate_node())
	for edge: Dictionary in edges:
		g.edges.append(edge.duplicate())
	return g


## 获取所有节点 id
func all_ids() -> Array[String]:
	var result: Array[String] = []
	for node: EffectNode in nodes:
		result.append(node.id)
	return result


## 节点数量
func size() -> int:
	return nodes.size()


## 是否为空
func is_empty() -> bool:
	return nodes.is_empty()


# ============================================================
# Internal
# ============================================================
