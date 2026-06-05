# ============================================================
# 大周天 — BattleStateMachine (战斗状态机 — 即时制)
# ============================================================
# 四层定位: L1 System Layer — 纯状态管理
#
# 即时制改造: 从 12 个回合状态扁平化为 4 个
#   PLAYING  — 战斗进行中, BattleClock 驱动
#   PAUSED   — 暂停 (目标选择/锻造/路径选择/手动暂停)
#   WON/LOST — 终端状态
#
# 移除的回合信号: turn_start, player_turn_start, enemy_turn_start,
#   qi_circulation_start, enemy_qi_circulation_start, turn_end
#   (全部由 BattleClock.tick 和具体系统信号代替)
# ============================================================
class_name BattleStateMachine
extends Node


enum BattleState {
	IDLE = -1,        ## 即时制: 战斗未初始化 (Phase 1 新增)
	PLAYING = 0,
	PAUSED = 1,
	RESOLVING = 2,    ## 即时制: effect_queue 正在串行结算 (Phase 1 新增)
	DIGEST = 3,       ## 即时制: 显著事件后慢动作窗口 (Phase 1 新增)
	GAME_OVER = 7,    ## 即时制: 战斗结束 (Phase 1 新增, 替代分散的胜/负)
	BATTLE_WON = 8,   ## DEPRECATED — Phase 4 移除, 用 GAME_OVER + result 替代
	BATTLE_LOST = 9,  ## DEPRECATED — Phase 4 移除, 用 GAME_OVER + result 替代
}


## 发射: 状态变化 (保留用于 UI 层的状态标签更新)
signal state_changed(from_state: int, to_state: int)

## 发射: 战斗胜利
signal battle_won()

## 发射: 战斗失败
signal battle_lost()

## 发射: 游戏暂停
signal playing()

## 发射: 游戏恢复
signal paused()

## 即时制新增信号
signal battle_started()   ## IDLE → PLAYING
signal battle_ended()     ## → GAME_OVER


var current_state: int = BattleState.PLAYING  ## Phase 4 改为 IDLE


const VALID_TRANSITIONS := {
	BattleState.IDLE:      [BattleState.PLAYING],
	BattleState.PLAYING:   [BattleState.PAUSED, BattleState.RESOLVING, BattleState.GAME_OVER, BattleState.BATTLE_WON, BattleState.BATTLE_LOST],
	BattleState.RESOLVING: [BattleState.PLAYING, BattleState.DIGEST, BattleState.GAME_OVER, BattleState.BATTLE_WON, BattleState.BATTLE_LOST],
	BattleState.DIGEST:    [BattleState.PLAYING, BattleState.RESOLVING],
	BattleState.PAUSED:    [BattleState.PLAYING, BattleState.GAME_OVER, BattleState.BATTLE_WON, BattleState.BATTLE_LOST],
	BattleState.GAME_OVER: [],
	BattleState.BATTLE_WON: [],
	BattleState.BATTLE_LOST: [],
}


func transition_to(new_state: int) -> void:
	if not _can_transition(current_state, new_state):
		push_warning("FSM: invalid transition ", current_state, " -> ", new_state)
		return

	var old := current_state
	current_state = new_state
	state_changed.emit(old, new_state)

	match new_state:
		BattleState.PLAYING:
			if old == BattleState.IDLE:
				battle_started.emit()
			playing.emit()
		BattleState.PAUSED:
			paused.emit()
		BattleState.RESOLVING:
			pass  # 进入结算, 不发 UI 信号
		BattleState.DIGEST:
			pass  # 消化窗口, 不发 UI 信号
		BattleState.GAME_OVER:
			battle_ended.emit()
		BattleState.BATTLE_WON:
			battle_won.emit()
		BattleState.BATTLE_LOST:
			battle_lost.emit()


func _can_transition(from_state: int, to_state: int) -> bool:
	var allowed: Array = VALID_TRANSITIONS.get(from_state, [])
	return to_state in allowed


func is_playing() -> bool:
	return current_state in [BattleState.PLAYING, BattleState.RESOLVING, BattleState.DIGEST]


func is_terminal() -> bool:
	return current_state in [BattleState.GAME_OVER, BattleState.BATTLE_WON, BattleState.BATTLE_LOST]


func get_state_name(state: int) -> String:
	match state:
		BattleState.IDLE: return "待初始化"
		BattleState.PLAYING: return "战斗中"
		BattleState.PAUSED: return "暂停"
		BattleState.RESOLVING: return "结算中"
		BattleState.DIGEST: return "消化中"
		BattleState.GAME_OVER: return "结束"
		BattleState.BATTLE_WON: return "胜利"
		BattleState.BATTLE_LOST: return "败北"
	return "?"
