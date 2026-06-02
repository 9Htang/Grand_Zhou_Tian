# ============================================================
# 大周天 — Main Root Scene (直接构建主菜单)
# ============================================================
extends Control


func _ready() -> void:
	_build_menu()


func _build_menu() -> void:
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

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)

	var title := Label.new()
	title.text = "大 周 天"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", GameColors.TEXT_TITLE)
	center.add_child(title)

	center.add_child(_spacer(20))

	var sub := Label.new()
	sub.text = "修仙卡牌"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	center.add_child(sub)

	center.add_child(_spacer(60))

	var start_btn := Button.new()
	start_btn.text = "开始修炼"
	start_btn.custom_minimum_size = Vector2(200, 50)
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.pressed.connect(_on_start)
	center.add_child(start_btn)

	center.add_child(_spacer(16))

	var quit_btn := Button.new()
	quit_btn.text = "离开"
	quit_btn.custom_minimum_size = Vector2(200, 50)
	quit_btn.pressed.connect(_on_quit)
	center.add_child(quit_btn)


func _spacer(height: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size.y = height
	return s


func _on_start() -> void:
	SceneManager.switch_to_scene("res://scenes/run_start/run_start_screen.tscn")


func _on_quit() -> void:
	get_tree().quit()
