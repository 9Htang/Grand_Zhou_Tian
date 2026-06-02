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


## 从 EffectNode 数组构建图
static func from_array(arr: Array) -> EffectGraph:
	var g: EffectGraph = EffectGraph.new()
	for node: EffectNode in arr:
		g.add_node(node)
	return g


## 从 CardData 的 legacy 字段构建图（过渡期兼容）
## 当 CardData.base_effects 为空时，用此方法从旧字段推导 EffectNode 列表
static func from_legacy(card: CardData) -> EffectGraph:
	var g: EffectGraph = EffectGraph.new()
	var idx: int = 0

	if card.damage > 0:
		g.add_node(_make_node("n%d" % idx, "damage", card.damage)); idx += 1
	if card.block > 0:
		g.add_node(_make_node("n%d" % idx, "block", card.block)); idx += 1
	if card.heal > 0:
		g.add_node(_make_node("n%d" % idx, "heal", card.heal)); idx += 1
	if card.draw_count > 0:
		g.add_node(_make_node("n%d" % idx, "draw", card.draw_count)); idx += 1
	if card.qi_gather_amount > 0:
		g.add_node(_make_node("n%d" % idx, "qi_gather", card.qi_gather_amount)); idx += 1
	if not card.buff_self.is_empty():
		g.add_node(_make_node("n%d" % idx, "buff", 0, {"name": card.buff_self})); idx += 1
	if not card.debuff_enemy.is_empty():
		g.add_node(_make_node("n%d" % idx, "debuff", 0, {"name": card.debuff_enemy})); idx += 1

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


static func _make_node(id: String, type: String, value: int, meta: Dictionary = {}) -> EffectNode:
	var n: EffectNode = EffectNode.new()
	n.id = id
	n.type = type
	n.value = value
	n.meta = meta
	return n
