# ============================================================
# 大周天 — WeightedRandom (加权随机选择)
# ============================================================
# 通用工具 — 从加权数组中按权重随机选取一项
# 适用场景: 事件随机结果 / 怪物掉落 / 卡包抽卡 / Boss奖励
# 支持 Dictionary 数组和 Resource (Object) 数组
# ============================================================
class_name WeightedRandom
extends RefCounted


## 从加权数组中随机选取一项
## array: 包含带权重字段的项，每项可以是 Dictionary 或 Object (Resource)
## weight_key: 权重字段名，默认 "weight"
## 返回选中的 Dictionary（Resource 也会被转换为 Dictionary），
## 如果数组为空或总权重<=0 则返回空字典
static func pick(array: Array, weight_key: String = "weight") -> Dictionary:
	if array.is_empty():
		return {}

	if array.size() == 1:
		return _to_dict(array[0])

	var total_weight: int = 0
	for item in array:
		total_weight += _get_weight(item, weight_key)

	if total_weight <= 0:
		return _to_dict(array[0])

	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for item in array:
		cumulative += _get_weight(item, weight_key)
		if roll < cumulative:
			return _to_dict(item)

	return _to_dict(array[-1])


## 从数组中随机选取一项，返回原始类型（不做 Dictionary 转换）
## 返回 null 如果数组为空或总权重<=0
static func pick_raw(array: Array, weight_key: String = "weight"):
	if array.is_empty():
		return null

	var total_weight: int = 0
	for item in array:
		total_weight += _get_weight(item, weight_key)

	if total_weight <= 0:
		return null

	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for item in array:
		cumulative += _get_weight(item, weight_key)
		if roll < cumulative:
			return item

	return array[-1]


# ============================================================
# Internal
# ============================================================

static func _get_weight(item, key: String) -> int:
	if item is Dictionary:
		return int(item.get(key, 1))
	# Resource / Object — use .get() method
	return int(item.get(key) if item.has_method("get") else 1)


static func _to_dict(item) -> Dictionary:
	if item is Dictionary:
		return item
	# Resource / Object — extract known fields
	var d: Dictionary = {}
	if item.has_method("get"):
		d["weight"] = int(item.get("weight")) if item.get("weight") != null else 1
		d["text"] = str(item.get("text")) if item.get("text") != null else ""
		d["effects"] = item.get("effects") if item.get("effects") != null else []
	return d
