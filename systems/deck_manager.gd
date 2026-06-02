# ============================================================
# 大周天 — Deck Manager (牌库/手牌/弃牌堆管理)
# ============================================================
class_name DeckManager
extends RefCounted

var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
var exhaust_pile: Array[CardData] = []

## 累积的抽牌惩罚，下回合生效（取消功法/持续技能时增加）
var pending_draw_penalty: int = 0

## 卡牌触发器路由器引用（可选），在区域转换时通知卡牌生命周期事件
## 由 BattleController 在 start_battle() 时注入
var trigger_router: Object = null


func initialize(card_ids: Array[String]) -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	pending_draw_penalty = 0

	for id in card_ids:
		var card := CardDatabase.get_card(id)
		if card:
			draw_pile.append(card)
	draw_pile.shuffle()


func draw_cards(count: int) -> Array[CardData]:
	var drawn: Array[CardData] = []
	for _i in range(count):
		if draw_pile.is_empty():
			_reshuffle_discard()
		if not draw_pile.is_empty():
			var card: CardData = draw_pile.pop_front()
			hand.append(card)
			drawn.append(card)
			_notify_drawn(card)
	return drawn


func draw_to_hand_size(target: int) -> Array[CardData]:
	var to_draw := target - hand.size()
	if to_draw <= 0:
		return []
	return draw_cards(to_draw)


func play_card(card: CardData) -> void:
	var idx := hand.find(card)
	if idx >= 0:
		hand.remove_at(idx)
		_notify_hand_leave(card)
	discard_pile.append(card)
	_notify_discarded(card)


func exhaust_card(card: CardData) -> void:
	var idx := hand.find(card)
	if idx >= 0:
		hand.remove_at(idx)
		_notify_hand_leave(card)
	exhaust_pile.append(card)
	_notify_exhausted(card)


func discard_hand() -> void:
	# 在移入手牌前通知每张卡牌离开手牌并进入弃牌堆
	for card: CardData in hand:
		_notify_hand_leave(card)
		_notify_discarded(card)
	discard_pile.append_array(hand)
	hand.clear()


# ============================================================
# Cancel Mechanics (功法 / 持续技能)
# ============================================================

## 取消运行中的功法：功法卡回抽牌堆，下回合抽牌数 -1
func cancel_technique(card: CardData) -> void:
	draw_pile.append(card)
	pending_draw_penalty += 1


## 取消持续增益技能：技能卡回抽牌堆，下回合抽牌数 -1
func cancel_persistent_skill(card: CardData) -> void:
	draw_pile.append(card)
	pending_draw_penalty += 1


## 是否还有可用的抽牌配额（考虑惩罚后）
func can_cancel(base_draw: int) -> bool:
	return (base_draw - pending_draw_penalty) > 0


## 应用抽牌惩罚后的实际抽牌数
func get_effective_draw_count(base_count: int) -> int:
	return max(0, base_count - pending_draw_penalty)


## 回合开始时清空抽牌惩罚（已在新抽牌数中体现）
func clear_draw_penalty() -> void:
	pending_draw_penalty = 0


## 获取抽牌堆数量
func get_draw_pile_count() -> int:
	return draw_pile.size()


func get_discard_count() -> int:
	return discard_pile.size()


func get_hand_size() -> int:
	return hand.size()


# ============================================================
# Trigger Notifications
# ============================================================


func _notify_drawn(card: CardData) -> void:
	if trigger_router and trigger_router.has_method("on_card_drawn"):
		trigger_router.on_card_drawn(card)


func _notify_discarded(card: CardData) -> void:
	if trigger_router and trigger_router.has_method("on_card_discarded"):
		trigger_router.on_card_discarded(card)


func _notify_exhausted(card: CardData) -> void:
	if trigger_router and trigger_router.has_method("on_card_exhausted"):
		trigger_router.on_card_exhausted(card)


func _notify_hand_leave(card: CardData) -> void:
	if trigger_router and trigger_router.has_method("on_hand_leave"):
		trigger_router.on_hand_leave(card)


func _reshuffle_discard() -> void:
	if discard_pile.is_empty():
		return
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	draw_pile.shuffle()
