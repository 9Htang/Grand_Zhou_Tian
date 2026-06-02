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


# ============================================================
# GameManager Sync (战斗开始/结束时调用)
# ============================================================

## 从 GameManager 加载状态到 PlayerActor（战斗开始时调用）
func load_from_gm() -> void:
	hp = GameManager.player_hp
	max_hp = GameManager.player_max_hp
	dantian_qi = GameManager.dantian_qi
	dantian_capacity = GameManager.dantian_capacity
	qi_gather_rate = GameManager.qi_gather_rate
	dantian_pressure = GameManager.dantian_pressure
	current_block = GameManager.current_block
	realm = GameManager.realm
	talent = GameManager.talent
	active_techniques = GameManager.active_techniques.duplicate()
	active_buffs = GameManager.active_buffs.duplicate()
	base_meridian = GameManager.base_meridian
	active_circuits = GameManager.active_circuits.duplicate()
	erosion_targets = GameManager.erosion_targets.duplicate()
	erosion_bonuses = GameManager.erosion_bonuses.duplicate()
	qi_gather_bonuses = GameManager.qi_gather_bonuses.duplicate()
	is_flow_dry = GameManager.is_flow_dry
	node_base_buffs = GameManager.node_base_buffs.duplicate()
	damaged_pathways = GameManager.damaged_pathways.duplicate()
	gold = GameManager.gold
	cultivation = GameManager.cultivation
	cultivation_to_next = GameManager.cultivation_to_next
	technique_pathways = GameManager.technique_pathways.duplicate()
	master_deck = GameManager.master_deck.duplicate()


## 将 PlayerActor 状态写回 GameManager（战斗结束时调用）
func save_to_gm() -> void:
	GameManager.player_hp = hp
	GameManager.player_max_hp = max_hp
	GameManager.dantian_qi = dantian_qi
	GameManager.dantian_capacity = dantian_capacity
	GameManager.qi_gather_rate = qi_gather_rate
	GameManager.dantian_pressure = dantian_pressure
	GameManager.current_block = current_block
	GameManager.realm = realm
	GameManager.talent = talent
	GameManager.active_techniques = active_techniques.duplicate()
	GameManager.active_buffs = active_buffs.duplicate()
	GameManager.base_meridian = base_meridian
	GameManager.active_circuits = active_circuits.duplicate()
	GameManager.erosion_targets = erosion_targets.duplicate()
	GameManager.erosion_bonuses = erosion_bonuses.duplicate()
	GameManager.qi_gather_bonuses = qi_gather_bonuses.duplicate()
	GameManager.is_flow_dry = is_flow_dry
	GameManager.node_base_buffs = node_base_buffs.duplicate()
	GameManager.damaged_pathways = damaged_pathways.duplicate()
	GameManager.gold = gold
	GameManager.cultivation = cultivation
	GameManager.cultivation_to_next = cultivation_to_next
	GameManager.technique_pathways = technique_pathways.duplicate()
	GameManager.master_deck = master_deck.duplicate()
