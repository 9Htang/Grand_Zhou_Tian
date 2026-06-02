# ============================================================
# 大周天 — Game Manager (全局游戏状态)
# ============================================================
extends Node

## 测试模式：设为 true 启动后直接进入战斗，跳过菜单流程
# === Signals ===
signal hp_changed(new_hp: int, max_hp: int)
signal qi_changed(new_qi: int, max_qi: int)
signal gold_changed(new_gold: int)
signal technique_activated(technique: TechniqueData)
signal technique_deactivated(technique: TechniqueData)
signal persistent_skill_added(card: CardData)
signal persistent_skill_removed(card: CardData)
signal equipment_changed(slot: int)
signal curio_added(curio: CurioData)
signal curio_removed(curio: CurioData)
signal card_added(card_id: String)
signal card_removed(card_id: String)
signal node_unlocked(node_name: String)
signal pathway_damaged(from_node: int, to_node: int)
signal pathway_repaired()
signal buffs_updated(buffs: Array)
signal cultivation_changed(current: int, needed: int)
signal realm_changed(new_realm: int)
signal circuit_formed(circuit: Dictionary)
signal circuit_broken(circuit: Dictionary)
# signal flow_updated() — reserved for future flow animation hooks
signal erosion_targets_changed()

# === Core Resources ===
var dantian_qi: int = 5
var dantian_capacity: int = 10
var qi_gather_rate: int = 3

# === Player Stats ===
var player_hp: int = 80
var player_max_hp: int = 80
var realm: int = 1
var talent: int = 2
var cultivation: int = 0
var cultivation_to_next: int = 100
var gold: int = 0

# === Battle State ===
var current_block: int = 0
var active_buffs: Array = []           # Array[TechniqueResolver.ResolvedBuff]
var active_techniques: Array[TechniqueData] = []
## 功法→路径绑定: {technique_id: {"from": int, "to": int}}
var technique_pathways: Dictionary = {}

# === Meridian State ===
var base_meridian: MeridianMapData = null
var damaged_pathways: Dictionary = {}   # Dictionary{turns, original_width, original_capacity} managed by MeridianDamageSystem
var node_base_buffs: Dictionary = {}    # {"node_name": "buff_string"}

# === Fluid Meridian State ===
var dantian_pressure: float = 5.0         # 丹田当前压强
var base_pressure: float = 5.0            # 基础压强（境界决定）
var active_circuits: Array[Dictionary] = []  # 当前活跃回路
var circuit_bonus_multiplier: float = 1.0 # 回路回灌倍率
var is_flow_dry: bool = true              # 经脉网络灵气是否已干涸
var erosion_targets: Array[int] = []       # 当前回合标记的冲刷目标(穴位索引)
var erosion_bonuses: Dictionary = {}        # 冲刷上限加成: {source_id: amount} 来源: 法宝/丹药/buff
var qi_gather_bonuses: Dictionary = {}      # 聚气加成: {source_id: amount} 来源: 法宝/丹药/buff/效果

# === Deck ===
var master_deck: Array[String] = []     # CardData IDs (persistent between battles)
var artifacts: Array[ArtifactData] = []

# === Equipment ===
## 装备槽位: Dictionary{int → EquipmentData}, key=Slot enum
var equipment: Dictionary = {}

# === Curios ===
var curios: Array[CurioData] = []

# === Persistent Skills (持续增益技能) ===
## 当前激活的持续增益技能卡牌列表
var persistent_skills: Array[CardData] = []

# === Run State ===
var current_chapter: int = 1
var current_encounter_index: int = 0
var turn_count: int = 0
var current_map_node_index: int = 0              # 当前所在地图节点
var current_chapter_data: ChapterData = null      # 当前章节数据



# ============================================================
# Lifecycle
# ============================================================

func _ready() -> void:
	# Load and reset default meridian
	if base_meridian == null:
		base_meridian = MeridianRegistry.get_meridian("small_circuit")
	_reset_meridian_state()


# ============================================================
# New Run
# ============================================================

func start_new_run(starting_technique_id: String = "") -> void:
	player_hp = 80
	player_max_hp = 80
	dantian_qi = 5
	dantian_capacity = 10
	qi_gather_rate = 3
	realm = 1
	talent = 2
	cultivation = 0
	cultivation_to_next = 100
	gold = 0
	current_block = 0

	active_techniques.clear()
	technique_pathways.clear()
	active_buffs.clear()
	artifacts.clear()
	equipment.clear()
	curios.clear()
	persistent_skills.clear()
	damaged_pathways.clear()
	node_base_buffs.clear()
	active_circuits.clear()
	erosion_targets.clear()
	erosion_bonuses.clear()
	qi_gather_bonuses.clear()

	dantian_pressure = 5.0
	base_pressure = 5.0
	circuit_bonus_multiplier = 1.0
	is_flow_dry = true

	current_chapter = 1
	current_encounter_index = 0
	turn_count = 0
	current_map_node_index = 0
	current_chapter_data = null

	# Default deck
	master_deck = [
		"attack_basic", "attack_basic", "attack_basic", "attack_basic",
		"defense_basic", "defense_basic", "defense_basic",
		"qi_gathering", "healing_breeze",
	]

	# Default meridian
	base_meridian = MeridianRegistry.get_meridian("small_circuit")
	_reset_meridian_state()

	# Start technique if provided
	if not starting_technique_id.is_empty():
		var tech: TechniqueData = TechniqueDatabase.get_technique(starting_technique_id)
		if tech:
			active_techniques.append(tech)
		# Add technique cards to deck
		for _i in range(2):
			master_deck.append("technique_" + starting_technique_id)

	# Clear run-scoped meta to prevent cross-run leakage
	for key in ["rest_bonus_qi"]:
		if has_meta(key):
			remove_meta(key)

	hp_changed.emit(player_hp, player_max_hp)
	qi_changed.emit(dantian_qi, dantian_capacity)


# ============================================================
# HP
# ============================================================

func heal(amount: int) -> void:
	player_hp = min(player_max_hp, player_hp + amount)
	hp_changed.emit(player_hp, player_max_hp)


func take_damage(amount: int) -> void:
	var remaining: int = amount
	if current_block > 0:
		var blocked: int = min(remaining, current_block)
		current_block -= blocked
		remaining -= blocked
	player_hp = max(0, player_hp - remaining)
	hp_changed.emit(player_hp, player_max_hp)
	ArtifactManager.on_damage_taken(self, amount)


func increase_max_hp(amount: int) -> void:
	player_max_hp += amount
	player_hp += amount
	hp_changed.emit(player_hp, player_max_hp)


# ============================================================
# Qi
# ============================================================

func add_qi(amount: int) -> void:
	dantian_qi = min(dantian_capacity, dantian_qi + amount)
	qi_changed.emit(dantian_qi, dantian_capacity)


func spend_qi(amount: int) -> bool:
	if dantian_qi < amount:
		return false
	dantian_qi -= amount
	qi_changed.emit(dantian_qi, dantian_capacity)
	return true


func emit_qi_changed() -> void:
	qi_changed.emit(dantian_qi, dantian_capacity)


# ============================================================
# Technique
# ============================================================

func activate_technique(tech: TechniqueData) -> void:
	if active_techniques.has(tech):
		return
	if active_techniques.size() >= talent:
		return  # Would need to replace (handled by UI)
	active_techniques.append(tech)
	technique_activated.emit(tech)


func deactivate_technique(tech: TechniqueData) -> void:
	active_techniques.erase(tech)
	technique_deactivated.emit(tech)


func replace_technique(old: TechniqueData, new: TechniqueData) -> void:
	var idx: int = active_techniques.find(old)
	if idx >= 0:
		active_techniques[idx] = new
		technique_deactivated.emit(old)
		technique_activated.emit(new)


# ============================================================
# Meridian
# ============================================================

func unlock_meridian_node(node_name: String) -> void:
	if base_meridian == null:
		return
	if node_name == "random":
		var locked: Array[int] = []
		for i in base_meridian.nodes.size():
			if not base_meridian.nodes[i].unlocked:
				locked.append(i)
		if locked.is_empty():
			return
		var idx := locked[randi() % locked.size()]
		base_meridian.nodes[idx].unlocked = true
		node_unlocked.emit(base_meridian.nodes[idx].name)
	else:
		for node in base_meridian.nodes:
			if node.name == node_name and not node.unlocked:
				node.unlocked = true
				node_unlocked.emit(node_name)
				return


## Bug 5 fix: delegate to MeridianDamageSystem for consistent data format
func damage_pathway(from_idx: int, to_idx: int, turns: int = 3) -> void:
	MeridianDamageSystem.damage_pathway(self, from_idx, to_idx, turns)


func repair_pathway(path_key: String) -> void:
	damaged_pathways.erase(path_key)
	pathway_repaired.emit()


func repair_random_pathway() -> void:
	if damaged_pathways.is_empty():
		return
	var keys: Array = damaged_pathways.keys()
	damaged_pathways.erase(keys[randi() % keys.size()])
	pathway_repaired.emit()


func repair_all_pathways() -> void:
	damaged_pathways.clear()
	pathway_repaired.emit()


func get_node_base_buff(node_name: String) -> String:
	return node_base_buffs.get(node_name, "")


func set_node_base_buff(node_name: String, buff: String) -> void:
	node_base_buffs[node_name] = buff


# ============================================================
# Erosion Targets (冲刷目标)
# ============================================================

## 获取当前最大同时冲刷数量（天资 + 法宝 + 丹药 + buff 加成）
func get_max_erosion_targets() -> int:
	var total: int = talent
	for bonus in erosion_bonuses.values():
		total += int(bonus)
	return max(0, total)


## 添加冲刷上限加成（source_id 用于去重: "artifact:xxx", "elixir:yyy", "buff:zzz"）
func add_erosion_bonus(source_id: String, amount: int) -> void:
	erosion_bonuses[source_id] = amount


## 移除冲刷上限加成
func remove_erosion_bonus(source_id: String) -> void:
	erosion_bonuses.erase(source_id)


# ============================================================
# Qi Gather Bonus (聚气加成)
# ============================================================

## 获取当前聚气总加成
func get_qi_gather_bonuses() -> int:
	var total: int = 0
	for v in qi_gather_bonuses.values():
		total += int(v)
	return total


## 添加聚气加成（source_id 用于去重: "artifact:xxx", "elixir:yyy", "effect"）
func add_qi_gather_bonus(source_id: String, amount: int) -> void:
	qi_gather_bonuses[source_id] = amount


## 移除聚气加成
func remove_qi_gather_bonus(source_id: String) -> void:
	qi_gather_bonuses.erase(source_id)


func toggle_erosion_target(node_idx: int) -> bool:
	var existing: int = erosion_targets.find(node_idx)
	if existing >= 0:
		erosion_targets.remove_at(existing)
		erosion_targets_changed.emit()
		return false  # 已移除
	if erosion_targets.size() >= get_max_erosion_targets():
		return false  # 已达上限
	erosion_targets.append(node_idx)
	erosion_targets_changed.emit()
	return true  # 已添加


func clear_erosion_targets() -> void:
	erosion_targets.clear()
	erosion_targets_changed.emit()


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
# Artifacts
# ============================================================

func gain_artifact(artifact_id: String) -> void:
	var art: ArtifactData = ArtifactRegistry.get_artifact(artifact_id)
	if art:
		artifacts.append(art)


func gain_random_artifact() -> void:
	var pool: Array[ArtifactData] = ArtifactRegistry.get_all_artifacts()
	if pool.is_empty():
		return
	artifacts.append(pool[randi() % pool.size()])


# ============================================================
# Divine Sense (神识)
# ============================================================

## 神识 = 境界基础 + 天赋加成 + 装备加成
func get_divine_sense() -> int:
	var base: int = realm * 2
	var talent_bonus: int = talent
	var equip_bonus: int = 0
	for eq: EquipmentData in equipment.values():
		if eq:
			equip_bonus += eq.divine_sense_bonus
	return base + talent_bonus + equip_bonus


## 当前法宝占用数量
func get_artifact_slot_used() -> int:
	return artifacts.size() + curios.size()


## 法宝槽位是否已满
func is_artifact_slot_full() -> bool:
	return get_artifact_slot_used() >= get_divine_sense()


# ============================================================
# Equipment
# ============================================================

func equip(item: EquipmentData) -> bool:
	if equipment.has(item.slot):
		return false  # 槽位已占用，需先卸下
	equipment[item.slot] = item
	equipment_changed.emit(item.slot)
	return true


func unequip(slot: int) -> EquipmentData:
	if not equipment.has(slot):
		return null
	var item: EquipmentData = equipment[slot]
	equipment.erase(slot)
	equipment_changed.emit(slot)
	return item


func get_equipment(slot: int) -> EquipmentData:
	return equipment.get(slot)


# ============================================================
# Curios
# ============================================================

func add_curio(curio: CurioData) -> bool:
	if is_artifact_slot_full():
		return false
	curios.append(curio)
	curio_added.emit(curio)
	return true


func remove_curio(curio: CurioData) -> void:
	curios.erase(curio)
	curio_removed.emit(curio)


# ============================================================
# Persistent Skills
# ============================================================

func add_persistent_skill(card: CardData) -> void:
	persistent_skills.append(card)
	persistent_skill_added.emit(card)


func remove_persistent_skill(card: CardData) -> void:
	persistent_skills.erase(card)
	persistent_skill_removed.emit(card)


# ============================================================
# Buffs
# ============================================================

func add_buff(buff_str: String) -> void:
	var parts: PackedStringArray = buff_str.split(":")
	if parts.size() < 2:
		return
	var buff := TechniqueResolver.ResolvedBuff.new()
	buff.name = parts[0]
	buff.value = int(parts[1])
	buff.source = "card"
	active_buffs.append(buff)
	buffs_updated.emit(active_buffs)


func clear_technique_buffs() -> void:
	# 清除冲穴生成的 buff（source="technique"），保留卡牌 buff
	var kept: Array = []
	for buff in active_buffs:
		if buff.source != "technique":
			kept.append(buff)
	active_buffs = kept
	buffs_updated.emit(active_buffs)


func clear_card_buffs() -> void:
	# 清除卡牌生成的 buff（source="card"），在 TURN_END 时调用
	var kept: Array = []
	for buff in active_buffs:
		if buff.source != "card":
			kept.append(buff)
	active_buffs = kept
	buffs_updated.emit(active_buffs)


# ============================================================
# Cultivation
# ============================================================

func add_cultivation(amount: int) -> void:
	cultivation += amount
	cultivation_changed.emit(cultivation, cultivation_to_next)
	if cultivation >= cultivation_to_next:
		# Signal for breakthrough
		pass


# Reset meridian to default state (only dantian unlocked, no qi/properties/blocked)
func _reset_meridian_state() -> void:
	if base_meridian == null:
		return
	var dantian_idx: int = base_meridian.dantian_node_index
	for i: int in base_meridian.nodes.size():
		var node: MeridianNodeData = base_meridian.nodes[i]
		if node:
			node.unlocked = (i == dantian_idx)
			node.current_qi = 0.0
			node.erosion_progress = 0.0
			node.technique_qi = {}
			node.properties.clear()
			node.blocked = false
	for pw in base_meridian.pathways:
		if pw:
			pw.current_qi = 0.0
			pw.technique_qi = {}
			pw.damaged = false
			pw.blocked = false



func trigger_breakthrough() -> void:
	cultivation -= cultivation_to_next
	cultivation_to_next = int(float(cultivation_to_next) * 1.5)
	realm += 1
	realm_changed.emit(realm)
	cultivation_changed.emit(cultivation, cultivation_to_next)
