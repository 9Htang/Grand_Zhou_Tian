# ============================================================
# 大周天 — RandomPolicy (随机决策)
# ============================================================
class_name RandomPolicy
extends Policy


var _rng: DeterministicRNG = null


func _init(rng: DeterministicRNG = null) -> void:
	_rng = rng


func select_action(_obs: SimulationObservation, legal_actions: Array[SimulationAction]) -> SimulationAction:
	if legal_actions.is_empty():
		return SimulationAction.skip()
	var idx: int = (_rng.randi() if _rng else randi()) % legal_actions.size()
	return legal_actions[idx]
