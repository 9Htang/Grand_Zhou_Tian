# ============================================================
# 大周天 — EnemyStatusSystem (敌人状态管理 — L2, 即时制)
# 即时制改造: 新增 tick_all_delta (按秒衰减)
# ============================================================
class_name EnemyStatusSystem
extends RefCounted


static func apply(enemy: EnemyActor, status_str: String) -> void:
	var parts: PackedStringArray = status_str.split(":")
	if parts.size() < 2:
		return
	var name: String = parts[0]

	match name:
		"burn":
			var damage: int = int(parts[1])
			var turns: int = int(parts[2]) if parts.size() >= 3 else 2
			if enemy.statuses.has("burn"):
				var existing: Dictionary = enemy.statuses["burn"]
				existing["damage"] = max(existing["damage"], damage)
				existing["turns"] = max(existing["turns"], turns)
			else:
				enemy.statuses["burn"] = {"damage": damage, "turns": turns}
		"vulnerable":
			var turns: int = int(parts[1])
			var existing_turns: int = enemy.statuses.get("vulnerable", {}).get("turns", 0)
			enemy.statuses["vulnerable"] = {"turns": max(existing_turns, turns)}
		"weak":
			var amount: int = int(parts[1])
			var turns: int = int(parts[2]) if parts.size() >= 3 else 1
			var existing_turns: int = enemy.statuses.get("weak", {}).get("turns", 0)
			var existing_amount: int = enemy.statuses.get("weak", {}).get("amount", 0)
			enemy.statuses["weak"] = {"amount": max(existing_amount, amount), "turns": max(existing_turns, turns)}


## 旧接口: 回合结束时调用 (保留兼容, 1回合≈5秒)
static func tick_all(enemies: Array[EnemyActor]) -> String:
	return tick_all_delta(enemies, 5.0)


## 即时制: 按 delta 秒数处理状态衰减
static func tick_all_delta(enemies: Array[EnemyActor], delta: float) -> String:
	var log_entries: Array[String] = []
	for enemy in enemies:
		if enemy.statuses.is_empty():
			continue
		var hp: int = enemy.hp
		var name_str: String = enemy.display_name

		if enemy.statuses.has("burn"):
			var burn: Dictionary = enemy.statuses["burn"]
			var dmg_this_tick: int = max(1, int(float(burn["damage"]) * delta))
			hp = max(0, hp - dmg_this_tick)
			var remaining: float = float(burn["turns"]) - delta
			burn["turns"] = remaining
			log_entries.append(name_str + " 灼烧 " + str(dmg_this_tick) + " 点")
			if remaining <= 0.0:
				enemy.statuses.erase("burn")

		if enemy.statuses.has("vulnerable"):
			var vuln: Dictionary = enemy.statuses["vulnerable"]
			var remaining: float = float(vuln["turns"]) - delta
			vuln["turns"] = remaining
			if remaining <= 0.0:
				enemy.statuses.erase("vulnerable")

		if enemy.statuses.has("weak"):
			var weak: Dictionary = enemy.statuses["weak"]
			var remaining: float = float(weak["turns"]) - delta
			weak["turns"] = remaining
			if remaining <= 0.0:
				enemy.statuses.erase("weak")

		enemy.hp = hp

	return ", ".join(log_entries)


static func has(enemy: EnemyActor, status_name: String) -> bool:
	return enemy.statuses.has(status_name)


static func get_value(enemy: EnemyActor, status_name: String, key: String = "damage", default: Variant = 0) -> Variant:
	if enemy.statuses.has(status_name):
		return enemy.statuses[status_name].get(key, default)
	return default
