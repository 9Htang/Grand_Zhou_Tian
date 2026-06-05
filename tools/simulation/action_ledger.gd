# ============================================================
# 大周天 — ActionLedger (动作账本)
# ============================================================
# 工具层: tools/simulation/ — 不属于四层运行时架构
#
# 纯追加日志 — 只记录，不决定。
# 职责:
#   - ID 分配 (stamp): 为 action 分配单调递增的唯一 ID
#   - 追加记录 (record): 将已执行的 action 追加到日志
#
# 红线:
#   - 不追踪执行边界 (current_id → Kernel 负责)
#   - 不参与执行排序 (ordering → Kernel Phase Model 负责)
#   - 不读取 world state
# ============================================================
class_name ActionLedger
extends RefCounted


## 下一个 action ID（单调递增）
var _next_id: int = 0

## 已录制的 action 序列（Dictionary 格式，追加只写）
var entries: Array[Dictionary] = []


## 为 action 分配 ID（纯函数，仅在 id < 0 时分配）
## 返回分配的 id
func stamp(action: SimulationAction) -> int:
	if action.id < 0:
		action.id = _next_id
		_next_id += 1
	return action.id


## 追加一条 action 记录（纯日志操作，不改变 ledger 自身状态）
func record(action: SimulationAction) -> void:
	entries.append(action.to_dict())


## 重置（新 run 开始时调用）
func reset() -> void:
	_next_id = 0
	entries.clear()
