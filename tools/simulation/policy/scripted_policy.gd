# ============================================================
# 大周天 — ScriptedPolicy (回放脚本策略)
# ============================================================
# 按预设动作序列逐帧播放，用于 Replay 验证。
# 由原始运行的 DecisionTrace 构建。
# ============================================================
class_name ScriptedPolicy
extends Policy


## 预设动作序列
var _actions: Array[SimulationAction] = []

## 当前索引
var _index: int = 0


func select_action(_obs: SimulationObservation, _legal_actions: Array[SimulationAction]) -> SimulationAction:
	if _index >= _actions.size():
		return SimulationAction.skip()
	var a: SimulationAction = _actions[_index]
	_index += 1
	return a


## 从决策日志构建（用于回放验证）
func set_actions(actions: Array[SimulationAction]) -> void:
	_actions = actions
	_index = 0


func reset() -> void:
	_index = 0


static func from_decision_log(log: Array) -> ScriptedPolicy:
	var p := ScriptedPolicy.new()
	for d in log:
		if d is DecisionTrace:
			p._actions.append(d.chosen_action)
	return p
