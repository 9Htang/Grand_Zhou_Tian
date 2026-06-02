# ============================================================
# 大周天 — Map Node Data (地图节点)
# ============================================================
@tool
class_name MapNodeData
extends Resource

enum NodeType {
	BATTLE = 0,
	ELITE = 1,
	REST = 2,
	SHOP = 3,
	EVENT = 4,
	BOSS = 5,
}

# === 基础信息 ===

## 地图节点唯一标识符，如 "c1_n0"（第1章第0号节点）
@export var node_id: String = ""

## 地图节点类型: 0=战斗 1=精英 2=休息 3=商店 4=事件 5=Boss
@export var node_type: int = NodeType.BATTLE

## 节点在地图中所处的列 (0-based)，控制水平位置
@export var column: int = 0

## 节点在列内所处的行 (0-based)，控制垂直位置
@export var row: int = 0

## 可到达的下一列节点索引列表，空数组表示终点列
@export var connections: Array = []

## 对应遭遇战的 ID（BATTLE/ELITE/BOSS 类型必填），对应 EncounterData.id
@export var encounter_id: String = ""

## 节点显示名称，如 "战斗" / "精英" / "休息" / "商店" / "???"
@export var display_name: String = ""


func get_type_icon() -> String:
	match node_type:
		NodeType.BATTLE: return "⚔"
		NodeType.ELITE:  return "💀"
		NodeType.REST:   return "🔥"
		NodeType.SHOP:   return "💰"
		NodeType.EVENT:  return "?"
		NodeType.BOSS:   return "☠"
	return "·"


func get_type_color() -> Color:
	match node_type:
		NodeType.BATTLE: return Color(0.6, 0.6, 0.6)
		NodeType.ELITE:  return Color(0.9, 0.7, 0.2)
		NodeType.REST:   return Color(0.2, 0.8, 0.3)
		NodeType.SHOP:   return Color(0.2, 0.5, 0.9)
		NodeType.EVENT:  return Color(0.7, 0.3, 0.9)
		NodeType.BOSS:   return Color(0.9, 0.1, 0.1)
	return Color.WHITE
