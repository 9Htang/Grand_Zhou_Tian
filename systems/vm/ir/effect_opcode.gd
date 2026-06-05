# ============================================================
# 大周天 — EffectOpcode
# 统一效果语义层 — 所有卡牌/丹药/法宝效果的整数编码
# 游戏中所有 effect 解释的唯一入口
# ============================================================
@tool
class_name EffectOpcode
extends RefCounted


## 效果操作码 — 游戏中所有效果类型的整数编码
enum Code {
	# === 战斗效果 ===
	## 对敌方造成伤害
	DAMAGE = 0,
	## 获得格挡
	BLOCK = 1,
	## 恢复生命
	HEAL = 2,

	# === 卡牌操作 ===
	## 抽牌
	DRAW = 3,

	# === 状态效果 ===
	## 施加状态: meta["status_type"] = "burn"/"vulnerable"/"weak"/"stun"/"buff"/"debuff"/"cleanse"
	APPLY_STATUS = 4,

	# === 灵气操作 ===
	## 聚集灵气 (被动增长)
	QI_GATHER = 5,
	## 恢复灵气 (立即获得)
	QI_RESTORE = 6,
	## 消耗灵气
	SPEND_QI = 7,

	# === 经脉/丹田 ===
	## 丹田容量提升
	DANTIAN_UP = 8,
	## 经脉路径容量提升
	PATHWAY_UP = 9,

	# === 角色属性 ===
	## 最大生命值提升
	MAX_HP_UP = 10,
	## 聚气速率提升
	GATHER_UP = 11,
	## 天资提升
	TALENT_UP = 12,
	## 对自身造成伤害 (丹药副作用)
	SELF_DAMAGE = 13,

	# === 经脉操作 ===
	## 解锁穴位
	UNLOCK_NODE = 14,
	## 修复经脉路径
	REPAIR_PATH = 15,

	# === 卡牌/物品操作 ===
	## 获得卡牌
	GAIN_CARD = 16,
	## 移除卡牌
	REMOVE_CARD = 17,
	## 升级卡牌
	UPGRADE_CARD = 18,
	## 变换卡牌
	TRANSFORM_CARD = 19,
	## 复制卡牌
	DUPLICATE_CARD = 20,
	## 获得法宝
	GAIN_ARTIFACT = 21,
	## 获得金币
	GOLD = 22,

	# === 特殊 ===
	## 清除所有 buff
	CLEANSE_ALL = 23,

	# === 控制流 + 敌人操作 ===
	## 条件跳转 — meta["condition"] 为真时跳转到 jump 索引
	JUMP_IF = 24,
	## 敌人力量增减
	APPLY_STRENGTH = 25,
	## 设置敌人 HP
	SET_ENEMY_HP = 26,
}


## type 字符串 → opcode 映射表
const TYPE_TO_OPCODE: Dictionary = {
	"damage": Code.DAMAGE,
	"block": Code.BLOCK,
	"heal": Code.HEAL,
	"draw": Code.DRAW,
	"burn": Code.APPLY_STATUS,
	"vulnerable": Code.APPLY_STATUS,
	"weak": Code.APPLY_STATUS,
	"stun": Code.APPLY_STATUS,
	"buff": Code.APPLY_STATUS,
	"debuff": Code.APPLY_STATUS,
	"cleanse": Code.APPLY_STATUS,
	"qi_gather": Code.QI_GATHER,
	"qi_restore": Code.QI_RESTORE,
	"dantian_up": Code.DANTIAN_UP,
	"pathway_capacity_up": Code.PATHWAY_UP,
	"max_hp_up": Code.MAX_HP_UP,
	"gather_up": Code.GATHER_UP,
	"talent_up": Code.TALENT_UP,
	"self_damage": Code.SELF_DAMAGE,
	"unlock_node": Code.UNLOCK_NODE,
	"repair_path": Code.REPAIR_PATH,
	"gain_card": Code.GAIN_CARD,
	"remove_card": Code.REMOVE_CARD,
	"upgrade_card": Code.UPGRADE_CARD,
	"transform_card": Code.TRANSFORM_CARD,
	"duplicate_card": Code.DUPLICATE_CARD,
	"gain_artifact": Code.GAIN_ARTIFACT,
	"gold": Code.GOLD,
	"cleanse_all": Code.CLEANSE_ALL,
	"jump_if": Code.JUMP_IF,
	"strength": Code.APPLY_STRENGTH,
}


## EffectResolver 字符串命令 → opcode 映射表
const STRING_CMD_TO_OPCODE: Dictionary = {
	"heal": Code.HEAL,
	"damage": Code.SELF_DAMAGE,
	"max_hp_up": Code.MAX_HP_UP,
	"dantian_up": Code.DANTIAN_UP,
	"gather_up": Code.GATHER_UP,
	"qi_restore": Code.QI_RESTORE,
	"talent_up": Code.TALENT_UP,
	"unlock_node": Code.UNLOCK_NODE,
	"repair_path": Code.REPAIR_PATH,
	"repair_all": Code.REPAIR_PATH,
	"gain_card": Code.GAIN_CARD,
	"remove_card": Code.REMOVE_CARD,
	"upgrade_card": Code.UPGRADE_CARD,
	"transform_card": Code.TRANSFORM_CARD,
	"duplicate_card": Code.DUPLICATE_CARD,
	"gain_elixir": Code.GAIN_CARD,
	"gain_artifact": Code.GAIN_ARTIFACT,
	"gold": Code.GOLD,
	"energy_up": Code.QI_RESTORE,
	"energy_down": Code.SPEND_QI,
	"self_damage": Code.SELF_DAMAGE,
	"buff": Code.APPLY_STATUS,
	"debuff": Code.APPLY_STATUS,
	"attack_up": Code.APPLY_STATUS,
	"defense_up": Code.APPLY_STATUS,
	"burn": Code.APPLY_STATUS,
	"draw_card": Code.DRAW,
	"block": Code.BLOCK,
	"cleanse_all": Code.CLEANSE_ALL,
}


## 从 type 字符串解析 opcode，未知类型返回 -1
static func from_type(type: String) -> int:
	return TYPE_TO_OPCODE.get(type, -1)


## 从 EffectResolver 字符串命令解析 opcode，未知返回 -1
static func from_string_cmd(cmd: String) -> int:
	return STRING_CMD_TO_OPCODE.get(cmd, -1)


## opcode → 可读名称（用于 trace/debug）
static func name_of(code: int) -> String:
	match code:
		Code.DAMAGE: return "DAMAGE"
		Code.BLOCK: return "BLOCK"
		Code.HEAL: return "HEAL"
		Code.DRAW: return "DRAW"
		Code.APPLY_STATUS: return "APPLY_STATUS"
		Code.QI_GATHER: return "QI_GATHER"
		Code.QI_RESTORE: return "QI_RESTORE"
		Code.SPEND_QI: return "SPEND_QI"
		Code.DANTIAN_UP: return "DANTIAN_UP"
		Code.PATHWAY_UP: return "PATHWAY_UP"
		Code.MAX_HP_UP: return "MAX_HP_UP"
		Code.GATHER_UP: return "GATHER_UP"
		Code.TALENT_UP: return "TALENT_UP"
		Code.SELF_DAMAGE: return "SELF_DAMAGE"
		Code.UNLOCK_NODE: return "UNLOCK_NODE"
		Code.REPAIR_PATH: return "REPAIR_PATH"
		Code.GAIN_CARD: return "GAIN_CARD"
		Code.REMOVE_CARD: return "REMOVE_CARD"
		Code.UPGRADE_CARD: return "UPGRADE_CARD"
		Code.TRANSFORM_CARD: return "TRANSFORM_CARD"
		Code.DUPLICATE_CARD: return "DUPLICATE_CARD"
		Code.GAIN_ARTIFACT: return "GAIN_ARTIFACT"
		Code.GOLD: return "GOLD"
		Code.CLEANSE_ALL: return "CLEANSE_ALL"
		Code.JUMP_IF: return "JUMP_IF"
		Code.APPLY_STRENGTH: return "APPLY_STRENGTH"
		Code.SET_ENEMY_HP: return "SET_ENEMY_HP"
	return "UNKNOWN(%d)" % code
