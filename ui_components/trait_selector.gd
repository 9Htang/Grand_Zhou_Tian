# ============================================================
# 大周天 — TraitSelector
# 特性选择弹窗 — 用于离火易象步骤 3/4
# ============================================================
class_name TraitSelector
extends PanelContainer


signal trait_selected(selected_trait)
signal cancelled()


func _init(
	traits: Array = [],
	title_text: String = "选择特性"
) -> void:
	name = "TraitSelectorPopup"
	_setup_style()
	_setup_content(traits, title_text)


func _setup_style() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(300, 160)

	var sb := StyleBoxFlat.new()
	sb.bg_color = GameColors.BG_CARD
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = GameColors.ACCENT_GOLD_BRIGHT
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", sb)


func _setup_content(traits, title_text: String) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", GameColors.ACCENT_GOLD_BRIGHT)
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	for f in traits:
		var d: Dictionary = f
		var btn := Button.new()
		btn.text = str(d.get("display_name", "?"))
		btn.flat = true
		btn.custom_minimum_size = Vector2(0, 32)
		btn.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_trait_picked.bind(d))
		vbox.add_child(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.flat = true
	cancel_btn.custom_minimum_size = Vector2(0, 28)
	cancel_btn.add_theme_color_override("font_color", GameColors.TEXT_DIM)
	cancel_btn.add_theme_font_size_override("font_size", 11)
	cancel_btn.pressed.connect(_on_cancel)
	vbox.add_child(cancel_btn)

	add_child(vbox)


func _on_trait_picked(selected_trait: Dictionary) -> void:
	trait_selected.emit(selected_trait)
	queue_free()


func _on_cancel() -> void:
	cancelled.emit()
	queue_free()
