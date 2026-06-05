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
enum ElixirUseLocation { BATTLE_ONLY = 0, MAP_ONLY = 1, BOTH = 2 }

## 卡牌打出后的生命周期行为:
##   NORMAL=打出→弃牌堆
##   TECHNIQUE=打出→移除, 功法持续运行, 取消→回手牌
##   PERSISTENT_SKILL=打出→移除, 增益持续运行, 取消→回抽牌堆
##   MOUNT_ARTIFACT=打出→移除, 挂载到遗物栏
##   CHARGE_ARTIFACT=打出→消耗充能, 攻击免费, 需重新充能
##   CONTAINER=打出→展开内容物, 加入手牌, 移除自身
##   FORGE=打出→转化卡牌特性 (薪火相传/离火易象)
enum CardBehavior { NORMAL = 0, TECHNIQUE = 1, PERSISTENT_SKILL = 2, MOUNT_ARTIFACT = 3, CHARGE_ARTIFACT = 4, CONTAINER = 5, FORGE = 6 }

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
## 支持: realm/talent/qi/has_technique/node_unlocked/turn/hand_size
@export var play_condition: String = ""

# === 功法卡牌 ===

## 关联的功法资源 ID，对应 TechniqueData.id
@export var technique_id: String = ""

# === 丹药卡牌 ===

## 丹药使用场景: 0=仅战斗中使用 1=仅地图界面使用 2=战斗和地图均可使用
@export var elixir_use_location: int = 0

## 丹药触发的效果字符串，使用统一效果协议
@export var elixir_effect: String = ""

# === 升级系统 ===

## 最大线性升级次数, 0=不可升级
@export var max_upgrade_level: int = 0

## 每级升级对应的 EffectOperator 数组，index 0 = Lv1, index 1 = Lv2, ...
## 空数组表示此卡无升级效果。
## 例: [[select_by_type("damage"), modify_value("damage", 3)]]
@export var upgrade_operators: Array = []

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

# === 旧版数值字段 (向后兼容) ===

## 基础伤害值
@export var damage: int = 0

## 基础格挡值
@export var block: int = 0

## 基础治疗值
@export var heal: int = 0

## 蓄气量
@export var qi_gather_amount: int = 0

## 自身增益效果，格式: "name:value:duration"，如 "strength:1:3"
@export var buff_self: String = ""

## 升级时伤害加成
@export var upgrade_damage_bonus: int = 0

## 升级时格挡加成
@export var upgrade_block_bonus: int = 0

## 目标类型: 0=无需目标 1=单体敌人 2=全体敌人 3=自身 4=随机敌人
@export var target_type: int = 0

## 每次升级减少的费用
@export var cost_reduce_per_upgrade: int = 0

# === 效果图 (新 — 替代 legacy 数值字段) ===

## 基础效果节点列表 — EffectNode 数组，定义这张卡"做什么"
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



	## 获取卡牌的有效效果节点列表
	## base_effects 非空 → 返回 base_effects
	## base_effects 为空 → 从旧版平铺字段自动合成 EffectNode
func get_or_build_effects() -> Array:
	if not base_effects.is_empty():
		return base_effects

	var nodes: Array = []
	if damage > 0:
		var n: EffectNode = EffectNode.new()
		n.id = "n_dmg"
		n.type = "damage"
		n.value = damage
		n.target = TargetSpec.from_card_type(target_type)
		nodes.append(n)
	if block > 0:
		var n: EffectNode = EffectNode.new()
		n.id = "n_block"
		n.type = "block"
		n.value = block
		n.target = TargetSpec.from_card_type(3)  # SELF
		nodes.append(n)
	if heal > 0:
		var n: EffectNode = EffectNode.new()
		n.id = "n_heal"
		n.type = "heal"
		n.value = heal
		n.target = TargetSpec.from_card_type(3)  # SELF
		nodes.append(n)
	if qi_gather_amount > 0:
		var n: EffectNode = EffectNode.new()
		n.id = "n_qi"
		n.type = "qi_gather"
		n.value = qi_gather_amount
		n.target = TargetSpec.from_card_type(0)  # NONE — self-effect
		nodes.append(n)
	if not buff_self.is_empty():
		var parts: PackedStringArray = buff_self.split(":")
		if parts.size() >= 2:
			var n: EffectNode = EffectNode.new()
			n.id = "n_buff"
			n.type = "buff"
			n.meta = {
				"status_type": parts[0],
				"value": int(parts[1]),
				"duration": int(parts[2]) if parts.size() >= 3 else 1
			}
			n.target = TargetSpec.from_card_type(3)  # SELF
			nodes.append(n)
	return nodes


## 是否包含指定触发器的效果
func has_trigger(key: String) -> bool:
	return trigger_effects.has(key) and not trigger_effects[key].is_empty()


## 是否可升级（线性: upgrade_level < max_upgrade_level）
func can_upgrade(inst: CardInstance) -> bool:
	if inst == null:
		return false
	return inst.upgrade_level < max_upgrade_level
