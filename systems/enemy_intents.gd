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
