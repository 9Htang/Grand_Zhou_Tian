# ============================================================
# 大周天 — RealtimeBuffSystem (实时 Buff 衰减 — L2)
# ============================================================
# 四层定位: L2 Domain Layer — 代替回合末统一 buff/debuff tick
#
# 职责:
#   - 玩家卡牌 buff 的实时秒数衰减
#   - 敌人状态的实时秒数衰减 (burn/vulnerable/weak)
#   - 燃烧伤害改为 DPS 模型
#
# 红线:
#   ❌ 不操作 UI
#   ❌ 不直接修改 actor 属性 (通过现有方法)
# ============================================================
class_name RealtimeBuffSystem
extends RefCounted


## 回合→秒转换系数: 1 回合 ≈ 5 秒
const TURN_TO_SECONDS: float = 5.0


## 对玩家执行一 tick 的 buff 衰减
## 处理 CombatActor.active_buffs 中的卡牌 buff (source="card")
static func tick_player_buffs(player: PlayerActor, delta: float) -> String:
	var log_entries: Array[String] = []
	var expired: Array[int] = []

	for i in range(player.active_buffs.size()):
		var buff = player.active_buffs[i]

		# 兼容 Dictionary 和 ResolvedBuff 两种格式
		var turns_remaining: float
		var buff_name: String
		var buff_value: int
		var buff_source: String

		if buff is Dictionary:
			turns_remaining = float(buff.get("turns_remaining", 0))
			buff_name = str(buff.get("name", ""))
			buff_value = int(buff.get("value", 0))
			buff_source = str(buff.get("source", ""))
		else:
			turns_remaining = float(buff.get("turns_remaining") if buff.get("turns_remaining") != null else 0)
			buff_name = str(buff.get("name") if buff.get("name") != null else "")
			buff_value = int(buff.get("value") if buff.get("value") != null else 0)
			buff_source = str(buff.get("source") if buff.get("source") != null else "")

		if turns_remaining <= 0.0:
			continue  # 永久 buff, 不衰减

		# 转换回合→秒 (首次 tick 时)
		if turns_remaining > 1000.0:
			# 标记: 仍然是回合值, 需要转换
			turns_remaining = turns_remaining * TURN_TO_SECONDS / 1000.0

		var new_remaining: float = max(0.0, turns_remaining - delta)

		# 写回
		if buff is Dictionary:
			buff["turns_remaining"] = new_remaining
		else:
			buff.set("turns_remaining", new_remaining)

		if new_remaining <= 0.0:
			expired.append(i)
			log_entries.append(buff_name + " 消散")

	# 从后往前删除已过期的 buff
	for i in range(expired.size() - 1, -1, -1):
		player.active_buffs.remove_at(expired[i])

	return ", ".join(log_entries)


## 对敌人执行一 tick 的状态衰减 (burn/vulnerable/weak)
static func tick_enemy_statuses(enemies: Array[EnemyActor], delta: float) -> String:
	var log_entries: Array[String] = []

	for enemy in enemies:
		if enemy.statuses.is_empty():
			continue

		# 燃烧: DPS 模型 — 每秒造成 burn["damage"] 伤害
		if enemy.statuses.has("burn"):
			var burn: Dictionary = enemy.statuses["burn"]
			var dps: int = burn.get("damage", 0)
			var seconds: float = burn.get("turns", 0.0) * TURN_TO_SECONDS

			# 首次 tick 转换标记
			if seconds > 1000.0:
				seconds = seconds * TURN_TO_SECONDS / 1000.0

			var dmg_this_tick: int = max(1, int(float(dps) * delta))
			enemy.hp = max(0, enemy.hp - dmg_this_tick)

			var new_seconds: float = max(0.0, seconds - delta)
			if new_seconds <= 0.0:
				enemy.statuses.erase("burn")
				log_entries.append(enemy.display_name + " 灼烧结束")
			else:
				burn["turns"] = new_seconds  # 存储秒数
				log_entries.append(enemy.display_name + " 灼烧 " + str(dmg_this_tick))

		# 易伤: 秒数倒计时
		if enemy.statuses.has("vulnerable"):
			var vuln: Dictionary = enemy.statuses["vulnerable"]
			var seconds: float = vuln.get("turns", 0.0)
			if seconds > 1000.0:
				seconds = seconds * TURN_TO_SECONDS / 1000.0
			seconds = max(0.0, seconds - delta)
			if seconds <= 0.0:
				enemy.statuses.erase("vulnerable")
				log_entries.append(enemy.display_name + " 易伤结束")
			else:
				vuln["turns"] = seconds

		# 虚弱: 秒数倒计时
		if enemy.statuses.has("weak"):
			var weak: Dictionary = enemy.statuses["weak"]
			var seconds: float = weak.get("turns", 0.0)
			if seconds > 1000.0:
				seconds = seconds * TURN_TO_SECONDS / 1000.0
			seconds = max(0.0, seconds - delta)
			if seconds <= 0.0:
				enemy.statuses.erase("weak")
				log_entries.append(enemy.display_name + " 虚弱结束")
			else:
				weak["turns"] = seconds

	return ", ".join(log_entries)
