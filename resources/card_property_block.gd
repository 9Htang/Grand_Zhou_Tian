# ============================================================
# 大周天 — CardPropertyBlock Resource
# 用于 CardFactory 的卡牌属性块，支持设计时批量生成 + 运行时动态生成
# 永不在运行时使用 — 本质是编辑器生产工具 (Excel → 配置表)
# ============================================================
@tool
class_name CardPropertyBlock
extends Resource


# === 基础信息 ===

## 卡牌唯一标识符
@export var id: String = ""

## 卡牌显示名称
@export var display_name: String = ""

## 卡牌类型: 0=攻击 1=防御 2=技能 3=法宝牌 4=功法 5=蓄气 6=丹药
@export var card_type: int = 0

## 卡牌稀有度: 0=基础 1=普通 2=罕见 3=稀有
@export var rarity: int = 0

## 打出此卡牌消耗的灵气点数
@export var cost: int = 1

## 目标类型: 0=无需目标 1=单个敌人 2=全体敌人 3=自身 4=随机敌人
@export var target_type: int = 1

## 五行元素: "火"/"水"/"木"/"金"/"土"/""=无
@export var element: String = ""

## 卡牌描述文字
@export_multiline var description: String = ""

## 卡牌风味文字
@export var flavor_text: String = ""

## 卡面美术资源路径
@export var card_art: String = ""

## 自由标签
@export var tags: Array[String] = []

## 打出条件表达式
@export var play_condition: String = ""

# === 生命周期 ===

## 卡牌生命周期行为: 0=普通 1=功法 2=持续增益 3=挂载型法宝 4=充能型法宝 5=容器型法宝
@export var behavior: int = 0

## 打出后延迟生效回合数, 0=立即
@export var delay_turns: int = 0

# === 数值 ===

## 基础伤害值
@export var damage: int = 0

## 基础格挡值
@export var block: int = 0

## 恢复的生命值
@export var heal: int = 0

## 额外抽取的卡牌数量
@export var draw_count: int = 0

## 蓄气时聚集的灵气量
@export var qi_gather_amount: int = 0

## 聚灵修正: 影响每回合灵气恢复量, 1.0=正常
@export var qi_regen_mod: float = 1.0

# === 增益/减益 ===

## 施加给自己的增益效果字符串，格式: "buff_name:value"
@export var buff_self: String = ""

## 施加给敌人的减益效果字符串，格式: "debuff_name:value"
@export var debuff_enemy: String = ""

# === 功法关联 (仅 TECHNIQUE 行为) ===

## 关联的功法资源 ID
@export var technique_id: String = ""

# === 丹药属性 (仅丹药卡) ===

## 丹药使用场景: 0=仅战斗 1=仅地图 2=双用
@export var elixir_use_location: int = 0

## 丹药触发的效果字符串（统一效果协议）
@export var elixir_effect: String = ""

# === 容器属性 (仅 CONTAINER 行为) ===

## 容器存储的物品 ID 列表
@export var container_contents: Array[String] = []

## 容器槽位类型限制: "elixir"/"artifact_active"/"any"
@export var container_types: Array[String] = []

# === 升级系统 ===

# -- 新字段（多级升级） --

## 最大线性升级次数, 0=不可升级
@export var max_upgrade_level: int = 0

## 每级伤害加成
@export var damage_per_upgrade: int = 0

## 每级格挡加成
@export var block_per_upgrade: int = 0

## 每级治疗加成
@export var heal_per_upgrade: int = 0

## 每级减少的灵气消耗
@export var cost_reduce_per_upgrade: int = 0

## 分支目标 CardData.id 列表
@export var upgrade_branches: Array[String] = []

# -- 旧字段（兼容） --

## [deprecated] 升级伤害加成 → 迁移到 damage_per_upgrade
@export var upgrade_damage_bonus: int = 3

## [deprecated] 升级格挡加成 → 迁移到 block_per_upgrade
@export var upgrade_block_bonus: int = 3

## [deprecated] 升级减费 → 迁移到 cost_reduce_per_upgrade
@export var upgrade_cost_reduction: int = 0

# === 效果图 (新) ===

## 基础效果节点 — EffectNode 数组
@export var base_effects: Array = []

## 生命周期触发器效果 — Dictionary{String: Array[EffectNode]}
## 支持 key: "on_draw" / "on_discard" / "on_exhaust" /
##   "on_hand_enter" / "on_hand_leave" / "on_retain"
@export var trigger_effects: Dictionary = {}
