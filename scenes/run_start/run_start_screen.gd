# ============================================================
# 大周天 — Run Start Screen (起始功法选择)
# ============================================================
extends Control

var _techniques: Array[TechniqueData] = []


func _ready() -> void:
	_techniques = TechniqueDatabase.get_starting_techniques()
	_build_ui()


func _build_ui() -> void:

	if ResourceLoader.exists("res://ui_components/background_ambiance.gd"):
		var ambiance_sc: GDScript = load("res://ui_components/background_ambiance.gd") as GDScript
		var ambiance := Control.new()
		ambiance.set_script(ambiance_sc)
		ambiance.name = "BackgroundAmbiance"
		add_child(ambiance)
	else:
		var bg := ColorRect.new()
		bg.color = GameColors.BG_VOID
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	var title := Label.new()
	title.text = "选择起始功法"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UIHelpers.scale_font(32, self))
	title.add_theme_color_override("font_color", GameColors.TEXT_TITLE)
	vbox.add_child(title)

	vbox.add_child(_spacer(UIHelpers.gap_medium(self)))

	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(card_row)

	for tech in _techniques:
		var card := _create_technique_card(tech)
		card_row.add_child(card)
		card_row.add_child(_spacer(UIHelpers.pct_w(0.016, self), true))


func _spacer(s: float, horizontal: bool = false) -> Control:
	var c := Control.new()
	if horizontal:
		c.custom_minimum_size.x = s
	else:
		c.custom_minimum_size.y = s
	return c


func _create_technique_card(tech: TechniqueData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.14, self)), float(UIHelpers.pct_h(0.39, self)))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Helpers.color_for_element(tech.get_element_int())
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = tech.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", UIHelpers.font_xl(self))
	name_label.add_theme_color_override("font_color", Helpers.color_for_element(tech.get_element_int()))
	vbox.add_child(name_label)

	var elem_label := Label.new()
	elem_label.text = "属性: %s" % tech.element
	elem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(elem_label)

	vbox.add_child(_spacer(8))

	var desc_label := Label.new()
	desc_label.text = tech.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", UIHelpers.font_small(self))
	vbox.add_child(desc_label)

	vbox.add_spacer(true)

	var choose_btn := Button.new()
	choose_btn.text = "选择"
	choose_btn.custom_minimum_size.y = UIHelpers.pct_h(0.05, self)
	choose_btn.pressed.connect(_on_choose.bind(tech.id))
	vbox.add_child(choose_btn)

	return panel


func _on_choose(tech_id: String) -> void:
	GameManager.start_new_run(tech_id)
	SceneManager.switch_to_scene("res://scenes/story/story_screen.tscn")
