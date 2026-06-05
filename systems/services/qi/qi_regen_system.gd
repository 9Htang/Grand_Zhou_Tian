# ============================================================
# 大周天 — QiRegenSystem (灵气连续回复 — L2)
# ============================================================
# 四层定位: L2 Domain Layer — 灵气回复规则执行
#
# 职责:
#   - 计算每 tick 灵气回复量 (rate * delta)
#   - 基础回复 + 功法压力加成 + 回路加成 + buff 加成
#   - 应用到所有 actor (player + enemies)
#
# 红线:
#   ❌ 不操作 UI
#   ❌ 不直接修改 GameManager
# ============================================================
class_name QiRegenSystem
extends RefCounted


## 计算一个 actor 的每秒灵气回复率
## 基础公式: qi_gather_rate + tech_bonus + circuit_bonus + buff_bonus + ext_bonus
static func calculate_rate(actor: CombatActor) -> float:
	var rate: float = float(actor.qi_gather_rate)

	# 功法压力加成: 每个功法 pressure_mod > 1.0 提供额外回复
	if actor.has_method("get_active_techniques"):
		for tech in actor.get_active_techniques():
			var td: TechniqueData = tech as TechniqueData
			if td and td.pressure_mod > 1.0:
				rate += (td.pressure_mod - 1.0) * 2.0

	# 活跃回路加成: 每个回路 +1 qi/s
	var circuits: Array = []
	if actor.get("active_circuits") != null:
		circuits = actor.active_circuits
	rate += float(circuits.size())

	# Buff 加成 (buff name = "gather_up")
	if actor.get("active_buffs") != null:
		for buff in actor.active_buffs:
			if buff is Dictionary:
				if buff.get("name", "") == "gather_up":
					rate += float(buff.get("value", 0))
			elif buff.has_method("get") or buff.get("name") != null:
				if str(buff.get("name")) == "gather_up":
					rate += float(buff.get("value", 0))

	# 扩展加成 (来自法宝/丹药)
	if actor.get("qi_gather_bonuses") != null:
		var d: Dictionary = actor.qi_gather_bonuses
		for v in d.values():
			rate += float(v)

	# 回复倍率 (buff/debuff 修正)
	if actor.get("qi_regen_multiplier") != null:
		rate *= float(actor.qi_regen_multiplier)

	return rate


## 对单个 actor 执行一 tick 的灵气回复
## 使用浮点累加器避免 int 截断: rate=3, delta=0.25 → 0.75/次, 累加至≥1时结算
static func tick_actor(actor: CombatActor, delta: float) -> void:
	var rate: float = calculate_rate(actor)
	if rate <= 0.0:
		return
	## 累加浮点灵气值, 避免 int(rate * delta) 截断导致低速率下永远不回复
	actor._qi_accumulator += rate * delta
	var gain: int = int(actor._qi_accumulator)
	if gain <= 0:
		return

	actor.add_qi(gain)  # 走 add_qi 确保 qi_changed 信号触发
	actor._qi_accumulator -= float(gain)


## 对所有敌人执行一 tick 的灵气回复
static func tick_enemies(enemies: Array[EnemyActor], delta: float) -> void:
	for enemy in enemies:
		if not enemy:
			continue
		tick_actor(enemy, delta)
