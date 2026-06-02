# ============================================================
# 大周天 — EncounterData Resource
# ============================================================
@tool
class_name EncounterData
extends Resource

# === 基础信息 ===

## 遭遇战唯一标识符
@export var id: String = ""

## 遭遇战类型: 0=普通战斗 1=精英战 2=Boss战
@export var encounter_type: int = 0

# === 敌人配置 ===

## 此遭遇战包含的敌人 ID 列表，对应 EnemyData.id
@export var enemy_ids: Array[String] = []

# === 奖励 ===

## 胜利后可选的卡牌奖励 ID 池，从池中随机抽取供玩家选择
@export var reward_card_pool: Array[String] = []

## 胜利后获得的灵石数量
@export var gold_reward: int = 10

## 胜利后获得的修为值
@export var cultivation_reward: int = 15

## 法宝掉落概率 (0.0~1.0)，精英战建议 0.3，Boss战建议 1.0
@export var artifact_drop_chance: float = 0.0
