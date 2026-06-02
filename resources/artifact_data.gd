# ============================================================
# 大周天 — ArtifactData Resource
# ============================================================
@tool
class_name ArtifactData
extends Resource

# === 基础信息 ===

## 法宝唯一标识符，用于数据库索引和商店/掉落引用
@export var id: String = ""

## 法宝显示名称，如 "聚灵珠"
@export var display_name: String = ""

## 法宝详细描述，展示在法宝界面的描述区域
@export_multiline var description: String = ""

# === 法宝类型 ===

## 法宝类型: "passive"=被动遗物 / "active_mount"=打出后挂载 / "active_charge"=充能型 / "active_container"=容器型
@export var artifact_type: String = "passive"

# === 灵气行为 ===

## 被动/挂载型每回合消耗的灵气量，0=不消耗
@export var qi_per_turn: int = 0

## 充能型攻击后的重新充能所需灵气量
@export var charge_cost: int = 0

## 充能型当前储存量（运行时动态变化）
@export var charge_stored: int = 0

# === 容器属性 (仅 active_container 型) ===

## 容器槽位数量
@export var container_slots: int = 3

## 容器可存储的物品类型: "elixir" / "artifact_active" / "any"
@export var container_types: Array[String] = []

## 容器当前存储的物品 ID 列表（运行时动态变化）
@export var container_contents: Array[String] = []

# === 触发与效果 ===

## 法宝触发时机: "on_turn_start"=回合开始 / "on_card_play"=打出卡牌时 /
##   "on_damage_taken"=受到伤害时 / "on_qi_circulate"=灵气循环时 /
##   "on_battle_start"=战斗开始时 / "always"=始终生效(被动) /
##   "on_attack_played"=打出攻击牌时 / "on_defense_played"=打出防御牌时
@export var trigger: String = "always"

## 触发条件表达式，满足此条件时法宝才会生效，空字符串表示无条件触发
@export var condition: String = ""

## 法宝效果字符串（使用统一效果协议格式），如 "gain_qi:2" / "damage_bonus:3"
@export var effect: String = ""


func get_trigger_int() -> int:
	match trigger:
		"on_turn_start": return 0
		"on_card_play": return 1
		"on_damage_taken": return 2
		"on_qi_circulate": return 3
		"on_battle_start": return 4
		"always": return 5
		"on_attack_played": return 6
		"on_defense_played": return 7
	return 5
