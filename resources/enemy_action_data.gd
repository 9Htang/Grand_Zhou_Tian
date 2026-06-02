# ============================================================
# 大周天 — EnemyActionData Resource（敌人行动定义）
# ============================================================
@tool
class_name EnemyActionData
extends Resource

enum IntentType {
	ATTACK = 0,
	ATTACK_MULTI = 1,
	DEFEND = 2,
	BUFF_SELF = 3,
	DEBUFF_PLAYER = 4,
	SEAL_MERIDIAN = 5,
	DAMAGE_PATHWAY = 6,
	DRAIN_QI = 7,
}

# === 基础战斗属性 ===

## 敌人行动意图类型: 0=攻击 1=多重攻击 2=防御 3=自增益 4=玩家减益 5=封印经脉 6=破坏路径 7=吸取灵气
@export var intent: int = IntentType.ATTACK

## 此行动造成的基础伤害值
@export var damage: int = 0

## 此行动获得的基础格挡值
@export var block: int = 0

## 施加给自己的增益效果字符串，格式: "buff_name:value"，如 "strength:3"
@export var buff_self: String = ""

## 施加给玩家的减益效果字符串，格式: "debuff_name:value"，如 "weak:2"
@export var debuff_player: String = ""

# === AI 行为 ===

## AI 选择此行动的随机权重，数值越大越容易被选中
@export var weight: int = 1

## 行动目标节点标识符（用于经脉封印/破坏类意图），空字符串表示无需指定目标
@export var target_node: String = ""
