# ============================================================
# 大周天 — Shop Screen (流浪商人)
# ============================================================
extends Control

const CARD_COST: Dictionary = {
	0: 30,   # BASIC
	1: 50,   # COMMON
	2: 80,   # UNCOMMON
	3: 120,  # RARE
}

var _shop_items: Array = []  # Array[Dictionary] - {type: "card"/"elixir", data: CardData, sold: bool}
var _heal_cost: int = 30
var _remove_card_cost: int = 50
var _gold_label: Label
var _heal_button: Button
var _remove_button: Button
var _remove_popup: Control
var _item_buttons: Dictionary = {}  # index -> Button


func _ready() -> void:
	_generate_shop_items()
	_build_ui()
	GameManager.gold_changed.connect(_update_gold)


func _generate_shop_items() -> void:
	# Try loading from ShopData if a current_shop_id is set on GameManager
	var shop_data: ShopData = null
	var shop_id_val: Variant = GameManager.get("current_shop_id")
	if shop_id_val != null and shop_id_val is String and not (shop_id_val as String).is_empty():
		var path: String = "res://resources/shop_data/%s.tres" % shop_id_val
		if ResourceLoader.exists(path):
			shop_data = load(path) as ShopData

	if shop_data != null:
		_heal_cost = shop_data.heal_cost
		_remove_card_cost = shop_data.remove_card_cost

		var card_pool: Array[String] = shop_data.card_pool.duplicate()
		card_pool.shuffle()
		var cards_to_take: int = min(shop_data.card_count, card_pool.size())
		for i in range(cards_to_take):
			var card: CardData = CardDatabase.get_card(card_pool[i])
			if card != null:
				_shop_items.append({"type": "card", "data": card, "sold": false})

		var elixir_pool: Array[String] = shop_data.elixir_pool.duplicate()
		elixir_pool.shuffle()
		var elixirs_to_take: int = min(shop_data.elixir_count, elixir_pool.size())
		for i in range(elixirs_to_take):
			var elixir: CardData = CardDatabase.get_card(elixir_pool[i])
			if elixir != null:
				_shop_items.append({"type": "elixir", "data": elixir, "sold": false})
	else:
		# Default shop: 3 random cards + 2 random elixirs
		var cards: Array[CardData] = CardDatabase.get_random_cards(3, GameManager.master_deck)
		for card in cards:
			_shop_items.append({"type": "card", "data": card, "sold": false})

		# Collect all ELIXIR-type cards
		var all_elixirs: Array[CardData] = []
		for c: CardData in CardDatabase.get_all_cards():
			if c != null and c.card_type == CardData.CardType.ELIXIR:
				all_elixirs.append(c)
		all_elixirs.shuffle()
		var elixir_count: int = min(2, all_elixirs.size())
		for i in range(elixir_count):
			_shop_items.append({"type": "elixir", "data": all_elixirs[i], "sold": false})


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = GameColors.BG_VOID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Scroll container for the whole content (in case items overflow)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	# Main VBox
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.custom_minimum_size.x = int(UIHelpers.vp_w(self) * 0.75)
	scroll.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "流浪商人"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GameColors.TEXT_TITLE)
	vbox.add_child(title)

	vbox.add_child(_spacer(10))

	# Gold display
	_gold_label = Label.new()
	_gold_label.text = "金币: %d" % GameManager.gold
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 22)
	_gold_label.add_theme_color_override("font_color", GameColors.TEXT_TITLE)
	vbox.add_child(_gold_label)

	vbox.add_child(_spacer(16))

	# Items header
	var items_header := Label.new()
	items_header.text = "—— 商品 ——"
	items_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	items_header.add_theme_font_size_override("font_size", 16)
	items_header.add_theme_color_override("font_color", GameColors.ACCENT_GOLD_DIM)
	vbox.add_child(items_header)

	vbox.add_child(_spacer(8))

	# Items grid (rows of up to 3)
	var items_grid := VBoxContainer.new()
	items_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(items_grid)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var count_in_row: int = 0
	for i in range(_shop_items.size()):
		var item_card := _create_item_card(_shop_items[i], i)
		row.add_child(item_card)
		row.add_child(_spacer(12, true))
		count_in_row += 1
		if count_in_row >= 3 and i < _shop_items.size() - 1:
			items_grid.add_child(row)
			items_grid.add_child(_spacer(12))
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			count_in_row = 0
	if count_in_row > 0:
		items_grid.add_child(row)

	vbox.add_child(_spacer(20))

	# Services header
	var services_header := Label.new()
	services_header.text = "—— 服务 ——"
	services_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	services_header.add_theme_font_size_override("font_size", 16)
	services_header.add_theme_color_override("font_color", GameColors.ACCENT_GOLD_DIM)
	vbox.add_child(services_header)

	vbox.add_child(_spacer(8))

	# Services VBox
	var services_vbox := VBoxContainer.new()
	services_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	services_vbox.add_theme_constant_override("separation", 10)
	vbox.add_child(services_vbox)

	# Heal button
	_heal_button = Button.new()
	_heal_button.text = "恢复 30%% HP (%d金)" % _heal_cost
	_heal_button.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.2, self)), float(UIHelpers.pct_h(0.06, self)))
	_heal_button.pressed.connect(_on_heal_pressed)
	services_vbox.add_child(_heal_button)

	# Remove card button
	_remove_button = Button.new()
	_remove_button.text = "移除一张卡牌 (%d金)" % _remove_card_cost
	_remove_button.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.2, self)), float(UIHelpers.pct_h(0.06, self)))
	_remove_button.pressed.connect(_on_remove_pressed)
	services_vbox.add_child(_remove_button)

	vbox.add_child(_spacer(24))

	# Leave button
	var leave_btn := Button.new()
	leave_btn.text = "离开"
	leave_btn.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.16, self)), float(UIHelpers.pct_h(0.06, self)))
	leave_btn.pressed.connect(_on_leave_pressed)
	vbox.add_child(leave_btn)

	vbox.add_child(_spacer(20))

	# Build the card-removal popup (hidden initially)
	_build_remove_popup()


func _build_remove_popup() -> void:
	_remove_popup = ColorRect.new()
	_remove_popup.color = GameColors.OVERLAY_DARK
	_remove_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_remove_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_remove_popup.visible = false
	add_child(_remove_popup)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.set_anchors_preset(Control.PRESET_CENTER)
	popup_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	popup_vbox.add_theme_constant_override("separation", 10)
	_remove_popup.add_child(popup_vbox)

	var popup_title := Label.new()
	popup_title.text = "选择要移除的卡牌"
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_title.add_theme_font_size_override("font_size", 22)
	popup_title.add_theme_color_override("font_color", GameColors.TEXT_TITLE)
	popup_vbox.add_child(popup_title)

	popup_vbox.add_child(_spacer(8))

	var deck: Array[String] = GameManager.master_deck
	if deck.is_empty():
		var empty_label := Label.new()
		empty_label.text = "牌组为空，无卡牌可移除"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
		popup_vbox.add_child(empty_label)
	else:
		# Group cards by ID for a cleaner list
		var card_counts: Dictionary = {}
		for card_id: String in deck:
			card_counts[card_id] = card_counts.get(card_id, 0) + 1

		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.5, self)), float(UIHelpers.pct_h(0.44, self)))
		popup_vbox.add_child(scroll)

		var card_list := VBoxContainer.new()
		card_list.alignment = BoxContainer.ALIGNMENT_CENTER
		card_list.add_theme_constant_override("separation", 6)
		scroll.add_child(card_list)

		for card_id: String in card_counts:
			var card_data: CardData = CardDatabase.get_card(card_id)
			if card_data == null:
				continue
			var count: int = card_counts[card_id]
			var card_hbox := HBoxContainer.new()
			card_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
			card_list.add_child(card_hbox)

			var name_label := Label.new()
			name_label.text = "%s (x%d)" % [card_data.display_name, count]
			name_label.custom_minimum_size.x = 190
			name_label.add_theme_color_override("font_color", Color.WHITE)
			card_hbox.add_child(name_label)

			var btn := Button.new()
			btn.text = "移除"
			btn.pressed.connect(_on_remove_card_selected.bind(card_id))
			card_hbox.add_child(btn)

	popup_vbox.add_child(_spacer(12))

	var close_btn := Button.new()
	close_btn.text = "取消"
	close_btn.custom_minimum_size.x = UIHelpers.pct_w(0.13, self)
	close_btn.pressed.connect(_on_close_remove_popup)
	popup_vbox.add_child(close_btn)


func _spacer(s: float, horiz: bool = false) -> Control:
	var c := Control.new()
	if horiz:
		c.custom_minimum_size.x = s
	else:
		c.custom_minimum_size.y = s
	return c


func _create_item_card(item: Dictionary, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.14, self)), float(UIHelpers.pct_h(0.25, self)))

	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.BG_CARD
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = GameColors.CARD_TECHNIQUE
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var card: CardData = item["data"]

	# Item-type badge
	var type_label := Label.new()
	if item["type"] == "elixir":
		type_label.text = "[丹药]"
	else:
		type_label.text = "[%s]" % card.get_type_name()
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.add_theme_color_override("font_color", GameColors.CARD_TECHNIQUE)
	vbox.add_child(type_label)

	# Item name
	var name_label := Label.new()
	name_label.text = card.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)

	# Description
	var desc_label := Label.new()
	desc_label.text = card.description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	vbox.add_child(desc_label)

	vbox.add_spacer(true)

	# Rarity name and price
	var rarity_names: Dictionary = {0: "凡品", 1: "良品", 2: "上品", 3: "极品"}
	var rarity_label := Label.new()
	rarity_label.text = rarity_names.get(card.rarity, "?")
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 10)
	rarity_label.add_theme_color_override("font_color", GameColors.BORDER_GOLD)
	vbox.add_child(rarity_label)

	# Price label
	var item_cost: int = CARD_COST.get(card.rarity, 50)
	var price_label := Label.new()
	price_label.text = "%d金" % item_cost
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 15)
	price_label.add_theme_color_override("font_color", GameColors.TEXT_TITLE)
	vbox.add_child(price_label)

	# Buy button
	var btn := Button.new()
	btn.text = "购买"
	btn.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.08, self)), float(UIHelpers.pct_h(0.042, self)))
	btn.pressed.connect(_on_buy_item.bind(index))
	vbox.add_child(btn)

	_item_buttons[index] = btn

	return panel


func _on_buy_item(index: int) -> void:
	if index < 0 or index >= _shop_items.size():
		return
	var item: Dictionary = _shop_items[index]
	if item["sold"]:
		return

	var card: CardData = item["data"]
	var item_cost: int = CARD_COST.get(card.rarity, 50)

	if GameManager.gold < item_cost:
		return

	GameManager.gold -= item_cost
	item["sold"] = true

	# Add to deck (elixirs are CardData with card_type=ELIXIR, same path)
	GameManager.add_card_to_deck(card.id)

	_update_gold()

	# Mark as sold visually
	var btn: Button = _item_buttons.get(index, null)
	if btn != null:
		btn.disabled = true
		btn.text = "已售"


func _on_heal_pressed() -> void:
	if GameManager.gold < _heal_cost:
		return
	GameManager.gold -= _heal_cost
	var heal_amount: int = int(GameManager.player_max_hp * 0.3)
	GameManager.heal(heal_amount)
	_update_gold()
	_heal_button.disabled = true
	_heal_button.text = "已购买"


func _on_remove_pressed() -> void:
	if GameManager.gold < _remove_card_cost:
		return
	# Rebuild popup to refresh card counts
	if _remove_popup:
		_remove_popup.queue_free()
	_build_remove_popup()
	_remove_popup.visible = true


func _on_remove_card_selected(card_id: String) -> void:
	if GameManager.gold < _remove_card_cost:
		_remove_popup.visible = false
		return
	GameManager.gold -= _remove_card_cost
	GameManager.remove_card(card_id)
	_update_gold()
	_remove_popup.visible = false
	_remove_button.disabled = true
	_remove_button.text = "已购买"


func _on_close_remove_popup() -> void:
	_remove_popup.visible = false


func _on_leave_pressed() -> void:
	SceneManager.switch_to_scene("res://scenes/chapter_map/chapter_map.tscn")


func _update_gold() -> void:
	_gold_label.text = "金币: %d" % GameManager.gold
