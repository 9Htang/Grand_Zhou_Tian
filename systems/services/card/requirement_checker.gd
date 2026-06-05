# ============================================================
# 大周天 — RequirementChecker (条件验证)
# ============================================================
# L2 Domain Service — 静态工具
# 解析条件表达式字符串，对比 GameManager 中的玩家属性
#
# 支持格式:
#   "realm>=3"              — 单条件
#   "realm>=3;talent>=5"    — 多条件 (全部满足)
# 支持运算符: >= > <= < ==
# ============================================================
class_name RequirementChecker
extends RefCounted


## 检查条件表达式是否满足
## 空字符串视为无条件满足
static func check(req: String) -> bool:
	if req.is_empty():
		return true

	var conditions: PackedStringArray = req.split(";")
	for cond in conditions:
		var stripped: String = cond.strip_edges()
		if stripped.is_empty():
			continue
		if not _check_single(stripped):
			return false
	return true


# ============================================================
# Internal
# ============================================================

static func _check_single(cond: String) -> bool:
	var op: String = ""
	var parts: PackedStringArray

	if ">=" in cond:
		op = ">="
		parts = cond.split(">=")
	elif "<=" in cond:
		op = "<="
		parts = cond.split("<=")
	elif ">" in cond:
		op = ">"
		parts = cond.split(">")
	elif "<" in cond:
		op = "<"
		parts = cond.split("<")
	elif "==" in cond:
		op = "=="
		parts = cond.split("==")
	else:
		return true  # 无法解析，默认通过

	if parts.size() < 2:
		return true

	var key: String = parts[0].strip_edges()
	var expected: int = int(parts[1].strip_edges())
	var current: int = _get_stat(key)

	match op:
		">=": return current >= expected
		">":  return current > expected
		"<=": return current <= expected
		"<":  return current < expected
		"==": return current == expected
	return true


static func _get_stat(key: String) -> int:
	match key:
		"realm":      return GameManager.realm
		"talent":     return GameManager.talent
		"dantian_qi": return GameManager.dantian_qi
		"gold":       return GameManager.gold
		"hp":         return GameManager.player_hp
		"luck":       return GameManager.luck
		"divine_sense": return GameManager.divine_sense
	return 0
