# ============================================================
# 大周天 — DeckManager (牌库/手牌/弃牌堆管理 — L2, 即时制)
# ============================================================
# 即时制改造:
#   - 删除 draw_penalty / cancel_penalty / get_effective_draw_count
#   - play_card 接入 CooldownManager (hand → cooldown)
#   - 冷却过期 → discard_pile (自动循环)
#   - discard_hand → 不再需要 (手牌持久)
#   - 新增 discard_single / return_to_hand
# ============================================================
class_name DeckManager
extends RefCounted


var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
var exhaust_pile: Array[CardData] = []

## 卡牌触发器路由器引用 (可选)
var trigger_router: Object = null

## 冷却管理引用 (由 Bootstrapper 注入)
var cooldown_manager: CooldownManager = null

## 确定性 RNG（由 Bootstrapper 注入，null = 使用全局 randi/shuffle）
var rng: DeterministicRNG = null


func initialize(card_ids: Array[String]) -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()

	for id in card_ids:
		var card := CardDatabase.get_card(id)
		if card:
			draw_pile.append(card.duplicate())
	if rng:
		rng.shuffle(draw_pile)
	else:
		draw_pile.shuffle()


## 从抽牌堆抽 count 张到手牌
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


## 打出卡牌: hand → cooldown
## card_key: 用于 CooldownManager 的唯一标识
func play_card(card: CardData) -> void:
	var idx := hand.find(card)
	if idx >= 0:
		hand.remove_at(idx)
		_notify_hand_leave(card)

	# 放入冷却 (默认 3 秒, 从 CardData 读取)
	var cd: float = card.get("cooldown_seconds") if card.get("cooldown_seconds") != null else 3.0
	if cooldown_manager:
		cooldown_manager.put_on_cooldown(card.resource_path, cd)


## 冷却过期回调: card_key → discard_pile
func on_cooldown_expired(card_key: String) -> void:
	# 从数据库加载卡牌数据并放入弃牌堆
	var card: CardData = CardDatabase.get_card(card_key)
	if card:
		discard_pile.append(card.duplicate())
		_notify_discarded(card)


## 耗竭卡牌: hand → exhaust_pile (永久移除)
func exhaust_card(card: CardData) -> void:
	var idx := hand.find(card)
	if idx >= 0:
		hand.remove_at(idx)
		_notify_hand_leave(card)
	exhaust_pile.append(card)
	_notify_exhausted(card)


## 弃掉单张手牌: hand → discard_pile
func discard_single(card: CardData) -> void:
	var idx := hand.find(card)
	if idx >= 0:
		hand.remove_at(idx)
		_notify_hand_leave(card)
	discard_pile.append(card)
	_notify_discarded(card)


## 将卡牌退回手牌 (取消功法等)
func return_to_hand(card: CardData) -> void:
	hand.append(card)


## 处理冷却过期 (由 BattleController._on_clock_tick 调用)
func process_expired_cooldowns(expired_keys: Array[String]) -> void:
	for key in expired_keys:
		on_cooldown_expired(key)


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
	if rng:
		rng.shuffle(draw_pile)
	else:
		draw_pile.shuffle()
