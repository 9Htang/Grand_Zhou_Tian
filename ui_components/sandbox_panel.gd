# ============================================================
# 大周天 — Sandbox Debug Panel
# ============================================================
# 按 ` 键或点击顶栏🔧呼出，战斗中调试用
# Tab 1: 经脉 — 穴位解锁/灵气/特性管理
# Tab 2: 卡牌 — 直接加牌到手牌
# Tab 3: 敌人 — 修改敌方 HP/格挡/状态/力量
# ============================================================
class_name SandboxPanel
extends CanvasLayer


var _battle: Node = null
var _snapshot: Dictionary = {}  # 穴位初始快照 {"name": {"unlocked":true, "current_qi":0, "properties":[]}}
var _tab_meridian: VBoxContainer
var _tab_cards: VBoxContainer
var _tab_enemies: VBoxContainer
var _tab_btns: Array[Button] = []
var _prop_list: Array[Dictionary] = []
var _prop_param: SpinBox
var _prop_dropdown: OptionButton
var _prop_target_node_idx: int = -1
var _node_list_container: VBoxContainer
var _card_list_container: VBoxContainer
var _enemy_list_container: VBoxContainer
var _infinite_qi: bool = false
var _infinite_qi_btn: CheckButton


func init(battle_screen: Node) -> void:
	_battle = battle_screen
	_build_ui()
	_save_snapshot()
	hide()


func is_infinite_qi() -> bool:
	return _infinite_qi


func _on_infinite_qi_toggled(toggled_on: bool) -> void:
	_infinite_qi = toggled_on
	if toggled_on and _battle and _battle.player_actor:
		_battle.player_actor.dantian_qi = _battle.player_actor.dantian_capacity


func _process(_delta: float) -> void:
	if _infinite_qi and _battle and _battle.player_actor:
		if _battle.player_actor.dantian_qi < _battle.player_actor.dantian_capacity:
			_battle.player_actor.dantian_qi = _battle.player_actor.dantian_capacity


func _build_ui() -> void:
	layer = 100

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_bg_clicked)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(320, 600)
	var panel_anchor := Control.new()
	panel_anchor.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel_anchor.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel_anchor.position = Vector2(-330, 10)
	panel_anchor.add_child(panel)
	add_child(panel_anchor)

	var outer := VBoxContainer.new()
	panel.add_child(outer)

	# --- Infinite Qi Toggle ---
	var qi_row := HBoxContainer.new()
	_infinite_qi_btn = CheckButton.new()
	_infinite_qi_btn.text = "无限灵气"
	_infinite_qi_btn.toggled.connect(_on_infinite_qi_toggled)
	qi_row.add_child(_infinite_qi_btn)
	outer.add_child(qi_row)

	# --- Tab Bar ---
	var tab_bar := HBoxContainer.new()
	_tab_meridian = VBoxContainer.new()
	_tab_cards = VBoxContainer.new()
	_tab_enemies = VBoxContainer.new()

	var names := ["经脉", "卡牌", "敌人"]
	var containers := [_tab_meridian, _tab_cards, _tab_enemies]
	for i in range(3):
		var btn := Button.new()
		btn.text = names[i]
		btn.flat = false
		btn.pressed.connect(_on_tab_changed.bind(i))
		_tab_btns.append(btn)
		tab_bar.add_child(btn)
	outer.add_child(tab_bar)

	# --- Tab 1: Meridian ---
	_build_meridian_tab()
	# --- Tab 2: Cards ---
	_build_cards_tab()
	# --- Tab 3: Enemies ---
	_build_enemies_tab()

	for c in containers:
		outer.add_child(c)

	# Default: show tab 0
	_on_tab_changed(0)


# ============================================================
# Tab 1: Meridian
# ============================================================

func _build_meridian_tab() -> void:
	# Shortcut buttons
	var shortcuts := HBoxContainer.new()
	for item in [["全部解锁", "_unlock_all"], ["注满灵气", "_fill_all_qi"], ["清除特性", "_clear_all_props"], ["重置经脉", "_reset_all"]]:
		var b := Button.new()
		b.text = item[0]
		b.pressed.connect(Callable(self, item[1]))
		b.add_theme_font_size_override("font_size", 11)
		shortcuts.add_child(b)
	_tab_meridian.add_child(shortcuts)

	# Property editor row
	var prop_row := HBoxContainer.new()
	_prop_dropdown = OptionButton.new()
	_prop_list = _build_property_options()
	for entry in _prop_list:
		_prop_dropdown.add_item(entry["label"])
	_prop_dropdown.item_selected.connect(_on_prop_selected)
	prop_row.add_child(_prop_dropdown)
	_prop_param = SpinBox.new()
	_prop_param.min_value = 0
	_prop_param.max_value = 99
	_prop_param.value = 1
	_prop_param.step = 1
	_prop_param.custom_minimum_size = Vector2(40, 24)
	prop_row.add_child(_prop_param)
	var add_btn := Button.new()
	add_btn.text = "+"
	add_btn.pressed.connect(_on_add_property)
	prop_row.add_child(add_btn)
	_tab_meridian.add_child(prop_row)

	# Scrollable node list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 420
	_node_list_container = VBoxContainer.new()
	scroll.add_child(_node_list_container)
	_tab_meridian.add_child(scroll)


func _refresh_node_list() -> void:
	for child in _node_list_container.get_children():
		child.queue_free()

	var mer: MeridianMapData = GameManager.base_meridian
	if mer == null:
		return

	for i: int in mer.nodes.size():
		var node: MeridianNodeData = mer.get_node(i)
		if node == null:
			continue

		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 28

		# Name
		var name_label := Label.new()
		name_label.text = "%d.%s" % [i, node.name]
		name_label.custom_minimum_size = Vector2(80, 24)
		name_label.add_theme_font_size_override("font_size", 10)
		row.add_child(name_label)

		# Lock toggle
		var lock_btn := Button.new()
		lock_btn.text = "🔓" if node.unlocked else "🔒"
		lock_btn.flat = true
		lock_btn.custom_minimum_size = Vector2(30, 24)
		lock_btn.pressed.connect(_on_toggle_lock.bind(i, lock_btn))
		row.add_child(lock_btn)

		# Qi SpinBox
		var qi_spin := SpinBox.new()
		qi_spin.min_value = 0
		qi_spin.max_value = node.capacity
		qi_spin.value = node.current_qi
		qi_spin.step = 0.5
		qi_spin.custom_minimum_size = Vector2(50, 24)
		qi_spin.value_changed.connect(_on_qi_changed.bind(i))
		row.add_child(qi_spin)

		# Properties list (as deletable labels)
		var prop_parent := HBoxContainer.new()
		prop_parent.name = "Props_%d" % i
		for prop: String in node.properties:
			var prop_btn := Button.new()
			prop_btn.text = prop
			prop_btn.flat = true
			prop_btn.add_theme_font_size_override("font_size", 8)
			prop_btn.pressed.connect(_on_remove_property.bind(i, prop))
			prop_parent.add_child(prop_btn)
		# "Add" target selector
		var target_btn := Button.new()
		target_btn.text = "→"
		target_btn.flat = true
		target_btn.custom_minimum_size = Vector2(20, 24)
		target_btn.pressed.connect(_on_select_prop_target.bind(i))
		prop_parent.add_child(target_btn)
		row.add_child(prop_parent)

		_node_list_container.add_child(row)


# ============================================================
# Tab 2: Cards
# ============================================================

func _build_cards_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 520
	_card_list_container = VBoxContainer.new()
	scroll.add_child(_card_list_container)
	_tab_cards.add_child(scroll)


func _refresh_card_list() -> void:
	for child in _card_list_container.get_children():
		child.queue_free()

	var ids: Array = CardDatabase.get_all_card_ids()
	for id: String in ids:
		var card: CardData = CardDatabase.get_card(id)
		if card == null:
			continue

		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 26

		var name_label := Label.new()
		var type_str: String = Constants.card_type_name(Constants.CardType.values()[card.card_type])
		name_label.text = "%s (%s) 费%d" % [card.display_name, type_str, card.cost]
		name_label.custom_minimum_size = Vector2(200, 24)
		name_label.add_theme_font_size_override("font_size", 10)
		row.add_child(name_label)

		var add_btn := Button.new()
		add_btn.text = "+1"
		add_btn.flat = true
		add_btn.custom_minimum_size = Vector2(40, 24)
		add_btn.pressed.connect(_on_add_card.bind(id))
		row.add_child(add_btn)

		_card_list_container.add_child(row)


# ============================================================
# Tab 3: Enemies
# ============================================================

func _build_enemies_tab() -> void:
	# Shortcuts
	var shortcuts := HBoxContainer.new()
	var kill_btn := Button.new()
	kill_btn.text = "💀秒杀全部"
	kill_btn.pressed.connect(_on_kill_all_enemies)
	kill_btn.add_theme_font_size_override("font_size", 11)
	shortcuts.add_child(kill_btn)
	var heal_btn := Button.new()
	heal_btn.text = "❤️回满全部"
	heal_btn.pressed.connect(_on_heal_all_enemies)
	heal_btn.add_theme_font_size_override("font_size", 11)
	shortcuts.add_child(heal_btn)
	_tab_enemies.add_child(shortcuts)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 480
	_enemy_list_container = VBoxContainer.new()
	scroll.add_child(_enemy_list_container)
	_tab_enemies.add_child(scroll)


func _refresh_enemy_list() -> void:
	for child in _enemy_list_container.get_children():
		child.queue_free()

	if _battle == null:
		return

	var enemies: Array = _battle.enemies
	for idx in range(enemies.size()):
		var actor: EnemyActor = enemies[idx]
		if actor == null:
			continue

		var box := VBoxContainer.new()
		box.custom_minimum_size.y = 20

		var title := Label.new()
		title.text = "[%d] %s (HP:%d/%d)" % [idx, actor.display_name, actor.hp, actor.max_hp]
		title.add_theme_font_size_override("font_size", 11)
		box.add_child(title)

		# HP
		var hp_row := _make_spin_row("HP",
			actor.hp, 0, actor.max_hp,
			func(v): actor.hp = v; _refresh_if_battle()
		)
		box.add_child(hp_row)

		# Block
		var blk_row := _make_spin_row("格挡",
			actor.current_block, 0, 99,
			func(v): actor.current_block = v; _refresh_if_battle()
		)
		box.add_child(blk_row)

		# Burn status
		var burn_row := _make_status_row("灼烧", "burn", "damage", "turns", actor)
		box.add_child(burn_row)

		# Vulnerable status
		var vuln_row := _make_status_row("易伤", "vulnerable", "turns", "", actor)
		box.add_child(vuln_row)

		# Weak status
		var weak_row := _make_status_row("虚弱", "weak", "amount", "turns", actor)
		box.add_child(weak_row)

		# Strength
		var str_row := _make_spin_row("力量", actor.strength, 0, 99,
			func(v): actor.strength = v
		)
		box.add_child(str_row)

		_enemy_list_container.add_child(box)

		# Separator
		var sep := HSeparator.new()
		_enemy_list_container.add_child(sep)


# ============================================================
# UI Helpers
# ============================================================

func _make_spin_row(label_str: String, initial: int, min_v: int, max_v: int, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 24
	var lbl := Label.new()
	lbl.text = label_str
	lbl.custom_minimum_size = Vector2(50, 20)
	lbl.add_theme_font_size_override("font_size", 10)
	row.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.value = initial
	spin.step = 1
	spin.custom_minimum_size = Vector2(60, 20)
	spin.value_changed.connect(func(v): callback.call(v))
	row.add_child(spin)
	return row


func _make_status_row(label_str: String, status_key: String, val_key: String, turns_key: String, actor: EnemyActor) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 24
	var lbl := Label.new()
	lbl.text = label_str
	lbl.custom_minimum_size = Vector2(50, 20)
	lbl.add_theme_font_size_override("font_size", 10)
	row.add_child(lbl)

	var statuses: Dictionary = actor.statuses
	var has_status: bool = statuses.has(status_key)

	var toggle := Button.new()
	toggle.text = "✓" if has_status else "✗"
	toggle.flat = true
	toggle.custom_minimum_size = Vector2(24, 20)
	toggle.pressed.connect(func():
		var s: Dictionary = actor.statuses
		if s.has(status_key):
			s.erase(status_key)
		else:
			var entry: Dictionary = {}
			entry[val_key] = 1
			if not turns_key.is_empty():
				entry[turns_key] = 2
			s[status_key] = entry
		actor.statuses = s
		_refresh_if_battle()
		_refresh_enemy_list()
	)
	row.add_child(toggle)

	var val_spin := SpinBox.new()
	val_spin.min_value = 0
	val_spin.max_value = 99
	val_spin.step = 1
	val_spin.custom_minimum_size = Vector2(40, 20)
	if has_status:
		val_spin.value = statuses[status_key].get(val_key, 1)
	val_spin.value_changed.connect(func(v):
		var s: Dictionary = actor.statuses
		if s.has(status_key):
			s[status_key][val_key] = v
			actor.statuses = s
	)
	row.add_child(val_spin)

	if not turns_key.is_empty():
		var turn_spin := SpinBox.new()
		turn_spin.min_value = 0
		turn_spin.max_value = 99
		turn_spin.step = 1
		turn_spin.custom_minimum_size = Vector2(40, 20)
		if has_status:
			turn_spin.value = statuses[status_key].get(turns_key, 2)
		turn_spin.value_changed.connect(func(v):
			var s: Dictionary = actor.statuses
			if s.has(status_key):
				s[status_key][turns_key] = v
				actor.statuses = s
		)
		row.add_child(turn_spin)

		var turn_lbl := Label.new()
		turn_lbl.text = "回合"
		turn_lbl.add_theme_font_size_override("font_size", 9)
		row.add_child(turn_lbl)

	return row


func _refresh_if_battle() -> void:
	if _battle and _battle.has_method("_refresh_enemy_display"):
		for ep in _battle.enemies:
			_battle._refresh_enemy_display(ep)


# ============================================================
# Tab Switching
# ============================================================

func _on_tab_changed(idx: int) -> void:
	_tab_meridian.visible = (idx == 0)
	_tab_cards.visible = (idx == 1)
	_tab_enemies.visible = (idx == 2)
	for i in range(_tab_btns.size()):
		_tab_btns[i].button_pressed = (i == idx)

	match idx:
		0: _refresh_node_list()
		1: _refresh_card_list()
		2: _refresh_enemy_list()


# ============================================================
# Meridian Callbacks
# ============================================================

func _save_snapshot() -> void:
	_snapshot.clear()
	var mer: MeridianMapData = GameManager.base_meridian
	if mer == null:
		return
	for node: MeridianNodeData in mer.nodes:
		if node == null:
			continue
		_snapshot[node.name] = {
			"unlocked": node.unlocked,
			"current_qi": node.current_qi,
			"properties": node.properties.duplicate(),
			"erosion_progress": node.erosion_progress,
		}


func _on_toggle_lock(idx: int, btn: Button) -> void:
	var mer: MeridianMapData = GameManager.base_meridian
	if mer == null:
		return
	var node: MeridianNodeData = mer.get_node(idx)
	if node == null:
		return
	node.unlocked = not node.unlocked
	btn.text = "🔓" if node.unlocked else "🔒"
	if _battle and _battle.has_method("_refresh_meridian_panel"):
		_battle._refresh_meridian_panel()


func _on_qi_changed(value: float, idx: int) -> void:
	var mer: MeridianMapData = GameManager.base_meridian
	if mer == null:
		return
	var node: MeridianNodeData = mer.get_node(idx)
	if node == null:
		return
	node.current_qi = float(value)
	if _battle and _battle.has_method("_refresh_meridian_panel"):
		_battle._refresh_meridian_panel()


func _on_select_prop_target(idx: int) -> void:
	_prop_target_node_idx = idx


func _on_prop_selected(_sel: int) -> void:
	var entry: Dictionary = _prop_list[_prop_dropdown.selected]
	_prop_param.visible = entry.get("has_param", false)


func _on_add_property() -> void:
	if _prop_target_node_idx < 0:
		return
	var mer: MeridianMapData = GameManager.base_meridian
	if mer == null:
		return
	var node: MeridianNodeData = mer.get_node(_prop_target_node_idx)
	if node == null:
		return

	var entry: Dictionary = _prop_list[_prop_dropdown.selected]
	var prop_key: String = entry["key"]
	var prop_str: String = prop_key
	if entry.get("has_param", false):
		prop_str = "%s:%d" % [prop_key, int(_prop_param.value)]

	if not node.properties.has(prop_str):
		node.properties.append(prop_str)
	_refresh_node_list()
	if _battle and _battle.has_method("_refresh_meridian_panel"):
		_battle._refresh_meridian_panel()


func _on_remove_property(idx: int, prop: String) -> void:
	var mer: MeridianMapData = GameManager.base_meridian
	if mer == null:
		return
	var node: MeridianNodeData = mer.get_node(idx)
	if node == null:
		return
	node.properties.erase(prop)
	_refresh_node_list()
	if _battle and _battle.has_method("_refresh_meridian_panel"):
		_battle._refresh_meridian_panel()


func _unlock_all() -> void:
	var mer: MeridianMapData = GameManager.base_meridian
	if mer == null:
		return
	for node in mer.nodes:
		if node:
			node.unlocked = true
	_refresh_node_list()
	if _battle and _battle.has_method("_refresh_meridian_panel"):
		_battle._refresh_meridian_panel()


func _fill_all_qi() -> void:
	var mer: MeridianMapData = GameManager.base_meridian
	if mer == null:
		return
	for node in mer.nodes:
		if node:
			node.current_qi = node.capacity
	_refresh_node_list()
	if _battle and _battle.has_method("_refresh_meridian_panel"):
		_battle._refresh_meridian_panel()


func _clear_all_props() -> void:
	var mer: MeridianMapData = GameManager.base_meridian
	if mer == null:
		return
	for node in mer.nodes:
		if node:
			node.properties.clear()
	_refresh_node_list()
	if _battle and _battle.has_method("_refresh_meridian_panel"):
		_battle._refresh_meridian_panel()


func _reset_all() -> void:
	var mer: MeridianMapData = GameManager.base_meridian
	if mer == null:
		return
	for node in mer.nodes:
		if node == null:
			continue
		var saved: Dictionary = _snapshot.get(node.name, {})
		if saved.is_empty():
			continue
		node.unlocked = saved.get("unlocked", true)
		node.current_qi = saved.get("current_qi", 0.0)
		node.properties = saved.get("properties", []).duplicate()
		node.erosion_progress = saved.get("erosion_progress", 0.0)
	_refresh_node_list()
	if _battle and _battle.has_method("_refresh_meridian_panel"):
		_battle._refresh_meridian_panel()


# ============================================================
# Card Callbacks
# ============================================================

func _on_add_card(card_id: String) -> void:
	if _battle == null:
		return
	var card: CardData = CardDatabase.get_card(card_id)
	if card == null:
		return

	# 直接加入手牌
	_battle.deck_manager.hand.append(card)
	if _battle.has_method("_refresh_hand_ui"):
		_battle._refresh_hand_ui()
	_refresh_card_list()


# ============================================================
# Enemy Callbacks
# ============================================================

func _on_kill_all_enemies() -> void:
	if _battle == null:
		return
	for actor: EnemyActor in _battle.enemies:
		actor.hp = 0
		if _battle.has_method("_refresh_enemy_display"):
			_battle._refresh_enemy_display(actor)
	_refresh_enemy_list()
	if _battle.has_method("_check_battle_end"):
		_battle._check_battle_end()


func _on_heal_all_enemies() -> void:
	if _battle == null:
		return
	for actor: EnemyActor in _battle.enemies:
		actor.hp = actor.max_hp
		actor.current_block = 0
		actor.statuses = {}
		actor.strength = 0
		if _battle.has_method("_refresh_enemy_display"):
			_battle._refresh_enemy_display(actor)
	_refresh_enemy_list()


# ============================================================
# Misc
# ============================================================

func _on_bg_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide()


func _build_property_options() -> Array[Dictionary]:
	return [
		{"key": "multi_target", "label": "multi_target (多目标)", "has_param": false},
		{"key": "apply_burn", "label": "apply_burn (灼烧)", "has_param": true},
		{"key": "apply_vulnerable", "label": "apply_vulnerable (易伤)", "has_param": true},
		{"key": "apply_weak", "label": "apply_weak (虚弱)", "has_param": true},
		{"key": "extra_draw", "label": "extra_draw (额外抽牌)", "has_param": true},
		{"key": "qi_efficiency", "label": "qi_efficiency (减费)", "has_param": true},
		{"key": "life_steal", "label": "life_steal (吸血)", "has_param": true},
		{"key": "reflect", "label": "reflect (反伤%)", "has_param": true},
		{"key": "pierce", "label": "pierce (穿透)", "has_param": true},
		{"key": "counter", "label": "counter (反击)", "has_param": true},
		{"key": "double_strike", "label": "double_strike (双重打击)", "has_param": false},
		{"key": "splash", "label": "splash (溅射)", "has_param": true},
	]
