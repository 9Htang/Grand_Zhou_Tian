# ============================================================
# 大周天 — CardData Resource (Layer0 静态模板)
# ============================================================
@tool
class_name CardData
extends Resource


enum CardType {
	ATTACK = 0,
	DEFENSE = 1,
	SKILL = 2,
	ARTIFACT_CARD = 3,
	TECHNIQUE = 4,
	QI_GATHER = 5,
	ELIXIR = 6,
}

enum CardRarity { BASIC = 0, COMMON = 1, UNCOMMON = 2, RARE = 3 }
enum TargetType { NONE = 0, SINGLE_ENEMY = 1, ALL_ENEMIES = 2, SELF = 3, RANDOM_ENEMY = 4 }
enum ElixirUseLocation { BATTLE_ONLY = 0, MAP_ONLY = 1, BOTH = 2 }

## 卡牌打出后的生命周期行为:
##   NORMAL=打出→弃牌堆
##   TECHNIQUE=打出→移除, 功法持续运行, 取消→回手牌
##   PERSISTENT_SKILL=打出→移除, 增益持续运行, 取消→回抽牌堆
##   MOUNT_ARTIFACT=打出→移除, 挂载到遗物栏
##   CHARGE_ARTIFACT=打出→消耗充能, 攻击免费, 需重新充能
##   CONTAINER=打出→展开内容物, 加入手牌, 移除自身
enum CardBehavior { NORMAL = 0, TECHNIQUE = 1, PERSISTENT_SKILL = 2, MOUNT_ARTIFACT = 3, CHARGE_ARTIFACT = 4, CONTAINER = 5 }

# === 基础信息 ===

## 卡牌唯一标识符，用于数据库索引和牌库引用
@export var id: String = ""

## 卡牌显示名称，如 "基础剑诀"
@export var display_name: String = ""

## 卡牌类型: 0=攻击 1=防御 2=技能 3=法宝牌 4=功法 5=蓄气 6=丹药
@export var card_type: CardType = CardType.ATTACK

## 卡牌稀有度: 0=基础(初始卡牌) 1=普通 2=罕见 3=稀有
@export var rarity: CardRarity = CardRarity.BASIC

## 五行元素: "火"/"水"/"木"/"金"/"土"/""=无
@export var element: String = ""

## 打出此卡牌消耗的灵气点数
@export var cost: int = 1

## 目标类型: 0=无需目标 1=单个敌人 2=全体敌人 3=自身 4=随机敌人
@export var target_type: TargetType = TargetType.SINGLE_ENEMY

## 卡牌描述文字，展示在卡牌界面的描述区域
@export_multiline var description: String = ""

## 卡牌风味文字，纯装饰性文本，不影响游戏逻辑
@export var flavor_text: String = ""

## 卡面美术资源路径，空字符串 = 根据 card_type 自动推导默认图
@export var card_art: String = ""

## 自由标签，用于牌库检索/联动/AI评估，如 ["剑法","火系","AOE"]
@export var tags: Array[String] = []

## 打出条件表达式，空字符串=无条件
## 格式: "key:value" 或 "key>=value"，多条件用 ; 分隔
## 支持: realm/talent/qi/hp_below/hp_above/has_technique/node_unlocked/turn/hand_size
@export var play_condition: String = ""

# === 功法卡牌 ===

## 关联的功法资源 ID，对应 TechniqueData.id
@export var technique_id: String = ""

# === 蓄气卡牌 ===

## 蓄气时聚集的灵气量
@export var qi_gather_amount: int = 0

## 聚灵修正: 影响每回合灵气恢复量, 1.0=正常, >1=增幅, <1=衰减
@export var qi_regen_mod: float = 1.0

# === 战斗属性 (legacy — 过渡期与新 base_effects 共存) ===

## 卡牌造成的基础伤害值
@export var damage: int = 0

## 卡牌提供的基础格挡值
@export var block: int = 0

## 卡牌恢复的生命值
@export var heal: int = 0

## 打出此卡牌时额外抽取的卡牌数量
@export var draw_count: int = 0

## 施加给自己的增益效果字符串，格式: "buff_name:value"，如 "strength:3"
@export var buff_self: String = ""

## 施加给敌人的减益效果字符串，格式: "debuff_name:value"，如 "burn:2"
@export var debuff_enemy: String = ""

# === 丹药卡牌 ===

## 丹药使用场景: 0=仅战斗中使用 1=仅地图界面使用 2=战斗和地图均可使用
@export var elixir_use_location: int = 0

## 丹药触发的效果字符串，使用统一效果协议
@export var elixir_effect: String = ""

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

## 分支目标 CardData.id 列表，如 ["fire_slash_rage","fire_slash_guard"]
## 非空时走分支替换升级，忽略 per_upgrade 线性加成
@export var upgrade_branches: Array[String] = []

# -- 旧字段（兼容现存 .tres，逐步迁移） --

## [deprecated] 升级后额外增加的伤害值 → 迁移到 damage_per_upgrade
@export var upgrade_damage_bonus: int = 3

## [deprecated] 升级后额外增加的格挡值 → 迁移到 block_per_upgrade
@export var upgrade_block_bonus: int = 3

## [deprecated] 升级后减少的灵气消耗量 → 迁移到 cost_reduce_per_upgrade
@export var upgrade_cost_reduction: int = 0

## [deprecated] 是否已升级 → 迁移到 CardInstance.upgrade_level
@export var upgraded: bool = false

# === 生命周期 ===

## 卡牌生命周期行为: 0=普通 1=功法 2=持续增益 3=挂载型法宝 4=充能型法宝 5=容器型法宝
@export var behavior: CardBehavior = CardBehavior.NORMAL

## 打出后延迟生效回合数, 0=立即
@export var delay_turns: int = 0

# === 容器属性 (仅 CONTAINER 型) ===

## 容器存储的物品 ID 列表，如丹药/主动法宝的 id
@export var container_contents: Array[String] = []

## 容器槽位类型限制: "elixir" / "artifact_active" / "any"，空数组表示无限制
@export var container_types: Array[String] = []

# === 效果图 (新 — 替代 legacy 数值字段) ===

## 基础效果节点列表 — EffectNode 数组，定义这张卡"做什么"
## 非空时优先使用此字段，忽略 legacy damage/block/heal 等字段
@export var base_effects: Array = []

## 生命周期触发器效果 — Dictionary{String: Array[EffectNode]}
## 支持 key: "on_draw" / "on_discard" / "on_exhaust" /
##   "on_hand_enter" / "on_hand_leave" / "on_retain"
## base_effects 等价于 "on_play"，无需在此重复
@export var trigger_effects: Dictionary = {}


# ============================================================
# 查询方法
# ============================================================


func get_type_name() -> String:
	match card_type:
		CardType.ATTACK: return "攻击"
		CardType.DEFENSE: return "防御"
		CardType.SKILL: return "技能"
		CardType.ARTIFACT_CARD: return "法宝"
		CardType.TECHNIQUE: return "功法"
		CardType.QI_GATHER: return "蓄气"
		CardType.ELIXIR: return "丹药"
	return "?"


func get_element_int() -> int:
	"""Convert element string to Element enum int. 0=无."""
	match element:
		"火": return 1
		"水": return 2
		"木": return 3
		"金": return 4
		"土": return 5
	return 0


## 是否使用新的 base_effects 系统
func uses_base_effects() -> bool:
	return not base_effects.is_empty()


## 是否包含指定触发器的效果
func has_trigger(key: String) -> bool:
	return trigger_effects.has(key) and not trigger_effects[key].is_empty()


## 是否有升级分支
func has_upgrade_branches() -> bool:
	return not upgrade_branches.is_empty()


## 是否可升级（线性或分支）
func can_upgrade(inst: CardInstance) -> bool:
	if inst == null:
		return false
	if has_upgrade_branches():
		# 分支升级: 检查当前 base_id 对应模板是否有下级分支
		var current_data: CardData = CardDatabase.get_card(inst.base_id)
		if current_data:
			return not current_data.upgrade_branches.is_empty()
		return false
	# 线性升级
	return inst.upgrade_level < max_upgrade_level


func apply_upgrade() -> CardData:
	"""旧版二元升级 — 向后兼容。新代码请使用 CardFactory.upgrade_instance()"""
	var c := duplicate()
	c.damage += upgrade_damage_bonus
	c.block += upgrade_block_bonus
	c.cost = maxi(0, c.cost - upgrade_cost_reduction)
	c.upgraded = true
	c.display_name = c.display_name + "+"
	return c
