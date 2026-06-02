# ============================================================
# 大周天 — Breakthrough Screen (境界突破 - 抽卡制)
# ============================================================
extends Control

var _options: Array[BreakthroughOptionData] = []


func _ready() -> void:
	_options = BreakthroughPool.draw_options(3, GameManager.realm)
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
	title.text = "境界突破!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UIHelpers.font_hero(self))
	title.add_theme_color_override("font_color", GameColors.TEXT_TITLE)
	vbox.add_child(title)

	vbox.add_child(_spacer(UIHelpers.pct_h(0.014, self)))

	var sub := Label.new()
	sub.text = "选择突破方式"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", GameColors.TEXT_DIM)
	vbox.add_child(sub)

	vbox.add_child(_spacer(UIHelpers.gap_medium(self)))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	for opt in _options:
		var card := _create_option_card(opt)
		row.add_child(card)
		row.add_child(_spacer(UIHelpers.pct_w(0.013, self), true))

	vbox.add_child(_spacer(UIHelpers.pct_h(0.028, self)))

	var skip := Button.new()
	skip.text = "放弃突破"
	skip.pressed.connect(_on_skip)
	vbox.add_child(skip)


func _spacer(s: float, horiz: bool = false) -> Control:
	var c := Control.new()
	if horiz: c.custom_minimum_size.x = s
	else: c.custom_minimum_size.y = s
	return c


func _create_option_card(opt: BreakthroughOptionData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.16, self)), float(UIHelpers.pct_h(0.39, self)))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = opt.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", UIHelpers.font_large(self))
	name_label.add_theme_color_override("font_color", GameColors.TEXT_TITLE)
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = opt.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", UIHelpers.font_small(self))
	vbox.add_child(desc_label)

	# Effects
	var effects_text := "效果:\n"
	for e in opt.effects:
		effects_text += "  + " + e + "\n"
	if not opt.risks.is_empty():
		effects_text += "风险:\n"
		for r in opt.risks:
			effects_text += "  - " + r + "\n"

	var eff_label := Label.new()
	eff_label.text = effects_text
	eff_label.add_theme_font_size_override("font_size", max(9, UIHelpers.font_tiny(self)))
	vbox.add_child(eff_label)

	vbox.add_spacer(true)

	var btn := Button.new()
	btn.text = "选择"
	btn.pressed.connect(_on_choose.bind(opt))
	vbox.add_child(btn)

	return panel


func _on_choose(opt: BreakthroughOptionData) -> void:
	EffectResolver.apply_all(GameManager, opt.effects)
	EffectResolver.apply_all(GameManager, opt.risks)
	GameManager.trigger_breakthrough()
	SceneManager.switch_to_scene("res://scenes/chapter_map/chapter_map.tscn")


func _on_skip() -> void:
	SceneManager.switch_to_scene("res://scenes/chapter_map/chapter_map.tscn")
