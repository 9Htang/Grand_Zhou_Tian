# ============================================================
# 大周天 — ForgePopup
# 锻造结果弹窗 — 纯表现层，接收 CardForgeResult 展示
# ============================================================
class_name ForgePopup
extends PanelContainer


var _vbox: VBoxContainer
var _title: Label
var _message: Label
var _close_btn: Button
var _auto_close_timer  # SceneTreeTimer


func _init(result: CardForgeResult) -> void:
	name = "ForgeResultPopup"
	_setup_style(result.success)
	_setup_content(result)


func _setup_style(success: bool) -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(360, 140)

	var sb := StyleBoxFlat.new()
	sb.bg_color = GameColors.BG_PANEL
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.border_color = GameColors.ACCENT_GOLD_BRIGHT if success else GameColors.ACCENT_CINNABAR
	sb.corner_radius_top_left = 10; sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10; sb.corner_radius_bottom_right = 10
	add_theme_stylebox_override("panel", sb)


func _setup_content(result: CardForgeResult) -> void:
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 10)

	_title = Label.new()
	_title.text = "转化成功!" if result.success else "转化失败"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", GameColors.ACCENT_GOLD_BRIGHT if result.success else GameColors.ACCENT_CINNABAR)
	_title.add_theme_font_size_override("font_size", 18)
	_vbox.add_child(_title)

	_message = Label.new()
	_message.text = result.message
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	_message.add_theme_font_size_override("font_size", 13)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD
	_vbox.add_child(_message)

	_close_btn = Button.new()
	_close_btn.text = "确定"
	_close_btn.flat = true
	_close_btn.custom_minimum_size = Vector2(80, 30)
	_close_btn.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	_close_btn.pressed.connect(queue_free)
	_vbox.add_child(_close_btn)

	add_child(_vbox)


func _ready() -> void:
	_auto_close_timer = get_tree().create_timer(3.0)
	_auto_close_timer.timeout.connect(queue_free)
