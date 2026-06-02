# ============================================================
# 大周天 — UIHelpers (自适应布局工具)
# 基于视口百分比计算 UI 尺寸，替代硬编码像素值
# 基准分辨率: 1280×720 (16:9)
# ============================================================
class_name UIHelpers
extends RefCounted


# === 基准分辨率 ===
const BASE_W: float = 1280.0
const BASE_H: float = 720.0

# === 布局比例常量（占视口高度的百分比） ===
const TOP_BAR_PCT: float = 0.033       # ~24/720
const ENEMY_AREA_PCT: float = 0.195    # ~140/720
const MERIDIAN_AREA_PCT: float = 0.278 # ~200/720
const TECH_AREA_PCT: float = 0.044     # ~32/720
const BUFFS_PCT: float = 0.036         # ~26/720
const PLAYER_AREA_PCT: float = 0.039   # ~28/720
const HAND_AREA_PCT: float = 0.306     # ~220/720

# === 卡牌尺寸比例（占视口的百分比） ===
const CARD_W_PCT: float = 0.078        # ~100/1280 — 普通卡牌宽
const CARD_H_PCT: float = 0.208        # ~150/720  — 普通卡牌高
const TECH_CARD_W_PCT: float = 0.086   # ~110/1280 — 功法卡牌宽
const TECH_CARD_H_PCT: float = 0.222   # ~160/720  — 功法卡牌高

# === 字号比例（相对于视口高度） ===
const FONT_TINY_PCT: float = 0.014     # ~10px
const FONT_SMALL_PCT: float = 0.017    # ~12px
const FONT_NORMAL_PCT: float = 0.019   # ~14px
const FONT_MEDIUM_PCT: float = 0.022   # ~16px
const FONT_LARGE_PCT: float = 0.025    # ~18px
const FONT_XL_PCT: float = 0.028       # ~20px
const FONT_TITLE_PCT: float = 0.042    # ~30px
const FONT_HERO_PCT: float = 0.050     # ~36px


# ============================================================
# 视口尺寸
# ============================================================

## 返回当前视口宽度。需要传入场景树中的任意 Node。
static func vp_w(node: Node) -> float:
	return float(node.get_viewport().get_visible_rect().size.x)


## 返回当前视口高度。
static func vp_h(node: Node) -> float:
	return float(node.get_viewport().get_visible_rect().size.y)


# ============================================================
# 百分比计算
# ============================================================

## 宽度 × 百分比 → 像素
static func pct_w(pct: float, node: Node) -> int:
	return int(vp_w(node) * pct)


## 高度 × 百分比 → 像素
static func pct_h(pct: float, node: Node) -> int:
	return int(vp_h(node) * pct)


# ============================================================
# 字号缩放
# ============================================================

## 按视口高度比例缩放字号。base 为基准分辨率(720)下的字号。
static func scale_font(base: int, node: Node) -> int:
	return int(float(base) * vp_h(node) / BASE_H)


# ============================================================
# 预设尺寸
# ============================================================

## 普通卡牌尺寸
static func card_size(node: Node) -> Vector2:
	return Vector2(float(pct_w(CARD_W_PCT, node)), float(pct_h(CARD_H_PCT, node)))


## 功法卡牌尺寸
static func tech_card_size(node: Node) -> Vector2:
	return Vector2(float(pct_w(TECH_CARD_W_PCT, node)), float(pct_h(TECH_CARD_H_PCT, node)))


## 字号预设
static func font_tiny(node: Node) -> int:
	return pct_h(FONT_TINY_PCT, node)


static func font_small(node: Node) -> int:
	return pct_h(FONT_SMALL_PCT, node)


static func font_normal(node: Node) -> int:
	return pct_h(FONT_NORMAL_PCT, node)


static func font_medium(node: Node) -> int:
	return pct_h(FONT_MEDIUM_PCT, node)


static func font_large(node: Node) -> int:
	return pct_h(FONT_LARGE_PCT, node)


static func font_xl(node: Node) -> int:
	return pct_h(FONT_XL_PCT, node)


static func font_title(node: Node) -> int:
	return pct_h(FONT_TITLE_PCT, node)


static func font_hero(node: Node) -> int:
	return pct_h(FONT_HERO_PCT, node)


# ============================================================
# 内边距比例
# ============================================================

## 标准水平内边距（左右各 2% 视口宽度）
static func pad_h(node: Node) -> int:
	return pct_w(0.02, node)

## 标准垂直内边距（上下各 2% 视口高度）
static func pad_v(node: Node) -> int:
	return pct_h(0.03, node)

## 小节间距
static func gap_small(node: Node) -> int:
	return pct_h(0.022, node)   # ~16px

static func gap_medium(node: Node) -> int:
	return pct_h(0.042, node)   # ~30px

static func gap_large(node: Node) -> int:
	return pct_h(0.083, node)   # ~60px
