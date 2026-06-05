# ============================================================
# 大周天 — BattleScreen (战斗 UI 壳 — L0)
# ============================================================
# 职责: 组件创建 + 信号接线 + 战斗启动
# 所有 UI 表现委托给 Presenter/Handler 子系统
# 所有流程逻辑委托给 BattleController + BattleFlowView
# ============================================================
extends CanvasLayer

# === UI Nodes (由 BattleLayoutBuilder.build() 设置) ===
var enemy_container: HBoxContainer
var meridian_panel: Panel
var technique_area: HBoxContainer
var buffs_bar: HBoxContainer
var hand_area: HBoxContainer
var end_turn_btn: Button
var player_hp_bar: Control
var player_qi_bar: Control
var realm_label: Label
var deck_info: Label
var turn_label: Label
var play_zone: Panel

# === Core References ===
var controller: BattleController
var player_actor: PlayerActor
var deck_manager: DeckManager  # shortcut set by flow_view after start_battle()
var fsm: BattleStateMachine

# === Subsystems ===
var layout_builder: BattleLayoutBuilder
var flow_view: BattleFlowView
var drag_handler: DragInputHandler
var snapshot_presenter: BattleSnapshotPresenter
var buff_presenter: BuffPresenter
var technique_presenter: TechniquePresenter
var enemy_presenter: EnemyPresenter
var meridian_presenter: MeridianPresenter
var hand_presenter: HandPresenter
var forge_presenter: ForgePresenter
var target_selection_view: TargetSelectionView

# === Sandbox (debug only) ===
var sandbox_panel: CanvasLayer = null
var _sandbox_enabled: bool = false


# ============================================================
# Ready
# ============================================================

func _ready() -> void:
	add_to_group("battle_screen")

	_sandbox_enabled = ProjectSettings.get_setting("game/debug/sandbox_enabled", false)

	# 1. Create PlayerActor
	player_actor = PlayerActor.new()
	player_actor.name = "PlayerActor"
	add_child(player_actor)
	player_actor.load_from_gm()
	player_actor.reset_meridian_for_battle()

	# 2. Create FSM (即时制: 4 状态)
	fsm = BattleStateMachine.new()
	fsm.name = "BattleStateMachine"
	add_child(fsm)

	# 3. Build layout (sets all node references on self)
	layout_builder = BattleLayoutBuilder.new()
	layout_builder.build(self)

	# 3. Sandbox debug panel (only when enabled)
	if _sandbox_enabled:
		var sp_sc: GDScript = load("res://ui_components/sandbox_panel.gd") as GDScript
		sandbox_panel = CanvasLayer.new()
		sandbox_panel.set_script(sp_sc)
		sandbox_panel.name = "SandboxPanel"
		sandbox_panel.init(self)
		add_child(sandbox_panel)

	# 4. Create controller
	controller = BattleController.new()
	controller.initialize(self, player_actor, fsm)

	# 5. Init presenters
	_init_presenters()

	# 6. Init subsystems
	_init_subsystems()

	# 7. Connect signals
	_connect_signals()

	# 8. Start battle
	flow_view.start_battle()


# ============================================================
# Init
# ============================================================

func _init_presenters() -> void:
	buff_presenter = BuffPresenter.new()
	buff_presenter.setup(buffs_bar)

	technique_presenter = TechniquePresenter.new()
	technique_presenter.setup(technique_area, _on_technique_clicked)

	enemy_presenter = EnemyPresenter.new()
	enemy_presenter.setup(enemy_container, _on_enemy_clicked)

	meridian_presenter = MeridianPresenter.new()
	meridian_presenter.setup(meridian_panel)

	hand_presenter = HandPresenter.new()
	hand_presenter.setup(
		hand_area,
		drag_handler_on_card_tapped,
		drag_handler_on_card_drag_started,
		drag_handler_on_card_drag_ended,
		_sandbox_enabled,
		sandbox_panel,
	)

	forge_presenter = ForgePresenter.new()
	forge_presenter.setup(self, turn_label, _on_forge_feature_selected, _on_forge_cancelled)

	snapshot_presenter = BattleSnapshotPresenter.new()
	snapshot_presenter.setup(
		buff_presenter, technique_presenter, enemy_presenter,
		meridian_presenter, hand_presenter,
		player_hp_bar, player_qi_bar, realm_label, deck_info,
	)

	target_selection_view = TargetSelectionView.new()
	target_selection_view.setup(turn_label, meridian_presenter, forge_presenter, enemy_presenter)


func _init_subsystems() -> void:
	flow_view = BattleFlowView.new()
	flow_view.setup(
		self, controller, fsm,
		snapshot_presenter, enemy_presenter,
		meridian_presenter, hand_presenter, forge_presenter,
	)

	drag_handler = DragInputHandler.new()
	drag_handler.setup(
		self, controller,
		play_zone, technique_area, hand_area,
		snapshot_presenter, meridian_presenter, enemy_presenter,
	)


# ============================================================
# Signal Connections
# ============================================================

func _connect_signals() -> void:
	# Clock 信号由 flow_view.start_battle() 内部接线
	# FSM 终端信号由 flow_view.connect_clock_signals() 接线

	# Pause button — 安全暂停/恢复 (Phase 6)
	end_turn_btn.pressed.connect(_on_pause_toggle)

	# FSM state changes → UI updates (Phase 6)
	fsm.state_changed.connect(_on_fsm_state_changed)

	# Player signals → snapshot refresh
	player_actor.hp_changed.connect(_on_player_stat_changed)
	player_actor.qi_changed.connect(_on_player_stat_changed)
	player_actor.buffs_updated.connect(_on_player_stat_changed)
	player_actor.technique_activated.connect(_on_technique_changed)
	player_actor.technique_deactivated.connect(_on_technique_changed)

	# Meridian panel signals → flow_view routing
	meridian_panel.node_clicked.connect(flow_view.handle_meridian_node_clicked)
	meridian_panel.node_double_clicked.connect(flow_view.handle_erosion_toggle)

	# TargetManager signals → TargetSelectionView + 交互暂停
	if controller and controller.target_manager:
		controller.target_manager.selection_started.connect(target_selection_view.on_selection_started)
		controller.target_manager.selection_completed.connect(target_selection_view.on_selection_completed)
		controller.target_manager.selection_cancelled.connect(target_selection_view.on_selection_cancelled)
		## 目标选择期间暂停游戏时间
		controller.target_manager.selection_started.connect(func(_s, _t): controller.begin_interaction())
		controller.target_manager.selection_completed.connect(func(_s, _t): controller.end_interaction())
		controller.target_manager.selection_cancelled.connect(func(): controller.end_interaction())


# ============================================================
# Signal Routing
# ============================================================

func _on_player_stat_changed(_a = null, _b = null) -> void:
	snapshot_presenter.apply_snapshot(controller.build_snapshot())


func _on_technique_changed(_tech: TechniqueData = null) -> void:
	snapshot_presenter.apply_snapshot(controller.build_snapshot())


func _on_technique_clicked(tech: TechniqueData) -> void:
	flow_view.handle_technique_clicked(tech)


func _on_enemy_clicked(event: InputEvent, panel: PanelContainer) -> void:
	if event is InputEventMouseButton and event.pressed:
		flow_view.handle_enemy_clicked(panel)


func _on_forge_feature_selected(feature: Dictionary) -> void:
	flow_view.handle_feature_selected(feature)


func _on_forge_cancelled() -> void:
	if controller:
		controller.cancel_current_operation()


# ============================================================
# Drag Callbacks (forward to drag_handler after init)
# ============================================================

func drag_handler_on_card_tapped(card_data: CardData) -> void:
	drag_handler.on_card_tapped(card_data)


func drag_handler_on_card_drag_started(card_data: CardData) -> void:
	drag_handler.on_card_drag_started(card_data)


func drag_handler_on_card_drag_ended(card_data: CardData, drop_area: String) -> void:
	drag_handler.on_card_drag_ended(card_data, drop_area)


# ============================================================
# External Passthroughs (Bootstrapper has_method 需要)
# ============================================================

func show_forge_hint(hint: String) -> void:
	forge_presenter.show_forge_hint(hint)


func show_forge_result(result: CardForgeResult) -> void:
	forge_presenter.show_forge_result(result)


func notify_effect_execution_done(result: Dictionary) -> void:
	flow_view.notify_effect_execution_done(result)


func clear_forge_ui() -> void:
	forge_presenter.clear_forge_ui()
	_refresh_all()


func draw_cards(count: int) -> void:
	enemy_presenter.draw_cards(count, deck_manager)
	snapshot_presenter.refresh_all(controller.build_snapshot(), deck_manager, _build_playability_map())


# ============================================================
# Engine Callbacks
# ============================================================

func _on_pause_toggle() -> void:
	## 委托 controller.toggle_manual_pause() — 交互暂停进行中时按钮无效
	controller.toggle_manual_pause()


## FSM 状态变化 → 更新暂停按钮文字 (Phase 6)
func _on_fsm_state_changed(_from: int, to: int) -> void:
	match to:
		BattleStateMachine.BattleState.PAUSED:
			end_turn_btn.text = "▶ 继续"
		BattleStateMachine.BattleState.PLAYING, BattleStateMachine.BattleState.RESOLVING, BattleStateMachine.BattleState.DIGEST:
			end_turn_btn.text = "⏸ 暂停"


func _process(delta: float) -> void:
	drag_handler.process(delta)


func _input(event: InputEvent) -> void:
	# ESC 取消 — 委托给 flow_view
	if flow_view.handle_input(event):
		return
	# Sandbox toggle (backtick)
	if _sandbox_enabled and event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_QUOTELEFT:
			_toggle_sandbox()


func _toggle_sandbox() -> void:
	if not _sandbox_enabled or sandbox_panel == null:
		return
	sandbox_panel.visible = not sandbox_panel.visible


# ============================================================
# Internal Helpers
# ============================================================

func _refresh_all() -> void:
	snapshot_presenter.refresh_all(controller.build_snapshot(), deck_manager, _build_playability_map())



## 导出当前战斗为 .replay 文件（战斗结束后调用）
func save_replay(file_path: String = "") -> bool:
	if controller == null:
		push_warning("BattleScreen: controller not initialized")
		return false
	var run: SimulationRun = controller.get_simulation_run()
	if run == null:
		push_warning("BattleScreen: no SimulationRun available — was battle recorder active?")
		return false
	var path := file_path
	if path.is_empty():
		var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
		path = "user://replays/battle_" + timestamp + ".replay"
	var ok := ReplayExporter.export_to_file(run, path)
	if ok:
		print("BattleScreen: replay saved to " + path)
	return ok

func _build_playability_map() -> Dictionary:
	var playability_map: Dictionary = {}
	if deck_manager:
		for card: CardData in deck_manager.hand:
			playability_map[card] = controller.is_card_playable(card)
	return playability_map


# ============================================================
# Replay Mode — render_tick (纯 UI 渲染, 不跑游戏逻辑)
# ============================================================

## 由 ReplayViewer 驱动 — 消费 BattleReplayAdapter 产出的状态快照，直接更新 UI
## state_dict 格式:
##   {tick: int, player: {hp, max_hp, qi, capacity, block, qi_gather_rate, realm},
##    enemies: [{id, hp, max_hp, block}]}
func render_tick(state_dict: Dictionary) -> void:
	if state_dict.is_empty():
		return

	# === Player Vitals ===
	var p: Dictionary = state_dict.get("player", {})
	if not p.is_empty():
		if player_hp_bar and player_hp_bar.has_method("set_values"):
			player_hp_bar.set_values(p.get("hp", 0), p.get("max_hp", 0))
		if player_qi_bar and player_qi_bar.has_method("set_values"):
			player_qi_bar.set_values(p.get("qi", 0), p.get("capacity", 0), p.get("qi_gather_rate", 0))
		if realm_label:
			realm_label.text = "境界: " + str(p.get("realm", 1))

	# === Enemy Vitals ===
	var enemies: Array = state_dict.get("enemies", [])
	if not enemies.is_empty() and enemy_presenter:
		_render_enemy_vitals(enemies)

	# === Deck Info ===
	if deck_info:
		var draw_count: int = state_dict.get("draw_pile_count", -1)
		var disc_count: int = state_dict.get("discard_count", -1)
		if draw_count >= 0:
			deck_info.text = "牌库:" + str(draw_count) + " 弃牌:" + str(disc_count)


## 直接更新敌人面板（按 index 匹配，不依赖 EnemyActor 引用）
func _render_enemy_vitals(enemy_list: Array) -> void:
	if enemy_container == null:
		return

	var panels: Array = enemy_container.get_children()
	for i in range(min(enemy_list.size(), panels.size())):
		var entry: Dictionary = enemy_list[i]
		var panel = panels[i]
		if panel == null:
			continue

		var hp_val: int = entry.get("hp", 0)
		var block_val: int = entry.get("block", 0)

		# 遍历面板子节点找 HP bar 和 block label
		for child in panel.get_children():
			if child is VBoxContainer:
				for c in child.get_children():
					if c.name == "EnemyHP" and c.has_method("set_values"):
						c.current_value = hp_val
					elif c.name == "EnemyBlock":
						if block_val > 0:
							c.text = "格挡 " + str(block_val)
							c.visible = true
						else:
							c.text = ""
							c.visible = false
