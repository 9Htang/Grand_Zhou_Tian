# ============================================================
# 大周天 — EquipmentData Resource
# 装备：有固定槽位限制，可出售/丢弃
# ============================================================
@tool
class_name EquipmentData
extends Resource

## 装备槽位: 0=头 1=身 2=裤 3=脚 4=武器
enum Slot { HEAD = 0, BODY = 1, PANTS = 2, FEET = 3, WEAPON = 4 }

## 装备稀有度: 0=普通 1=罕见 2=稀有
enum Rarity { COMMON = 0, UNCOMMON = 1, RARE = 2 }

# === 基础信息 ===

## 装备唯一标识符
@export var id: String = ""

## 装备显示名称
@export var display_name: String = ""

## 装备详细描述
@export_multiline var description: String = ""

## 装备槽位: 0=头 1=身 2=裤 3=脚 4=武器
@export var slot: Slot = Slot.HEAD

## 装备稀有度: 0=普通 1=罕见 2=稀有
@export var rarity: Rarity = Rarity.COMMON

# === 属性加成 ===

## 生命上限加成
@export var hp_bonus: int = 0

## 每回合格挡加成
@export var block_bonus: int = 0

## 聚灵加成（每回合额外灵气恢复）
@export var qi_regen_bonus: int = 0

## 神识加成（影响法宝槽位上限）
@export var divine_sense_bonus: int = 0

# === 特殊效果 ===

## 装备特殊效果列表（统一效果协议），如 ["gain_qi:1", "attack_up:2"]
@export var effects: Array[String] = []
