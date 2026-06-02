# ============================================================
# 大周天 — EnemyStatusSystem (敌人状态管理)
# ============================================================
# 管理敌人身上的 burn/vulnerable/weak 等状态
# 纯逻辑 — 不涉及 UI 刷新
# ============================================================
class_name EnemyStatusSystem
extends RefCounted


## 向敌人施加一个状态效果
## status_str 格式: "burn:3:2" (伤害:3, 持续:2回合), "vulnerable:2", "weak:1:2"
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


## 处理所有敌人的回合结束状态（燃烧伤害 + 倒计时）
## 返回 log 文本
static func tick_all(enemies: Array[EnemyActor]) -> String:
	var log_entries: Array[String] = []
	for enemy in enemies:
		if enemy.statuses.is_empty():
			continue
		var hp: int = enemy.hp
		var name_str: String = enemy.display_name

		# Burn tick
		if enemy.statuses.has("burn"):
			var burn: Dictionary = enemy.statuses["burn"]
			var dmg: int = burn["damage"]
			hp = max(0, hp - dmg)
			burn["turns"] = burn["turns"] - 1
			log_entries.append(name_str + " 灼烧 " + str(dmg) + " 点")
			if burn["turns"] <= 0:
				enemy.statuses.erase("burn")

		# Vulnerable countdown
		if enemy.statuses.has("vulnerable"):
			var vuln: Dictionary = enemy.statuses["vulnerable"]
			vuln["turns"] = vuln["turns"] - 1
			if vuln["turns"] <= 0:
				enemy.statuses.erase("vulnerable")

		# Weak countdown
		if enemy.statuses.has("weak"):
			var weak: Dictionary = enemy.statuses["weak"]
			weak["turns"] = weak["turns"] - 1
			if weak["turns"] <= 0:
				enemy.statuses.erase("weak")

		enemy.hp = hp

	return ", ".join(log_entries)


## 检查敌人是否有某状态
static func has(enemy: EnemyActor, status_name: String) -> bool:
	return enemy.statuses.has(status_name)


## 获取状态值
static func get_value(enemy: EnemyActor, status_name: String, key: String = "damage", default: Variant = 0) -> Variant:
	if enemy.statuses.has(status_name):
		return enemy.statuses[status_name].get(key, default)
	return default
