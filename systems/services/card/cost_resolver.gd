# ============================================================
# 大周天 — CostResolver (消耗验证与执行)
# ============================================================
# L2 Domain Service — 静态工具
# 解析消耗表达式字符串，检查玩家是否可支付并执行消耗
#
# 支持格式: "key:value"
#   正数 = 获得 (始终可支付)
#   负数 = 消耗
# 示例:
#   "hp:-10"       — 消耗10气血
#   "gold:50"      — 获得50金币
#   "dantian_qi:-5"— 消耗5灵气
#   "remove_card:random" — 随机移除一张卡牌
# ============================================================
class_name CostResolver
extends RefCounted


# === 消耗名称映射 (中文) ===
const _COST_NAMES := {
	"hp": "气血",
	"dantian_qi": "灵气",
	"gold": "金币",
}


## 检查是否可以支付该消耗
static func can_pay(cost: String) -> bool:
	if cost.is_empty():
		return true

	var parsed: Dictionary = _parse(cost)
	if parsed.is_empty():
		return true

	var key: String = parsed["key"]
	var value: int = parsed["value"]

	# 正数 = 获得，始终可支付
	if value >= 0:
		return true

	var abs_val: int = abs(value)
	match key:
		"hp":
			return GameManager.player_hp > abs_val
		"dantian_qi":
			return GameManager.dantian_qi >= abs_val
		"gold":
			return GameManager.gold >= abs_val
		"remove_card":
			return not GameManager.master_deck.is_empty()
	return true


## 执行消耗（正数为获得，负数为消耗）
static func apply(cost: String) -> void:
	if cost.is_empty():
		return

	var parsed: Dictionary = _parse(cost)
	if parsed.is_empty():
		return

	var key: String = parsed["key"]
	var value: int = parsed["value"]
	var raw_value: String = parsed["raw_value"]

	match key:
		"hp":
			if value < 0:
				GameManager.take_damage(abs(value))
			else:
				GameManager.heal(value)
		"dantian_qi":
			if value < 0:
				GameManager.spend_qi(abs(value))
			else:
				GameManager.add_qi(value)
		"gold":
			GameManager.gold += value
		"remove_card":
			GameManager.remove_card(raw_value)


## 获取消耗的中文描述
## 例: "hp:-10" → "消耗气血 10"
##      "gold:50" → "" (获得不显示消耗)
static func describe(cost: String) -> String:
	if cost.is_empty():
		return ""

	var parsed: Dictionary = _parse(cost)
	if parsed.is_empty():
		return ""

	var key: String = parsed["key"]
	var value: int = parsed["value"]

	# 正数（获得）不需要消耗描述
	if value >= 0:
		return ""

	# 特殊处理 remove_card
	if key == "remove_card":
		return "随机移除一张卡牌"

	var abs_val: int = abs(value)
	var display_name: String = _COST_NAMES.get(key, key)
	return "消耗" + display_name + " " + str(abs_val)


# ============================================================
# Internal
# ============================================================

## 解析消耗表达式 "key:value" → {key, value, raw_value}
static func _parse(cost: String) -> Dictionary:
	var parts: PackedStringArray = cost.split(":", false)
	if parts.size() < 2:
		return {}
	return {
		"key": parts[0].strip_edges(),
		"value": int(parts[1]),
		"raw_value": parts[1].strip_edges(),
	}
