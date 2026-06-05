# ============================================================
# 大周天 — Enemy AI (敌人三层决策系统)
# Layer 1: 加权随机选择
# Layer 2: 条件修饰因子
# Layer 3: 经脉冲刷目标自动选择
# ============================================================
class_name EnemyAI
extends RefCounted


# Strategy constants
const STRATEGY_AGGRESSIVE := "aggressive"
const STRATEGY_DEFENSIVE := "defensive"
const STRATEGY_BALANCED := "balanced"
const STRATEGY_BOSS_PHASE := "boss_phase"


## Layer 1+2: Select an action based on weighted random + conditional overrides
## actor: the EnemyActor making the decision
## opponent: the CombatActor being fought (player_actor)
## data: the EnemyData resource (holds the action pool)
static func select_action(actor: EnemyActor, opponent: CombatActor, data: EnemyData, rng: DeterministicRNG = null) -> EnemyActionData:
	if data.actions.is_empty():
		return null

	# Build a weighted pool, then apply modifiers
	var weights: Array[int] = []
	var actions: Array = data.actions

	for action in actions:
		var action_data: EnemyActionData = action as EnemyActionData
		if action_data == null:
			weights.append(0)
			continue

		var w: int = action_data.weight
		# Layer 2: Conditional modifiers
		var hp_pct: float = float(actor.hp) / float(actor.max_hp)

		match action_data.intent:
			0, 1:  # ATTACK / ATTACK_MULTI
				if actor.ai_strategy == STRATEGY_AGGRESSIVE:
					w *= 2
				if opponent_has_status(opponent, "vulnerable"):
					w = int(float(w) * 1.5)
			2:  # DEFEND
				if hp_pct < 0.5 or actor.ai_strategy == STRATEGY_DEFENSIVE:
					w *= 3
				if hp_pct < 0.3:
					w *= 2
			3:  # BUFF_SELF
				if actor.strength > 0:
					w = int(float(w) * 0.5)
			4:  # DEBUFF_PLAYER
				if opponent_has_status(opponent, "weak"):
					w = int(float(w) * 0.3)
			5, 6, 7:  # SEAL_MERIDIAN / DAMAGE_PATHWAY / DRAIN_QI
				if opponent.base_meridian == null:
					w = 0
				else:
					var unlocked_count: int = 0
					for node in opponent.base_meridian.nodes:
						var mn: MeridianNodeData = node as MeridianNodeData
						if mn != null and mn.unlocked:
							unlocked_count += 1
					if unlocked_count <= 2:
						w = 0
					else:
						w = int(float(w) * (1.0 + float(unlocked_count - 2) * 0.3))

		weights.append(max(0, w))

	# Weighted pick
	var total: int = 0
	for w in weights:
		total += w
	if total == 0:
		return actions[0] as EnemyActionData

	var roll: int = (rng.randi() if rng else randi()) % total
	var cumulative: int = 0
	for i in actions.size():
		cumulative += weights[i]
		if roll < cumulative:
			return actions[i] as EnemyActionData

	return actions[actions.size() - 1] as EnemyActionData


## Layer 3: Select erosion targets for the enemy's qi circulation
## Picks adjacent locked nodes to unlocked nodes, preferring narrow pathways
static func select_erosion_targets(actor: EnemyActor) -> Array[int]:
	var result: Array[int] = []
	var meridian: MeridianMapData = actor.base_meridian
	if meridian == null:
		return result

	var max_targets: int = actor.get_max_erosion_targets()
	if max_targets <= 0:
		return result

	# Find locked nodes that are adjacent to unlocked nodes
	var candidates: Array[Dictionary] = []  # [{idx, pathway_width}]
	for i in meridian.nodes.size():
		var node: MeridianNodeData = meridian.get_node(i)
		if node == null or node.unlocked:
			continue
		# Check if adjacent to any unlocked node
		var adjacent_unlocked := false
		var min_pathway_width: float = 999.0
		for conn in node.connections:
			var conn_idx: int = conn as int
			var neighbor: MeridianNodeData = meridian.get_node(conn_idx)
			if neighbor and neighbor.unlocked:
				adjacent_unlocked = true
				# Find the connecting pathway
				for pw in meridian.pathways:
					var pw_data: MeridianPathwayData = pw as MeridianPathwayData
					if pw_data == null:
						continue
					if (pw_data.from_node == i and pw_data.to_node == conn_idx) or (pw_data.from_node == conn_idx and pw_data.to_node == i):
						if pw_data.width < min_pathway_width:
							min_pathway_width = pw_data.width
		if adjacent_unlocked:
			candidates.append({"idx": i, "pathway_width": min_pathway_width})

	# Sort by pathway width ascending (prefer narrow pathways — faster erosion)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["pathway_width"] < b["pathway_width"]
	)

	# Take up to max_targets, then set them
	for i in min(max_targets, candidates.size()):
		var idx: int = candidates[i]["idx"] as int
		actor.toggle_erosion_target(idx)
		result.append(idx)

	return result


## Check if a CombatActor has a specific debuff
static func opponent_has_status(opponent: CombatActor, status_name: String) -> bool:
	for buff in opponent.active_buffs:
		if buff.name == status_name:
			return true
	return false


## Get a human-readable description of the AI's decision
static func describe_decision(actor: EnemyActor, action: EnemyActionData) -> String:
	var strategy_names := {
		STRATEGY_AGGRESSIVE: "猛攻",
		STRATEGY_DEFENSIVE: "防守",
		STRATEGY_BALANCED: "均衡",
		STRATEGY_BOSS_PHASE: "boss阶段",
	}
	var strategy: String = strategy_names.get(actor.ai_strategy, actor.ai_strategy)
	var intent_text: String = EnemyIntents.get_intent_text(action)
	return "%s[%s] → %s" % [actor.display_name, strategy, intent_text]
