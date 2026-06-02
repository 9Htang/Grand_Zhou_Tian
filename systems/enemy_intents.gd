# ============================================================
# 大周天 — Enemy Intents (敌人AI意图选择)
# ============================================================
class_name EnemyIntents
extends RefCounted


## Select an action for the enemy using weighted random selection.
static func select_action(enemy_data: EnemyData) -> EnemyActionData:
	if enemy_data.actions.is_empty():
		return null

	# Weighted random selection
	var total_weight := 0
	for action in enemy_data.actions:
		total_weight += action.weight

	if total_weight == 0:
		return enemy_data.actions[0]

	var roll := randi() % total_weight
	var cumulative := 0
	for action in enemy_data.actions:
		cumulative += action.weight
		if roll < cumulative:
			return action

	return enemy_data.actions[-1]


## Determine intent display text.
static func get_intent_text(action: EnemyActionData) -> String:
	match action.intent:
		0: return "攻击 %d" % action.damage
		1: return "连击 %d×2" % action.damage
		2: return "防御 %d" % action.block
		3: return "强化"
		4: return "削弱"
		5: return "封穴"
		6: return "断脉"
		7: return "吸灵"
	return "?"


## Select an action using the new EnemyAI (Layer 1 + Layer 2 conditional)
static func select_action_weighted(actor: EnemyActor, opponent: CombatActor, data: EnemyData) -> EnemyActionData:
	return EnemyAI.select_action(actor, opponent, data)


## Get intent icon color.
static func get_intent_color(intent: int) -> Color:
	match intent:
		0, 1: return Color(1, 0, 0)        # Attack
		2: return Color(0.118, 0.565, 1)   # Defend
		3: return Color(0, 1, 0)           # Buff
		4: return Color(0.5, 0, 0.5)       # Debuff
		5, 6: return Color(1, 0.5, 0)      # Meridian attacks
		7: return Color(0, 1, 1)           # Drain
	return Color(0.5, 0.5, 0.5)


## Execute an enemy action intent, applying effects directly to actor and opponent.
## Returns array of human-readable log strings.
static func execute_intent(action: EnemyActionData, actor: EnemyActor, opponent: CombatActor) -> Array[String]:
	var logs: Array[String] = []

	# Check for weak status on enemy (reduces damage dealt)
	var weak_amount: int = 0
	if actor.statuses.has("weak"):
		weak_amount = actor.statuses["weak"].get("amount", 0)

	match action.intent:
		EnemyActionData.IntentType.ATTACK, EnemyActionData.IntentType.ATTACK_MULTI:
			# Damage calculation with enemy strength bonus
			var raw_dmg: int = action.damage + actor.strength
			var dmg: int = DamageCalculation.enemy_damage(raw_dmg, opponent.realm, actor.realm)

			# Player vulnerable: damage x1.5
			for buff in opponent.active_buffs:
				if buff.name == "vulnerable":
					dmg = int(float(dmg) * 1.5)
					break

			# Enemy weak: damage -N
			dmg = max(0, dmg - weak_amount)
			opponent.take_damage(dmg)
			logs.append(actor.display_name + " 攻击造成 " + str(dmg) + " 伤害")

			# Node property: counter
			var counter_val: float = NodePropertyResolver.get_active_property_total(opponent, "counter")
			if counter_val > 0.0:
				var new_hp: int = max(0, actor.hp - int(counter_val))
				actor.hp = new_hp
				logs.append(" 反击 " + str(int(counter_val)))

			# Node property: reflect
			var reflect_pct: float = NodePropertyResolver.get_active_property_total(opponent, "reflect")
			if reflect_pct > 0.0:
				var reflect_dmg: int = max(1, int(float(dmg) * reflect_pct / 100.0))
				actor.hp = max(0, actor.hp - reflect_dmg)
				logs.append(" 反伤 " + str(reflect_dmg))

		EnemyActionData.IntentType.DEFEND:
			actor.current_block += action.block
			logs.append(actor.display_name + " 防御 +" + str(action.block))

		EnemyActionData.IntentType.BUFF_SELF:
			if not action.buff_self.is_empty():
				var parts: PackedStringArray = action.buff_self.split(":")
				if parts.size() >= 2:
					match parts[0]:
						"strength":
							actor.strength += int(parts[1])
							logs.append(actor.display_name + " 力量 +" + parts[1])
						_:
							logs.append(actor.display_name + " 强化")
				else:
					logs.append(actor.display_name + " 强化")
			else:
				logs.append(actor.display_name + " 强化")

		EnemyActionData.IntentType.DEBUFF_PLAYER:
			if not action.debuff_player.is_empty():
				var parts: PackedStringArray = action.debuff_player.split(":")
				if parts.size() >= 2:
					match parts[0]:
						"weak":
							var rb := TechniqueResolver.ResolvedBuff.new()
							rb.name = "weak"
							rb.value = int(parts[1])
							rb.source = "enemy"
							opponent.active_buffs.append(rb)
							opponent.buffs_updated.emit(opponent.active_buffs)
							logs.append(actor.display_name + " 虚弱玩家 (-" + parts[1] + " 伤害)")
						"energy_down":
							opponent.spend_qi(int(parts[1]))
							logs.append(actor.display_name + " 吸取灵气 " + parts[1])
						_:
							logs.append(actor.display_name + " 削弱玩家")
			else:
				logs.append(actor.display_name + " 削弱玩家")

		EnemyActionData.IntentType.SEAL_MERIDIAN:
			var target_node_idx: int = -1
			if action.target_node == "random":
				var candidates: Array[int] = []
				var mer: MeridianMapData = opponent.base_meridian
				if mer:
					for i: int in mer.nodes.size():
						var n: MeridianNodeData = mer.get_node(i)
						if n and n.unlocked and not n.blocked and n.current_qi > 0:
							candidates.append(i)
				if not candidates.is_empty():
					target_node_idx = candidates[randi() % candidates.size()]
			if target_node_idx >= 0:
				var mn: MeridianNodeData = opponent.base_meridian.get_node(target_node_idx)
				MeridianDamageSystem.block_node(opponent, mn.name)
				logs.append(actor.display_name + " 封穴 " + mn.name)
			else:
				logs.append(actor.display_name + " 封穴 (无有效目标)")

		EnemyActionData.IntentType.DAMAGE_PATHWAY:
			var pathways: Array = opponent.base_meridian.pathways
			if not pathways.is_empty():
				var pw = pathways[randi() % pathways.size()]
				MeridianDamageSystem.damage_pathway(opponent, pw.from_node, pw.to_node)
				logs.append(actor.display_name + " 断脉 " + str(pw.from_node) + "->" + str(pw.to_node))
			else:
				logs.append(actor.display_name + " 断脉 (无经脉)")

		EnemyActionData.IntentType.DRAIN_QI:
			var drain_amount: int = action.damage
			if drain_amount <= 0:
				drain_amount = 3
			var actual: float = QiFlowSystem.draw_from_meridian(opponent, float(drain_amount))
			logs.append(actor.display_name + " 吸灵 " + str(int(actual)) + " 点")
			if not action.debuff_player.is_empty():
				var parts: PackedStringArray = action.debuff_player.split(":")
				if parts.size() >= 2 and parts[0] == "energy_down":
					opponent.spend_qi(int(parts[1]))

		_:
			logs.append(actor.display_name + " " + get_intent_text(action))

	return logs
