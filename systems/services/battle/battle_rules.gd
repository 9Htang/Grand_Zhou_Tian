# ============================================================
# 大周天 — BattleRules (战斗规则 — L2)
# ============================================================
# 四层定位: L2 Domain Layer — 纯规则, 无状态
#
# 职责: 战斗参数规则 (手牌数 / 抽牌数 / 上限 等)
# 红线: 不持有状态 / 不执行操作 / 不依赖 PlayerActor / GameManager
#
# 使用者: BattleController (L1) / SimulationKernel / ReplayEngine
# ============================================================
class_name BattleRules
extends Object


## 计算开局初始手牌数
static func get_initial_hand_size() -> int:
	return 5
