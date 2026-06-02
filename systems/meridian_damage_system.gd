# ============================================================
# 大周天 — Meridian Damage System (经脉损伤/修复/宽度管理)
# ============================================================
# 统一管理经脉宽度的所有变化入口
# 损伤=临时变窄（流速变快但承载减半），修复=恢复原宽
# 展宽/缩窄=永久改变宽度（丹药/奇遇/境界效果）
# 阻塞=丹药临时封穴（预留接口）
# ============================================================
class_name MeridianDamageSystem
extends RefCounted


const DAMAGE_WIDTH_FACTOR: float = 0.5       # 损伤后宽度倍率
const DAMAGE_CAPACITY_FACTOR: float = 0.5    # 损伤后承载倍率
const DEFAULT_DAMAGE_TURNS: int = 3          # 默认损伤持续回合


# ============================================================
# Damage / Repair
# ============================================================

## 损伤经脉（五行碰撞导致）
static func damage_pathway(gm: Node, from_idx: int, to_idx: int, turns: int = DEFAULT_DAMAGE_TURNS) -> void:
	if gm == null or gm.base_meridian == null:
		return

	var pw: MeridianPathwayData = _find_pathway(gm, from_idx, to_idx)
	if pw == null or pw.damaged:
		return

	# 记录原始值用于恢复
	var original_width: float = pw.width
	var original_capacity: float = pw.max_capacity

	pw.damaged = true
	pw.width = original_width * DAMAGE_WIDTH_FACTOR
	pw.max_capacity = original_capacity * DAMAGE_CAPACITY_FACTOR

	# 存储元数据用于自动恢复
	gm.damaged_pathways[_pw_key(from_idx, to_idx)] = {
		"turns": turns,
		"original_width": original_width,
		"original_capacity": original_capacity,
	}

	gm.pathway_damaged.emit(from_idx, to_idx)


## 修复特定经脉
static func repair_pathway(gm: Node, from_idx: int, to_idx: int) -> void:
	if gm == null or gm.base_meridian == null:
		return

	var pw: MeridianPathwayData = _find_pathway(gm, from_idx, to_idx)
	if pw == null or not pw.damaged:
		return

	var key: String = _pw_key(from_idx, to_idx)
	var data: Dictionary = gm.damaged_pathways.get(key, {})
	var original_width: float = data.get("original_width", 1.0)
	var original_capacity: float = data.get("original_capacity", 5.0)

	pw.damaged = false
	pw.width = original_width
	pw.max_capacity = original_capacity

	gm.damaged_pathways.erase(key)
	gm.pathway_repaired.emit()


## 修复所有受损经脉
static func repair_all(gm: Node) -> void:
	if gm == null or gm.base_meridian == null:
		return

	for pw in gm.base_meridian.pathways:
		if pw.damaged:
			# 找对应的损伤记录
			var key1: String = _pw_key(pw.from_node, pw.to_node)
			var key2: String = _pw_key(pw.to_node, pw.from_node)
			var data: Dictionary = gm.damaged_pathways.get(key1, gm.damaged_pathways.get(key2, {}))
			var original_width: float = data.get("original_width", 1.0)
			var original_capacity: float = data.get("original_capacity", 5.0)

			pw.damaged = false
			pw.width = original_width
			pw.max_capacity = original_capacity

	gm.damaged_pathways.clear()
	gm.pathway_repaired.emit()


# ============================================================
# Width Modification (permanent)
# ============================================================

## 永久展宽经脉（丹药/奇遇效果）
static func widen_pathway(gm: Node, from_idx: int, to_idx: int, amount: float) -> void:
	var pw: MeridianPathwayData = _find_pathway(gm, from_idx, to_idx)
	if pw == null:
		return
	pw.width = min(3.0, pw.width + amount)
	pw.max_capacity = min(15.0, pw.max_capacity + amount * 2.0)


## 永久缩窄经脉
static func narrow_pathway(gm: Node, from_idx: int, to_idx: int, amount: float) -> void:
	var pw: MeridianPathwayData = _find_pathway(gm, from_idx, to_idx)
	if pw == null:
		return
	pw.width = max(0.2, pw.width - amount)
	pw.max_capacity = max(1.0, pw.max_capacity - amount * 2.0)


# ============================================================
# Node Block (reserved interface for elixir system)
# ============================================================

## 阻塞穴位（丹药效果 — 预留接口）
static func block_node(gm: Node, node_name: String) -> void:
	if gm == null or gm.base_meridian == null:
		return
	for node in gm.base_meridian.nodes:
		if node.name == node_name:
			node.blocked = true
			return


## 解除穴位阻塞
static func unblock_node(gm: Node, node_name: String) -> void:
	if gm == null or gm.base_meridian == null:
		return
	for node in gm.base_meridian.nodes:
		if node.name == node_name:
			node.blocked = false
			return


# ============================================================
# Tick (回合结束减损伤计时)
# ============================================================

## 回合结束：损伤计时递减，到0自动修复
static func tick_damage_timers(gm: Node) -> void:
	if gm == null:
		return

	var to_repair: Array[Dictionary] = []

	for key: String in gm.damaged_pathways.keys():
		var data: Dictionary = gm.damaged_pathways[key]
		data["turns"] = data.get("turns", 0) - 1
		if data["turns"] <= 0:
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
	for pw in gm.base_meridian.pathways:
		if (pw.from_node == from_idx and pw.to_node == to_idx) or \
		   (pw.from_node == to_idx and pw.to_node == from_idx):
			return pw
	return null


static func _pw_key(from_idx: int, to_idx: int) -> String:
	# 标准化key：小→大 在前
	if from_idx <= to_idx:
		return "%d→%d" % [from_idx, to_idx]
	return "%d→%d" % [to_idx, from_idx]
