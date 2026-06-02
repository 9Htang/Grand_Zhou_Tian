# ============================================================
# 大周天 — Health Bar (雕纹HP条)
# ============================================================
# 修仙风格：金边双层描边 + 朱砂色填充 + 低血量渐变暗红
# + 受伤闪白动画 + 痊愈翠绿动画
# ============================================================
@tool
class_name HealthBar
extends PanelContainer


@export var max_value: int = 80:
	set(v):
		max_value = max(v, 1)
		_update()
@export var current_value: int = 80:
	set(v):
		var old: int = current_value
		current_value = clampi(v, 0, max_value)
		if old > current_value:
			_play_damage_flash()
		elif old < current_value:
			_play_heal_flash()
		_update()
@export var show_label: bool = true
@export var bar_height: int = 22

var _bar_fill: ColorRect
var _bar_bg: ColorRect
var _bar_shine: ColorRect
var _icon_label: Label
var _text_label: Label
var _border: PanelContainer
var _ratio: float = 1.0


func _ready() -> void:
	_build_ui()
	_update()


func _build_ui() -> void:
	if custom_minimum_size.x < 2:
		custom_minimum_size = Vector2(180, bar_height + 4)

	# Outer golden border wrapper
	self.add_theme_stylebox_override("panel", _make_outer_border())

	# Inner container with padding
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 3)
	add_child(margin)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	margin.add_child(inner)

	# Heart icon
	_icon_label = Label.new()
	_icon_label.text = "❤"
	_icon_label.add_theme_font_size_override("font_size", 14)
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(_icon_label)

	# Bar background with inner border
	var bar_container := PanelContainer.new()
	bar_container.custom_minimum_size = Vector2(250, bar_height)
	bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_container.add_theme_stylebox_override("panel", _make_bar_bg())
	inner.add_child(bar_container)

	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.016, 0.016, 0.031)
	bar_container.add_child(_bar_bg)

	_bar_fill = ColorRect.new()
	_bar_fill.color = GameColors.HP_FILL
	bar_container.add_child(_bar_fill)

	# Shine overlay (white gleam at top of fill)
	_bar_shine = ColorRect.new()
	_bar_shine.color = Color(1, 1, 1, 0.08)
	bar_container.add_child(_bar_shine)

	# Text label centered on bar
	_text_label = Label.new()
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.add_theme_font_size_override("font_size", 13)
	_text_label.add_theme_color_override("font_color", GameColors.HP_TEXT)
	bar_container.add_child(_text_label)


func _update() -> void:
	if not is_inside_tree() or _bar_fill == null:
		return

	_ratio = float(current_value) / float(max_value)

	# Fill color: green(high) → yellow(mid) → red(low) → dark red(critical)
	var fill_color: Color
	if _ratio > 0.5:
		var t: float = (_ratio - 0.5) * 2.0  # 0→1 between 50%→100%
		fill_color = Color(
			lerpf(0.851, 0.298, t),
			0.149 + t * 0.5,
			lerpf(0.149, 0.314, t),
		)
	else:
		var t: float = _ratio * 2.0  # 0→1 between 0→50%
		fill_color = Color(
			lerpf(0.651, 0.851, t),
			lerpf(0.118, 0.149, t),
			lerpf(0.118, 0.149, t),
		)

	_bar_fill.color = fill_color

	var bar_w: float = max(_bar_bg.size.x, 1.0)
	_bar_fill.size.x = bar_w * _ratio
	_bar_fill.size.y = bar_height

	# Shine: only on filled portion
	_bar_shine.size.x = _bar_fill.size.x
	_bar_shine.size.y = bar_height * 0.45

	if show_label and _text_label:
		_text_label.text = "%d / %d" % [current_value, max_value]
		_text_label.size = Vector2(bar_w, bar_height)

	# Icon pulse on low health
	if _ratio < 0.25:
		var pulse: float = 0.6 + sin(Time.get_ticks_msec() * 0.005) * 0.4
		_icon_label.modulate = Color(1, pulse, pulse)
	else:
		_icon_label.modulate = Color(1, 1, 1)


# ============================================================
# 动画
# ============================================================

func _play_damage_flash() -> void:
	if _bar_fill == null:
		return
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.4)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.add_child(flash)

	var fill_start: float = _bar_fill.size.x
	flash.size = Vector2(fill_start, bar_height)

	var t := create_tween()
	t.tween_property(flash, "color", Color(1, 1, 1, 0), 0.25)
	t.tween_callback(flash.queue_free)

	# Subtle shake via margin offset
	var margin: MarginContainer = get_child(0) if get_child_count() > 0 else null
	if margin:
		var mt := create_tween()
		mt.tween_property(margin, "position", Vector2(3, 0), 0.03)
		mt.tween_property(margin, "position", Vector2(-2, 0), 0.03)
		mt.tween_property(margin, "position", Vector2(1, 0), 0.03)
		mt.tween_property(margin, "position", Vector2.ZERO, 0.03)


func _play_heal_flash() -> void:
	if _bar_fill == null:
		return
	var flash := ColorRect.new()
	flash.color = Color(0.2, 0.9, 0.3, 0.3)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.add_child(flash)

	flash.size = _bar_fill.size

	var t := create_tween()
	t.tween_property(flash, "color", Color(0.2, 0.9, 0.3, 0), 0.3)
	t.tween_callback(flash.queue_free)


# ============================================================
# 公共接口
# ============================================================

func set_values(current: int, maximum: int) -> void:
	max_value = maximum
	current_value = current
	_update()


func set_health(current: int, maximum: int) -> void:
	max_value = maximum
	current_value = current
	_update()


# ============================================================
# 样式工厂
# ============================================================

func _make_outer_border() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.024, 0.024, 0.043)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = GameColors.HP_BORDER
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	sb.shadow_size = 3
	sb.shadow_color = Color(GameColors.ACCENT_CINNABAR.r, GameColors.ACCENT_CINNABAR.g, GameColors.ACCENT_CINNABAR.b, 0.15)
	return sb


func _make_bar_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.016, 0.016, 0.031)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.12, 0.09, 0.08)
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	return sb
