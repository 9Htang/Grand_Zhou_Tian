# ============================================================
# 大周天 — MeridianMapData Resource（经脉地图定义）
# ============================================================
@tool
class_name MeridianMapData
extends Resource

# === 基础信息 ===

## 经脉地图唯一标识符，如 "small_circuit" / "grand_circuit"
@export var id: String = ""

## 经脉地图显示名称，如 "小周天" / "大周天"
@export var display_name: String = ""

## 是否为循环经脉（首尾相连），true=小周天回路 false=线性经脉
@export var is_circular: bool = false

## 丹田节点在 nodes 数组中的索引位置
@export var dantian_node_index: int = 0

# === 经脉结构 ===

## 经脉地图包含的所有穴位节点列表
@export var nodes: Array[MeridianNodeData] = []

## 经脉地图包含的所有经脉路径列表（节点间的连接）
@export var pathways: Array[MeridianPathwayData] = []


func get_node(index: int) -> MeridianNodeData:
	if index < 0 or index >= nodes.size():
		return null
	return nodes[index]


func get_next_node(from_index: int) -> int:
	var node := get_node(from_index)
	if not node or node.connections.is_empty():
		return -1
	return node.connections[0]


func get_node_count() -> int:
	return nodes.size()


func is_valid_index(index: int) -> bool:
	return index >= 0 and index < nodes.size()
