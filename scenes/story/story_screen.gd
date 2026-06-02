# ============================================================
# 大周天 — Story Screen (剧情文字)
# ============================================================
extends Control

var _chapter: ChapterData
var _full_text: String = ""
var _displayed: int = 0
var _timer: Timer
var _text_label: Label


func _ready() -> void:
	_load_chapter()
	_build_ui()
	_start_typewriter()


func _load_chapter() -> void:
	var path := "res://resources/chapter_data/chapter_1.tres"
	if ResourceLoader.exists(path):
		_chapter = load(path) as ChapterData
		if _chapter != null:
			_full_text = _chapter.story_intro
	# Guard: if text is empty or null, show fallback so player isn't stuck
	if _full_text == null or _full_text.is_empty():
		_full_text = "天地初开，万物有灵……"


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

	var margin_h: int = UIHelpers.pct_w(0.06, self)   # ~80/1280
	var margin_v: int = UIHelpers.pct_h(0.11, self)   # ~80/720

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", margin_h)
	margin.add_theme_constant_override("margin_right", margin_h)
	margin.add_theme_constant_override("margin_top", margin_v)
	margin.add_theme_constant_override("margin_bottom", margin_v)
	add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	vbox.add_spacer(true)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text_label.add_theme_font_size_override("font_size", UIHelpers.pct_h(UIHelpers.FONT_XL_PCT, self))
	_text_label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	_text_label.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.75, self)), float(UIHelpers.pct_h(0.55, self)))
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_text_label)

	vbox.add_spacer(true)

	# Continue button (hidden until text finishes)
	var btn := Button.new()
	btn.text = "继续"
	btn.visible = false
	btn.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.13, self)), float(UIHelpers.pct_h(0.06, self)))
	btn.pressed.connect(_on_continue)
	vbox.add_child(btn)

	_timer = Timer.new()
	_timer.wait_time = 0.05
	_timer.timeout.connect(_reveal_char)
	add_child(_timer)

	# Click anywhere to skip typewriter
	gui_input.connect(_on_click)


func _start_typewriter() -> void:
	_displayed = 0
	_text_label.text = ""
	_timer.start()


func _reveal_char() -> void:
	if _displayed < _full_text.length():
		_displayed += 1
		_text_label.text = _full_text.substr(0, _displayed)
	else:
		_timer.stop()
		var btn := _find_continue_button()
		if btn:
			btn.visible = true


func _on_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _displayed < _full_text.length():
			_displayed = _full_text.length()
			_text_label.text = _full_text
			_timer.stop()
			var btn := _find_continue_button()
			if btn:
				btn.visible = true


func _find_continue_button() -> Button:
	for child in get_children():
		if child is MarginContainer:
			for c in child.get_children():
				if c is VBoxContainer:
					for btn in c.get_children():
						if btn is Button:
							return btn
	return null


func _on_continue() -> void:
	SceneManager.switch_to_scene("res://scenes/chapter_map/chapter_map.tscn")
