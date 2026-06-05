# ============================================================
# 大周天 — MeridianDamageSystem (经脉损伤/修复/宽度管理 — L2)
# 即时制改造: 新增 tick_damage_timers_delta(按秒衰减)
# ============================================================
class_name MeridianDamageSystem
extends RefCounted


const DAMAGE_WIDTH_FACTOR: float = 0.5
const DAMAGE_CAPACITY_FACTOR: float = 0.5
const DEFAULT_DAMAGE_TURNS: int = 3


# ============================================================
# Damage / Repair
# ============================================================

static func damage_pathway(gm: Node, from_idx: int, to_idx: int, turns: int = DEFAULT_DAMAGE_TURNS) -> void:
	if gm == null or gm.base_meridian == null:
		return

	var pw: MeridianPathwayData = _find_pathway(gm, from_idx, to_idx)
	if pw == null or pw.damaged:
		return

	var original_width: float = pw.width
	var original_capacity: float = pw.max_capacity

	pw.damaged = true
	pw.width = original_width * DAMAGE_WIDTH_FACTOR
	pw.max_capacity = original_capacity * DAMAGE_CAPACITY_FACTOR

	gm.damaged_pathways[_pw_key(from_idx, to_idx)] = {
		"turns": turns,
		"original_width": original_width,
		"original_capacity": original_capacity,
	}

	gm.pathway_damaged.emit(from_idx, to_idx)


static func repair_pathway(gm: Node, from_idx: int, to_idx: int) -> void:
	if gm == null or gm.base_meridian == null:
		return

	var pw: MeridianPathwayData = _find_pathway(gm, from_idx, to_idx)
	if pw == null or not pw.damaged:
		return

	var key: String = _pw_key(from_idx, to_idx)
	var data: Dictionary = gm.damaged_pathways.get(key, {})
	var original_width: float = data.get("original_width", 1.0)
	var original_capacity: float = data.get("original_capacity", pw.base_capacity)

	pw.damaged = false
	pw.width = original_width
	pw.max_capacity = original_capacity

	gm.damaged_pathways.erase(key)
	gm.pathway_repaired.emit()


static func repair_all(gm: Node) -> void:
	if gm == null or gm.base_meridian == null:
		return

	for pw in gm.base_meridian.pathways:
		if pw.damaged:
			var key1: String = _pw_key(pw.from_node, pw.to_node)
			var key2: String = _pw_key(pw.to_node, pw.from_node)
			var data: Dictionary = gm.damaged_pathways.get(key1, gm.damaged_pathways.get(key2, {}))
			var original_width: float = data.get("original_width", 1.0)
			var original_capacity: float = data.get("original_capacity", pw.base_capacity)

			pw.damaged = false
			pw.width = original_width
			pw.max_capacity = original_capacity

	gm.damaged_pathways.clear()
	gm.pathway_repaired.emit()


# ============================================================
# Width Modification (permanent)
# ============================================================

static func widen_pathway(gm: Node, from_idx: int, to_idx: int, amount: float) -> void:
	var pw: MeridianPathwayData = _find_pathway(gm, from_idx, to_idx)
	if pw == null:
		return
	pw.width = min(3.0, pw.width + amount)
	pw.max_capacity = min(15.0, pw.max_capacity + amount * 2.0)


static func narrow_pathway(gm: Node, from_idx: int, to_idx: int, amount: float) -> void:
	var pw: MeridianPathwayData = _find_pathway(gm, from_idx, to_idx)
	if pw == null:
		return
	pw.width = max(0.2, pw.width - amount)
	pw.max_capacity = max(1.0, pw.max_capacity - amount * 2.0)


# ============================================================
# Node Block
# ============================================================

static func block_node(gm: Node, node_name: String) -> void:
	if gm == null or gm.base_meridian == null:
		return
	for node in gm.base_meridian.nodes:
		if node.name == node_name:
			node.blocked = true
			return


static func unblock_node(gm: Node, node_name: String) -> void:
	if gm == null or gm.base_meridian == null:
		return
	for node in gm.base_meridian.nodes:
		if node.name == node_name:
			node.blocked = false
			return


# ============================================================
# Tick (损伤计时衰减)
# ============================================================

## 旧接口: 回合减速减 (保留兼容 — 1回合 = 5秒)
static func tick_damage_timers(gm: Node) -> void:
	tick_damage_timers_delta(gm, 5.0)


## 即时制: 按秒数递减损伤计时
static func tick_damage_timers_delta(gm: Node, delta: float) -> void:
	if gm == null:
		return

	var to_repair: Array[Dictionary] = []

	for key: String in gm.damaged_pathways.keys():
		var data: Dictionary = gm.damaged_pathways[key]
		var remaining: float = float(data.get("turns", 0))
		remaining = max(0.0, remaining - delta)
		data["turns"] = remaining
		if remaining <= 0.0:
			to_repair.append({"key": key, "data": data})

	for item in to_repair:
		var data: Dictionary = item["data"]
		var parts: PackedStringArray = item["key"].split("→")
		if parts.size() == 2:
			var from_idx: int = int(parts[0])
			var to_idx: int = int(parts[1])
			repair_pathway(gm, from_idx, to_idx)


# ============================================================
# Helpers
# ============================================================

static func _find_pathway(gm: Node, from_idx: int, to_idx: int) -> MeridianPathwayData:
	if gm == null or gm.base_meridian == null:
		return null
	return gm.base_meridian.find_pathway(from_idx, to_idx)


static func _pw_key(from_idx: int, to_idx: int) -> String:
	if from_idx <= to_idx:
		return "%d→%d" % [from_idx, to_idx]
	return "%d→%d" % [to_idx, from_idx]
