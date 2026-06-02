# ============================================================
# 大周天 — Main Menu (主菜单)
# ============================================================
extends Control


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Background ambiance
	var ambiance_sc: GDScript = load("res://ui_components/background_ambiance.gd") as GDScript
	var ambiance := Control.new()
	ambiance.set_script(ambiance_sc)
	ambiance.name = "BackgroundAmbiance"
	add_child(ambiance)

	# Center container
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)

	# Title — large gold text with breathing glow
	var title := Label.new()
	title.text = "大 周 天"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", GameColors.TEXT_TITLE)
	center.add_child(title)

	center.add_child(_spacer(16))

	# Subtitle
	var sub := Label.new()
	sub.text = "修 仙 卡 牌"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	center.add_child(sub)

	center.add_child(_spacer(60))

	# Start button
	var start_btn := _make_menu_button("开 始 修 炼")
	start_btn.pressed.connect(_on_start)
	center.add_child(start_btn)

	center.add_child(_spacer(16))

	# Continue button
	var cont_btn := _make_menu_button("继 续 修 炼")
	cont_btn.disabled = true
	center.add_child(cont_btn)

	center.add_child(_spacer(16))

	# Quit button
	var quit_btn := _make_menu_button("离 开")
	quit_btn.pressed.connect(_on_quit)
	center.add_child(quit_btn)


func _make_menu_button(btn_text: String) -> Button:
	var btn := Button.new()
	btn.text = btn_text
	btn.flat = true
	btn.custom_minimum_size = Vector2(220, 50)

	# Normal style: dark panel + gold border
	var normal := StyleBoxFlat.new()
	normal.bg_color = GameColors.BG_PANEL
	normal.border_width_left = 1; normal.border_width_right = 1
	normal.border_width_top = 1; normal.border_width_bottom = 1
	normal.border_color = GameColors.BORDER_GOLD
	normal.corner_radius_top_left = 8; normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8; normal.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", normal)

	# Hover: glow
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = GameColors.BG_PANEL.lightened(0.05)
	hover.border_color = GameColors.ACCENT_GOLD
	hover.shadow_size = 8
	hover.shadow_color = Color(GameColors.ACCENT_GOLD.r, GameColors.ACCENT_GOLD.g, GameColors.ACCENT_GOLD.b, 0.3)
	btn.add_theme_stylebox_override("hover", hover)

	# Pressed
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = GameColors.ACCENT_GOLD_DIM
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", GameColors.TEXT_TITLE)
	btn.add_theme_color_override("font_disabled_color", GameColors.TEXT_DIM)
	btn.add_theme_font_size_override("font_size", 22)
	return btn


func _spacer(height: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size.y = height
	return s


func _on_start() -> void:
	SceneManager.switch_to_scene("res://scenes/run_start/run_start_screen.tscn")


func _on_quit() -> void:
	get_tree().quit()
