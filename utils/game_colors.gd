# ============================================================
# 大周天 — GameColors (统一色板)
# ============================================================
# 修仙水墨风格配色。所有 UI 组件从这里取色。
# 禁止在组件中硬编码颜色值。
# ============================================================
class_name GameColors
extends RefCounted


# ============================================================
# 底色系 (Backgrounds)
# ============================================================

## 最深层底色 — 墨色深渊
const BG_VOID := Color(0.031, 0.031, 0.055)          # #08080E
## 面板底色 — 宣纸暗面
const BG_PANEL := Color(0.047, 0.055, 0.078)          # #0C0E14
## 卡片底色 — 古卷微亮
const BG_CARD := Color(0.063, 0.071, 0.102)            # #10121A
## 输入区域底色 — 半透墨色
const BG_INPUT := Color(0.078, 0.086, 0.118)           # #14161E
## 遮罩层 — 墨色半透
const OVERLAY_DARK := Color(0.0, 0.0, 0.02, 0.75)      # 弹窗背景遮罩
const OVERLAY_LIGHT := Color(0.0, 0.0, 0.02, 0.35)     # 轻遮罩


# ============================================================
# 强调色 (Accents)
# ============================================================

## 金文 — 主强调色（标题、激活态、金币）
const ACCENT_GOLD := Color(0.831, 0.655, 0.271)        # #D4A745
## 金文亮 — hover/高亮
const ACCENT_GOLD_BRIGHT := Color(0.961, 0.784, 0.392)  # #F5C864
## 金文暗 — 边框/分隔
const ACCENT_GOLD_DIM := Color(0.690, 0.529, 0.212)     # #B08736

## 翡翠绿 — 次强调（治疗、正面buff）
const ACCENT_JADE := Color(0.298, 0.686, 0.314)         # #4CAF50
## 翡翠亮
const ACCENT_JADE_BRIGHT := Color(0.400, 0.800, 0.420)  # #66CC6B

## 朱砂红 — 危险/HP/负面
const ACCENT_CINNABAR := Color(0.910, 0.298, 0.239)      # #E84C3D
## 朱砂亮
const ACCENT_CINNABAR_BRIGHT := Color(0.980, 0.420, 0.350)  # #FA6B59

## 天青 — 灵气/信息
const ACCENT_CERULEAN := Color(0.200, 0.549, 0.902)     # #338CE6
## 天青亮
const ACCENT_CERULEAN_BRIGHT := Color(0.300, 0.650, 0.980)  # #4DA6FA


# ============================================================
# 五行色 (Five Elements)
# ============================================================

## 火 — 烈焰红
const FIRE := Color(0.910, 0.298, 0.239)      # #E84C3D
const FIRE_DIM := Color(0.580, 0.200, 0.160)  # 暗火
const FIRE_GLOW := Color(1.000, 0.420, 0.300) # 火光

## 水 — 深海蓝
const WATER := Color(0.227, 0.482, 0.835)      # #3A7BD5
const WATER_DIM := Color(0.150, 0.300, 0.530)  # 暗水
const WATER_GLOW := Color(0.350, 0.650, 1.000) # 水光

## 木 — 翠绿
const WOOD := Color(0.298, 0.686, 0.314)       # #4CAF50
const WOOD_DIM := Color(0.180, 0.420, 0.190)   # 暗木
const WOOD_GLOW := Color(0.420, 0.850, 0.440)  # 木光

## 金 — 黄金
const METAL := Color(0.831, 0.655, 0.271)      # #D4A745
const METAL_DIM := Color(0.550, 0.420, 0.180)  # 暗金
const METAL_GLOW := Color(1.000, 0.820, 0.400) # 金光

## 土 — 赭石
const EARTH := Color(0.651, 0.486, 0.329)      # #A67C34
const EARTH_DIM := Color(0.420, 0.300, 0.200)  # 暗土
const EARTH_GLOW := Color(0.820, 0.630, 0.440) # 土光


# ============================================================
# 五行色查找表 (字符串索引)
# ============================================================

const ELEMENT_COLOR_MAP := {
	"火": FIRE,
	"水": WATER,
	"木": WOOD,
	"金": METAL,
	"土": EARTH,
	"":  Color(1.0, 1.0, 1.0),   # 无属性默认白色
}

const ELEMENT_GLOW_MAP := {
	"火": FIRE_GLOW,
	"水": WATER_GLOW,
	"木": WOOD_GLOW,
	"金": METAL_GLOW,
	"土": EARTH_GLOW,
	"":  Color(1.0, 1.0, 1.0),
}

const ELEMENT_DIM_MAP := {
	"火": FIRE_DIM,
	"水": WATER_DIM,
	"木": WOOD_DIM,
	"金": METAL_DIM,
	"土": EARTH_DIM,
	"":  Color(0.3, 0.3, 0.3),
}


# ============================================================
# 文字色 (Text)
# ============================================================

const TEXT_PRIMARY := Color(0.922, 0.898, 0.820)       # 主文字 — 米白
const TEXT_SECONDARY := Color(0.549, 0.549, 0.651)     # 次文字 — 灰蓝
const TEXT_DIM := Color(0.302, 0.302, 0.400)           # 暗文字 — 深灰
const TEXT_TITLE := Color(0.961, 0.784, 0.392)         # 标题文字 — 金色

## 文字阴影色
const TEXT_SHADOW := Color(0.0, 0.0, 0.02, 0.6)


# ============================================================
# 功能色 (Functional)
# ============================================================

## HP 相关
const HP_FILL := Color(0.851, 0.149, 0.149)            # HP满
const HP_FILL_LOW := Color(0.651, 0.118, 0.118)        # HP低
const HP_BORDER := Color(0.702, 0.200, 0.200)           # HP边框
const HP_TEXT := Color(0.980, 0.800, 0.780)            # HP文字

## 灵气相关
const QI_FILL := Color(0.200, 0.549, 0.902)            # 灵气填充
const QI_FILL_LOW := Color(0.129, 0.349, 0.600)        # 灵气低
const QI_BORDER := Color(0.349, 0.650, 0.902)          # 灵气边框
const QI_TEXT := Color(0.780, 0.902, 0.980)            # 灵气文字

## 格挡
const BLOCK_FILL := Color(0.788, 0.651, 0.200)         # 格挡填充
const BLOCK_BORDER := Color(0.902, 0.749, 0.251)       # 格挡边框

## 状态
const WARNING := Color(0.949, 0.200, 0.149)            # 警告
const SUCCESS := Color(0.200, 0.800, 0.298)            # 成功
const INFO := Color(0.349, 0.651, 0.902)               # 信息
const DAMAGE_TEXT := Color(1.0, 0.349, 0.149)          # 伤害数字
const HEAL_TEXT := Color(0.302, 0.902, 0.349)          # 治疗数字


# ============================================================
# 卡牌类型色 (Card Type Colors)
# ============================================================

const CARD_ATTACK := Color(0.910, 0.298, 0.239)        # 攻击 — 朱砂
const CARD_DEFENSE := Color(0.349, 0.549, 0.902)       # 防御 — 天青
const CARD_SKILL := Color(0.298, 0.686, 0.314)         # 技能 — 翡翠
const CARD_ARTIFACT := Color(0.831, 0.655, 0.271)      # 法宝 — 金
const CARD_TECHNIQUE := Color(0.651, 0.349, 0.902)     # 功法 — 紫
const CARD_QI := Color(0.349, 0.800, 0.902)            # 蓄气 — 青
const CARD_ELIXIR := Color(0.902, 0.549, 0.702)        # 丹药 — 粉

const CARD_TYPE_COLOR_MAP := {
	0: CARD_ATTACK,
	1: CARD_DEFENSE,
	2: CARD_SKILL,
	3: CARD_ARTIFACT,
	4: CARD_TECHNIQUE,
	5: CARD_QI,
	6: CARD_ELIXIR,
}


# ============================================================
# 稀有度色 (Rarity Colors)
# ============================================================

const RARITY_BASIC := Color(0.702, 0.702, 0.702)       # 基础 — 白灰
const RARITY_COMMON := Color(0.400, 0.749, 0.349)       # 普通 — 绿
const RARITY_UNCOMMON := Color(0.349, 0.651, 0.902)    # 精良 — 蓝
const RARITY_RARE := Color(0.651, 0.349, 0.902)         # 稀有 — 紫
const RARITY_LEGENDARY := Color(0.961, 0.651, 0.200)    # 传说 — 橙金

const RARITY_COLOR_MAP := {
	0: RARITY_BASIC,
	1: RARITY_COMMON,
	2: RARITY_UNCOMMON,
	3: RARITY_RARE,
}


# ============================================================
# 边框/线色 (Borders & Lines)
# ============================================================

const BORDER_GOLD := Color(0.690, 0.529, 0.212, 0.5)   # 金边
const BORDER_SUBTLE := Color(0.149, 0.160, 0.220, 0.8) # 细边框
const BORDER_GLOW := Color(0.961, 0.784, 0.392, 0.6)   # 发光边
const SEPARATOR := Color(0.149, 0.160, 0.220)          # 分隔线


# ============================================================
# 辅助方法
# ============================================================

## 获取五行色，带默认值
static func element_color(element: String, variant: String = "main") -> Color:
	match variant:
		"glow": return ELEMENT_GLOW_MAP.get(element, Color(1, 1, 1))
		"dim":  return ELEMENT_DIM_MAP.get(element, Color(0.3, 0.3, 0.3))
		_:      return ELEMENT_COLOR_MAP.get(element, Color(0.5, 0.5, 0.5))


## 获取卡牌类型色
static func card_type_color(card_type: int) -> Color:
	return CARD_TYPE_COLOR_MAP.get(card_type, Color(0.5, 0.5, 0.5))


## 获取稀有度色
static func rarity_color(rarity: int) -> Color:
	return RARITY_COLOR_MAP.get(rarity, RARITY_BASIC)


## 混合墨色背景 — 颜色叠加墨底，使其符合整体色调
static func ink_blend(c: Color, strength: float = 0.3) -> Color:
	return c.lerp(BG_PANEL, strength)


## 创建发光变体 — 调亮
static func glow(c: Color, factor: float = 1.3) -> Color:
	return Color(
		clampf(c.r * factor, 0.0, 1.0),
		clampf(c.g * factor, 0.0, 1.0),
		clampf(c.b * factor, 0.0, 1.0),
		c.a,
	)


## 创建暗色变体 — 调暗
static func dim(c: Color, factor: float = 0.5) -> Color:
	return Color(c.r * factor, c.g * factor, c.b * factor, c.a)


## level 0-1: 1 = full, 0 = dim
static func fill_ratio_color(fill: Color, ratio: float) -> Color:
	var r: float = lerpf(fill.r * 0.4, fill.r, ratio)
	var g: float = lerpf(fill.g * 0.4, fill.g, ratio)
	var b: float = lerpf(fill.b * 0.4, fill.b, ratio)
	return Color(r, g, b, fill.a)
