# ============================================================
# 大周天 — DragInputHandler (拖拽输入处理 — L0)
# 职责: 卡牌拖拽检测、打出区域高亮、卡牌打出路由
# 红线: deck_manager 始终从 screen.deck_manager 读取 (延迟绑定)
# ============================================================
class_name DragInputHandler
extends RefCounted

var screen: CanvasLayer
var controller: BattleController
var play_zone: Panel
var technique_area: HBoxContainer
var hand_area: HBoxContainer
var snapshot_presenter: BattleSnapshotPresenter
var meridian_presenter: MeridianPresenter
var enemy_presenter: EnemyPresenter

var _dragged_card: CardData = null
var _is_technique_highlighted: bool = false
var _is_over_play_zone: bool = false
var _hovered_enemy_panel: PanelContainer = null


## 注入依赖 — 不注入 deck_manager (setup 时尚未初始化，由 screen.deck_manager 延迟读取)
func setup(
	p_screen: CanvasLayer,
	p_controller: BattleController,
	p_play_zone: Panel,
	p_technique_area: HBoxContainer,
	p_hand_area: HBoxContainer,
	p_snapshot_presenter: BattleSnapshotPresenter,
	p_meridian_presenter: MeridianPresenter,
	p_enemy_presenter: EnemyPresenter,
) -> void:
	screen = p_screen
	controller = p_controller
	play_zone = p_play_zone
	technique_area = p_technique_area
	hand_area = p_hand_area
	snapshot_presenter = p_snapshot_presenter
	meridian_presenter = p_meridian_presenter
	enemy_presenter = p_enemy_presenter


# ============================================================
# Process (拖拽帧更新)
# ============================================================

func process(_delta: float) -> void:
	if _dragged_card != null:
		_update_play_zone_rect()
		play_zone.visible = true
		var mouse_pos: Vector2 = screen.get_viewport().get_mouse_position()

		# 打出区域悬停高亮
		var over_play: bool = play_zone.get_global_rect().has_point(mouse_pos)
		_set_play_zone_highlight(over_play)

		# 敌人面板悬停高亮（拖拽到敌人身上）
		_update_enemy_hover(mouse_pos)

		# 功法卡拖拽 → 功法区域高亮
		if _dragged_card.card_type == CardData.CardType.TECHNIQUE:
			var tech_parent = technique_area.get_parent()
			var over_tech: bool = tech_parent.get_global_rect().has_point(mouse_pos)
			_set_technique_highlight(over_tech)
		else:
			_set_technique_highlight(false)
	else:
		play_zone.visible = false
		_set_play_zone_highlight(false)
		_set_technique_highlight(false)
		_clear_enemy_hover()


# ============================================================
# Card Drag Events
# ============================================================

func on_card_drag_started(card_data: CardData) -> void:
	_dragged_card = card_data
	## 拖拽开始 → 暂停游戏时间，让玩家从容决策
	controller.begin_interaction()


func on_card_drag_ended(card_data: CardData, _drop_area: String) -> void:
	## 拖拽结束 → 先恢复游戏时间，再处理 drop (卡牌打出需要 is_input_blocked=false)
	controller.end_interaction()
	_set_technique_highlight(false)
	_set_play_zone_highlight(false)
	play_zone.visible = false
	var handled := false
	var mouse_pos: Vector2 = screen.get_viewport().get_mouse_position()

	# -1. 拖到敌人身上 → 预选目标 + 打出卡牌（优先级最高）
	var enemy_panel := _find_enemy_under_mouse(mouse_pos)
	if enemy_panel:
		_clear_enemy_hover()
		var actor: EnemyActor = enemy_panel.get_meta("actor")
		if actor:
			_preselect_enemy_target(actor)
			handled = try_play_card(card_data)

	# 0. 打出区域 → 打出卡牌
	if not handled and play_zone.get_global_rect().has_point(mouse_pos):
		handled = try_play_card(card_data)

	# 1. 功法区域 → 挂载功法
	if not handled:
		var tech_parent: MarginContainer = technique_area.get_parent() as MarginContainer
		if tech_parent and tech_parent.get_global_rect().has_point(mouse_pos):
			if card_data.card_type == CardData.CardType.TECHNIQUE:
				var result: Dictionary = controller.activate_technique_via_card(card_data)
				if result.get("success", false):
					_refresh_all()
			handled = true

	# 2. 弃牌区域（手牌下方 50px）
	if not handled:
		var dm: DeckManager = screen.deck_manager
		var hand_rect: Rect2 = hand_area.get_global_rect()
		if mouse_pos.y > hand_rect.position.y + hand_rect.size.y + 50:
			if dm and dm.hand.has(card_data):
				controller.discard_card(card_data)
				snapshot_presenter.refresh_all(controller.build_snapshot(), dm, _build_playability_map())
			handled = true

	# 3. 无效放置 → 卡牌弹回原位
	if not handled:
		snapshot_presenter.refresh_all(controller.build_snapshot(), screen.deck_manager, _build_playability_map())

	_dragged_card = null


## 点击卡牌 — 仅用于目标选择（如锻淬流程中选择祭品卡牌）
func on_card_tapped(card_data: CardData) -> void:
	if controller.target_manager and controller.target_manager.is_selecting():
		var stype: String = controller.get_selection_type()
		if stype == "card":
			var target: Dictionary = {
				"card": card_data,
				"display_name": card_data.display_name,
				"id": card_data.id,
			}
			if not controller.target_manager.is_valid_target(target):
				return
			controller.target_manager.submit_target(target)
			return


# ============================================================
# Card Play
# ============================================================

## 尝试打出卡牌
## 返回 true 表示卡牌已打出（含进入路径选择/锻造模式），false 表示不可打出
func try_play_card(card_data: CardData) -> bool:
	if controller.is_input_blocked():
		return false

	var result: Dictionary = controller.play_card(card_data)

	if not result.get("played", false):
		return false

	# 功法卡进入路径选择模式 → 高亮可用起点，等待穴位点击
	if result.get("awaiting_pathway", false):
		## 路径选择期间暂停游戏，让玩家从容选择穴位
		controller.begin_interaction()
		meridian_presenter.highlight_available_start_nodes(screen.player_actor)
		screen.turn_label.text = "选择经脉路径: 先点击起点穴位"
		return true

	# 锻造卡进入多步选择模式 — 卡牌已消耗，刷新手牌以显示可选卡牌
	if result.get("awaiting_forge", false):
		## 锻淬选择期间暂停游戏，让玩家从容选择祭品/特性
		controller.begin_interaction()
		var forge_type: String = result.get("forge_type", "")
		if forge_type == "pass_torch":
			screen.show_forge_hint("薪火相传 — 选择祭品卡牌")
		elif forge_type == "swap_li":
			screen.show_forge_hint("离火易象 — 选择卡牌 A")
		snapshot_presenter.refresh_all(controller.build_snapshot(), screen.deck_manager, _build_playability_map())
		return true

	# UI refresh
	_refresh_all()
	_check_battle_end_display()
	return true


# ============================================================
# Highlight Helpers
# ============================================================

func _set_technique_highlight(active: bool) -> void:
	if active == _is_technique_highlighted:
		return
	_is_technique_highlighted = active
	if active:
		technique_area.modulate = GameColors.ACCENT_GOLD_BRIGHT
	else:
		technique_area.modulate = Color(1, 1, 1)


func _set_play_zone_highlight(active: bool) -> void:
	if active == _is_over_play_zone:
		return
	_is_over_play_zone = active
	if play_zone == null:
		return
	var sb := play_zone.get_theme_stylebox("panel") as StyleBoxFlat
	if sb == null:
		return
	if active:
		sb.border_color = GameColors.ACCENT_GOLD_BRIGHT
		sb.bg_color = Color(0.078, 0.086, 0.118, 0.7)
		sb.shadow_color = Color(GameColors.ACCENT_GOLD.r, GameColors.ACCENT_GOLD.g, GameColors.ACCENT_GOLD.b, 0.5)
		var label := play_zone.get_node_or_null("PlayZoneLabel") as Label
		if label:
			label.add_theme_color_override("font_color", GameColors.ACCENT_GOLD_BRIGHT)
	else:
		sb.border_color = GameColors.BORDER_GOLD
		sb.bg_color = Color(0.063, 0.071, 0.102, 0.55)
		sb.shadow_color = Color(GameColors.ACCENT_GOLD.r, GameColors.ACCENT_GOLD.g, GameColors.ACCENT_GOLD.b, 0.3)
		var label := play_zone.get_node_or_null("PlayZoneLabel") as Label
		if label:
			label.add_theme_color_override("font_color", GameColors.ACCENT_GOLD_DIM)


func _update_play_zone_rect() -> void:
	if play_zone == null:
		return
	var pw: int = UIHelpers.pct_w(UIHelpers.PLAY_ZONE_WIDTH_PCT, screen)
	var ph: int = UIHelpers.pct_h(UIHelpers.PLAY_ZONE_HEIGHT_PCT, screen)
	var vp_w: float = UIHelpers.vp_w(screen)
	var x: float = (vp_w - float(pw)) / 2.0
	var y: float = UIHelpers.pct_h(UIHelpers.PLAY_ZONE_Y_PCT, screen)
	play_zone.position = Vector2(x, y)
	play_zone.size = Vector2(float(pw), float(ph))


# ============================================================
# Internal Helpers
# ============================================================

func _refresh_all() -> void:
	snapshot_presenter.refresh_all(controller.build_snapshot(), screen.deck_manager, _build_playability_map())


func _check_battle_end_display() -> void:
	var result: int = controller.check_battle_end()
	if result == 1:
		var snap := controller.build_snapshot()
		snapshot_presenter.apply_snapshot(snap)


func _build_playability_map() -> Dictionary:
	var playability_map: Dictionary = {}
	var dm: DeckManager = screen.deck_manager
	if dm:
		for card: CardData in dm.hand:
			playability_map[card] = controller.is_card_playable(card)
	return playability_map


# ============================================================
# Enemy Drag Hover (拖拽到敌人)
# ============================================================


func _update_enemy_hover(mouse_pos: Vector2) -> void:
	if enemy_presenter == null:
		return
	var panel := _find_enemy_under_mouse(mouse_pos)
	if panel == _hovered_enemy_panel:
		return
	# 清除旧高亮
	_clear_enemy_hover()
	# 设置新高亮
	if panel:
		_hovered_enemy_panel = panel
		_hovered_enemy_panel.self_modulate = Color(1.0, 1.0, 0.6, 1.0)  # 淡金色


func _clear_enemy_hover() -> void:
	if _hovered_enemy_panel:
		_hovered_enemy_panel.self_modulate = Color.WHITE
		_hovered_enemy_panel = null


func _find_enemy_under_mouse(mouse_pos: Vector2) -> PanelContainer:
	if enemy_presenter == null:
		return null
	for panel: PanelContainer in enemy_presenter._enemy_panel_map.values():
		if panel.get_global_rect().has_point(mouse_pos):
			return panel
	return null


func _preselect_enemy_target(actor: EnemyActor) -> void:
	var target: Dictionary = {
		"actor": actor,
		"hp": actor.hp,
		"block": actor.current_block,
	}
	controller.target_manager.set_preselected(target)
