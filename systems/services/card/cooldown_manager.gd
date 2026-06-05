# ============================================================
# 大周天 — CooldownManager (卡牌冷却管理 — L2)
# ============================================================
# 四层定位: L2 Domain Layer — 冷却规则执行
#
# 职责:
#   - 追踪每张卡牌实例的冷却剩余时间
#   - 每 tick 递减所有冷却
#   - 查询卡牌是否处于冷却中
#
# 红线:
#   ❌ 不操作 UI (冷却遮罩由 L0 查询 get_remaining 自行渲染)
#   ❌ 不持有 CardData/CardInstance 引用 (用 card_instance_id 做 key)
# ============================================================
class_name CooldownManager
extends RefCounted


## 内部冷却记录: { card_instance_id: { remaining: float, total: float } }
var _entries: Dictionary = {}


## 将卡牌实例放入冷却
## card_key: 卡牌实例的唯一标识 (CardInstance 的 resource_path 或自定义 id)
## seconds: 冷却总时长
func put_on_cooldown(card_key: String, seconds: float) -> void:
	_entries[card_key] = {
		"remaining": seconds,
		"total": seconds,
	}


## 每 tick 递减所有冷却, 返回过期卡牌 key 列表
func tick(delta: float) -> Array[String]:
	var expired: Array[String] = []
	for key in _entries:
		var entry: Dictionary = _entries[key]
		entry["remaining"] = max(0.0, entry["remaining"] - delta)
		if entry["remaining"] <= 0.0:
			expired.append(key)
	for key in expired:
		_entries.erase(key)
	return expired


## 检查卡牌是否在冷却中
func is_on_cooldown(card_key: String) -> bool:
	return _entries.has(card_key) and _entries[card_key]["remaining"] > 0.0


## 获取剩余冷却时间 (秒), 不在冷却中返回 0
func get_remaining(card_key: String) -> float:
	if not _entries.has(card_key):
		return 0.0
	return _entries[card_key]["remaining"]


## 获取冷却进度比例 [0, 1], 0=刚开始冷却, 1=冷却完成
func get_cooldown_ratio(card_key: String) -> float:
	if not _entries.has(card_key):
		return 1.0
	var entry: Dictionary = _entries[card_key]
	if entry["total"] <= 0.0:
		return 1.0
	return 1.0 - (entry["remaining"] / entry["total"])


## 立即移除卡牌的冷却
func remove_cooldown(card_key: String) -> void:
	_entries.erase(card_key)


## 清空所有冷却
func clear_all() -> void:
	_entries.clear()
