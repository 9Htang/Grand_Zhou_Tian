# ============================================================
# 大周天 — Qi Bar (灵气水晶条)
# ============================================================
# 天青色填充 + 微光呼吸动画 + 流动光效 + 聚气速率显示
# ============================================================
@tool
class_name QiBar
extends PanelContainer


@export var max_qi: int = 10:
	set(v):
		max_qi = max(v, 1)
		_update()
@export var current_qi: int = 5:
	set(v):
		var old: int = current_qi
		current_qi = clampi(v, 0, max_qi)
		if old != current_qi:
			_play_pulse()
		_update()
@export var gather_rate: int = 3
@export var show_label: bool = true
@export var bar_height: int = 22

var _bar_fill: ColorRect
var _bar_bg: ColorRect
var _bar_shine: ColorRect
var _bar_flow: ColorRect  # animated flow line
var _icon_label: Label
var _text_label: Label
var _ratio: float = 0.5
var _breath_phase: float = 0.0


func _ready() -> void:
	_build_ui()
	_update()


func _process(delta: float) -> void:
	if _bar_fill == null:
		return
	_breath_phase = fmod(_breath_phase + delta * 2.0, TAU)

	# Breathing glow on fill opacity
	if _bar_shine and _ratio > 0.01:
		var glow: float = sin(_breath_phase) * 0.3 + 0.7  # 0.4→1.0
		_bar_shine.modulate.a = glow * 0.15

	# Flowing highlight moves across filled area
	if _bar_flow and _ratio > 0.01:
		_bar_flow.visible = true
		var flow_x: float = fmod(_breath_phase * _bar_fill.size.x / TAU, _bar_fill.size.x + 20) - 10
		_bar_flow.position.x = flow_x
	else:
		_bar_flow.visible = false


func _build_ui() -> void:
	if custom_minimum_size.x < 2:
		custom_minimum_size = Vector2(180, bar_height + 4)

	# Outer border
	self.add_theme_stylebox_override("panel", _make_outer_border())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 3)
	add_child(margin)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	margin.add_child(inner)

	# Diamond/crystal icon
	_icon_label = Label.new()
	_icon_label.text = "◈"
	_icon_label.add_theme_font_size_override("font_size", 14)
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(_icon_label)

	# Bar container
	var bar_container := PanelContainer.new()
	bar_container.custom_minimum_size = Vector2(250, bar_height)
	bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_container.add_theme_stylebox_override("panel", _make_bar_bg())
	bar_container.clip_contents = true
	inner.add_child(bar_container)

	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.016, 0.024, 0.039)
	bar_container.add_child(_bar_bg)

	_bar_fill = ColorRect.new()
	_bar_fill.color = GameColors.QI_FILL
	bar_container.add_child(_bar_fill)

	# Flow highlight stripe
	_bar_flow = ColorRect.new()
	_bar_flow.color = Color(1, 1, 1, 0.25)
	_bar_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(_bar_flow)

	# Shine overlay
	_bar_shine = ColorRect.new()
	_bar_shine.color = Color(0.6, 0.85, 1.0, 0.08)
	bar_container.add_child(_bar_shine)

	# Text
	_text_label = Label.new()
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.add_theme_font_size_override("font_size", 13)
	_text_label.add_theme_color_override("font_color", GameColors.QI_TEXT)
	bar_container.add_child(_text_label)


func _update() -> void:
	if not is_inside_tree() or _bar_fill == null:
		return

	_ratio = float(current_qi) / float(max_qi)

	# Fill color: deeper blue when low, brighter when full
	_bar_fill.color = GameColors.fill_ratio_color(GameColors.QI_FILL, _ratio)

	var bar_w: float = max(_bar_bg.size.x, 1.0)
	_bar_fill.size.x = bar_w * _ratio
	_bar_fill.size.y = bar_height

	# Flow stripe
	_bar_flow.size = Vector2(bar_height * 0.4, bar_height * 0.6)
	_bar_flow.position.y = bar_height * 0.2

	# Shine
	_bar_shine.size.x = _bar_fill.size.x
	_bar_shine.size.y = bar_height * 0.45

	if show_label and _text_label:
		_text_label.text = "%d / %d  (+%d)" % [current_qi, max_qi, gather_rate]
		_text_label.size = Vector2(bar_w, bar_height)


func _play_pulse() -> void:
	if _icon_label == null:
		return
	var t := create_tween()
	t.tween_property(_icon_label, "modulate", Color(1, 1, 1.5), 0.1)
	t.tween_property(_icon_label, "modulate", Color(1, 1, 1), 0.2)


# ============================================================
# 公共接口
# ============================================================

func set_values(current: int, maximum: int, rate: int = -1) -> void:
	max_qi = maximum
	current_qi = current
	if rate >= 0:
		gather_rate = rate
	_update()


func set_qi(current: int, maximum: int) -> void:
	max_qi = maximum
	current_qi = current
	_update()


# ============================================================
# 样式工厂
# ============================================================

func _make_outer_border() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.020, 0.024, 0.047)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = GameColors.QI_BORDER
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	sb.shadow_size = 3
	sb.shadow_color = Color(GameColors.ACCENT_CERULEAN.r, GameColors.ACCENT_CERULEAN.g, GameColors.ACCENT_CERULEAN.b, 0.15)
	return sb


func _make_bar_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.016, 0.024, 0.039)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.08, 0.12, 0.18)
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	return sb
