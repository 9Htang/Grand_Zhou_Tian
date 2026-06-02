# ============================================================
# 大周天 — Rest Screen (灵气泉眼)
# ============================================================
extends Control

var _feedback_label: Label = null


func _ready() -> void:
	# Apply rest effects immediately on entering
	var heal_amount: int = int(GameManager.player_max_hp * 0.3)
	GameManager.heal(heal_amount)
	_build_ui()


func _build_ui() -> void:
	# Background
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

	# Use FULL_RECT margin + center-aligned VBox so layout never overflows
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m_h: int = UIHelpers.pad_h(self) * 3
	var m_v: int = UIHelpers.pad_v(self) * 2
	margin.add_theme_constant_override("margin_left", m_h)
	margin.add_theme_constant_override("margin_right", m_h)
	margin.add_theme_constant_override("margin_top", m_v)
	margin.add_theme_constant_override("margin_bottom", m_v)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	vbox.add_spacer(true)

	# Title
	var title := Label.new()
	title.text = "灵气泉眼"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UIHelpers.font_title(self))
	title.add_theme_color_override("font_color", GameColors.TEXT_TITLE)
	vbox.add_child(title)

	vbox.add_child(_spacer(UIHelpers.pct_h(0.014, self)))

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "你在灵气泉眼旁打坐休息，灵气流转全身..."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	subtitle.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	subtitle.add_theme_font_size_override("font_size", UIHelpers.font_medium(self))
	vbox.add_child(subtitle)

	vbox.add_child(_spacer(UIHelpers.gap_medium(self)))

	# Heal result message
	var heal_amount: int = int(GameManager.player_max_hp * 0.3)
	var heal_msg := Label.new()
	heal_msg.text = "恢复 %d HP" % heal_amount
	heal_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heal_msg.add_theme_color_override("font_color", GameColors.ACCENT_JADE)
	heal_msg.add_theme_font_size_override("font_size", UIHelpers.font_large(self))
	vbox.add_child(heal_msg)

	# Current HP display
	var hp_msg := Label.new()
	hp_msg.text = "当前生命: %d / %d" % [GameManager.player_hp, GameManager.player_max_hp]
	hp_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_msg.add_theme_color_override("font_color", GameColors.TEXT_DIM)
	hp_msg.add_theme_font_size_override("font_size", UIHelpers.font_normal(self))
	vbox.add_child(hp_msg)

	vbox.add_child(_spacer(UIHelpers.gap_medium(self) + UIHelpers.pct_h(0.014, self)))

	# Action buttons row
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	var btn_w: int = UIHelpers.pct_w(0.13, self)
	var btn_h: int = UIHelpers.pct_h(0.06, self)

	# Button 1: Repair pathway
	var has_damaged: bool = not GameManager.damaged_pathways.is_empty()
	var repair_btn := Button.new()
	repair_btn.custom_minimum_size = Vector2(float(btn_w), float(btn_h))
	if has_damaged:
		repair_btn.text = "修复经脉"
		repair_btn.pressed.connect(_on_repair_pathway.bind(repair_btn))
	else:
		repair_btn.text = "经脉完好"
		repair_btn.disabled = true
	row.add_child(repair_btn)

	row.add_child(_spacer(UIHelpers.pct_w(0.013, self), true))

	# Button 2: Meditate
	var meditated: bool = GameManager.has_meta("rest_bonus_qi")
	var meditate_btn := Button.new()
	meditate_btn.custom_minimum_size = Vector2(float(btn_w), float(btn_h))
	if meditated:
		meditate_btn.text = "已冥想"
		meditate_btn.disabled = true
	else:
		meditate_btn.text = "冥想"
		meditate_btn.pressed.connect(_on_meditate.bind(meditate_btn))
	row.add_child(meditate_btn)

	# Feedback label (shown below action buttons)
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_color_override("font_color", GameColors.ACCENT_GOLD)
	_feedback_label.add_theme_font_size_override("font_size", UIHelpers.font_normal(self))
	_feedback_label.visible = false
	vbox.add_child(_feedback_label)

	vbox.add_spacer(true)

	# Continue button — always visible, always clickable
	var continue_btn := Button.new()
	continue_btn.text = "继续"
	continue_btn.custom_minimum_size = Vector2(float(btn_w + UIHelpers.pct_w(0.02, self)), float(btn_h + UIHelpers.pct_h(0.007, self)))
	continue_btn.pressed.connect(_on_continue)
	vbox.add_child(continue_btn)


func _spacer(s: float, horiz: bool = false) -> Control:
	var c := Control.new()
	if horiz:
		c.custom_minimum_size.x = s
	else:
		c.custom_minimum_size.y = s
	return c


func _on_repair_pathway(btn: Button) -> void:
	GameManager.repair_random_pathway()
	btn.disabled = true
	btn.text = "经脉已修复"
	_show_feedback("经脉修复成功！")


func _on_meditate(btn: Button) -> void:
	GameManager.set_meta("rest_bonus_qi", 2)
	btn.disabled = true
	btn.text = "已冥想"
	_show_feedback("获得「冥想」效果：下一场战斗+2起始灵气")


func _show_feedback(text: String) -> void:
	if _feedback_label != null:
		_feedback_label.text = text
		_feedback_label.visible = true


func _on_continue() -> void:
	SceneManager.switch_to_scene("res://scenes/chapter_map/chapter_map.tscn")
