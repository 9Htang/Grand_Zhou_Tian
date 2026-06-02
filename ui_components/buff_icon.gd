# ============================================================
# 大周天 — Buff Icon (灵气buff图标)
# ============================================================
# emoji图标 + 数值 + 剩余回合 + 正面/负面颜色
# ============================================================
@tool
class_name BuffIcon
extends PanelContainer


@export var buff_name: String = "":
	set(v):
		buff_name = v
		_update()
@export var buff_value: int = 0:
	set(v):
		buff_value = v
		_update()
@export var buff_duration: int = -1:  # -1 = 不显示回合
	set(v):
		buff_duration = v
		_update()
@export var is_positive: bool = true:
	set(v):
		is_positive = v
		_update()

## 预设 buff 图标映射
const BUFF_ICONS := {
	"strength":     "💪",
	"block":        "🛡",
	"burn":         "🔥",
	"vulnerable":   "⚡",
	"weak":         "💤",
	"qi_flow":      "🌀",
	"meditation":   "🧘",
	"rage":         "😡",
	"regeneration": "🌿",
	"reflect":      "🪞",
	"pierce":       "🗡",
	"double_strike":"⚔",
	"counter":      "↩",
	"life_steal":   "🩸",
	"extra_draw":   "🃏",
	"qi_efficiency":"💠",
	"multi_target": "🎯",
	"splash":       "💥",
}

var _bg: ColorRect
var _icon_label: Label
var _value_label: Label
var _turn_label: Label


func _ready() -> void:
	_build_ui()
	_update()


func _build_ui() -> void:
	custom_minimum_size = Vector2(52, 34)

	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	add_theme_stylebox_override("panel", sb)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 2)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(inner)

	_icon_label = Label.new()
	_icon_label.add_theme_font_size_override("font_size", 12)
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(_icon_label)

	_value_label = Label.new()
	_value_label.add_theme_font_size_override("font_size", 11)
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	_value_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(_value_label)

	_turn_label = Label.new()
	_turn_label.add_theme_font_size_override("font_size", 9)
	_turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_turn_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(_turn_label)


func _update() -> void:
	if not is_inside_tree() or _icon_label == null:
		return

	# Icon
	_icon_label.text = BUFF_ICONS.get(buff_name.to_lower(), "✨")

	# Value
	if buff_value > 0:
		_value_label.text = "+%d" % buff_value if is_positive else "%d" % buff_value
	else:
		_value_label.text = ""

	# Duration
	if buff_duration >= 0:
		_turn_label.text = "%d" % buff_duration
		_turn_label.add_theme_color_override("font_color", GameColors.TEXT_DIM)
	else:
		_turn_label.text = ""

	# Colors
	var border: Color
	var bg: Color
	if is_positive:
		border = Color(GameColors.ACCENT_JADE.r, GameColors.ACCENT_JADE.g, GameColors.ACCENT_JADE.b, 0.5)
		bg = Color(GameColors.ACCENT_JADE.r * 0.1, GameColors.ACCENT_JADE.g * 0.1, GameColors.ACCENT_JADE.b * 0.1, 0.8)
	else:
		border = Color(GameColors.ACCENT_CINNABAR.r, GameColors.ACCENT_CINNABAR.g, GameColors.ACCENT_CINNABAR.b, 0.5)
		bg = Color(GameColors.ACCENT_CINNABAR.r * 0.1, GameColors.ACCENT_CINNABAR.g * 0.1, GameColors.ACCENT_CINNABAR.b * 0.1, 0.8)

	var sb := get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb.bg_color = bg
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.border_color = border


# ============================================================
# 公共接口
# ============================================================

func setup(p_name: String, p_value: int, p_positive: bool = true, p_color: Color = GameColors.ACCENT_JADE) -> void:
	buff_name = p_name
	buff_value = p_value
	is_positive = p_positive
	_update()


func set_buff(buff_type: String, value: int, duration: int = -1) -> void:
	buff_name = buff_type
	buff_value = value
	buff_duration = duration
	_update()
