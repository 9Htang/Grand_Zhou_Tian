# ============================================================
# 大周天 — EventScreen (事件 UI 壳 — L0)
# ============================================================
# 职责: UI 构建 + 按钮点击 + 结果展示
# 所有业务逻辑委托给 EventController (L1)
# ============================================================
extends Control

# === Subsystems ===
var _controller: EventController

# === Dynamic Nodes ===
var _title_label: Label
var _desc_label: Label
var _choices_vbox: VBoxContainer
var _result_label: Label
var _continue_btn: Button

var _full_description: String = ""


# ============================================================
# Lifecycle
# ============================================================

func _ready() -> void:
	_controller = EventController.new()
	_build_background()
	_build_ui()


# ============================================================
# 背景 / 装饰（纯 UI，不做逻辑）
# ============================================================

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var header_bar := ColorRect.new()
	header_bar.color = Color(0.5, 0.2, 0.6, 0.3)
	header_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_bar.custom_minimum_size.y = 3
	add_child(header_bar)

	var footer_bar := ColorRect.new()
	footer_bar.color = Color(0.9, 0.8, 0.4, 0.15)
	footer_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer_bar.custom_minimum_size.y = 1
	add_child(footer_bar)


# ============================================================
# UI 构建（纯布局，数据全部来自 EventController）
# ============================================================

func _build_ui() -> void:
	var event_data: Dictionary = _controller.start_event()

	var m_h: int = UIHelpers.pad_h(self) * 2
	var m_v: int = UIHelpers.pad_v(self) * 2

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", m_h)
	margin.add_theme_constant_override("margin_right", m_h)
	margin.add_theme_constant_override("margin_top", m_v)
	margin.add_theme_constant_override("margin_bottom", m_v)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIHelpers.pct_h(0.02, self))
	margin.add_child(vbox)

	# ── 标题 ──
	_title_label = Label.new()
	_title_label.text = event_data.get("display_name", "未知奇遇")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", UIHelpers.font_title(self))
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.3, 0.15, 0.0, 0.5))
	vbox.add_child(_title_label)

	# ── 装饰分隔线 ──
	var sep := ColorRect.new()
	sep.color = Color(0.5, 0.2, 0.6, 0.35)
	sep.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.25, self)), 2.0)
	vbox.add_child(sep)

	# ── 描述文字（带打字延迟效果） ──
	_desc_label = Label.new()
	_desc_label.text = ""
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.add_theme_font_size_override("font_size", UIHelpers.font_medium(self))
	_desc_label.add_theme_color_override("font_color", Color(0.78, 0.73, 0.73))
	_desc_label.custom_minimum_size.y = float(UIHelpers.pct_h(0.125, self))
	vbox.add_child(_desc_label)

	_full_description = event_data.get("description", "四周一片寂静……")

	var typing_timer := Timer.new()
	typing_timer.one_shot = true
	typing_timer.timeout.connect(_reveal_description)
	add_child(typing_timer)
	typing_timer.start(0.4)

	# ── 选项区域 ──
	_choices_vbox = VBoxContainer.new()
	_choices_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(_choices_vbox)
	_build_choices(event_data.get("choices", []))

	# ── 结果文字（初始隐藏） ──
	_result_label = Label.new()
	_result_label.text = ""
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_result_label.add_theme_font_size_override("font_size", UIHelpers.font_medium(self))
	_result_label.add_theme_color_override("font_color", Color(0.88, 0.82, 0.68))
	_result_label.visible = false
	vbox.add_child(_result_label)

	# ── 弹性空间 ──
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND
	vbox.add_child(spacer)

	# ── 继续按钮（初始隐藏） ──
	_continue_btn = Button.new()
	_continue_btn.text = "继续"
	_continue_btn.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.16, self)), float(UIHelpers.pct_h(0.06, self)))
	_continue_btn.add_theme_font_size_override("font_size", UIHelpers.font_large(self))
	_continue_btn.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	_continue_btn.visible = false
	_continue_btn.pressed.connect(_on_continue_pressed)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_child(_continue_btn)
	vbox.add_child(btn_hbox)


func _reveal_description() -> void:
	_desc_label.text = _full_description


# ============================================================
# 选项构建（纯 UI — 数据来自 EventController 预检）
# ============================================================

func _build_choices(choices: Array) -> void:
	if choices.is_empty():
		var no_choice := Button.new()
		no_choice.text = "离开此地"
		no_choice.custom_minimum_size.y = UIHelpers.pct_h(0.06, self)
		no_choice.pressed.connect(_on_no_choice)
		_choices_vbox.add_child(no_choice)
		return

	for choice_data in choices:
		_choices_vbox.add_child(_create_choice_button(choice_data))


func _create_choice_button(choice_data: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size.y = UIHelpers.pct_h(0.067, self)
	btn.add_theme_font_size_override("font_size", UIHelpers.font_medium(self))

	# 构建选项文字（含提示）
	var text: String = choice_data.get("text", "未知选项")
	var hint: String = choice_data.get("hint", "")
	if not hint.is_empty():
		text += "  （" + hint + "）"
	btn.text = text

	var disabled: bool = choice_data.get("disabled", false)
	btn.disabled = disabled

	if disabled:
		btn.modulate = Color(0.4, 0.4, 0.4)
		_apply_disabled_style(btn)
	else:
		_apply_enabled_style(btn)
		var index: int = choice_data.get("index", 0)
		btn.pressed.connect(_on_choice_selected.bind(index))

	return btn


# ============================================================
# 按钮样式（纯 UI 装饰）
# ============================================================

func _apply_disabled_style(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.1, 0.2)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.2, 0.4)
	style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style)


func _apply_enabled_style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.2, 0.12, 0.25)
	normal.border_width_left = 2; normal.border_width_right = 2
	normal.border_width_top = 2; normal.border_width_bottom = 2
	normal.border_color = Color(0.55, 0.22, 0.75)
	normal.corner_radius_top_left = 6; normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6; normal.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.3, 0.18, 0.35)
	hover.border_width_left = 2; hover.border_width_right = 2
	hover.border_width_top = 2; hover.border_width_bottom = 2
	hover.border_color = Color(0.7, 0.3, 0.9)
	hover.corner_radius_top_left = 6; hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6; hover.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("hover", hover)


# ============================================================
# 事件处理（纯 UI — 委托 EventController）
# ============================================================

func _on_choice_selected(choice_index: int) -> void:
	# 清除选项
	for child in _choices_vbox.get_children():
		_choices_vbox.remove_child(child)
		child.queue_free()

	# 委托执行
	var result: EventResult = _controller.select_choice(choice_index)

	# 展示结果
	_result_label.text = result.text
	_result_label.visible = true
	_continue_btn.visible = true

	# 确保描述已显示
	_desc_label.text = _full_description


func _on_no_choice() -> void:
	_result_label.text = "你转身离开了这里。"
	_result_label.visible = true
	_continue_btn.visible = true


func _on_continue_pressed() -> void:
	SceneManager.switch_to_scene("res://scenes/chapter_map/chapter_map.tscn")
