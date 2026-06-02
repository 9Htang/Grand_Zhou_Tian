# ============================================================
# 大周天 — Constants & Enums
# ============================================================
class_name Constants

# --- Card Types ---
enum CardType {
	ATTACK = 0,
	DEFENSE = 1,
	SKILL = 2,
	ARTIFACT_CARD = 3,
	TECHNIQUE = 4,
	QI_GATHER = 5,
	ELIXIR = 6,
}

static func card_type_name(t: CardType) -> String:
	match t:
		CardType.ATTACK: return "攻击"
		CardType.DEFENSE: return "防御"
		CardType.SKILL: return "技能"
		CardType.ARTIFACT_CARD: return "法宝"
		CardType.TECHNIQUE: return "功法"
		CardType.QI_GATHER: return "蓄气"
		CardType.ELIXIR: return "丹药"
	return "未知"

# --- Five Elements (五行) ---
enum Element {
	NONE = 0,
	FIRE = 1,    # 火
	WATER = 2,   # 水
	WOOD = 3,    # 木
	METAL = 4,   # 金
	EARTH = 5,   # 土
}

static func element_name(e: Element) -> String:
	match e:
		Element.NONE: return "无"
		Element.FIRE: return "火"
		Element.WATER: return "水"
		Element.WOOD: return "木"
		Element.METAL: return "金"
		Element.EARTH: return "土"
	return "?"

static func element_from_string(s: String) -> Element:
	match s:
		"火", "fire": return Element.FIRE
		"水", "water": return Element.WATER
		"木", "wood": return Element.WOOD
		"金", "metal": return Element.METAL
		"土", "earth": return Element.EARTH
	return Element.NONE

# 相生: Generator -> Generated
const ELEMENT_GENERATES := {
	Element.FIRE: Element.EARTH,   # 火生土
	Element.EARTH: Element.METAL,  # 土生金
	Element.METAL: Element.WATER,  # 金生水
	Element.WATER: Element.WOOD,   # 水生木
	Element.WOOD: Element.FIRE,    # 木生火
}

# 相克: Overcomer -> Overcomee
const ELEMENT_OVERCOMES := {
	Element.FIRE: Element.METAL,   # 火克金
	Element.METAL: Element.WOOD,   # 金克木
	Element.WOOD: Element.EARTH,   # 木克土
	Element.EARTH: Element.WATER,  # 土克水
	Element.WATER: Element.FIRE,   # 水克火
}

# 被生: reverse of ELEMENT_GENERATES
const ELEMENT_GENERATED_BY := {
	Element.EARTH: Element.FIRE,   # 土被火生
	Element.METAL: Element.EARTH,  # 金被土生
	Element.WATER: Element.METAL,  # 水被金生
	Element.WOOD: Element.WATER,   # 木被水生
	Element.FIRE: Element.WOOD,    # 火被木生
}

# 被克: reverse of ELEMENT_OVERCOMES
const ELEMENT_OVERCOME_BY := {
	Element.METAL: Element.FIRE,   # 金被火克
	Element.WOOD: Element.METAL,   # 木被金克
	Element.EARTH: Element.WOOD,   # 土被木克
	Element.WATER: Element.EARTH,  # 水被土克
	Element.FIRE: Element.WATER,   # 火被水克
}

# Get the relationship between two elements
enum ElementRelation {
	NEUTRAL = 0,
	GENERATES = 1,      # a 生 b
	GENERATED_BY = 2,   # a 被 b 生
	OVERCOMES = 3,      # a 克 b
	OVERCOME_BY = 4,    # a 被 b 克
	SAME = 5,
}

static func get_element_relation(a: Element, b: Element) -> ElementRelation:
	if a == Element.NONE or b == Element.NONE:
		return ElementRelation.NEUTRAL
	if a == b:
		return ElementRelation.SAME
	if ELEMENT_GENERATES.get(a) == b:
		return ElementRelation.GENERATES
	if ELEMENT_GENERATES.get(b) == a:
		return ElementRelation.GENERATED_BY
	if ELEMENT_OVERCOMES.get(a) == b:
		return ElementRelation.OVERCOMES
	if ELEMENT_OVERCOMES.get(b) == a:
		return ElementRelation.OVERCOME_BY
	return ElementRelation.NEUTRAL

# --- Battle States ---
enum BattleState {
	INTRO = 0,
	PRE_BATTLE = 1,
	QI_CIRCULATION = 2,   # 灵气游走阶段
	PLAYER_TURN = 3,
	PLAYER_ACTION = 4,
	ENEMY_TURN = 5,
	ENEMY_ACTION = 6,
	TURN_END = 7,
	BATTLE_WON = 8,
	BATTLE_LOST = 9,
	TURN_START = 10,
}

# --- Pathway Status ---
enum PathwayStatus {
	NORMAL = 0,
	DAMAGED = 1,
	BLOCKED = 2,
}

# --- Reward Types ---
enum RewardType {
	CARD = 0,
	CARD_UPGRADE = 1,
	ELIXIR = 2,
	GOLD = 3,
	HEAL = 4,
	MERIDIAN = 5,
	DANTIAN = 6,
	TALENT = 7,
	ARTIFACT = 8,
	REMOVE_CARD = 9,
}

# --- Artifact Trigger Types ---
enum TriggerType {
	ON_TURN_START = 0,
	ON_CARD_PLAY = 1,
	ON_DAMAGE_TAKEN = 2,
	ON_QI_CIRCULATE = 3,
	ON_BATTLE_START = 4,
	ALWAYS = 5,
	ON_ATTACK_PLAYED = 6,
	ON_DEFENSE_PLAYED = 7,
}

# --- Encounter Types ---
enum EncounterType {
	NORMAL = 0,
	ELITE = 1,
	BOSS = 2,
	EVENT = 3,
	SHOP = 4,
	REST = 5,
}

# --- Enemy Intent Types ---
enum IntentType {
	ATTACK = 0,
	ATTACK_MULTI = 1,
	DEFEND = 2,
	BUFF_SELF = 3,
	DEBUFF_PLAYER = 4,
	SEAL_MERIDIAN = 5,    # 封穴
	DAMAGE_PATHWAY = 6,   # 断脉
	DRAIN_QI = 7,         # 吸灵
}

# --- Circuit Mode ---
enum CircuitMode {
	CIRCULAR = 0,  # 大周天(环形)
	DEAD_END = 1,  # 小周天(发散)
}

# --- Card Rarity ---
enum CardRarity {
	BASIC = 0,
	COMMON = 1,
	UNCOMMON = 2,
	RARE = 3,
}

# --- Target Type ---
enum TargetType {
	NONE = 0,
	SINGLE_ENEMY = 1,
	ALL_ENEMIES = 2,
	SELF = 3,
	RANDOM_ENEMY = 4,
}

# --- Elixir Use Location ---
enum ElixirUseLocation {
	BATTLE_ONLY = 0,
	MAP_ONLY = 1,
	BOTH = 2,
}

# --- Map Node Type ---
enum MapNodeType {
	BATTLE = 0,
	ELITE = 1,
	BOSS = 2,
	EVENT = 3,
	SHOP = 4,
	REST = 5,
	TREASURE = 6,
}

# --- Effect Commands (效果协议) ---
# All systems use these string prefixes to parse effects.
# Format: "command:param" or "command:param1:param2"
const EFFECT_HEAL          := "heal"
const EFFECT_DAMAGE        := "damage"
const EFFECT_MAX_HP_UP     := "max_hp_up"
const EFFECT_DANTIAN_UP    := "dantian_up"
const EFFECT_GATHER_UP     := "gather_up"
const EFFECT_QI_RESTORE    := "qi_restore"
const EFFECT_TALENT_UP     := "talent_up"
const EFFECT_UNLOCK_NODE   := "unlock_node"
const EFFECT_REPAIR_PATH   := "repair_path"
const EFFECT_REPAIR_ALL    := "repair_all"
const EFFECT_GAIN_CARD     := "gain_card"
const EFFECT_REMOVE_CARD   := "remove_card"
const EFFECT_UPGRADE_CARD  := "upgrade_card"
const EFFECT_TRANSFORM_CARD:= "transform_card"
const EFFECT_DUPLICATE_CARD:= "duplicate_card"
const EFFECT_GAIN_ELIXIR   := "gain_elixir"
const EFFECT_GAIN_ARTIFACT := "gain_artifact"
const EFFECT_GOLD          := "gold"
const EFFECT_BUFF          := "buff"
const EFFECT_DEBUFF        := "debuff"
const EFFECT_ATTACK_UP     := "attack_up"
const EFFECT_DEFENSE_UP    := "defense_up"
const EFFECT_ENERGY_UP     := "energy_up"
const EFFECT_ENERGY_DOWN   := "energy_down"
const EFFECT_BURN          := "burn"
const EFFECT_DRAW_CARD     := "draw_card"
const EFFECT_BLOCK         := "block"
const EFFECT_CLEANSE       := "cleanse_all"
const EFFECT_STRENGTH      := "strength"
const EFFECT_VULNERABLE    := "vulnerable"

# --- Hand & Deck Constants ---
const MAX_HAND_SIZE   := 10
const DEFAULT_DRAW    := 5
const DEFAULT_QI      := 5
const DEFAULT_CAPACITY:= 10
const DEFAULT_GATHER  := 3
const DEFAULT_HP      := 80
const DEFAULT_TALENT  := 2
const DEFAULT_REALM   := 1

# --- Acupoint Property Types (穴位特性类型) ---
enum NodeProperty {
	MULTI_TARGET = 0,       # 攻击所有敌人
	SPLASH = 1,             # 溅射伤害
	APPLY_BURN = 2,         # 附加灼烧
	APPLY_VULNERABLE = 3,   # 附加易伤
	APPLY_WEAK = 4,         # 附加虚弱
	EXTRA_DRAW = 5,         # 额外抽牌
	QI_EFFICIENCY = 6,      # 减灵气消耗
	LIFE_STEAL = 7,         # 吸血
	REFLECT = 8,            # 反伤
	PIERCE = 9,             # 穿透
	DOUBLE_STRIKE = 10,     # 双重打击
	COUNTER = 11,           # 反击
}

static func node_property_name(p: NodeProperty) -> String:
	match p:
		NodeProperty.MULTI_TARGET: return "multi_target"
		NodeProperty.SPLASH: return "splash"
		NodeProperty.APPLY_BURN: return "apply_burn"
		NodeProperty.APPLY_VULNERABLE: return "apply_vulnerable"
		NodeProperty.APPLY_WEAK: return "apply_weak"
		NodeProperty.EXTRA_DRAW: return "extra_draw"
		NodeProperty.QI_EFFICIENCY: return "qi_efficiency"
		NodeProperty.LIFE_STEAL: return "life_steal"
		NodeProperty.REFLECT: return "reflect"
		NodeProperty.PIERCE: return "pierce"
		NodeProperty.DOUBLE_STRIKE: return "double_strike"
		NodeProperty.COUNTER: return "counter"
	return ""

# --- Status Effect Names ---
const STATUS_BURN       := "burn"
const STATUS_VULNERABLE := "vulnerable"
const STATUS_WEAK       := "weak"
const STATUS_POISON     := "poison"
