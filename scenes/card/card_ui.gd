# ============================================================
# 大周天 — Card UI (古卷卡牌)
# ============================================================
# 修仙风格：四角金纹装饰 + 稀有度渐变边框 + 朱砂消耗圆
# + 金文卡名 + 元素辉光(功法) + hover金晕 + drag尾迹
# ============================================================
@tool
class_name CardUI
extends PanelContainer


signal card_clicked(card: CardData)
signal card_drag_started(card: CardData)
signal card_drag_ended(card: CardData, drop_area: String)


@export var card_data: CardData = null:
	set(v):
		card_data = v
		_update_display()


var _name_label: Label
var _cost_label: Label
var _desc_label: Label
var _type_label: Label
var _element_label: Label
var _rarity_stars: Label
var _is_dragging: bool = false
var _is_pressed: bool = false
var _is_playable: bool = true
var _original_position: Vector2
var _drag_start_pos: Vector2
var _has_dragged: bool = false
const DRAG_THRESHOLD: float = 8.0
var _corner_size: float = 8.0


func _ready() -> void:
	_build_ui()
	_update_display()
	mouse_entered.connect(_on_hover_in)
	mouse_exited.connect(_on_hover_out)
	gui_input.connect(_on_gui_input)


func _build_ui() -> void:
	custom_minimum_size = Vector2(100, 150)
	size = Vector2(100, 150)
	mouse_filter = Control.MOUSE_FILTER_STOP

	self.add_theme_stylebox_override("panel", _make_card_bg())

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	# --- Top row: cost + type ---
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	vbox.add_child(top_row)

	# Cost badge
	_cost_label = Label.new()
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_label.add_theme_font_size_override("font_size", 16)
	_cost_label.add_theme_color_override("font_color", GameColors.ACCENT_CINNABAR_BRIGHT)
	top_row.add_child(_cost_label)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top_spacer)

	# Element icon
	_element_label = Label.new()
	_element_label.add_theme_font_size_override("font_size", 10)
	top_row.add_child(_element_label)

	# Type label
	_type_label = Label.new()
	_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type_label.add_theme_font_size_override("font_size", 10)
	_type_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	vbox.add_child(_type_label)

	# Name
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 15)
	_name_label.add_theme_color_override("font_color", GameColors.TEXT_TITLE)
	vbox.add_child(_name_label)

	vbox.add_spacer(true)

	# Description
	_desc_label = Label.new()
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.add_theme_font_size_override("font_size", 10)
	_desc_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	vbox.add_child(_desc_label)

	vbox.add_spacer(true)

	# Rarity stars at bottom
	_rarity_stars = Label.new()
	_rarity_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rarity_stars.add_theme_font_size_override("font_size", 9)
	vbox.add_child(_rarity_stars)


# ============================================================
# 显示更新
# ============================================================

func _update_display() -> void:
	if not is_inside_tree() or card_data == null:
		return

	_name_label.text = card_data.display_name
	_cost_label.text = str(card_data.cost)
	_desc_label.text = card_data.description
	_type_label.text = card_data.get_type_name()

	# Card type color
	var type_color: Color = GameColors.card_type_color(card_data.card_type)

	# Element icon (for technique cards)
	if card_data.card_type == CardData.CardType.TECHNIQUE and card_data.has_method("get_technique_data"):
		var tech: TechniqueData = card_data.get_technique_data() as TechniqueData
		if tech and tech.element != "":
			_element_label.text = _element_icon(tech.element)
			_element_label.add_theme_color_override("font_color", GameColors.element_color(tech.element))
			_element_label.visible = true
		else:
			_element_label.visible = false
	else:
		_element_label.visible = false

	# Rarity stars
	_rarity_stars.text = _rarity_star_text(card_data.rarity)
	var rarity_color: Color = GameColors.rarity_color(card_data.rarity)
	_rarity_stars.add_theme_color_override("font_color", rarity_color)

	# Update border with type color + rarity
	var sb := get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb.border_color = type_color.lerp(rarity_color, 0.4)
		sb.bg_color = Color(type_color.r * 0.06, type_color.g * 0.06, type_color.b * 0.08, 0.95)
		sb.shadow_color = Color(type_color.r, type_color.g, type_color.b, 0.2)

	# Technique cards are slightly larger
	if card_data.card_type == CardData.CardType.TECHNIQUE:
		custom_minimum_size = Vector2(110, 160)
		size = Vector2(110, 160)
	else:
		custom_minimum_size = Vector2(100, 150)
		size = Vector2(100, 150)


# ============================================================
# 交互
# ============================================================

func set_playable(playable: bool) -> void:
	_is_playable = playable
	if playable:
		modulate = Color(1, 1, 1)
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		modulate = Color(0.45, 0.45, 0.45, 1.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_hover_in() -> void:
	if not _is_dragging and _is_playable:
		var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.12)
		z_index = 10

		# Golden glow on hover
		var sb := get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			sb.shadow_size = 8
			sb.shadow_color = Color(GameColors.ACCENT_GOLD.r, GameColors.ACCENT_GOLD.g, GameColors.ACCENT_GOLD.b, 0.35)


func _on_hover_out() -> void:
	if not _is_dragging and not _is_pressed:
		var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)
		z_index = 0

		var sb := get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			sb.shadow_size = 4
			sb.shadow_color = Color(0, 0, 0, 0.25)


func _process(_delta: float) -> void:
	if not _is_dragging:
		# Check if we should begin a drag (threshold exceeded)
		if _is_pressed and not _has_dragged:
			var dist: float = (get_global_mouse_position() - _drag_start_pos).length()
			if dist > DRAG_THRESHOLD:
				_begin_drag()
		return

	# Already dragging — follow mouse
	global_position = get_global_mouse_position() - size * 0.5


func _on_gui_input(event: InputEvent) -> void:
	if not _is_playable:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_start_pos = get_global_mouse_position()
				_has_dragged = false
				_is_pressed = true
				_press_visual()
			else:
				_is_pressed = false
				# Only emit card_clicked if drag never actually started
				if not _has_dragged:
					card_clicked.emit(card_data)
				else:
					_end_drag()


func _press_visual() -> void:
	# Subtle scale-up on press (not a drag yet)
	var tween := create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.08)
	z_index = 10


func _begin_drag() -> void:
	_has_dragged = true
	_is_dragging = true
	_original_position = global_position
	z_index = 100
	card_drag_started.emit(card_data)

	var tween := create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.08)
	tween.parallel().tween_property(self, "modulate", Color(1, 1, 1, 0.65), 0.08)

	# Pop front: bring to top layer
	var parent_container: Control = get_parent() if get_parent() is Control else null
	if parent_container:
		parent_container.move_child(self, parent_container.get_child_count() - 1)


func _end_drag() -> void:
	_is_dragging = false
	_is_pressed = false
	z_index = 0
	card_drag_ended.emit(card_data, "")

	if is_inside_tree() and not is_queued_for_deletion():
		var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)
		tween.parallel().tween_property(self, "modulate", Color(1, 1, 1, 1), 0.12)
		tween.parallel().tween_property(self, "global_position", _original_position, 0.15)


# ============================================================
# 样式
# ============================================================

func _make_card_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GameColors.BG_CARD
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = GameColors.BORDER_SUBTLE
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.shadow_size = 4
	sb.shadow_color = Color(0, 0, 0, 0.25)
	return sb


# ============================================================
# 辅助
# ============================================================

func _element_icon(element: String) -> String:
	match element:
		"火": return "🔥"
		"水": return "💧"
		"木": return "🌿"
		"金": return "⚙️"
		"土": return "🪨"
		_: return ""


func _rarity_star_text(rarity: int) -> String:
	match rarity:
		0: return "★"
		1: return "★★"
		2: return "★★★"
		3: return "★★★★"
		_: return "★"
