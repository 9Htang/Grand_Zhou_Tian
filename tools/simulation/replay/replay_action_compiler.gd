# ============================================================
# 大周天 — ReplayActionCompiler (事件→动作反向编译器)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# ⚠️ DEPRECATED — Migration Layer Only
#   新录像优先使用 SimulationRun.actions（直接录制），
#   本模块仅用于兼容没有 actions 字段的旧录像。
#   不要扩展此文件的功能。
#
# 将 SimulationEvent 流转换为 SimulationAction 序列。
#
# 设计原则:
#   - 纯静态函数 — 无状态，无副作用
#   - source_type == "INPUT" 过滤 — 只取玩家输入，系统/触发事件由 VM 重新产生
#   - source_card_id 为稳定锚点 — hand_index 不可靠（shuffle/draw/auto_play 影响手牌结构）
#   - runtime_card_uid 为将来一级锚点（Phase 2）
#
# 事件→动作映射:
#   "card_played" (INPUT) → SimulationAction.play_card(hand_idx, card_id, target_idx)
# ============================================================
class_name ReplayActionCompiler
extends RefCounted


## 将事件流编译为可重放的动作序列
## 只编译玩家输入事件；系统事件 (damage/qi/status) 由 VM 在重跑时重新产生
static func compile(events: Array[SimulationEvent]) -> Array[SimulationAction]:
	var actions: Array[SimulationAction] = []
	var next_action_id: int = 0

	for e in events:
		if not _is_input_action(e):
			continue

		match e.type:
			"card_played":
				var action: SimulationAction = _compile_card_play(e, next_action_id)
				actions.append(action)
				next_action_id += 1

	return actions


## 过滤: 只有 source_type == "INPUT" 的 card_played 是玩家输入动作
## TIME 事件 (damage_dealt / qi_generated / buff) 由 VM 重新产生
## TRIGGER 事件 (连锁 / 复制 / 触发) 也由 VM 重跑时产生
static func _is_input_action(e: SimulationEvent) -> bool:
	return e.type == "card_played" and e.payload.get("source_type", "") == "INPUT"


## 编译单条出牌事件为动作
## 锚点优先级:
##   1. runtime_card_uid（将来实现 — 每张卡实例的全局唯一 ID）
##   2. source_card_id（卡牌数据 ID，当前一级锚点）
##   3. hand_index（最不可靠，仅 fallback）
static func _compile_card_play(event: SimulationEvent, action_id: int) -> SimulationAction:
	var hand_idx: int = event.payload.get("hand_index", -1)
	var card_id: String = event.source_card_id
	var target_idx: int = event.payload.get("target_index", -1)

	var action := SimulationAction.play_card(hand_idx, card_id, target_idx)
	action.id = action_id
	return action
