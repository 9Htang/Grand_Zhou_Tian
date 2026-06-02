# ============================================================
# 大周天 — BattleScreen (战斗 UI 壳)
# ============================================================
# 职责: UI构建、刷新、输入事件、sandbox
# 逻辑委托给 BattleController，状态管理委托给 EnemyStatusSystem
# ============================================================
extends CanvasLayer

# === UI Nodes ===
@onready var enemy_container: HBoxContainer
@onready var meridian_panel: Panel
@onready var technique_area: HBoxContainer
@onready var buffs_bar: HBoxContainer
@onready var hand_area: HBoxContainer
@onready var end_turn_btn: Button
@onready var player_hp_bar: Control
@onready var player_qi_bar: Control
@onready var realm_label: Label
@onready var deck_info: Label
@onready var turn_label: Label

# === Battle Controller (流程编排) ===
var controller: BattleController

# === Core References ===
var player_actor: PlayerActor
var deck_manager: DeckManager  # shortcut for UI queries
var fsm: BattleStateMachine

# === State ===
var _animating: bool = false
var sandbox_panel: CanvasLayer
var _sandbox_enabled: bool = false  # 设为 true 开启调试面板（` 键呼出）

var _dragged_card: CardData = null
var _is_technique_highlighted: bool = false

# Backward-compatible proxies for CardEffects (expects Node with .enemies + .get_target_enemy())
var enemies: Array[EnemyActor]:
	get: return controller.enemies


func get_target_enemy() -> EnemyActor:
	return controller.get_target_enemy()


# Shortcut to player actor for backward-compatible system calls
func _gm() -> Node:
	return player_actor


# ============================================================
# Ready
# ============================================================

func _ready() -> void:
	add_to_group("battle_screen")

	# Create and populate player actor from GameManager
	player_actor = PlayerActor.new()
	player_actor.name = "PlayerActor"
	add_child(player_actor)
	player_actor.load_from_gm()
	# Ensure meridian starts clean
	_reset_meridian_for_battle()

	_build_layout()

	# Sandbox debug panel (only when enabled)
	if _sandbox_enabled:
		var sp_sc: GDScript = load("res://ui_components/sandbox_panel.gd") as GDScript
		sandbox_panel = CanvasLayer.new()
		sandbox_panel.set_script(sp_sc)
		sandbox_panel.name = "SandboxPanel"
		sandbox_panel.init(self)
		add_child(sandbox_panel)

	# Create controller (orchestrates turn flow + system calls)
	controller = BattleController.new()
	controller.initialize(self, player_actor, fsm)

	_connect_signals()
	_start_battle()


# ============================================================
# Battle Start
# ============================================================

func _start_battle() -> void:
	if not controller.start_battle():
		return

	deck_manager = controller.deck_manager
	_spawn_enemies()

	_update_all_ui()

	fsm.transition_to(BattleStateMachine.BattleState.PRE_BATTLE)
	await get_tree().create_timer(0.3).timeout
	fsm.transition_to(BattleStateMachine.BattleState.TURN_START)


func _load_encounter() -> EncounterData:
	# Delegated to controller — kept here only for _spawn_enemies reference
	return controller.current_encounter


func _spawn_enemies() -> void:
	for child in enemy_container.get_children():
		enemy_container.remove_child(child)
		child.queue_free()
	controller.enemies.clear()

	for enemy_id: String in controller.current_encounter.enemy_ids:
		var data: EnemyData = EnemyDatabase.get_enemy(enemy_id)
		if data == null:
			continue
		var display: Control = _create_enemy_display(data)
		enemy_container.add_child(display)
		var actor: EnemyActor = display.get_meta("actor")
		if actor:
			controller.enemies.append(actor)


# ============================================================
# Layout / UI Construction
# ============================================================

func _build_layout() -> void:
	# === Adaptive sizing (viewport-relative) ===
	var top_h: int = UIHelpers.pct_h(UIHelpers.TOP_BAR_PCT, self)
	var enemy_h: int = UIHelpers.pct_h(UIHelpers.ENEMY_AREA_PCT, self)
	var meridian_h: int = UIHelpers.pct_h(UIHelpers.MERIDIAN_AREA_PCT, self)
	var tech_h: int = UIHelpers.pct_h(UIHelpers.TECH_AREA_PCT, self)
	var buffs_h: int = UIHelpers.pct_h(UIHelpers.BUFFS_PCT, self)
	var player_h: int = UIHelpers.pct_h(UIHelpers.PLAYER_AREA_PCT, self)
	var hand_h: int = UIHelpers.pct_h(UIHelpers.HAND_AREA_PCT, self)
	var btn_h: int = max(28, int(float(hand_h) * 0.15))
	var hp_bar_w: int = UIHelpers.pct_w(0.11, self)
	var hp_bar_h: int = max(16, int(float(player_h) * 0.7))
	var meridian_panel_w: int = UIHelpers.pct_w(0.55, self)
	var meridian_panel_h: int = max(140, meridian_h - 20)
	var sandbox_btn_sz: Vector2 = Vector2(float(max(24, int(float(top_h) * 0.8))), float(top_h))

	# Root control fills the screen
	var root := Control.new()
	root.name = "Layout"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background ambiance
	var ambiance_sc: GDScript = load("res://ui_components/background_ambiance.gd") as GDScript
	var ambiance := Control.new()
	ambiance.set_script(ambiance_sc)
	ambiance.name = "BackgroundAmbiance"
	root.add_child(ambiance)

	# Main VBox layout
	var vbox := VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(vbox)
	add_child(root)

	# === Top Bar ===
	var top := HBoxContainer.new()
	top.name = "TopBar"
	top.custom_minimum_size.y = top_h

	turn_label = Label.new()
	turn_label.name = "TurnLabel"
	turn_label.text = "战斗开始"
	turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_label.add_theme_color_override("font_color", GameColors.TEXT_TITLE)
	turn_label.add_theme_font_size_override("font_size", UIHelpers.scale_font(16, self))
	top.add_child(turn_label)

	var wrench_btn := Button.new()
	wrench_btn.name = "SandboxBtn"
	wrench_btn.text = "🔧"
	wrench_btn.flat = true
	wrench_btn.custom_minimum_size = sandbox_btn_sz
	wrench_btn.pressed.connect(_toggle_sandbox)
	wrench_btn.visible = _sandbox_enabled
	top.add_child(wrench_btn)

	vbox.add_child(top)

	# === Enemy Area ===
	var enemy_area := MarginContainer.new()
	enemy_area.name = "EnemyArea"
	enemy_area.custom_minimum_size.y = enemy_h
	enemy_container = HBoxContainer.new()
	enemy_container.name = "EnemyContainer"
	enemy_container.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_area.add_child(enemy_container)
	vbox.add_child(enemy_area)

	# === Meridian Area ===
	var meridian_area := MarginContainer.new()
	meridian_area.name = "MeridianArea"
	meridian_area.custom_minimum_size.y = meridian_h
	meridian_panel = Panel.new()
	meridian_panel.name = "MeridianPanel"
	meridian_panel.custom_minimum_size = Vector2(float(meridian_panel_w), float(meridian_panel_h))
	var mv_sc: GDScript = load("res://ui_components/meridian_view.gd") as GDScript
	meridian_panel.set_script(mv_sc)
	meridian_area.add_child(meridian_panel)
	vbox.add_child(meridian_area)

	# === Technique Area ===
	var tech_area := MarginContainer.new()
	tech_area.name = "TechniqueArea"
	tech_area.custom_minimum_size.y = tech_h
	tech_area.add_theme_constant_override("margin_left", UIHelpers.pad_h(self))
	tech_area.add_theme_constant_override("margin_right", UIHelpers.pad_h(self))
	var tech_label := Label.new()
	tech_label.text = "⚡ 活跃功法"
	tech_label.add_theme_color_override("font_color", GameColors.ACCENT_GOLD_DIM)
	tech_label.add_theme_font_size_override("font_size", UIHelpers.scale_font(12, self))
	tech_area.add_child(tech_label)
	technique_area = HBoxContainer.new()
	technique_area.name = "TechniqueContainer"
	technique_area.add_theme_constant_override("separation", UIHelpers.gap_small(self))
	tech_area.add_child(technique_area)
	vbox.add_child(tech_area)

	# === Buffs Bar ===
	var buffs := MarginContainer.new()
	buffs.name = "BuffsBar"
	buffs.custom_minimum_size.y = buffs_h
	buffs.add_theme_constant_override("margin_left", UIHelpers.pad_h(self))
	buffs.add_theme_constant_override("margin_right", UIHelpers.pad_h(self))
	buffs_bar = HBoxContainer.new()
	buffs_bar.name = "BuffsContainer"
	buffs_bar.add_theme_constant_override("separation", UIHelpers.gap_small(self))
	buffs.add_child(buffs_bar)
	vbox.add_child(buffs)

	# === Player Area ===
	var player_area := HBoxContainer.new()
	player_area.name = "PlayerArea"
	player_area.custom_minimum_size.y = player_h
	player_area.add_theme_constant_override("separation", UIHelpers.gap_small(self))
	player_area.add_theme_constant_override("margin_left", UIHelpers.pad_h(self))
	player_area.add_theme_constant_override("margin_right", UIHelpers.pad_h(self))
	player_hp_bar = _create_health_bar(hp_bar_w, hp_bar_h)
	player_qi_bar = _create_qi_bar(hp_bar_w, hp_bar_h)
	realm_label = Label.new()
	realm_label.name = "RealmLabel"
	realm_label.add_theme_color_override("font_color", GameColors.TEXT_TITLE)
	realm_label.add_theme_font_size_override("font_size", UIHelpers.scale_font(14, self))
	deck_info = Label.new()
	deck_info.name = "DeckInfo"
	deck_info.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	deck_info.add_theme_font_size_override("font_size", UIHelpers.scale_font(12, self))
	player_area.add_child(player_hp_bar)
	player_area.add_child(player_qi_bar)
	player_area.add_child(realm_label)
	player_area.add_child(deck_info)
	vbox.add_child(player_area)

	# === Hand Area ===
	var hand_area_container := MarginContainer.new()
	hand_area_container.name = "HandArea"
	hand_area_container.custom_minimum_size.y = hand_h
	hand_area_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_area_container.add_theme_constant_override("margin_left", UIHelpers.pad_h(self))
	hand_area_container.add_theme_constant_override("margin_right", UIHelpers.pad_h(self))
	var hand_vbox := VBoxContainer.new()
	hand_area = HBoxContainer.new()
	hand_area.name = "HandContainer"
	hand_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_area.add_theme_constant_override("separation", UIHelpers.gap_small(self))
	hand_vbox.add_child(hand_area)
	end_turn_btn = Button.new()
	end_turn_btn.name = "EndTurnButton"
	end_turn_btn.text = "═ 结束回合 ═"
	end_turn_btn.custom_minimum_size.y = btn_h
	end_turn_btn.flat = true
	var et_sb := StyleBoxFlat.new()
	et_sb.bg_color = GameColors.BG_PANEL
	et_sb.border_width_left = 1; et_sb.border_width_right = 1
	et_sb.border_width_top = 1; et_sb.border_width_bottom = 1
	et_sb.border_color = GameColors.BORDER_GOLD
	et_sb.corner_radius_top_left = 6; et_sb.corner_radius_top_right = 6
	et_sb.corner_radius_bottom_left = 6; et_sb.corner_radius_bottom_right = 6
	end_turn_btn.add_theme_stylebox_override("normal", et_sb)
	end_turn_btn.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	end_turn_btn.add_theme_font_size_override("font_size", UIHelpers.scale_font(15, self))
	hand_vbox.add_child(end_turn_btn)
	hand_area_container.add_child(hand_vbox)
	vbox.add_child(hand_area_container)

	fsm = BattleStateMachine.new()
	fsm.name = "BattleStateMachine"
	add_child(fsm)


func _create_health_bar(w: int, h: int) -> Control:
	var bar := PanelContainer.new()
	bar.name = "HPBar"
	bar.custom_minimum_size = Vector2(float(w), float(h))
	var sc: GDScript = load("res://ui_components/health_bar.gd")
	bar.set_script(sc)
	bar.max_value = player_actor.max_hp
	bar.current_value = player_actor.hp
	return bar


func _create_qi_bar(w: int, h: int) -> Control:
	var bar := PanelContainer.new()
	bar.name = "QiBar"
	bar.custom_minimum_size = Vector2(float(w), float(h))
	var sc: GDScript = load("res://ui_components/qi_bar.gd")
	bar.set_script(sc)
	return bar


func _create_enemy_display(data: EnemyData) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.11, self)), float(UIHelpers.pct_h(0.18, self)))

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var sprite := ColorRect.new()
	sprite.color = data.texture_color
	var sprite_sz: int = UIHelpers.pct_h(0.083, self)
	sprite.custom_minimum_size = Vector2(float(sprite_sz), float(sprite_sz))
	vbox.add_child(sprite)

	var name_label := Label.new()
	name_label.text = data.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	name_label.add_theme_font_size_override("font_size", UIHelpers.scale_font(13, self))
	vbox.add_child(name_label)

	var hp := PanelContainer.new()
	hp.name = "EnemyHP"
	hp.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.094, self)), float(UIHelpers.pct_h(0.019, self)))
	var hp_sc: GDScript = load("res://ui_components/health_bar.gd") as GDScript
	hp.set_script(hp_sc)
	hp.max_value = data.max_hp
	hp.current_value = data.max_hp
	vbox.add_child(hp)

	var block_label := Label.new()
	block_label.name = "EnemyBlock"
	block_label.text = ""
	block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block_label.add_theme_font_size_override("font_size", UIHelpers.pct_h(UIHelpers.FONT_TINY_PCT, self))
	block_label.add_theme_color_override("font_color", GameColors.ACCENT_CERULEAN)
	vbox.add_child(block_label)

	var status_label := Label.new()
	status_label.name = "EnemyStatus"
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", UIHelpers.pct_h(UIHelpers.FONT_TINY_PCT, self))
	status_label.add_theme_color_override("font_color", GameColors.ACCENT_CERULEAN)
	status_label.visible = false
	vbox.add_child(status_label)

	panel.set_meta("enemy_data", data)

	var enemy_actor := EnemyActor.new()
	enemy_actor.name = "EnemyActor_" + data.display_name
	enemy_actor.initialize_from_data(data)
	panel.add_child(enemy_actor)
	panel.set_meta("actor", enemy_actor)

	panel.gui_input.connect(_on_enemy_clicked.bind(panel))
	return panel


# ============================================================
# Signal Connections
# ============================================================

func _connect_signals() -> void:
	fsm.state_changed.connect(_on_state_changed)
	fsm.turn_start.connect(_on_turn_start)
	fsm.qi_circulation_start.connect(_on_qi_circulation)
	fsm.player_turn_start.connect(_on_player_turn)
	fsm.enemy_turn_start.connect(_on_enemy_turn)
	fsm.enemy_qi_circulation_start.connect(_on_enemy_qi_circulation)
	fsm.battle_won.connect(_on_battle_won)
	fsm.battle_lost.connect(_on_battle_lost)
	fsm.turn_end.connect(_on_turn_end)
	end_turn_btn.pressed.connect(_on_end_turn)
	meridian_panel.node_clicked.connect(_on_node_info)
	meridian_panel.node_double_clicked.connect(_on_erosion_toggle)
	player_actor.hp_changed.connect(_update_hp)
	player_actor.qi_changed.connect(_update_qi)
	player_actor.buffs_updated.connect(_update_buffs)
	player_actor.technique_activated.connect(_on_technique_changed)
	player_actor.technique_deactivated.connect(_on_technique_changed)

	# TargetManager signals
	if controller and controller.target_manager:
		controller.target_manager.selection_started.connect(_on_target_selection_started)
		controller.target_manager.selection_completed.connect(_on_target_selection_completed)
		controller.target_manager.selection_cancelled.connect(_on_target_selection_cancelled)


# ============================================================
# FSM Handlers (thin wrappers — logic in BattleController)
# ============================================================

func _on_state_changed(_from: int, to: int) -> void:
	turn_label.text = "阶段: " + fsm.get_state_name(to)


func _on_turn_start() -> void:
	controller.execute_turn_start()
	_update_all_ui()


func _on_player_turn() -> void:
	controller.execute_player_turn()
	_refresh_hand_ui()
	_update_all_ui()


func _on_qi_circulation() -> void:
	_animating = true
	var log_text: String = controller.execute_qi_circulation()
	if not log_text.is_empty():
		turn_label.text = log_text
	_refresh_meridian_panel()
	_animating = false
	# Transition handled by controller (now at ENEMY_TURN)


func _on_enemy_turn() -> void:
	var actions_log: String = controller.execute_enemy_turn()
	turn_label.text = "敌人行动: " + actions_log
	_update_all_ui()
	# Refresh all enemy displays
	for enemy in controller.enemies:
		_refresh_enemy_display(enemy, enemy_container)
	fsm.transition_to(BattleStateMachine.BattleState.ENEMY_ACTION)
	await get_tree().create_timer(1.0).timeout
	fsm.transition_to(BattleStateMachine.BattleState.ENEMY_QI_CIRCULATION)


func _on_enemy_qi_circulation() -> void:
	controller.execute_enemy_qi_circulation()


func _on_turn_end() -> void:
	var result: Dictionary = controller.execute_turn_end()
	var state: String = result.get("state", "continue")

	if state == "won":
		return  # BATTLE_WON transition already done by controller
	if state == "lost":
		return  # BATTLE_LOST transition already done by controller

	# Process enemy statuses at turn end (UI-coupled: needs _refresh_enemy_display)
	var status_log: String = EnemyStatusSystem.tick_all(controller.enemies)
	# Guard: if battle ended during status processing, stop
	if fsm.current_state == BattleStateMachine.BattleState.BATTLE_WON or fsm.current_state == BattleStateMachine.BattleState.BATTLE_LOST:
		return
	if not status_log.is_empty():
		turn_label.text = "状态: " + status_log

	# Consume pending effects
	var pending: Array = result.get("pending_effects", [])
	for effect in pending:
		match effect["type"]:
			"burn":
				for enemy in controller.enemies:
					EnemyStatusSystem.apply(enemy, "burn:" + str(effect["value"]) + ":2")
					_refresh_enemy_display(enemy, enemy_container)
			"draw_card":
				_refresh_hand_ui()

	# Refresh enemy displays after status processing
	for enemy in controller.enemies:
		_refresh_enemy_display(enemy, enemy_container)

	# Check for dead enemies from status processing
	_check_battle_end_display()

	_update_all_ui()
	# FSM transition to TURN_START happens here — after ALL turn-end processing is done
	fsm.transition_to(BattleStateMachine.BattleState.TURN_START)


func _on_battle_won() -> void:
	var result: Dictionary = controller.execute_battle_won()
	if result.get("is_boss", false):
		SceneManager.go_to_reward()
	else:
		SceneManager.go_to_map()


func _on_battle_lost() -> void:
	controller.execute_battle_lost()
	SceneManager.go_to_game_over(false)


func _on_end_turn() -> void:
	if _animating:
		return
	fsm.transition_to(BattleStateMachine.BattleState.QI_CIRCULATION)


# ============================================================
# Card Play / Drag (UI input → controller delegation)
# ============================================================

func _on_card_clicked(card_data: CardData) -> void:
	if _animating:
		return

	var result: Dictionary = controller.play_card(card_data)

	if not result.get("played", false):
		return

	# 功法卡进入路径选择模式 → 高亮可用起点，等待穴位点击
	if result.get("awaiting_pathway", false):
		_highlight_available_start_nodes()
		turn_label.text = "选择经脉路径: 先点击起点穴位"
		return

	# UI refresh
	var target: EnemyActor = controller.get_target_enemy()
	if target:
		_refresh_enemy_display(target, enemy_container)
	_refresh_hand_ui()
	_update_all_ui()
	_check_battle_end_display()


func _on_card_drag_started(card_data: CardData) -> void:
	_dragged_card = card_data


func _on_card_drag_ended(card_data: CardData, _drop_area: String) -> void:
	_set_technique_highlight(false)
	var handled := false
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	# 1. Check technique area drop
	var tech_parent: MarginContainer = technique_area.get_parent() as MarginContainer
	if tech_parent and tech_parent.get_global_rect().has_point(mouse_pos):
		if card_data.card_type == CardData.CardType.TECHNIQUE:
			var result: Dictionary = controller.activate_technique_via_card(card_data)
			if result.get("success", false):
				_refresh_hand_ui()
				_update_all_ui()
		handled = true

	# 2. Check discard zone (below hand area)
	if not handled:
		var hand_rect: Rect2 = hand_area.get_global_rect()
		if mouse_pos.y > hand_rect.position.y + hand_rect.size.y + 50:
			if deck_manager.hand.has(card_data):
				deck_manager.play_card(card_data)
				deck_manager.draw_cards(1)
				_refresh_hand_ui()
			handled = true

	# 3. Invalid drop - snap back
	if not handled:
		_refresh_hand_ui()

	_dragged_card = null


func _on_technique_changed(_tech: TechniqueData) -> void:
	_refresh_technique_area()


func _on_technique_clicked(event: InputEvent, tech: TechniqueData) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if controller.cancel_technique(tech):
			_refresh_hand_ui()
			_update_all_ui()


# ============================================================
# Meridian Interaction
# ============================================================

## Single click acupoint → target selection OR pathway selection OR info popup
func _on_node_info(idx: int, node: MeridianNodeData) -> void:
	# TargetManager 选择模式下 → 提交节点目标
	if controller.target_manager and controller.target_manager.is_selecting():
		var sel_type: String = controller.target_manager.pending_selector.get("type", "")
		var target: Dictionary = {}
		match sel_type:
			"node":
				target = {"idx": idx, "name": node.name, "unlocked": node.unlocked}
			"path":
				# 路径选择需要两个点击 — 交由旧 flow 处理
				pass
		if not target.is_empty():
			controller.target_manager.submit_target(target)
		return

	# 功法路径选择模式下 → 节点点击 = 选路径
	if controller.pending_technique_card != null:
		var sel_result: int = controller.select_pathway_node(idx)
		match sel_result:
			-1:  # 无效选择
				pass
			0:   # 已选起点，等待终点
				_highlight_available_end_nodes()
				turn_label.text = "选择经脉路径: 再点击终点穴位"
			1:   # 完成绑定
				_clear_pathway_highlights()
				turn_label.text = "功法已挂载"
				_refresh_hand_ui()
				_refresh_technique_area()
				_update_all_ui()
		return

	# 正常模式 → 显示穴位信息弹窗
	for child in get_children():
		if child is CanvasLayer and child.name.begins_with("NodeInfo_"):
			child.queue_free()
	var popup := CanvasLayer.new()
	var sc: GDScript = load("res://ui_components/node_info_popup.gd") as GDScript
	popup.set_script(sc)
	popup.name = "NodeInfo_" + str(idx)
	add_child(popup)
	popup.show_info(idx, node)


## Double click acupoint → toggle erosion target
func _on_erosion_toggle(idx: int, node: MeridianNodeData) -> void:
	if node.unlocked:
		return

	var adjacent_unlocked := false
	for conn in node.connections:
		var cn: MeridianNodeData = player_actor.base_meridian.get_node(conn)
		if cn and cn.unlocked:
			adjacent_unlocked = true
			break
	if not adjacent_unlocked:
		return

	player_actor.toggle_erosion_target(idx)
	_refresh_meridian_panel()


## Called by BattleController when a node unlocks during qi circulation
func notify_node_unlocked(idx: int) -> void:
	if meridian_panel and meridian_panel.has_method("notify_node_unlocked"):
		meridian_panel.notify_node_unlocked(idx)


## 高亮所有可用的起点穴位（丹田邻接、已解锁、未阻塞）
func _highlight_available_start_nodes() -> void:
	if not meridian_panel or not meridian_panel.has_method("set_pathway_highlights"):
		return
	var nodes: Array[int] = player_actor.get_dantian_adjacent_nodes()
	meridian_panel.set_pathway_highlights(nodes, [])  # 起点高亮，终点无


## 高亮所有可用的终点穴位（除起点外的任意已解锁穴位）
func _highlight_available_end_nodes() -> void:
	if not meridian_panel or not meridian_panel.has_method("set_pathway_highlights"):
		return
	var from_idx: int = controller.pathway_selection_from
	if from_idx < 0:
		return
	var mer: MeridianMapData = player_actor.base_meridian
	if mer == null:
		return
	var end_nodes: Array[int] = []
	for i: int in mer.nodes.size():
		var node: MeridianNodeData = mer.nodes[i]
		if node and node.unlocked and not node.blocked and i != from_idx:
			end_nodes.append(i)
	meridian_panel.set_pathway_highlights([from_idx], end_nodes)


## 清除所有路径选择高亮
func _clear_pathway_highlights() -> void:
	if meridian_panel and meridian_panel.has_method("clear_pathway_highlights"):
		meridian_panel.clear_pathway_highlights()


# ============================================================
# TargetManager Handlers
# ============================================================


## TargetManager 发起选择 → 高亮合法目标
func _on_target_selection_started(selector: Dictionary, valid_targets: Array) -> void:
	var stype: String = selector.get("type", "")
	match stype:
		"node":
			var indices: Array[int] = []
			for t in valid_targets:
				var idx: int = t.get("idx", -1)
				if idx >= 0:
					indices.append(idx)
			if meridian_panel and meridian_panel.has_method("set_pathway_highlights"):
				meridian_panel.set_pathway_highlights(indices, [])
			turn_label.text = "选择目标穴位 (%d个可选)" % indices.size()
		"path":
			var from_nodes: Array[int] = []
			var to_nodes: Array[int] = []
			for t in valid_targets:
				from_nodes.append(t.get("from", -1))
				to_nodes.append(t.get("to", -1))
			if meridian_panel and meridian_panel.has_method("set_pathway_highlights"):
				meridian_panel.set_pathway_highlights(from_nodes, to_nodes)
			turn_label.text = "选择目标经脉路径 (%d条可选)" % valid_targets.size()
		_:
			turn_label.text = "选择目标 (%s)" % stype


func _on_target_selection_completed(_selector: Dictionary, _selected: Array) -> void:
	_clear_pathway_highlights()
	turn_label.text = ""


func _on_target_selection_cancelled() -> void:
	_clear_pathway_highlights()
	turn_label.text = ""
	if controller:
		controller._pending_runtime = null
		controller._pending_battle_ctx = null


## Resolver 执行完成后刷新 UI
func _on_effect_execution_done(_result: Dictionary) -> void:
	_refresh_hand_ui()
	_update_all_ui()
	controller.check_battle_end()


# ============================================================
# UI Refresh
# ============================================================

func _update_all_ui() -> void:
	_update_hp(player_actor.hp, player_actor.max_hp)
	_update_qi(player_actor.dantian_qi, player_actor.dantian_capacity)
	_update_buffs(player_actor.active_buffs)
	realm_label.text = "境界: " + str(player_actor.realm)
	if deck_manager:
		deck_info.text = "牌库:" + str(deck_manager.get_draw_pile_count()) + " 弃牌:" + str(deck_manager.get_discard_count())
	_refresh_technique_area()
	_refresh_meridian_panel()


func _update_hp(_hp: int, _max: int) -> void:
	if player_hp_bar:
		player_hp_bar.set_values(player_actor.hp, player_actor.max_hp)


func _update_qi(_qi: int, _max: int) -> void:
	if player_qi_bar:
		player_qi_bar.set_values(player_actor.dantian_qi, player_actor.dantian_capacity, player_actor.qi_gather_rate)


const DEBUFF_NAMES := ["burn", "vulnerable", "weak", "self_damage", "energy_down", "poison"]

func _update_buffs(buffs: Array) -> void:
	for child in buffs_bar.get_children():
		buffs_bar.remove_child(child)
		child.queue_free()
	for buff in buffs:
		var icon := PanelContainer.new()
		icon.name = "BuffIcon"
		var sc: GDScript = load("res://ui_components/buff_icon.gd")
		icon.set_script(sc)
		var is_pos: bool = not (buff.name in DEBUFF_NAMES)
		icon.setup(buff.name, buff.value, is_pos)
		buffs_bar.add_child(icon)


func _refresh_hand_ui() -> void:
	if deck_manager == null:
		return
	for child in hand_area.get_children():
		hand_area.remove_child(child)
		child.queue_free()

	var gm: Node = _gm()
	for card: CardData in deck_manager.hand:
		var card_ui := PanelContainer.new()
		var sc: GDScript = load("res://scenes/card/card_ui.gd")
		card_ui.set_script(sc)
		card_ui.card_data = card
		card_ui.set_playable((_sandbox_enabled and sandbox_panel != null and sandbox_panel.is_infinite_qi()) or QiPoolManager.can_afford(gm, card.cost))
		card_ui.card_clicked.connect(_on_card_clicked)
		card_ui.card_drag_started.connect(_on_card_drag_started)
		card_ui.card_drag_ended.connect(_on_card_drag_ended)
		hand_area.add_child(card_ui)


func _process(_delta: float) -> void:
	if _dragged_card != null and _dragged_card.card_type == CardData.CardType.TECHNIQUE:
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var tech_parent = technique_area.get_parent()
		var over: bool = tech_parent.get_global_rect().has_point(mouse_pos)
		_set_technique_highlight(over)
	else:
		_set_technique_highlight(false)


func _set_technique_highlight(active: bool) -> void:
	if active == _is_technique_highlighted:
		return
	_is_technique_highlighted = active
	if active:
		technique_area.modulate = GameColors.ACCENT_GOLD_BRIGHT
	else:
		technique_area.modulate = Color(1, 1, 1)


func _refresh_technique_area() -> void:
	for child in technique_area.get_children():
		technique_area.remove_child(child)
		child.queue_free()

	for tech: TechniqueData in player_actor.active_techniques:
		var label := Label.new()
		var element_color: Color = Helpers.color_for_element(tech.get_element_int())
		label.text = tech.display_name + " (" + tech.element + ")"
		label.add_theme_color_override("font_color", element_color)
		label.add_theme_font_size_override("font_size", 13)
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.gui_input.connect(_on_technique_clicked.bind(tech))
		technique_area.add_child(label)

	if player_actor.active_techniques.size() < player_actor.talent:
		var empty := Label.new()
		empty.text = "[空位]"
		empty.add_theme_color_override("font_color", GameColors.TEXT_DIM)
		technique_area.add_child(empty)


func _refresh_meridian_panel() -> void:
	if meridian_panel and meridian_panel.has_method("set_meridian"):
		meridian_panel.set_meridian(player_actor.base_meridian)
		meridian_panel.set_erosion_targets(player_actor.erosion_targets)
		meridian_panel.set_max_targets(player_actor.get_max_erosion_targets())

		# Pass active circuit pathways for highlighting
		var circuit_pathway_keys: Array[String] = []
		for circuit in player_actor.active_circuits:
			var pathways: Array = circuit.get("pathways", [])
			for pwp in pathways:
				var from_idx: int = pwp.get("from", -1)
				var to_idx: int = pwp.get("to", -1)
				if from_idx >= 0 and to_idx >= 0:
					var a: int = min(from_idx, to_idx)
					var b: int = max(from_idx, to_idx)
					circuit_pathway_keys.append(str(a) + "->" + str(b))

		if meridian_panel.has_method("set_circuit_pathways"):
			meridian_panel.set_circuit_pathways(circuit_pathway_keys)

		if meridian_panel.has_method("set_dry"):
			meridian_panel.set_dry(player_actor.is_flow_dry)

		# Pass technique colors
		var tech_colors: Dictionary = {}
		for tech in player_actor.active_techniques:
			tech_colors[tech.id] = Helpers.color_for_element(tech.get_element_int())
		if meridian_panel.has_method("set_technique_colors"):
			meridian_panel.set_technique_colors(tech_colors)

		# Pass collision data (now stored on controller)
		# Pass technique pathway bindings
			if meridian_panel.has_method("set_technique_pathways"):
				var pathway_data: Dictionary = {}
				for tech_id in player_actor.technique_pathways:
					var binding: Dictionary = player_actor.technique_pathways[tech_id]
					var key: String = str(binding.get("from", -1)) + "->" + str(binding.get("to", -1))
					if not pathway_data.has(key):
						pathway_data[key] = []
					pathway_data[key].append(tech_id)
				meridian_panel.set_technique_pathways(pathway_data)

			if meridian_panel.has_method("set_collision_data") and controller._last_collision != null:
				meridian_panel.set_collision_data(controller._last_collision)


func _refresh_enemy_display(actor: EnemyActor, container: Node) -> void:
	var current_hp: int = actor.hp
	var current_block: int = actor.current_block
	var statuses: Dictionary = actor.statuses

	for child in container.get_children():
		var panel_actor: EnemyActor = child.get_meta("actor")
		if panel_actor != actor:
			continue
		for vbox_child in child.get_children():
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


# ============================================================
# Helpers
# ============================================================

func _on_enemy_clicked(event: InputEvent, panel: PanelContainer) -> void:
	if event is InputEventMouseButton and event.pressed:
		var actor: EnemyActor = panel.get_meta("actor")
		if actor == null:
			return
		var idx: int = controller.enemies.find(actor)
		if idx >= 0:
			controller.current_target = idx


func draw_cards(count: int) -> void:
	if deck_manager:
		deck_manager.draw_cards(count)
		_refresh_hand_ui()


func _reset_meridian_for_battle() -> void:
	var mer: MeridianMapData = player_actor.base_meridian
	if mer == null:
		return
	var dantian_idx: int = mer.dantian_node_index
	for i: int in mer.nodes.size():
		var node: MeridianNodeData = mer.nodes[i]
		if node:
			node.unlocked = (i == dantian_idx)
			node.current_qi = 0.0
			node.erosion_progress = 0.0
			node.technique_qi = {}
			node.properties.clear()
			node.blocked = false
	for pw in mer.pathways:
		if pw:
			pw.current_qi = 0.0
			pw.technique_qi = {}
			pw.damaged = false
			pw.blocked = false


func _check_battle_end_display() -> void:
	var result: int = controller.check_battle_end()
	if result == 1:
		# Won — refresh enemy displays for death visuals
		for enemy in controller.enemies:
			_refresh_enemy_display(enemy, enemy_container)
	elif result == 2:
		pass  # Lost — FSM already transitioned


# ============================================================
# Sandbox Debug Panel
# ============================================================

func _input(event: InputEvent) -> void:
	# Esc 取消功法路径选择
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and controller.pending_technique_card != null:
			controller.cancel_pathway_selection()
			_clear_pathway_highlights()
			_refresh_hand_ui()
			turn_label.text = "已取消路径选择"
			return

	if not _sandbox_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT:
			_toggle_sandbox()


func _toggle_sandbox() -> void:
	if not _sandbox_enabled:
		return
	if sandbox_panel:
		sandbox_panel.visible = not sandbox_panel.visible
