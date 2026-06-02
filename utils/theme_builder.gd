# ============================================================
# 大周天 — ThemeBuilder (古风主题工厂)
# ============================================================
# 构建统一的 Godot Theme 资源，供所有 UI 控件使用。
# 使用 GameColors 色板 + 可配置字体。
# ============================================================
class_name ThemeBuilder
extends RefCounted


## 构建默认 Theme
static func build_default() -> Theme:
	var theme := Theme.new()

	# 尝试加载中文字体
	var default_font: Font = _load_best_font()

	# === 默认字体 ===
	theme.set_default_font(default_font)
	theme.set_default_font_size(14)

	# === Button ===
	theme.set_stylebox("normal", "Button", _make_button_style(false))
	theme.set_stylebox("hover", "Button", _make_button_style(true))
	theme.set_stylebox("pressed", "Button", _make_button_pressed_style())
	theme.set_stylebox("disabled", "Button", _make_button_disabled_style())
	theme.set_stylebox("focus", "Button", _make_button_focus_style())
	theme.set_color("font_color", "Button", GameColors.TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", GameColors.TEXT_TITLE)
	theme.set_color("font_pressed_color", "Button", GameColors.ACCENT_GOLD_BRIGHT)
	theme.set_color("font_disabled_color", "Button", GameColors.TEXT_DIM)
	theme.set_font_size("font_size", "Button", 16)

	# === Label ===
	theme.set_color("font_color", "Label", GameColors.TEXT_PRIMARY)
	theme.set_font_size("font_size", "Label", 14)

	# === PanelContainer ===
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = GameColors.BG_PANEL
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = GameColors.BORDER_SUBTLE
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	return theme


# ============================================================
# StyleBox 工厂方法
# ============================================================

## 普通按钮样式
static func _make_button_style(hover: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GameColors.BG_PANEL
	if hover:
		sb.bg_color = GameColors.BG_PANEL.lightened(0.05)

	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = GameColors.BORDER_GOLD if hover else GameColors.BORDER_SUBTLE
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6

	if hover:
		sb.shadow_size = 4
		sb.shadow_color = Color(GameColors.ACCENT_GOLD.r, GameColors.ACCENT_GOLD.g, GameColors.ACCENT_GOLD.b, 0.25)

	return sb


## 按钮按下样式
static func _make_button_pressed_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GameColors.ACCENT_GOLD_DIM.lightened(0.05)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = GameColors.ACCENT_GOLD
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	return sb


## 按钮禁用样式
static func _make_button_disabled_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.06, 0.6)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = GameColors.BORDER_SUBTLE.darkened(0.5)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	return sb


## 按钮聚焦样式
static func _make_button_focus_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GameColors.BG_PANEL
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = GameColors.ACCENT_GOLD
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	return sb


# ============================================================
# 公共 StyleBox 工厂
# ============================================================

## 金边面板
static func make_gold_panel(bg_alpha: float = 1.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GameColors.BG_PANEL.r, GameColors.BG_PANEL.g, GameColors.BG_PANEL.b, bg_alpha)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = GameColors.BORDER_GOLD
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	return sb


## 暗色面板（无边框）
static func make_dark_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GameColors.BG_PANEL
	sb.border_width_left = 0
	sb.border_width_right = 0
	sb.border_width_top = 0
	sb.border_width_bottom = 0
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb


## 发光金边面板
static func make_glow_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GameColors.BG_PANEL
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = GameColors.BORDER_GLOW
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_size = 6
	sb.shadow_color = Color(GameColors.ACCENT_GOLD.r, GameColors.ACCENT_GOLD.g, GameColors.ACCENT_GOLD.b, 0.3)
	return sb


## 卡牌面板底
static func make_card_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GameColors.BG_CARD
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = GameColors.BORDER_SUBTLE
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	return sb


## 进度条背景
static func make_bar_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.04, 0.8)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = GameColors.BORDER_SUBTLE
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	return sb


# ============================================================
# 字体加载
# ============================================================

## 尝试加载最佳中文字体
static func _load_best_font() -> Font:
	# 尝试顺序: 楷体 > 宋体 > 黑体 > 系统默认
	var font_paths := [
		"C:/Windows/Fonts/simkai.ttf",       # 楷体 — 最合适修仙风格
		"C:/Windows/Fonts/STKAITI.TTF",       # 华文楷体
		"C:/Windows/Fonts/STSONG.TTF",        # 华文宋体
		"C:/Windows/Fonts/simsun.ttc",        # 宋体
		"C:/Windows/Fonts/simhei.ttf",        # 黑体
	]

	for path in font_paths:
		if FileAccess.file_exists(path):
			var font: FontFile = load(path) as FontFile
			if font != null:
				return font

	# Fallback: 使用 Godot 默认字体
	return ThemeDB.fallback_font


## 加载标题用楷体
static func load_title_font() -> Font:
	var title_paths := [
		"C:/Windows/Fonts/simkai.ttf",
		"C:/Windows/Fonts/STKAITI.TTF",
		"C:/Windows/Fonts/STSONG.TTF",
		"C:/Windows/Fonts/simsun.ttc",
	]

	for path in title_paths:
		if FileAccess.file_exists(path):
			var font := FontFile.new()
			font.font_data = load(path)
			if font.font_data != null:
				return font

	return _load_best_font()
