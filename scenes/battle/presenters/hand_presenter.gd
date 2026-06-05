# ============================================================
# 大周天 — HandPresenter (手牌展示 — L0)
# 职责: hand_area 的差分刷新，CardUI 节点的创建/复用/信号接线
# 红线: 不调 controller, playability 由 BattleScreen 预计算传入
# ============================================================
class_name HandPresenter
extends RefCounted

## 手牌容器
var hand_area: HBoxContainer
## 卡牌点击回调
var _on_card_clicked: Callable
## 卡牌拖拽开始回调
var _on_card_drag_started: Callable
## 卡牌拖拽结束回调
var _on_card_drag_ended: Callable
## 沙盒面板引用 (用于无限灵气检测)
var _sandbox_enabled: bool = false
var _sandbox_panel: CanvasLayer = null


## 注入依赖
func setup(
	p_hand_area: HBoxContainer,
	p_on_card_clicked: Callable,
	p_on_card_drag_started: Callable,
	p_on_card_drag_ended: Callable,
	p_sandbox_enabled: bool = false,
	p_sandbox_panel: CanvasLayer = null,
) -> void:
	hand_area = p_hand_area
	_on_card_clicked = p_on_card_clicked
	_on_card_drag_started = p_on_card_drag_started
	_on_card_drag_ended = p_on_card_drag_ended
	_sandbox_enabled = p_sandbox_enabled
	_sandbox_panel = p_sandbox_panel


## 刷新卡牌手牌 UI — 全量重建 (避免 diff 复用导致 tween/card_data 竞态)
## playability_map: Dictionary[CardData, bool] — 由 BattleScreen 预计算
func refresh_hand(snap: BattleSnapshot, deck_manager: DeckManager, playability_map: Dictionary) -> void:
	if deck_manager == null:
		return

	var hand_cards: Array = deck_manager.hand
	var infinite_qi: bool = _sandbox_enabled and _sandbox_panel != null and _sandbox_panel.is_infinite_qi()

	# 全量清空旧节点 (避免 card_data 错位 / tween 残留)
	for child in hand_area.get_children():
		hand_area.remove_child(child)
		child.queue_free()

	# 为每张手牌创建全新 CardUI
	for card: CardData in hand_cards:
		var playable: bool = snap.is_selecting_cards or infinite_qi or playability_map.get(card, false)
		var card_ui := PanelContainer.new()
		var sc: GDScript = load("res://scenes/card/card_ui.gd") as GDScript
		card_ui.set_script(sc)
		card_ui.card_data = card
		card_ui.set_playable(playable)
		card_ui.card_clicked.connect(_on_card_clicked)
		card_ui.card_drag_started.connect(_on_card_drag_started)
		card_ui.card_drag_ended.connect(_on_card_drag_ended)
		hand_area.add_child(card_ui)


## 清空手牌
func clear_hand() -> void:
	for child in hand_area.get_children():
		hand_area.remove_child(child)
		child.queue_free()
