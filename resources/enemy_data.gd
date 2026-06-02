@tool
class_name EnemyData
extends Resource

# === 基础信息 ===

## 敌人唯一标识符，用于数据库索引和遭遇战引用
@export var id: String = ""

## 敌人显示名称，展示在战斗界面的敌人名称栏
@export var display_name: String = "敌人"

## 敌人最大生命值
@export var max_hp: int = 20

## 敌人修为境界等级，影响基础属性缩放
@export var realm: int = 1

## 敌人五行属性: "火"/"水"/"木"/"金"/"土"，空字符串表示无属性
@export var element: String = ""

# === 行动配置 ===

## 敌人可用的行动列表，AI 每回合按权重从中选择
@export var actions: Array[EnemyActionData] = []

## 敌人每回合执行的行动数量
@export var action_count: int = 1

# === 奖励 ===

## 击败敌人后获得的灵石数量
@export var reward_gold: int = 10

## 击败敌人后获得的修为值
@export var reward_cultivation: int = 20

## 战斗场景中敌人的显示颜色
@export var texture_color: Color = Color(1, 0.2, 0.2)

# === 对称战斗字段（经脉系统） ===

## 敌人经脉地图标识符，对应 MeridianMapData.id
@export var meridian_id: String = ""

## 敌人丹田灵气容量上限
@export var dantian_capacity: int = 8

## 敌人丹田压强，影响灵气流动速度
@export var dantian_pressure: float = 3.0

## 敌人每回合自动聚集的灵气量
@export var qi_gather_rate: int = 2

## 敌人初始功法 ID 列表，对应 TechniqueData.id
@export var initial_techniques: Array[String] = []

## 敌人牌库卡牌 ID 列表，对应 CardData.id
@export var deck_card_ids: Array[String] = []

## AI 策略标识符: "balanced"=均衡 / "aggressive"=激进 / "defensive"=防御
@export var ai_strategy: String = "balanced"

## 敌人天赋等级，影响 AI 决策智能程度和属性加成
@export var talent: int = 1
