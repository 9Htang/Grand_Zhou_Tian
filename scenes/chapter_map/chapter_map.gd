# ============================================================
# 大周天 — Chapter Map (杀戮尖塔式网状地图)
# ============================================================
extends Control

# NodeType constants (mirrors MapNodeData.NodeType)
const N_BATTLE := 0
const N_ELITE := 1
const N_REST := 2
const N_SHOP := 3
const N_EVENT := 4
const N_BOSS := 5

const NODE_SIZE := Vector2(80, 60)
const COLUMN_GAP := 160
const ROW_GAP := 100
const MAP_PADDING := 60

var _chapter: ChapterData
var _node_buttons: Array[Button] = []
var _current_index: int = 0
var _connection_layer: Control

# Cached node data for fast lookup
var _nodes: Array = []          # Array of MapNodeData


func _ready() -> void:
	_load_chapter()
	_build_map()


func _load_chapter() -> void:
	_chapter = GameManager.current_chapter_data
	if _chapter == null:
		var path: String = "res://resources/chapter_data/chapter_1.tres"
		if ResourceLoader.exists(path):
			_chapter = load(path) as ChapterData
			GameManager.current_chapter_data = _chapter

	if _chapter == null or _chapter.map_nodes.is_empty():
		_generate_default_map()

	_current_index = GameManager.current_map_node_index
	_nodes = _chapter.map_nodes  # cache for fast access


func _node_icon(ntype: int) -> String:
	match ntype:
		N_BATTLE: return "[战]"
		N_ELITE:  return "[精]"
		N_REST:   return "[休]"
		N_SHOP:   return "[商]"
		N_EVENT:  return "[?]"
		N_BOSS:   return "[BOSS]"
	return "·"


func _node_color(ntype: int) -> Color:
	match ntype:
		N_BATTLE: return GameColors.ACCENT_CINNABAR
		N_ELITE:  return GameColors.ACCENT_GOLD
		N_REST:   return GameColors.ACCENT_JADE
		N_SHOP:   return GameColors.ACCENT_CERULEAN
		N_EVENT:  return GameColors.CARD_TECHNIQUE
		N_BOSS:   return GameColors.WARNING
	return Color.WHITE


func _generate_default_map() -> void:
	_chapter = ChapterData.new()
	_chapter.id = "chapter_1"
	_chapter.display_name = "第一章·山林试炼"
	_chapter.chapter_index = 1
	_chapter.map_nodes = _build_chapter1_nodes()
	_chapter.entry_node_index = 0
	_chapter.boss_node_indices = [_chapter.map_nodes.size() - 2, _chapter.map_nodes.size() - 1]
	GameManager.current_chapter_data = _chapter
	_nodes = _chapter.map_nodes


func _add_node(nodes: Array, col: int, r: int, ntype: int, dname: String, enc: String = "") -> void:
	var n := MapNodeData.new()
	n.column = col; n.row = r; n.node_type = ntype
	n.display_name = dname; n.encounter_id = enc
	nodes.append(n)


func _set_conn(nodes: Array, from_idx: int, to_indices: Array) -> void:
	nodes[from_idx].connections = to_indices.duplicate()


func _build_chapter1_nodes() -> Array:
	var nodes: Array = []
	var a = func(c, r, t, nm, enc=""): _add_node(nodes, c, r, t, nm, enc)

	# Column 0: Entry
	a.call(0, 1, N_BATTLE, "初入山林", "ch1_encounter_1")

	# Column 1
	a.call(1, 0, N_BATTLE, "妖兽巢穴", "ch1_encounter_1")
	a.call(1, 1, N_EVENT,  "古洞奇遇", "")
	a.call(1, 2, N_BATTLE, "密林小径", "ch1_encounter_2")

	# Column 2
	a.call(2, 0, N_SHOP,  "流浪商人", "")
	a.call(2, 1, N_REST,  "灵气泉眼", "")
	a.call(2, 2, N_BATTLE, "断崖险路", "ch1_encounter_2")

	# Column 3
	a.call(3, 0, N_BATTLE, "狼群围攻", "ch1_encounter_1")
	a.call(3, 1, N_ELITE, "散修拦路", "ch1_boss")
	a.call(3, 2, N_EVENT, "仙人遗府", "")

	# Column 4
	a.call(4, 0, N_BATTLE, "山巅风雷", "ch1_encounter_1")
	a.call(4, 1, N_REST,  "古刹休憩", "")
	a.call(4, 2, N_BATTLE, "密道突袭", "ch1_encounter_2")

	# Column 5: Bosses
	a.call(5, 0, N_BOSS, "执事长老", "ch1_boss")
	a.call(5, 2, N_BOSS, "护山灵兽", "ch1_boss")

	# Connections
	_set_conn(nodes, 0, [1, 2, 3])
	_set_conn(nodes, 1, [4, 5])
	_set_conn(nodes, 2, [4, 5, 6])
	_set_conn(nodes, 3, [5, 6])
	_set_conn(nodes, 4, [7, 8])
	_set_conn(nodes, 5, [7, 8, 9])
	_set_conn(nodes, 6, [8, 9])
	_set_conn(nodes, 7, [10, 11])
	_set_conn(nodes, 8, [10, 11, 12])
	_set_conn(nodes, 9, [11, 12])
	_set_conn(nodes, 10, [13, 14])
	_set_conn(nodes, 11, [13, 14])
	_set_conn(nodes, 12, [14])

	return nodes


func _build_map() -> void:
	var bg := ColorRect.new()
	bg.color = GameColors.BG_VOID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.name = "MapScroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.follow_focus = true
	add_child(scroll)

	var max_col: int = 0; var max_row: int = 0
	for n in _nodes: max_col = max(max_col, n.column); max_row = max(max_row, n.row)

	var map_w: float = max_col * COLUMN_GAP + MAP_PADDING * 2 + NODE_SIZE.x
	var map_h: float = max_row * ROW_GAP + MAP_PADDING * 2 + NODE_SIZE.y
	var map_ct := Control.new()
	map_ct.name = "MapContainer"
	map_ct.custom_minimum_size = Vector2(map_w, map_h)
	scroll.add_child(map_ct)

	var title := Label.new()
	title.text = _chapter.display_name
	title.position = Vector2(MAP_PADDING, 12)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", GameColors.TEXT_TITLE)
	map_ct.add_child(title)

	_connection_layer = Control.new()
	_connection_layer.name = "Connections"
	_connection_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_connection_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_ct.add_child(_connection_layer)
	_connection_layer.draw.connect(_draw_connections)

	_create_node_buttons(map_ct)


func _node_pos(node) -> Vector2:
	return Vector2(MAP_PADDING + node.column * COLUMN_GAP, MAP_PADDING + 36 + node.row * ROW_GAP)


func _create_node_buttons(parent: Control) -> void:
	for i: int in _nodes.size():
		var node = _nodes[i]
		var btn := Button.new()
		btn.name = "Node_" + str(i)
		btn.position = _node_pos(node)
		btn.size = NODE_SIZE

		var ntype: int = node.node_type
		var col: Color = _node_color(ntype)
		var style := StyleBoxFlat.new()
		style.bg_color = col.darkened(0.5)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = col
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", style)

		var hs := style.duplicate() as StyleBoxFlat
		hs.bg_color = col.darkened(0.3)
		btn.add_theme_stylebox_override("hover", hs)

		btn.text = _node_icon(ntype) + "\n" + node.display_name
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color.WHITE)

		var visited: bool = _is_visited(i)
		var available: bool = _is_available(i)

		if visited:
			btn.modulate = GameColors.TEXT_DIM
			btn.disabled = true
		elif available:
			btn.modulate = Color.WHITE
			btn.pressed.connect(_on_node_pressed.bind(i))
		else:
			btn.modulate = GameColors.TEXT_DIM.darkened(0.5)
			btn.disabled = true

		btn.set_meta("node_index", i)
		parent.add_child(btn)
		_node_buttons.append(btn)


func _is_visited(idx: int) -> bool:
	var cur_col: int = _nodes[_current_index].column
	return _nodes[idx].column < cur_col


func _is_available(idx: int) -> bool:
	if idx == _current_index:
		return false
	var cur_node = _nodes[_current_index]
	return idx in cur_node.connections


func _on_node_pressed(idx: int) -> void:
	_current_index = idx
	GameManager.current_map_node_index = idx

	var node = _nodes[idx]
	var ntype: int = node.node_type
	match ntype:
		N_BATTLE, N_ELITE, N_BOSS:
			SceneManager.go_to_battle(node.encounter_id)
		N_REST:
			SceneManager.switch_to_scene("res://scenes/rest/rest_screen.tscn")
		N_SHOP:
			SceneManager.switch_to_scene("res://scenes/shop/shop_screen.tscn")
		N_EVENT:
			SceneManager.switch_to_scene("res://scenes/event/event_screen.tscn")


func _update_all_buttons() -> void:
	for i: int in _node_buttons.size():
		var btn: Button = _node_buttons[i]
		var visited: bool = _is_visited(i)
		var available: bool = _is_available(i)
		if visited:
			btn.modulate = GameColors.TEXT_DIM; btn.disabled = true
		elif available:
			btn.modulate = Color.WHITE; btn.disabled = false
		else:
			btn.modulate = GameColors.TEXT_DIM.darkened(0.5); btn.disabled = true
	_connection_layer.queue_redraw()


func _draw_connections() -> void:
	var drawn: Dictionary = {}
	for i: int in _nodes.size():
		var from_node = _nodes[i]
		var from_pos: Vector2 = _node_pos(from_node) + NODE_SIZE / 2
		for ci in from_node.connections:
			var conn_idx: int = ci
			var key: String = str(min(i, conn_idx)) + "->" + str(max(i, conn_idx))
			if drawn.has(key): continue
			drawn[key] = true

			if conn_idx < 0 or conn_idx >= _nodes.size():
				continue
			var to_node = _nodes[conn_idx]
			var to_pos: Vector2 = _node_pos(to_node) + NODE_SIZE / 2
			var color: Color = Color(0.3, 0.3, 0.3)
			if _is_visited(i) or _is_visited(conn_idx):
				color = Color(0.5, 0.5, 0.5)
			if _is_available(conn_idx) and i == _current_index:
				color = Color(0.9, 0.8, 0.3)
			_connection_layer.draw_line(from_pos, to_pos, color, 3)
