# ============================================================
# 大周天 — Policy (决策策略抽象接口)
# ============================================================
# 工具层: tools/simulation/policy/ — 不属于四层运行时架构
#
# 模拟与决策分离的核心。
# SimulationKernel 通过此接口注入决策逻辑。
#
# 实现:
#   - RandomPolicy: 纯随机（baseline）
#   - HeuristicPolicy: 贪心规则（优先高伤害）
#   - ScriptedPolicy: 预设动作序列（回放用）
# ============================================================
class_name Policy
extends RefCounted


## 给定观察和合法动作，返回选择的动作
## 默认实现: 选第一个动作
func select_action(obs: SimulationObservation, legal_actions: Array[SimulationAction]) -> SimulationAction:
	if legal_actions.is_empty():
		return SimulationAction.skip()
	return legal_actions[0]
