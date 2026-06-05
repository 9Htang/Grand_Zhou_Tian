# ============================================================
# 大周天 — HeuristicPolicy (贪心规则决策)
# ============================================================
class_name HeuristicPolicy
extends Policy


## 优先打出伤害最高的卡牌
func select_action(obs: SimulationObservation, legal_actions: Array[SimulationAction]) -> SimulationAction:
	if legal_actions.is_empty():
		return SimulationAction.skip()

	var best: SimulationAction = legal_actions[0]
	var best_score: float = -1.0

	for action in legal_actions:
		var score: float = _score_action(action, obs)
		if score > best_score:
			best_score = score
			best = action

	return best


func _score_action(action: SimulationAction, obs: SimulationObservation) -> float:
	if action.type == SimulationAction.Type.SKIP:
		return 0.0

	# 从手牌信息估算伤害
	var card_info: Dictionary = {}
	for c in obs.hand_cards:
		if c.get("id", "") == action.card_id:
			card_info = c
			break

	var damage: float = float(card_info.get("damage_estimate", 0))
	var cost: float = float(card_info.get("cost", 1))
	if cost <= 0: cost = 1

	# 伤害/费用 比 + 血量紧急度加成
	var score := damage / cost
	if obs.player_hp < obs.player_max_hp * 0.3:
		score += 10.0  # 低血量时优先一切
	return score
