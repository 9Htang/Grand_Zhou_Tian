# ============================================================
# 大周天 — StyledButton (古风按钮)
# ============================================================
# 统一按钮风格: 墨色底 + 金边 + hover发光 + press缩小
# 使用 GameColors 色板，禁止硬编码颜色。
# ============================================================
@tool
class_name StyledButton
extends Button


enum ButtonVariant {
	NORMAL,     # 标准金边按钮
	PRIMARY,    # 主操作（金色填充底）
	DANGER,     # 危险操作（朱砂边）
	SUCCESS,    # 确认操作（翡翠边）
	GHOST,      # 透明底（只显示文字）
}


@export var variant: ButtonVariant = ButtonVariant.NORMAL:
	set(v):
		variant = v
		_update_style()


var _font_size: int = 16
var _is_hovering: bool = false


func _ready() -> void:
	flat = true
	custom_minimum_size = Vector2(120, 36)
	_update_style()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed_anim)
	button_up.connect(_on_released_anim)


func _update_style() -> void:
	var bg: Color
	var border: Color
	var text_color: Color
	var hover_brightness: float

	match variant:
		ButtonVariant.NORMAL:
			bg = GameColors.BG_PANEL
			border = GameColors.BORDER_GOLD
			text_color = GameColors.TEXT_PRIMARY
			hover_brightness = 1.15
		ButtonVariant.PRIMARY:
			bg = GameColors.ACCENT_GOLD_DIM
			border = GameColors.ACCENT_GOLD
			text_color = GameColors.TEXT_TITLE
			hover_brightness = 1.1
		ButtonVariant.DANGER:
			bg = GameColors.BG_PANEL
			border = Color(GameColors.ACCENT_CINNABAR.r, GameColors.ACCENT_CINNABAR.g, GameColors.ACCENT_CINNABAR.b, 0.5)
			text_color = GameColors.ACCENT_CINNABAR
			hover_brightness = 1.15
		ButtonVariant.SUCCESS:
			bg = GameColors.BG_PANEL
			border = Color(GameColors.ACCENT_JADE.r, GameColors.ACCENT_JADE.g, GameColors.ACCENT_JADE.b, 0.5)
			text_color = GameColors.ACCENT_JADE
			hover_brightness = 1.15
		ButtonVariant.GHOST:
			bg = Color(0, 0, 0, 0)
			border = Color(0, 0, 0, 0)
			text_color = GameColors.TEXT_SECONDARY
			hover_brightness = 1.3

	# Normal style
	var normal_style := _build_sb(bg, border, 6, 0)
	add_theme_stylebox_override("normal", normal_style)

	# Hover style
	var hover_bg := bg.lightened(0.05)
	var hover_border := GameColors.glow(border, hover_brightness)
	hover_border.a = clampf(hover_border.a, 0.3, 0.8)
	var hover_style := _build_sb(hover_bg, hover_border, 6, 4)
	hover_style.shadow_color = Color(border.r, border.g, border.b, 0.2)
	add_theme_stylebox_override("hover", hover_style)

	# Pressed style
	var pressed_style := _build_sb(hover_border, GameColors.glow(border, 1.4), 6, 0)
	pressed_style.bg_color.a = 0.6
	add_theme_stylebox_override("pressed", pressed_style)

	# Disabled
	var dis_style := _build_sb(Color(0.03, 0.03, 0.05, 0.5), GameColors.BORDER_SUBTLE.darkened(0.4), 6, 0)
	add_theme_stylebox_override("disabled", dis_style)

	# Focus
	var focus_style := _build_sb(bg, GameColors.BORDER_GLOW, 6, 0)
	add_theme_stylebox_override("focus", focus_style)

	# Font
	add_theme_color_override("font_color", text_color)
	add_theme_color_override("font_hover_color", GameColors.glow(text_color, 1.2))
	add_theme_color_override("font_pressed_color", GameColors.glow(text_color, 1.4))
	add_theme_color_override("font_disabled_color", GameColors.TEXT_DIM)
	add_theme_font_size_override("font_size", _font_size)


func _build_sb(bg: Color, border: Color, radius: int, shadow_sz: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = border
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	if shadow_sz > 0:
		sb.shadow_size = shadow_sz
	return sb


# ============================================================
# 动画
# ============================================================

func _on_mouse_entered() -> void:
	_is_hovering = true
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.03, 1.03), 0.08)


func _on_mouse_exited() -> void:
	_is_hovering = false
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)


func _on_pressed_anim() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(0.97, 0.97), 0.05)


func _on_released_anim() -> void:
	var target := Vector2(1.03, 1.03) if _is_hovering else Vector2(1.0, 1.0)
	var t := create_tween()
	t.tween_property(self, "scale", target, 0.08)
