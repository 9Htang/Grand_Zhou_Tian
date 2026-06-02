# ============================================================
# 大周天 — PlayerActor (玩家战斗角色)
# 继承 CombatActor，添加玩家专属状态与方法
# ============================================================
class_name PlayerActor
extends CombatActor


# === Signals ===
signal gold_changed(new_gold: int)
signal cultivation_changed(current: int, needed: int)
signal realm_changed(new_realm: int)
signal card_added(card_id: String)
signal card_removed(card_id: String)


# === Player Stats ===
var gold: int = 0
var cultivation: int = 0
var cultivation_to_next: int = 100

# === Deck ===
var master_deck: Array[String] = []


# ============================================================
# Deck
# ============================================================

func add_card_to_deck(card_id: String) -> void:
	master_deck.append(card_id)
	card_added.emit(card_id)


func remove_card(card_id: String) -> void:
	if card_id == "random":
		if master_deck.is_empty():
			return
		var idx := randi() % master_deck.size()
		var removed: String = master_deck[idx]
		master_deck.remove_at(idx)
		card_removed.emit(removed)
	else:
		var idx := master_deck.find(card_id)
		if idx >= 0:
			master_deck.remove_at(idx)
			card_removed.emit(card_id)


func upgrade_card(card_id: String) -> void:
	if card_id == "random":
		if master_deck.is_empty():
			return
		var idx := randi() % master_deck.size()
		var id := master_deck[idx]
		if not id.ends_with("+"):
			master_deck[idx] = id + "+"
	else:
		var idx := master_deck.find(card_id)
		if idx >= 0 and not card_id.ends_with("+"):
			master_deck[idx] = card_id + "+"


func transform_random_card() -> void:
	if master_deck.is_empty():
		return
	var idx := randi() % master_deck.size()
	var pool: Array[String] = CardDatabase.get_all_card_ids()
	pool.erase(master_deck[idx])
	if pool.is_empty():
		return
	master_deck[idx] = pool[randi() % pool.size()]


func duplicate_random_card() -> void:
	if master_deck.is_empty():
		return
	var idx := randi() % master_deck.size()
	master_deck.append(master_deck[idx])


# ============================================================
# Cultivation
# ============================================================

func add_cultivation(amount: int) -> void:
	cultivation += amount
	cultivation_changed.emit(cultivation, cultivation_to_next)
	if cultivation >= cultivation_to_next:
		# Signal for breakthrough
		pass


func trigger_breakthrough() -> void:
	cultivation -= cultivation_to_next
	cultivation_to_next = int(float(cultivation_to_next) * 1.5)
	realm += 1
	realm_changed.emit(realm)
	cultivation_changed.emit(cultivation, cultivation_to_next)
