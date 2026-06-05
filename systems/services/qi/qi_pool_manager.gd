class_name QiPoolManager
extends RefCounted


static func gather_passive(gm: Node) -> void:
	var base: int = gm.qi_gather_rate

	# Add technique pressure bonuses
	var tech_bonus: float = 0.0
	for tech in gm.active_techniques:
		var td: TechniqueData = tech
		if td.pressure_mod > 1.0:
			tech_bonus += (td.pressure_mod - 1.0) * 2.0  # Each 0.1 over 1.0 = +0.2 gather

	# Add buff bonuses (buffs with name "gather_up")
	var buff_bonus: int = 0
	for buff in gm.active_buffs:
		var rb: TechniqueResolver.ResolvedBuff = buff
		if rb.name == "gather_up":
			buff_bonus += rb.value

	# Add circuit bonus: each active circuit adds +1
	var circuit_bonus: int = gm.active_circuits.size()

	# Add extensible bonuses (from artifacts/elixirs)
	var ext_bonus: int = 0
	if gm.has_method("get_qi_gather_bonuses"):
		ext_bonus = gm.get_qi_gather_bonuses()
	elif gm.get("qi_gather_bonuses") != null:
		var d: Dictionary = gm.qi_gather_bonuses
		for v in d.values():
			ext_bonus += int(v)

	# Add one-time rest bonus if present, then consume it
	var rest_bonus: int = 0
	if gm.has_meta("rest_bonus_qi"):
		rest_bonus = int(gm.get_meta("rest_bonus_qi"))
		gm.remove_meta("rest_bonus_qi")

	var total: int = base + int(tech_bonus) + buff_bonus + circuit_bonus + ext_bonus + rest_bonus
	gm.dantian_qi = min(gm.dantian_capacity, gm.dantian_qi + total)


static func gather_active(gm: Node, amount: int) -> void:
	gm.dantian_qi = min(gm.dantian_capacity, gm.dantian_qi + amount)


static func spend(gm: Node, cost: int) -> bool:
	if gm.dantian_qi < cost:
		return false
	gm.dantian_qi -= cost
	gm.emit_qi_changed()
	return true


static func can_afford(gm: Node, cost: int) -> bool:
	return gm.dantian_qi >= cost


static func get_remaining(gm: Node) -> int:
	return gm.dantian_qi


static func distribute(remaining: int, technique_count: int) -> Array[int]:
	if technique_count == 0:
		return []
	var per: int = remaining / technique_count
	var result: Array[int] = []
	for _i in range(technique_count):
		result.append(per)
	return result


static func calculate_steps(technique: TechniqueData, qi_allocated: int) -> int:
	if technique.qi_per_step <= 0:
		return 0
	return qi_allocated / technique.qi_per_step


static func return_qi(gm: Node, amount: int) -> void:
	gm.dantian_qi = min(gm.dantian_capacity, gm.dantian_qi + amount)


static func dissipate(gm: Node) -> void:
	gm.dantian_qi = 0
	gm.emit_qi_changed()
