# ============================================================
# 大周天 — EnemyPresenter (敌人展示 — L0)
# 职责: 敌人面板创建、O(1) 刷新、点击事件、选择高亮
# 红线: 不调 controller (除 draw_cards 的薄包装)
# ============================================================
class_name EnemyPresenter
extends RefCounted

## 敌人容器
var enemy_container: HBoxContainer
## 敌人点击回调 (event: InputEvent, panel: PanelContainer) → void
var _on_clicked: Callable
## EnemyActor → PanelContainer 映射，避免 O(n) 容器扫描
var _enemy_panel_map: Dictionary = {}


## 注入依赖
func setup(p_enemy_container: HBoxContainer, p_on_clicked: Callable) -> void:
	enemy_container = p_enemy_container
	_on_clicked = p_on_clicked


## 创建敌人展示面板 — 内部创建 EnemyActor 并 add_child, 匹配原始 _create_enemy_display 行为
func create_enemy_display(data: EnemyData, screen_node: Node) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.11, screen_node)), float(UIHelpers.pct_h(0.18, screen_node)))

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var sprite := ColorRect.new()
	sprite.color = data.texture_color
	var sprite_sz: int = UIHelpers.pct_h(0.083, screen_node)
	sprite.custom_minimum_size = Vector2(float(sprite_sz), float(sprite_sz))
	vbox.add_child(sprite)

	var name_label := Label.new()
	name_label.text = data.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	name_label.add_theme_font_size_override("font_size", UIHelpers.scale_font(13, screen_node))
	vbox.add_child(name_label)

	var hp := PanelContainer.new()
	hp.name = "EnemyHP"
	hp.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.094, screen_node)), float(UIHelpers.pct_h(0.019, screen_node)))
	var hp_sc: GDScript = load("res://ui_components/health_bar.gd") as GDScript
	hp.set_script(hp_sc)
	hp.max_value = data.max_hp
	hp.current_value = data.max_hp
	vbox.add_child(hp)

	var block_label := Label.new()
	block_label.name = "EnemyBlock"
	block_label.text = ""
	block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block_label.add_theme_font_size_override("font_size", UIHelpers.pct_h(UIHelpers.FONT_TINY_PCT, screen_node))
	block_label.add_theme_color_override("font_color", GameColors.ACCENT_CERULEAN)
	vbox.add_child(block_label)

	var status_label := Label.new()
	status_label.name = "EnemyStatus"
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", UIHelpers.pct_h(UIHelpers.FONT_TINY_PCT, screen_node))
	status_label.add_theme_color_override("font_color", GameColors.ACCENT_CERULEAN)
	status_label.visible = false
	vbox.add_child(status_label)

	# 匹配原始顺序: 创建 EnemyActor → add_child → set_meta → 注册 map
	var enemy_actor := EnemyActor.new()
	enemy_actor.name = "EnemyActor_" + data.display_name
	enemy_actor.initialize_from_data(data)
	panel.add_child(enemy_actor)

	panel.set_meta("enemy_data", data)
	panel.set_meta("actor", enemy_actor)

	# 注册到 O(1) 查找表
	_enemy_panel_map[enemy_actor] = panel

	panel.gui_input.connect(_on_clicked.bind(panel))
	return panel


## 根据快照刷新所有敌人面板
func apply(snap: BattleSnapshot) -> void:
	for enemy_snap in snap.enemy_snapshots:
		var actor: EnemyActor = enemy_snap["actor"]
		var panel: PanelContainer = _enemy_panel_map.get(actor) as PanelContainer
		if panel == null:
			continue

		var current_hp: int = enemy_snap["hp"]
		var current_block: int = enemy_snap["current_block"]
		var statuses: Dictionary = enemy_snap["statuses"]

		for vbox_child in panel.get_children():
			if vbox_child is VBoxContainer:
				for c in vbox_child.get_children():
					if c.name == "EnemyHP" and c.has_method("set_values"):
						c.current_value = current_hp
					elif c.name == "EnemyBlock":
						if current_block > 0:
							c.text = "格挡 " + str(current_block)
							c.visible = true
						else:
							c.text = ""
							c.visible = false
					elif c.name == "EnemyStatus":
						var status_text: String = ""
						if statuses.has("burn"):
							var burn: Dictionary = statuses["burn"]
							status_text += "[火]" + str(burn["damage"]) + "(" + str(burn["turns"]) + ")"
						if statuses.has("vulnerable"):
							var vuln_turns: int = statuses["vulnerable"]["turns"]
							status_text += " [弱]" + str(vuln_turns)
						if statuses.has("weak"):
							var weak: Dictionary = statuses["weak"]
							status_text += " [虚]" + str(weak["amount"]) + "(" + str(weak["turns"]) + ")"
						c.text = status_text
						c.visible = not status_text.is_empty()
				break


## 高亮可选敌人（TargetManager 选择时调用）
func highlight_valid(valid_targets: Array) -> void:
	# 先全部变暗
	for panel: PanelContainer in _enemy_panel_map.values():
		panel.self_modulate = Color(0.5, 0.5, 0.5, 1.0)
	# 合法目标高亮
	for target in valid_targets:
		var actor: Node = target.get("actor")
		if actor and _enemy_panel_map.has(actor):
			var panel = _enemy_panel_map[actor]
			panel.self_modulate = Color(1.0, 1.0, 0.6, 1.0)  # 淡金色高亮


## 清除敌人高亮
func clear_highlight() -> void:
	for panel: PanelContainer in _enemy_panel_map.values():
		panel.self_modulate = Color.WHITE


## 清空所有敌人面板
func clear_displays() -> void:
	for child in enemy_container.get_children():
		enemy_container.remove_child(child)
		child.queue_free()
	_enemy_panel_map.clear()


## 抽牌 — 委托给 DeckManager，结果由外部刷新 UI
func draw_cards(count: int, deck_manager: DeckManager) -> void:
	if deck_manager:
		deck_manager.draw_cards(count)
