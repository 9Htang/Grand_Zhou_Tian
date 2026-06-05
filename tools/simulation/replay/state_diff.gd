# ============================================================
# 大周天 — StateDiff (状态差异分析)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 对两个 CanonicalState 做结构级差异分析。
# 当 hash 不一致时，定位具体是哪个字段、哪个实体、哪个区导致的分歧。
#
# 职责:
#   - field-level diff (player/enemy/deck/vm)
#   - human-readable 输出
#   - 纯函数，无状态
#
# hash = fast equality      (StateHasher)
# diff = explain divergence (StateDiff)
# ============================================================
class_name StateDiff
extends RefCounted


class DiffResult:
	var has_diff: bool = false
	var player_diffs: Dictionary = {}       # {field: [old, new]}
	var enemy_diffs: Array[Dictionary] = [] # [{index, field, old, new}]
	var deck_diffs: Dictionary = {}         # {zone: {added, removed, reordered}}
	var vm_diffs: Dictionary = {}           # {field: [old, new]}

	func is_empty() -> bool:
		return player_diffs.is_empty() and enemy_diffs.is_empty() and deck_diffs.is_empty() and vm_diffs.is_empty()


## 比较两个 CanonicalState — 与 hash 共享同一 capture（不会假不一致）
static func compare(a: CanonicalState, b: CanonicalState) -> DiffResult:
	return _compare_dicts(a.data() if a else {}, b.data() if b else {})


## 比较两个状态 Dictionary（无需 CanonicalState 包装）
static func compare_dicts(a: Dictionary, b: Dictionary) -> DiffResult:
	return _compare_dicts(a, b)


## 比较两个状态 dict（底层 — 外部应使用 CanonicalState 版本）
static func _compare_dicts(a: Dictionary, b: Dictionary) -> DiffResult:
	var r := DiffResult.new()
	r.player_diffs = _diff_player(a.get("player", {}), b.get("player", {}))
	r.enemy_diffs = _diff_enemies(a.get("enemies", []), b.get("enemies", []))
	r.deck_diffs = _diff_deck(a.get("deck", {}), b.get("deck", {}))
	r.vm_diffs = _diff_vm(a.get("vm", {}), b.get("vm", {}))
	r.has_diff = not r.is_empty()
	return r


static func _diff_player(a: Dictionary, b: Dictionary) -> Dictionary:
	var diffs: Dictionary = {}
	for key in ["hp", "max_hp", "qi", "capacity", "block"]:
		var va = a.get(key); var vb = b.get(key)
		if str(va) != str(vb):
			diffs[key] = [va, vb]
	return diffs


static func _diff_enemies(a: Array, b: Array) -> Array[Dictionary]:
	var diffs: Array[Dictionary] = []
	var limit: int = max(a.size(), b.size())
	for i in range(limit):
		var ea: Dictionary = a[i] if i < a.size() else {}
		var eb: Dictionary = b[i] if i < b.size() else {}
		if ea.is_empty() and eb.is_empty():
			continue
		for key in ["hp", "max_hp", "qi"]:
			var va = ea.get(key); var vb = eb.get(key)
			if str(va) != str(vb):
				diffs.append({"index": i, "field": key, "old": va, "new": vb})
	return diffs


static func _diff_deck(a: Dictionary, b: Dictionary) -> Dictionary:
	var diffs: Dictionary = {}
	for zone in ["draw", "hand", "discard", "exhaust"]:
		var aa: Array = a.get(zone, [])
		var bb: Array = b.get(zone, [])
		var zone_diff: Dictionary = {}
		if aa.size() != bb.size():
			zone_diff["size_change"] = [aa.size(), bb.size()]
		var reordered: bool = false
		for j in range(min(aa.size(), bb.size())):
			var ca: Dictionary = aa[j] if j < aa.size() else {}
			var cb: Dictionary = bb[j] if j < bb.size() else {}
			if ca.get("id", "") != cb.get("id", ""):
				reordered = true
				break
		if reordered:
			zone_diff["reordered"] = true
		if not zone_diff.is_empty():
			diffs[zone] = zone_diff
	return diffs


static func _diff_vm(a: Dictionary, b: Dictionary) -> Dictionary:
	var diffs: Dictionary = {}
	for key in ["ip", "stack", "event_queue", "pending", "trigger_stack"]:
		var va: Array = a.get(key) if a.get(key) is Array else []
		var vb: Array = b.get(key) if b.get(key) is Array else []
		if key == "ip":
			if str(a.get(key)) != str(b.get(key)):
				diffs[key] = [a.get(key), b.get(key)]
		elif va.size() != vb.size():
			diffs[key] = ["size: %d" % va.size(), "size: %d" % vb.size()]
	return diffs


## 生成可读差异摘要
static func to_text(r: DiffResult) -> String:
	if not r.has_diff:
		return "[StateDiff] No differences"

	var lines: PackedStringArray = []
	lines.append("[StateDiff] Structural divergence:")

	if not r.player_diffs.is_empty():
		for field in r.player_diffs:
			var change: Array = r.player_diffs[field]
			lines.append("  player.%s: %s → %s" % [field, change[0], change[1]])

	if not r.enemy_diffs.is_empty():
		for d in r.enemy_diffs:
			lines.append("  enemy[%d].%s: %s → %s" % [d.index, d.field, d.old, d.new])

	if not r.deck_diffs.is_empty():
		for zone in r.deck_diffs:
			var zd: Dictionary = r.deck_diffs[zone]
			var parts: PackedStringArray = []
			if zd.has("size_change"):
				var sc: Array = zd.size_change
				parts.append("size %s→%s" % [sc[0], sc[1]])
			if zd.get("reordered", false):
				parts.append("reordered")
			lines.append("  deck.%s: %s" % [zone, ", ".join(parts)])

	if not r.vm_diffs.is_empty():
		for field in r.vm_diffs:
			var change: Array = r.vm_diffs[field]
			lines.append("  vm.%s: %s → %s" % [field, change[0], change[1]])

	return "\n".join(lines)
