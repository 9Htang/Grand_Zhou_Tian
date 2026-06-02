# ============================================================
# 大周天 — Battle State Machine (战斗状态机)
# ============================================================
class_name BattleStateMachine
extends Node

# States
enum BattleState {
	INTRO = 0,
	PRE_BATTLE = 1,
	QI_CIRCULATION = 2,
	PLAYER_TURN = 3,
	PLAYER_ACTION = 4,
	ENEMY_TURN = 5,
	ENEMY_ACTION = 6,
	TURN_END = 7,
	BATTLE_WON = 8,
	BATTLE_LOST = 9,
	TURN_START = 10,
	ENEMY_QI_CIRCULATION = 11,
}

signal state_changed(from_state: int, to_state: int)
signal battle_won()
signal battle_lost()
signal player_turn_start()
signal enemy_turn_start()
signal qi_circulation_start()
signal enemy_qi_circulation_start()
signal turn_start()
signal turn_end()

var current_state: int = BattleState.PRE_BATTLE
var turn_count: int = 0

# Transition table: {from: [allowed_to]}
# 三阶段循环: 聚气 → 出牌 → 冲穴 → 敌人 → 回合结束
const VALID_TRANSITIONS := {
	BattleState.INTRO: [BattleState.PRE_BATTLE],
	BattleState.PRE_BATTLE: [BattleState.TURN_START],
	BattleState.TURN_START: [BattleState.PLAYER_TURN, BattleState.ENEMY_QI_CIRCULATION],
	BattleState.PLAYER_TURN: [BattleState.PLAYER_ACTION],
	BattleState.PLAYER_ACTION: [BattleState.QI_CIRCULATION, BattleState.BATTLE_WON, BattleState.BATTLE_LOST],
	BattleState.QI_CIRCULATION: [BattleState.ENEMY_TURN],
	BattleState.ENEMY_TURN: [BattleState.ENEMY_ACTION],
	BattleState.ENEMY_ACTION: [BattleState.ENEMY_QI_CIRCULATION],
	BattleState.ENEMY_QI_CIRCULATION: [BattleState.TURN_END],
	BattleState.TURN_END: [BattleState.TURN_START, BattleState.BATTLE_WON, BattleState.BATTLE_LOST],
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

	# Emit specific signals
	if new_state == BattleState.TURN_START:
		turn_start.emit()
	elif new_state == BattleState.PLAYER_TURN:
		turn_count += 1
		player_turn_start.emit()
	elif new_state == BattleState.ENEMY_TURN:
		enemy_turn_start.emit()
	elif new_state == BattleState.QI_CIRCULATION:
		qi_circulation_start.emit()
	elif new_state == BattleState.ENEMY_QI_CIRCULATION:
		enemy_qi_circulation_start.emit()
	elif new_state == BattleState.TURN_END:
		turn_end.emit()
	elif new_state == BattleState.BATTLE_WON:
		battle_won.emit()
	elif new_state == BattleState.BATTLE_LOST:
		battle_lost.emit()


func _can_transition(from_state: int, to_state: int) -> bool:
	var allowed: Array = VALID_TRANSITIONS.get(from_state, [])
	return to_state in allowed


func get_state_name(state: int) -> String:
	match state:
		BattleState.INTRO: return "INTRO"
		BattleState.PRE_BATTLE: return "PRE_BATTLE"
		BattleState.QI_CIRCULATION: return "QI_CIRCULATION"
		BattleState.PLAYER_TURN: return "PLAYER_TURN"
		BattleState.PLAYER_ACTION: return "PLAYER_ACTION"
		BattleState.ENEMY_TURN: return "ENEMY_TURN"
		BattleState.ENEMY_ACTION: return "ENEMY_ACTION"
		BattleState.TURN_END: return "TURN_END"
		BattleState.BATTLE_WON: return "BATTLE_WON"
		BattleState.BATTLE_LOST: return "BATTLE_LOST"
		BattleState.TURN_START: return "TURN_START"
		BattleState.ENEMY_QI_CIRCULATION: return "敌人冲穴"
	return "?"
