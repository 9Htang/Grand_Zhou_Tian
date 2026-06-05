# ============================================================
# 大周天 — BattleFlowView (Clock → UI 适配器 — L0, 即时制)
# 即时制改造:
#   - FSM 信号 → BattleClock 信号 + WinLossMonitor 信号
#   - 移除所有 turn 相关 handler
#   - 移除 _on_end_turn
#   - 新增 _on_tick (周期性 UI 刷新)
# ============================================================
class_name BattleFlowView
extends RefCounted


var screen: CanvasLayer
var controller: BattleController
var fsm: BattleStateMachine
var snapshot_presenter: BattleSnapshotPresenter
var enemy_presenter: EnemyPresenter
var meridian_presenter: MeridianPresenter
var hand_presenter: HandPresenter
var forge_presenter: ForgePresenter


func setup(
	p_screen: CanvasLayer,
	p_controller: BattleController,
	p_fsm: BattleStateMachine,
	p_snapshot_presenter: BattleSnapshotPresenter,
	p_enemy_presenter: EnemyPresenter,
	p_meridian_presenter: MeridianPresenter,
	p_hand_presenter: HandPresenter,
	p_forge_presenter: ForgePresenter,
) -> void:
	screen = p_screen
	controller = p_controller
	fsm = p_fsm
	snapshot_presenter = p_snapshot_presenter
	enemy_presenter = p_enemy_presenter
	meridian_presenter = p_meridian_presenter
	hand_presenter = p_hand_presenter
	forge_presenter = p_forge_presenter


# ============================================================
# Signal Wiring — 即时制: Clock + WinLoss 信号
# ============================================================

func connect_clock_signals() -> void:
	var clock: BattleClock = controller.battle_clock
	if clock == null:
		return

	# 每 4 ticks (1s) 刷新一次 UI
	clock.battle_second.connect(_on_tick)

	# FSM 终端信号 (保留)
	fsm.state_changed.connect(_on_state_changed)
	fsm.battle_won.connect(_on_battle_won)
	fsm.battle_lost.connect(_on_battle_lost)

	# 敌人行动信号
	var ets: EnemyTimerSystem = controller.enemy_timer_system
	if ets:
		ets.enemy_action_ready.connect(_on_enemy_action)
		ets.enemy_qi_circulation_ready.connect(_on_enemy_qi_circulation)


# ============================================================
# Battle Start
# ============================================================

func start_battle() -> void:
	if not controller.start_battle():
		return

	screen.deck_manager = controller.deck_manager
	spawn_enemies()

	# 首次 UI 刷新 — refresh_all 含手牌, apply_snapshot 不刷手牌
	snapshot_presenter.refresh_all(controller.build_snapshot(), controller.deck_manager, _build_playability_map())

	# 开始时钟
	connect_clock_signals()

	# 锻淬流程交互暂停 — forge 完成/取消时恢复游戏时间
	if controller.forge_service:
		controller.forge_service.forge_finished.connect(func(): controller.end_interaction())
		controller.forge_service.forge_cancelled.connect(func(): controller.end_interaction())

	controller.battle_clock.paused = false


func _load_encounter() -> EncounterData:
	return controller.get_current_encounter()


func spawn_enemies() -> void:
	enemy_presenter.clear_displays()
	controller.clear_enemies()

	for enemy_id: String in controller.get_encounter_enemy_ids():
		var data: EnemyData = EnemyDatabase.get_enemy(enemy_id)
		if data == null:
			continue
		var display: Control = enemy_presenter.create_enemy_display(data, screen)
		screen.enemy_container.add_child(display)
		var actor_from_panel: EnemyActor = display.get_meta("actor") as EnemyActor
		if actor_from_panel:
			controller.add_enemy(actor_from_panel, data)


# ============================================================
# Clock / Enemy Handlers
# ============================================================

func _on_tick(_tick_number: int) -> void:
	if fsm.is_terminal():
		return
	_refresh_all()


func _on_state_changed(_from: int, to: int) -> void:
	screen.turn_label.text = fsm.get_state_name(to)


func _on_enemy_action(enemy: EnemyActor, action: EnemyActionData) -> void:
	screen.turn_label.text = enemy.display_name + ": " + EnemyAI.describe_decision(enemy, action)
	_refresh_all()


func _on_enemy_qi_circulation(_enemy: EnemyActor) -> void:
	# 敌人灵气循环由 controller 处理, 这里刷新 UI
	_refresh_all()


func _on_battle_won() -> void:
	controller.battle_clock.paused = true
	var result: Dictionary = controller.execute_battle_won()
	if result.get("is_boss", false):
		SceneManager.go_to_reward()
	else:
		SceneManager.go_to_map()


func _on_battle_lost() -> void:
	controller.battle_clock.paused = true
	controller.execute_battle_lost()
	SceneManager.go_to_game_over(false)


# ============================================================
# Routing Methods (called by BattleScreen signal handlers)
# ============================================================

func handle_meridian_node_clicked(idx: int, node: MeridianNodeData) -> void:
	if controller.target_manager and controller.target_manager.is_selecting():
		var sel_type: String = controller.get_selection_type()
		var target: Dictionary = {}
		match sel_type:
			"node":
				target = {"idx": idx, "name": node.name, "unlocked": node.unlocked}
		if not target.is_empty():
			controller.target_manager.submit_target(target)
		return

	if controller.is_pathway_selection_active():
		var sel_result: int = controller.select_pathway_node(idx)
		match sel_result:
			-1:
				pass
			0:
				meridian_presenter.highlight_available_end_nodes(controller.get_pathway_selection_from(), screen.player_actor)
				screen.turn_label.text = "选择经脉路径: 再点击终点穴位"
			1:
				## 路径选择完成 → 恢复游戏时间
				controller.end_interaction()
				meridian_presenter.clear_pathway_highlights()
				screen.turn_label.text = "功法已挂载"
				_refresh_all()
		return

	meridian_presenter.show_node_info_popup(idx, node, screen)


func handle_erosion_toggle(idx: int, _node: MeridianNodeData) -> void:
	if not screen.player_actor.can_toggle_erosion(idx):
		return
	screen.player_actor.toggle_erosion_target(idx)
	_refresh_all()


func handle_technique_clicked(tech: TechniqueData) -> void:
	if controller.cancel_technique(tech):
		_refresh_all()


func handle_enemy_clicked(panel: PanelContainer) -> void:
	var actor: EnemyActor = panel.get_meta("actor")
	if actor == null:
		return

	if controller.target_manager and controller.target_manager.is_selecting():
		var stype: String = controller.get_selection_type()
		if stype == "enemy":
			var target: Dictionary = {
				"actor": actor,
				"hp": actor.hp,
				"block": actor.current_block,
				"index": controller.get_enemies().find(actor),
			}
			controller.target_manager.submit_target(target)
			return


func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if controller.cancel_current_operation():
				## ESC 取消交互 → 恢复游戏时间 (路径选择/锻淬/目标选择)
				controller.end_interaction()
				meridian_presenter.clear_pathway_highlights()
				snapshot_presenter.refresh_all(controller.build_snapshot(), screen.deck_manager, _build_playability_map())
				screen.turn_label.text = "已取消"
				return true
	return false


func notify_effect_execution_done(_result: Dictionary) -> void:
	_refresh_all()


func handle_feature_selected(feature: Dictionary) -> void:
	if controller and controller.target_manager:
		controller.target_manager.submit_target(feature)


# ============================================================
# Internal Helpers
# ============================================================

func _refresh_all() -> void:
	snapshot_presenter.refresh_all(controller.build_snapshot(), screen.deck_manager, _build_playability_map())


func _build_playability_map() -> Dictionary:
	var playability_map: Dictionary = {}
	if screen.deck_manager:
		for card: CardData in screen.deck_manager.hand:
			playability_map[card] = controller.is_card_playable(card)
	return playability_map
