class_name DamageCalculation
extends RefCounted


static func calculate(base_damage: int, player_realm: int, buffs: Array, attacker_realm: int = 1) -> int:
	var dmg: int = base_damage

	if attacker_realm > player_realm:
		dmg = int(float(dmg) * 1.2)

	dmg += _sum_buffs(buffs, "attack_up")
	dmg += _sum_buffs(buffs, "strength")

	if _has_buff(buffs, "vulnerable"):
		dmg = int(float(dmg) * 1.5)

	return max(0, dmg)


static func calculate_block(raw_damage: int, current_block: int) -> Dictionary:
	var block: int = current_block
	var reduced: int = min(raw_damage, block)
	var new_block: int = current_block - reduced
	return {"damage_taken": raw_damage - reduced, "remaining_block": new_block}


static func enemy_damage(base_damage: int, player_realm: int, enemy_realm: int) -> int:
	var dmg: int = base_damage
	if enemy_realm > player_realm:
		dmg = int(float(dmg) * 1.2)
	return max(0, dmg)


static func _sum_buffs(buffs: Array, buff_name: String) -> int:
	var total: int = 0
	for buff in buffs:
		if buff.name == buff_name:
			total += int(buff.value)
	return total


static func _has_buff(buffs: Array, buff_name: String) -> bool:
	for buff in buffs:
		if buff.name == buff_name:
			return true
	return false
