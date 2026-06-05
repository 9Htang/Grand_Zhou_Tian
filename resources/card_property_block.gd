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

# === 升级系统 ===

## 最大线性升级次数, 0=不可升级
@export var max_upgrade_level: int = 0

## 每级升级对应的 EffectOperator 数组，index 0 = Lv1
@export var upgrade_operators: Array = []

# === 效果图 ===

## 基础效果节点 — EffectNode 数组
@export var base_effects: Array = []

## 生命周期触发器效果 — Dictionary{String: Array[EffectNode]}
## 支持 key: "on_draw" / "on_discard" / "on_exhaust" /
##   "on_hand_enter" / "on_hand_leave" / "on_retain"
@export var trigger_effects: Dictionary = {}
