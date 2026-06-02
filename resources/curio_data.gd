# ============================================================
# 大周天 — CurioData Resource
# 奇物：佩戴即生效（被动），有主动技能的需消耗灵气触发，可出售
# ============================================================
@tool
class_name CurioData
extends Resource

# === 基础信息 ===

## 奇物唯一标识符
@export var id: String = ""

## 奇物显示名称
@export var display_name: String = ""

## 奇物详细描述
@export_multiline var description: String = ""

# === 被动效果 ===

## 始终生效的被动效果列表（统一效果协议），如 ["qi_restore:1"]
@export var passive_effects: Array[String] = []

# === 主动技能 (可选) ===

## 主动技能消耗的灵气量，0=无主动技能
@export var active_skill_cost: int = 0

## 主动技能效果字符串（统一效果协议），如 "heal:10"
@export var active_skill_effect: String = ""

## 主动技能描述
@export var active_skill_description: String = ""
