# ============================================================
# 大周天 — TechniqueData Resource
# ============================================================
@tool
class_name TechniqueData
extends Resource

# === 基础信息 ===

## 功法唯一标识符，用于数据库索引和卡牌/经脉引用
@export var id: String = ""

## 功法显示名称，如 "烈火诀"
@export var display_name: String = ""

## 功法详细描述，展示在功法界面的描述区域
@export_multiline var description: String = ""

## 功法五行属性: "火"/"水"/"木"/"金"/"土"
@export var element: String = "火"

# === 灵气运行 ===

## 功法每经过一个穴位消耗的灵气量
@export var qi_per_step: int = 1

## 功法完成一个小周天后返回的灵气占比 (0.0~1.0)
@export var qi_return_rate: float = 0.8

## 功法-穴位反应映射: key=五行元素名, value=反应效果字符串
## 如 {"火": "attack_up:3", "水": "energy_down:1"}
@export var node_reactions: Dictionary = {}

# === 战斗修正 ===

## 攻击力倍率: 1.0=正常, >1=增幅, <1=衰减
@export var attack_multiplier: float = 1.0

## 防御力倍率: 1.0=正常, >1=增幅, <1=衰减
@export var defense_multiplier: float = 1.0

## 攻击附加效果字符串，格式: "效果名:参数"，如 "burn:2"
@export var attack_bonus: String = ""

## 防御附加效果字符串，格式: "效果名:参数"
@export var defense_bonus: String = ""

# === 经脉扩展 ===

## 此功法解锁/激活的经脉路径 ID 列表
@export var meridian_extension: Array[String] = []

## 功法每回合从经脉抽取的灵气速率，宽经可支撑高消耗流派
@export var qi_draw_rate: float = 0.0

## 聚灵修正: 影响每回合灵气恢复量, 1.0=正常, >1=增幅, <1=衰减
@export var qi_regen_mod: float = 1.0

## 功法对丹田压强的修正系数: 1.0=不变, >1=增压(加快流速), <1=减压(减缓流速)
@export var pressure_mod: float = 1.0

## 灵气优先流向的元素方向，空字符串表示无偏好
@export var preferred_element: String = ""


func get_element_int() -> int:
	"""Convert element string to Element enum int."""
	match element:
		"火": return 1
		"水": return 2
		"木": return 3
		"金": return 4
		"土": return 5
	return 0


func get_reaction_for(element_name: String) -> String:
	return node_reactions.get(element_name, "")
