# ============================================================
# 大周天 — Game Over Screen
# ============================================================
extends Control

var _won: bool = false


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Background ambiance
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
	add_child(vbox)

	var title := Label.new()
	title.text = "陨 落" if not _won else "得 道"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	if _won:
		title.add_theme_color_override("font_color", GameColors.TEXT_TITLE)
	else:
		title.add_theme_color_override("font_color", GameColors.ACCENT_CINNABAR)
	vbox.add_child(title)

	vbox.add_child(_spacer(20))

	var stats := Label.new()
	stats.text = "境界: %d   天资: %d" % [GameManager.realm, GameManager.talent]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	stats.add_theme_font_size_override("font_size", 18)
	vbox.add_child(stats)

	vbox.add_child(_spacer(40))

	var restart := _make_button("重 新 修 炼")
	restart.pressed.connect(func(): SceneManager.switch_to_scene("res://scenes/run_start/run_start_screen.tscn"))
	vbox.add_child(restart)

	vbox.add_child(_spacer(12))

	var menu := _make_button("返 回 主 菜 单")
	menu.pressed.connect(func(): SceneManager.switch_to_scene("res://scenes/menu/main_menu.tscn"))
	vbox.add_child(menu)


func _make_button(btn_text: String) -> Button:
	var btn := Button.new()
	btn.text = btn_text
	btn.flat = true
	btn.custom_minimum_size = Vector2(200, 44)

	var normal := StyleBoxFlat.new()
	normal.bg_color = GameColors.BG_PANEL
	normal.border_width_left = 1; normal.border_width_right = 1
	normal.border_width_top = 1; normal.border_width_bottom = 1
	normal.border_color = GameColors.BORDER_GOLD
	normal.corner_radius_top_left = 6; normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6; normal.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = GameColors.BG_PANEL.lightened(0.05)
	hover.border_color = GameColors.ACCENT_GOLD
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", GameColors.TEXT_TITLE)
	btn.add_theme_font_size_override("font_size", 18)
	return btn


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c
