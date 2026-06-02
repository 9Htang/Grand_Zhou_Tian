# ============================================================
# 大周天 — Reward Screen (奖励选择)
# ============================================================
extends Control

var _rewards: Array = []  # Array[Dictionary]


func _ready() -> void:
	_generate_rewards()
	_build_ui()


func _generate_rewards() -> void:
	# Card reward
	var cards := CardDatabase.get_random_cards(3, GameManager.master_deck)
	for card in cards:
		_rewards.append({"type": "card", "data": card, "text": "新卡牌: %s" % card.display_name})

	# Heal
	_rewards.append({"type": "heal", "amount": 15, "text": "恢复 15 HP"})

	# Gold
	_rewards.append({"type": "gold", "amount": 20, "text": "获得 20 金币"})

	_rewards.shuffle()
	_rewards = _rewards.slice(0, 3)


func _build_ui() -> void:

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	var title := Label.new()
	title.text = "选择奖励"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UIHelpers.font_title(self))
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	vbox.add_child(title)

	vbox.add_child(_spacer(UIHelpers.gap_medium(self)))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	for reward in _rewards:
		var card := _create_reward_card(reward)
		row.add_child(card)
		row.add_child(_spacer(UIHelpers.pct_w(0.013, self), true))


func _spacer(s: float, horiz: bool = false) -> Control:
	var c := Control.new()
	if horiz: c.custom_minimum_size.x = s
	else: c.custom_minimum_size.y = s
	return c


func _create_reward_card(reward: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.14, self)), float(UIHelpers.pct_h(0.28, self)))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = reward["text"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)

	vbox.add_spacer(true)

	var btn := Button.new()
	btn.text = "选择"
	btn.custom_minimum_size.y = UIHelpers.pct_h(0.05, self)
	btn.pressed.connect(_on_select.bind(reward))
	vbox.add_child(btn)

	return panel


func _on_select(reward: Dictionary) -> void:
	match reward["type"]:
		"card":
			GameManager.add_card_to_deck(reward["data"].id)
		"heal":
			GameManager.heal(reward["amount"])
		"gold":
			GameManager.gold += reward["amount"]

	SceneManager.switch_to_scene("res://scenes/chapter_map/chapter_map.tscn")
