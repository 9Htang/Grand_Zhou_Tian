extends CanvasLayer

@onready var fsm: BattleStateMachine
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

var deck_manager: DeckManager
var current_encounter: EncounterData
var enemies: Array[EnemyActor] = []
var current_target: int = 0
var _animating: bool = false
var sandbox_panel: CanvasLayer
var _sandbox_enabled: bool = false  # 设为 true 开启调试面板（` 键呼出）

var _dragged_card: CardData = null
var _is_technique_highlighted: bool = false
var _last_collision = null  # QiCollisionResolver.CollisionResult — for meridian view

var player_actor: PlayerActor

# Shortcut to player actor for system calls
func _gm() -> Node:
	return player_actor


func _ready() -> void:
	add_to_group("battle_screen")

	# Create and populate player actor from GameManager
	player_actor = PlayerActor.new()
	player_actor.name = "PlayerActor"
	add_child(player_actor)
	_populate_player_actor()

	_build_layout()

	# Sandbox debug panel (only when enabled)
	if _sandbox_enabled:
		var sp_sc: GDScript = load("res://ui_components/sandbox_panel.gd") as GDScript
		sandbox_panel = CanvasLayer.new()
		sandbox_panel.set_script(sp_sc)
		sandbox_panel.name = "SandboxPanel"
		sandbox_panel.init(self)
		add_child(sandbox_panel)

	_connect_signals()
	_start_battle()


func _populate_player_actor() -> void:
	player_actor.hp = GameManager.player_hp
	player_actor.max_hp = GameManager.player_max_hp
	player_actor.dantian_qi = GameManager.dantian_qi
	player_actor.dantian_capacity = GameManager.dantian_capacity
	player_actor.qi_gather_rate = GameManager.qi_gather_rate
	player_actor.dantian_pressure = GameManager.dantian_pressure
	player_actor.current_block = GameManager.current_block
	player_actor.realm = GameManager.realm
	player_actor.talent = GameManager.talent
	player_actor.active_techniques = GameManager.active_techniques.duplicate()
	player_actor.active_buffs = GameManager.active_buffs.duplicate()
	player_actor.base_meridian = GameManager.base_meridian
	# Ensure meridian starts clean — reset node states in case shared Resource was polluted
	_reset_meridian_for_battle()
	player_actor.active_circuits = GameManager.active_circuits.duplicate()
	player_actor.erosion_targets = GameManager.erosion_targets.duplicate()
	player_actor.erosion_bonuses = GameManager.erosion_bonuses.duplicate()
	player_actor.qi_gather_bonuses = GameManager.qi_gather_bonuses.duplicate()
	player_actor.is_flow_dry = GameManager.is_flow_dry
	player_actor.node_base_buffs = GameManager.node_base_buffs.duplicate()
	player_actor.damaged_pathways = GameManager.damaged_pathways.duplicate()
	player_actor.gold = GameManager.gold
	player_actor.cultivation = GameManager.cultivation
	player_actor.cultivation_to_next = GameManager.cultivation_to_next
	player_actor.master_deck = GameManager.master_deck.duplicate()


func _sync_player_back_to_gm() -> void:
	GameManager.player_hp = player_actor.hp
	GameManager.player_max_hp = player_actor.max_hp
	GameManager.dantian_qi = player_actor.dantian_qi
	GameManager.dantian_capacity = player_actor.dantian_capacity
	GameManager.qi_gather_rate = player_actor.qi_gather_rate
	GameManager.dantian_pressure = player_actor.dantian_pressure
	GameManager.current_block = player_actor.current_block
	GameManager.realm = player_actor.realm
	GameManager.talent = player_actor.talent
	GameManager.active_techniques = player_actor.active_techniques.duplicate()
	GameManager.active_buffs = player_actor.active_buffs.duplicate()
	GameManager.base_meridian = player_actor.base_meridian
	GameManager.active_circuits = player_actor.active_circuits.duplicate()
	GameManager.erosion_targets = player_actor.erosion_targets.duplicate()
	GameManager.erosion_bonuses = player_actor.erosion_bonuses.duplicate()
	GameManager.qi_gather_bonuses = player_actor.qi_gather_bonuses.duplicate()
	GameManager.is_flow_dry = player_actor.is_flow_dry
	GameManager.node_base_buffs = player_actor.node_base_buffs.duplicate()
	GameManager.damaged_pathways = player_actor.damaged_pathways.duplicate()
	GameManager.gold = player_actor.gold
	GameManager.cultivation = player_actor.cultivation
	GameManager.cultivation_to_next = player_actor.cultivation_to_next
	GameManager.master_deck = player_actor.master_deck.duplicate()


func _build_layout() -> void:
	# === Adaptive sizing (viewport-relative) ===
	var top_h: int = UIHelpers.pct_h(UIHelpers.TOP_BAR_PCT, self)
	var enemy_h: int = UIHelpers.pct_h(UIHelpers.ENEMY_AREA_PCT, self)
	var meridian_h: int = UIHelpers.pct_h(UIHelpers.MERIDIAN_AREA_PCT, self)
	var tech_h: int = UIHelpers.pct_h(UIHelpers.TECH_AREA_PCT, self)
	var buffs_h: int = UIHelpers.pct_h(UIHelpers.BUFFS_PCT, self)
	var player_h: int = UIHelpers.pct_h(UIHelpers.PLAYER_AREA_PCT, self)
	var hand_h: int = UIHelpers.pct_h(UIHelpers.HAND_AREA_PCT, self)
	var btn_h: int = max(28, int(float(hand_h) * 0.15))  # end turn button ~15% of hand area
	var card_sz: Vector2 = UIHelpers.card_size(self)
	var tech_card_sz: Vector2 = UIHelpers.tech_card_size(self)
	var hp_bar_w: int = UIHelpers.pct_w(0.11, self)   # ~140/1280
	var hp_bar_h: int = max(16, int(float(player_h) * 0.7))
	var meridian_panel_w: int = UIHelpers.pct_w(0.55, self)  # enough for 9-node graph
	var meridian_panel_h: int = max(140, meridian_h - 20)
	var enemy_panel_w: int = UIHelpers.pct_w(0.11, self)
	var enemy_panel_h: int = enemy_h - 10
	var sandbox_btn_sz: Vector2 = Vector2(float(max(24, int(float(top_h) * 0.8))), float(top_h))

	# Root control fills the screen
	var root := Control.new()
	root.name = "Layout"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background ambiance (ink-wash + floating qi particles)
	var ambiance_sc: GDScript = load("res://ui_components/background_ambiance.gd") as GDScript
	var ambiance := Control.new()
	ambiance.set_script(ambiance_sc)
	ambiance.name = "BackgroundAmbiance"
	root.add_child(ambiance)

	# Main VBox layout on top of background
	var vbox := VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(vbox)
	add_child(root)

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

	var enemy_area := MarginContainer.new()
	enemy_area.name = "EnemyArea"
	enemy_area.custom_minimum_size.y = enemy_h
	enemy_container = HBoxContainer.new()
	enemy_container.name = "EnemyContainer"
	enemy_container.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_area.add_child(enemy_container)
	vbox.add_child(enemy_area)

	var meridian_area := MarginContainer.new()
	meridian_area.name = "MeridianArea"
	meridian_area.custom_minimum_size.y = meridian_h
	# Use the new meridian view component
	meridian_panel = Panel.new()
	meridian_panel.name = "MeridianPanel"
	meridian_panel.custom_minimum_size = Vector2(float(meridian_panel_w), float(meridian_panel_h))
	var mv_sc: GDScript = load("res://ui_components/meridian_view.gd") as GDScript
	meridian_panel.set_script(mv_sc)
	meridian_area.add_child(meridian_panel)
	vbox.add_child(meridian_area)

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


func _start_battle() -> void:
	current_encounter = _load_encounter()
	if current_encounter == null:
		return

	deck_manager = DeckManager.new()
	deck_manager.initialize(player_actor.master_deck.duplicate())

	_spawn_enemies()
	_update_all_ui()

	fsm.transition_to(BattleStateMachine.BattleState.PRE_BATTLE)
	await get_tree().create_timer(0.3).timeout
	fsm.transition_to(BattleStateMachine.BattleState.TURN_START)


func _load_encounter() -> EncounterData:
	# Get encounter from current map node
	var chapter: ChapterData = GameManager.current_chapter_data
	var enc_id: String = "ch1_encounter_1"  # fallback
	if chapter != null:
		var node_idx: int = GameManager.current_map_node_index
		if node_idx >= 0 and node_idx < chapter.map_nodes.size():
			var node = chapter.map_nodes[node_idx]
			if not node.encounter_id.is_empty():
				enc_id = node.encounter_id
	var path: String = "res://resources/encounter_data/" + enc_id + ".tres"
	if ResourceLoader.exists(path):
		return load(path) as EncounterData
	return null


func _spawn_enemies() -> void:
	for child in enemy_container.get_children():
		child.queue_free()
	enemies.clear()

	for enemy_id: String in current_encounter.enemy_ids:
		var data: EnemyData = EnemyDatabase.get_enemy(enemy_id)
		if data == null:
			continue
		var display: Control = _create_enemy_display(data)
		enemy_container.add_child(display)
		# Store EnemyActor reference; the visual wrapper is in the container
		var actor: EnemyActor = display.get_meta("actor")
		if actor:
			enemies.append(actor)


func _create_enemy_display(data: EnemyData) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.11, self)), float(UIHelpers.pct_h(0.18, self)))

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var sprite := ColorRect.new()
	sprite.color = data.texture_color
	var sprite_sz: int = UIHelpers.pct_h(0.083, self)  # ~60/720
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

	# Block indicator
	var block_label := Label.new()
	block_label.name = "EnemyBlock"
	block_label.text = ""
	block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block_label.add_theme_font_size_override("font_size", UIHelpers.pct_h(UIHelpers.FONT_TINY_PCT, self))
	block_label.add_theme_color_override("font_color", GameColors.ACCENT_CERULEAN)
	vbox.add_child(block_label)

	# Status indicator
	var status_label := Label.new()
	status_label.name = "EnemyStatus"
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", UIHelpers.pct_h(UIHelpers.FONT_TINY_PCT, self))
	status_label.add_theme_color_override("font_color", GameColors.ACCENT_CERULEAN)
	status_label.visible = false
	vbox.add_child(status_label)

	panel.set_meta("enemy_data", data)

	# Create EnemyActor and attach to panel
	var enemy_actor := EnemyActor.new()
	enemy_actor.name = "EnemyActor_" + data.display_name
	enemy_actor.initialize_from_data(data)
	panel.add_child(enemy_actor)
	panel.set_meta("actor", enemy_actor)

	panel.gui_input.connect(_on_enemy_clicked.bind(panel))
	return panel


# ============================================================
# FSM Handlers
# ============================================================

func _on_state_changed(_from: int, to: int) -> void:
	turn_label.text = "阶段: " + fsm.get_state_name(to)


func _on_qi_circulation() -> void:
	_animating = true
	_run_qi_circulation()
	# Bug 1 fix: display collision descriptions to player
	if _last_collision and not _last_collision.descriptions.is_empty():
		turn_label.text = "碰撞: " + ", ".join(_last_collision.descriptions)
	_animating = false
	fsm.transition_to(BattleStateMachine.BattleState.ENEMY_TURN)


func _on_turn_start() -> void:
	# Gather phase: dantian absorbs qi from environment/techniques
	# Erosion targets persist across turns until nodes unlock
	var gm: Node = _gm()
	QiPoolManager.gather_passive(gm)
	# 被动法宝轮询（按序执行，灵气不够则跳过）
	ArtifactManager.poll_passive(gm, GameManager.turn_count)
	ArtifactManager.on_turn_start(gm, GameManager.turn_count)
	# 充能型法宝每回合同步积蓄灵气
	ArtifactManager.charge_artifacts(gm, player_actor.qi_gather_rate)
	_update_all_ui()
	fsm.transition_to(BattleStateMachine.BattleState.PLAYER_TURN)


func _on_player_turn() -> void:
	# 应用抽牌惩罚后的有效抽牌数
	var effective_draw: int = deck_manager.get_effective_draw_count(5)
	deck_manager.draw_to_hand_size(effective_draw)
	deck_manager.clear_draw_penalty()

	# Node property: extra draw
	var extra_draw: float = NodePropertyResolver.get_active_property_total(_gm(), "extra_draw")
	if extra_draw > 0:
		deck_manager.draw_cards(int(extra_draw))

	_refresh_hand_ui()
	_update_all_ui()
	fsm.transition_to(BattleStateMachine.BattleState.PLAYER_ACTION)


func _on_enemy_turn() -> void:
	var actions_log: String = _execute_enemy_turn()
	turn_label.text = "敌人行动: " + actions_log
	_update_all_ui()
	fsm.transition_to(BattleStateMachine.BattleState.ENEMY_ACTION)
	await get_tree().create_timer(1.0).timeout
	fsm.transition_to(BattleStateMachine.BattleState.ENEMY_QI_CIRCULATION)


func _on_enemy_qi_circulation() -> void:
	for enemy_panel in enemies:
		var actor: EnemyActor = enemy_panel
		if actor == null:
			continue
		if actor.active_techniques.is_empty() or actor.base_meridian == null:
			continue
		# Auto-select erosion targets for the enemy
		if actor.erosion_targets.is_empty():
			EnemyAI.select_erosion_targets(actor)
		_run_qi_circulation_for_actor(actor)
	fsm.transition_to(BattleStateMachine.BattleState.TURN_END)


func _on_battle_won() -> void:
	_sync_player_back_to_gm()
	GameManager.add_cultivation(current_encounter.cultivation_reward)
	GameManager.gold += current_encounter.gold_reward
	# Check if it was a boss node
	var chapter: ChapterData = GameManager.current_chapter_data
	if chapter != null:
		var current_idx: int = GameManager.current_map_node_index
		if current_idx >= 0 and current_idx < chapter.map_nodes.size():
			var node = chapter.map_nodes[current_idx]
			if node.node_type == 5:  # MapNodeData.NodeType.BOSS
				SceneManager.go_to_reward()  # Boss -> reward screen -> next chapter
				return
	SceneManager.go_to_map()  # Normal battle -> back to map


func _on_battle_lost() -> void:
	_sync_player_back_to_gm()
	SceneManager.go_to_game_over(false)


func _on_end_turn() -> void:
	if _animating:
		return
	fsm.transition_to(BattleStateMachine.BattleState.QI_CIRCULATION)


func _on_turn_end() -> void:
	# Check battle end conditions, then advance to next turn
	if player_actor.hp <= 0:
		fsm.transition_to(BattleStateMachine.BattleState.BATTLE_LOST)
		return
	var all_dead := true
	for enemy in enemies:
		if enemy.hp > 0:
			all_dead = false
			break
	if all_dead:
		fsm.transition_to(BattleStateMachine.BattleState.BATTLE_WON)
		return

	# Tick meridian damage timers (Bug 4 fix: damage duration countdown)
	MeridianDamageSystem.tick_damage_timers(player_actor)
	for enemy in enemies:
		MeridianDamageSystem.tick_damage_timers(enemy)

	# Clear card buffs (technique buffs persist across turns)
	player_actor.clear_card_buffs()
	player_actor.current_block = 0

	# Process enemy status effects (burn tick / debuff countdown)
	var status_log: String = process_enemy_statuses()
	# Guard: if battle ended during status processing, stop turn-end logic
	if fsm.current_state == fsm.BattleState.BATTLE_WON or fsm.current_state == fsm.BattleState.BATTLE_LOST:
		return
	if not status_log.is_empty():
		turn_label.text = "状态: " + status_log

	# Consume pending effects (from EffectResolver / elixirs / breakthroughs)
	var pending: Array = _gm().get_meta("pending_effects", [])
	for effect in pending:
		match effect["type"]:
			"burn":
				for enemy in enemies:
					add_enemy_status(enemy, "burn:" + str(effect["value"]) + ":2")
			"draw_card":
				deck_manager.draw_cards(effect["value"])
				_refresh_hand_ui()
	_gm().set_meta("pending_effects", [])

	deck_manager.discard_hand()
	_update_all_ui()
	fsm.transition_to(BattleStateMachine.BattleState.TURN_START)


# ============================================================
# Qi Circulation
# ============================================================

func _run_qi_circulation() -> void:
	_run_qi_circulation_for_actor(player_actor)
	_refresh_meridian_panel()


func _run_qi_circulation_for_actor(actor: CombatActor) -> void:
	var meridian: MeridianMapData = actor.base_meridian
	if meridian == null:
		return

	var techniques: Array = actor.active_techniques

	# 灵气持久流动 — 不清零！回路中的灵气跨回合保持
	# 只清理断流无回路时的微量残留
	if actor.active_circuits.is_empty() and actor.dantian_qi <= 0:
		QiFlowSystem.clear_flow_state(actor)

	# 流量追踪：累积每个穴位本回合流经的灵气量，用于 buff 生成
	var flow_tracker: Dictionary = {}

	# Fluid tick loop: inject -> propagate -> erode -> deliver
	const MAX_TICKS: int = 20
	for _i in range(MAX_TICKS):
		var tick_result: Dictionary = QiFlowSystem.tick(actor, flow_tracker)
		var new_circuits: Array = tick_result.get("circuits_formed", [])
		if not new_circuits.is_empty():
			for circuit in new_circuits:
				actor.circuit_formed.emit(circuit)
		# Unlock visual feedback (player only)
		var unlocked_names: Array = tick_result.get("nodes_unlocked", [])
		if not unlocked_names.is_empty() and actor is PlayerActor:
			for node_name in unlocked_names:
				for j: int in meridian.nodes.size():
					var mn: MeridianNodeData = meridian.nodes[j]
					if mn and mn.name == node_name and meridian_panel.has_method("notify_node_unlocked"):
						meridian_panel.notify_node_unlocked(j)
						break
		if tick_result.get("is_dry", false):
			break
		if not tick_result.get("flow_moved", false):
			break

	actor.is_flow_dry = QiPoolManager.get_remaining(actor) <= 0

	# Collect active nodes
	var active_nodes: Array[int] = []
	for i: int in meridian.nodes.size():
		var node: MeridianNodeData = meridian.get_node(i)
		if node and node.current_qi > 0 and node.unlocked and not node.blocked:
			active_nodes.append(i)

	# Collision resolution
	var collision = null
	if techniques.size() >= 2 and not active_nodes.is_empty():
		collision = QiCollisionResolver.resolve_all(techniques, active_nodes, meridian)
		for dmg in collision.damaged_pathways:
			MeridianDamageSystem.damage_pathway(actor, dmg["from"], dmg["to"], dmg.get("turns", 3))

	# Save collision for meridian view (player only)
	if actor is PlayerActor:
		_last_collision = collision

	# Buff generation (linear scaling)
	actor.clear_technique_buffs()
	var all_buffs: Array = TechniqueResolver.resolve_network_buffs(
		techniques, meridian, actor.node_base_buffs, collision, flow_tracker
	)
	actor.active_buffs = all_buffs

	# Consume generated buffs
	for buff in all_buffs:
		match buff.name:
			"burn":
				# Player-originated burn applies to enemies
				if actor is PlayerActor:
					for enemy in enemies:
						add_enemy_status(enemy, "burn:" + str(buff.value) + ":2")
			"draw_card":
				if actor is PlayerActor:
					deck_manager.draw_cards(buff.value)
					_refresh_hand_ui()
			"heal":
				actor.heal(buff.value)
			"block":
				actor.current_block += buff.value
			"energy_up":
				actor.add_qi(buff.value)
			"energy_down":
				actor.spend_qi(buff.value)
			"self_damage":
				actor.take_damage(buff.value)

	ArtifactManager.on_qi_circulate(actor)


# ============================================================
# Enemy Turn
# ============================================================

func _execute_enemy_turn() -> String:
	var log_entries: Array[String] = []
	for enemy in enemies:
		var actor: EnemyActor = enemy
		if actor == null:
			continue
		var data: EnemyData = null
		# Find the visual panel that has enemy_data meta
		for child in enemy_container.get_children():
			var panel_data: EnemyData = child.get_meta("enemy_data")
			if panel_data and child.get_meta("actor") == actor:
				data = panel_data
				break
		if data == null:
			continue

		var action: EnemyActionData = EnemyAI.select_action(actor, player_actor, data)
		if action == null:
			continue

		log_entries.append(EnemyAI.describe_decision(actor, action))

		# Check for weak status on enemy (reduces damage dealt)
		var weak_amount: int = 0
		if actor.statuses.has("weak"):
			weak_amount = actor.statuses["weak"].get("amount", 0)

		match action.intent:
			EnemyActionData.IntentType.ATTACK, EnemyActionData.IntentType.ATTACK_MULTI:
				# Enemy strength bonus
				var raw_dmg: int = action.damage + actor.strength
				var dmg: int = DamageCalculation.enemy_damage(
					raw_dmg, player_actor.realm, actor.realm
				)
				# Player vulnerable: damage x1.5
				for buff in player_actor.active_buffs:
					if buff.name == "vulnerable":
						dmg = int(float(dmg) * 1.5)
						break
				# Enemy weak: damage -N
				dmg = max(0, dmg - weak_amount)
				player_actor.take_damage(dmg)
				log_entries.append(actor.display_name + " 攻击造成 " + str(dmg) + " 伤害")

				# Node property: counter
				var counter_val: float = NodePropertyResolver.get_active_property_total(_gm(), "counter")
				if counter_val > 0.0:
					var new_hp: int = max(0, actor.hp - int(counter_val))
					actor.hp = new_hp
					log_entries.append(" 反击 " + str(int(counter_val)))

				# Node property: reflect
				var reflect_pct: float = NodePropertyResolver.get_active_property_total(_gm(), "reflect")
				if reflect_pct > 0.0:
					var reflect_dmg: int = max(1, int(float(dmg) * reflect_pct / 100.0))
					actor.hp = max(0, actor.hp - reflect_dmg)
					log_entries.append(" 反伤 " + str(reflect_dmg))

			EnemyActionData.IntentType.DEFEND:
				actor.current_block += action.block
				log_entries.append(actor.display_name + " 防御 +" + str(action.block))

			EnemyActionData.IntentType.BUFF_SELF:
				if not action.buff_self.is_empty():
					var parts: PackedStringArray = action.buff_self.split(":")
					if parts.size() >= 2:
						match parts[0]:
							"strength":
								actor.strength += int(parts[1])
								log_entries.append(actor.display_name + " 力量 +" + parts[1])
							_:
								log_entries.append(actor.display_name + " 强化")
				else:
					log_entries.append(actor.display_name + " 强化")

			EnemyActionData.IntentType.DEBUFF_PLAYER:
				if not action.debuff_player.is_empty():
					var parts: PackedStringArray = action.debuff_player.split(":")
					if parts.size() >= 2:
						match parts[0]:
							"weak":
								var rb := TechniqueResolver.ResolvedBuff.new()
								rb.name = "weak"
								rb.value = int(parts[1])
								rb.source = "enemy"
								player_actor.active_buffs.append(rb)
								player_actor.buffs_updated.emit(player_actor.active_buffs)
								log_entries.append(actor.display_name + " 虚弱玩家 (-" + parts[1] + " 伤害)")
							"energy_down":
								player_actor.spend_qi(int(parts[1]))
								log_entries.append(actor.display_name + " 吸取灵气 " + parts[1])
							_:
								log_entries.append(actor.display_name + " 削弱玩家")
				else:
					log_entries.append(actor.display_name + " 削弱玩家")

			EnemyActionData.IntentType.SEAL_MERIDIAN:
				var target_node_idx: int = -1
				if action.target_node == "random":
					var candidates: Array[int] = []
					var mer: MeridianMapData = player_actor.base_meridian
					if mer:
						for i: int in mer.nodes.size():
							var n: MeridianNodeData = mer.get_node(i)
							if n and n.unlocked and not n.blocked and n.current_qi > 0:
								candidates.append(i)
					if not candidates.is_empty():
						target_node_idx = candidates[randi() % candidates.size()]
				if target_node_idx >= 0:
					var mn: MeridianNodeData = player_actor.base_meridian.get_node(target_node_idx)
					MeridianDamageSystem.block_node(player_actor, mn.name)
					log_entries.append(actor.display_name + " 封穴 " + mn.name)
				else:
					log_entries.append(actor.display_name + " 封穴 (无有效目标)")

			EnemyActionData.IntentType.DAMAGE_PATHWAY:
				var pathways: Array = player_actor.base_meridian.pathways
				if not pathways.is_empty():
					var pw = pathways[randi() % pathways.size()]
					MeridianDamageSystem.damage_pathway(player_actor, pw.from_node, pw.to_node)
					log_entries.append(actor.display_name + " 断脉 " + str(pw.from_node) + "->" + str(pw.to_node))
				else:
					log_entries.append(actor.display_name + " 断脉 (无经脉)")

			EnemyActionData.IntentType.DRAIN_QI:
				var drain_amount: int = action.damage
				if drain_amount <= 0:
					drain_amount = 3
				var actual: float = QiFlowSystem.draw_from_meridian(player_actor, float(drain_amount))
				log_entries.append(actor.display_name + " 吸灵 " + str(int(actual)) + " 点")
				if not action.debuff_player.is_empty():
					var parts: PackedStringArray = action.debuff_player.split(":")
					if parts.size() >= 2 and parts[0] == "energy_down":
						player_actor.spend_qi(int(parts[1]))

			_:
				log_entries.append(actor.display_name + " " + EnemyIntents.get_intent_text(action))

		_refresh_enemy_display(actor, enemy_container)

	if log_entries.is_empty():
		return "无"
	return ", ".join(log_entries)


# ============================================================
# Card Play
# ============================================================

func _on_card_clicked(card_data: CardData) -> void:
	if _animating:
		return

	var gm: Node = _gm()
	var result: Dictionary = CardEffects.apply(gm, card_data, self)

	if not result.get("success", false):
		return

	# 根据行为标记路由卡牌去向
	var destination: String = result.get("destination", "discard")
	match destination:
		"discard":
			deck_manager.play_card(card_data)
		"exhaust":
			deck_manager.exhaust_card(card_data)
		_:
			pass

	# 容器展开：内容物卡牌加入手牌
	var container_cards: Array = result.get("container_cards", [])
	for cc: CardData in container_cards:
		deck_manager.hand.append(cc)

	# 刷新 UI
	var target: EnemyActor = get_target_enemy()
	if target:
		_refresh_enemy_display(target, enemy_container)
	_refresh_hand_ui()
	_update_all_ui()
	_check_battle_end()


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
			# 通过 CardEffects 统一处理功法激活
			var result: Dictionary = CardEffects.apply(_gm(), card_data, self)
			if result.get("success", false):
				var dest: String = result.get("destination", "discard")
				if dest == "exhaust":
					deck_manager.exhaust_card(card_data)
				else:
					deck_manager.play_card(card_data)
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

	# 3. Invalid drop - snap back by refreshing hand layout
	if not handled:
		_refresh_hand_ui()

	_dragged_card = null


func _on_technique_changed(_tech: TechniqueData) -> void:
	_refresh_technique_area()


func _on_technique_clicked(event: InputEvent, tech: TechniqueData) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 检查是否有剩余抽牌配额
		if not deck_manager.can_cancel(5):
			return
		player_actor.deactivate_technique(tech)
		# 将功法卡返还手牌
		var card_id: String = "technique_" + tech.id
		var card: CardData = CardDatabase.get_card(card_id)
		if card:
			deck_manager.cancel_technique(card)
		_refresh_hand_ui()
		_update_all_ui()


# Single click acupoint -> show info popup (dedup: remove existing first)
func _on_node_info(idx: int, node: MeridianNodeData) -> void:
	# Remove any existing popup before creating a new one
	for child in get_children():
		if child is CanvasLayer and child.name.begins_with("NodeInfo_"):
			child.queue_free()
	var popup := CanvasLayer.new()
	var sc: GDScript = load("res://ui_components/node_info_popup.gd") as GDScript
	popup.set_script(sc)
	popup.name = "NodeInfo_" + str(idx)
	add_child(popup)
	popup.show_info(idx, node)


# Double click acupoint -> toggle erosion target (locked nodes with adjacent unlocked only)
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


# ============================================================
# UI Updates
# ============================================================

func _update_all_ui() -> void:
	_update_hp(player_actor.hp, player_actor.max_hp)
	_update_qi(player_actor.dantian_qi, player_actor.dantian_capacity)
	_update_buffs(player_actor.active_buffs)
	realm_label.text = "境界: " + str(player_actor.realm)
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
	for child in hand_area.get_children():
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

		# Pass technique colors for per-technique visualization
		var tech_colors: Dictionary = {}
		for tech in player_actor.active_techniques:
			tech_colors[tech.id] = Helpers.color_for_element(tech.get_element_int())
		if meridian_panel.has_method("set_technique_colors"):
			meridian_panel.set_technique_colors(tech_colors)

		# Pass collision data for 相生/相克 visualization
		if meridian_panel.has_method("set_collision_data") and _last_collision != null:
			meridian_panel.set_collision_data(_last_collision)


# ============================================================
# Helpers
# ============================================================

func _on_enemy_clicked(event: InputEvent, panel: PanelContainer) -> void:
	if event is InputEventMouseButton and event.pressed:
		var actor: EnemyActor = panel.get_meta("actor")
		if actor == null:
			return
		var idx: int = enemies.find(actor)
		if idx >= 0:
			current_target = idx


func get_target_enemy() -> EnemyActor:
	if enemies.is_empty():
		return null
	if current_target >= enemies.size():
		current_target = 0
	return enemies[current_target]


# ============================================================
# Enemy Status System (debuff/burn/vulnerable/weak)
# ============================================================

# Apply a status effect to an enemy
# status_str: "burn:3:2" (damage:3, turns:2), "vulnerable:2" (turns:2), "weak:1:2"
func add_enemy_status(enemy: EnemyActor, status_str: String) -> void:
	var parts: PackedStringArray = status_str.split(":")
	if parts.size() < 2:
		return
	var name: String = parts[0]

	match name:
		"burn":
			var damage: int = int(parts[1])
			var turns: int = int(parts[2]) if parts.size() >= 3 else 2
			if enemy.statuses.has("burn"):
				var existing: Dictionary = enemy.statuses["burn"]
				existing["damage"] = max(existing["damage"], damage)
				existing["turns"] = max(existing["turns"], turns)
			else:
				enemy.statuses["burn"] = {"damage": damage, "turns": turns}
		"vulnerable":
			var turns: int = int(parts[1])
			var existing_turns: int = enemy.statuses.get("vulnerable", {}).get("turns", 0)
			enemy.statuses["vulnerable"] = {"turns": max(existing_turns, turns)}
		"weak":
			var amount: int = int(parts[1])
			var turns: int = int(parts[2]) if parts.size() >= 3 else 1
			var existing_turns: int = enemy.statuses.get("weak", {}).get("turns", 0)
			var existing_amount: int = enemy.statuses.get("weak", {}).get("amount", 0)
			enemy.statuses["weak"] = {"amount": max(existing_amount, amount), "turns": max(existing_turns, turns)}

	_refresh_enemy_display(enemy, enemy_container)


# Process all enemy statuses at turn end (burn tick / debuff countdown)
# Returns log string
func process_enemy_statuses() -> String:
	var log_entries: Array[String] = []
	for enemy in enemies:
		if enemy.statuses.is_empty():
			continue
		var hp: int = enemy.hp
		var name_str: String = enemy.display_name

		# Burn tick
		if enemy.statuses.has("burn"):
			var burn: Dictionary = enemy.statuses["burn"]
			var dmg: int = burn["damage"]
			hp = max(0, hp - dmg)
			burn["turns"] = burn["turns"] - 1
			log_entries.append(name_str + " 灼烧 " + str(dmg) + " 点")
			if burn["turns"] <= 0:
				enemy.statuses.erase("burn")

		# Vulnerable countdown
		if enemy.statuses.has("vulnerable"):
			var vuln: Dictionary = enemy.statuses["vulnerable"]
			vuln["turns"] = vuln["turns"] - 1
			if vuln["turns"] <= 0:
				enemy.statuses.erase("vulnerable")

		# Weak countdown
		if enemy.statuses.has("weak"):
			var weak: Dictionary = enemy.statuses["weak"]
			weak["turns"] = weak["turns"] - 1
			if weak["turns"] <= 0:
				enemy.statuses.erase("weak")

		enemy.hp = hp
		_refresh_enemy_display(enemy, enemy_container)

		# Remove dead enemies — check battle end and return early if decided
		if hp <= 0:
			_check_battle_end()
			if fsm.current_state == fsm.BattleState.BATTLE_WON or fsm.current_state == fsm.BattleState.BATTLE_LOST:
				return ", ".join(log_entries)

	return ", ".join(log_entries)


# Check if enemy has a specific status
func enemy_has_status(enemy: EnemyActor, status_name: String) -> bool:
	return enemy.statuses.has(status_name)


# Get status value
func get_enemy_status_value(enemy: EnemyActor, status_name: String, key: String = "damage", default: Variant = 0):
	if enemy.statuses.has(status_name):
		return enemy.statuses[status_name].get(key, default)
	return default


func _refresh_enemy_display(actor: EnemyActor, container: Node) -> void:
	var current_hp: int = actor.hp
	var current_block: int = actor.current_block
	var statuses: Dictionary = actor.statuses

	# Find the visual panel for this actor
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


func draw_cards(count: int) -> void:
	deck_manager.draw_cards(count)
	_refresh_hand_ui()


# Reset meridian nodes to default state (only dantian unlocked) before battle
# Prevents battle_test shared Resource pollution from leaking into normal games
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


func _check_battle_end() -> void:
	var all_dead := true
	for enemy in enemies:
		if enemy.hp > 0:
			all_dead = false
			break
	if all_dead:
		fsm.transition_to(BattleStateMachine.BattleState.BATTLE_WON)
		return

	if player_actor.hp <= 0:
		fsm.transition_to(BattleStateMachine.BattleState.BATTLE_LOST)


# ============================================================
# Sandbox Debug Panel
# ============================================================

func _input(event: InputEvent) -> void:
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
