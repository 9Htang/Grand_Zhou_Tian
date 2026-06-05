# ============================================================
# 大周天 — SimulationReport (模拟结果报告)
# ============================================================
# 工具层: tools/simulation/ — 不属于四层运行时架构
#
# 从 EventRecorder 的事件流生成聚合统计。
# 按 actor_id 区分 "谁造成的伤害" vs "谁受到的伤害"。
# raw_events 保留原始数据，供 Phase 2 Analyzer 重算。
# ============================================================
class_name SimulationReport
extends RefCounted


## 是否获胜 (玩家存活且所有敌人死亡)
var win: bool = false

## 实际战斗时长 (秒)
var duration: float = 0.0

# === 伤害统计 ===

## 玩家造成的总伤害 (enemy damage_taken 的总和)
var total_damage_dealt: float = 0.0

## 玩家受到的总伤害 (player damage_taken 的总和)
var total_damage_taken: float = 0.0

# === 灵气统计 ===

## 灵气总生成量
var total_qi_generated: float = 0.0

## 灵气总消耗量
var total_qi_consumed: float = 0.0

## 灵气浪费量 (估算 — Phase 1 近似值, 见 qi_wasted_estimated 事件)
var total_qi_wasted_estimated: float = 0.0

## 战斗中达到的最高灵气值
var max_qi_reached: float = 0.0

# === 卡牌统计 ===

## 打出卡牌总数
var cards_played: int = 0

## 激活功法次数
var techniques_activated: int = 0

# === 原始数据 ===

## 完整事件流 — 供 Analyzer 重算
var raw_events: Array[SimulationEvent] = []


# ============================================================
# Factory
# ============================================================


## 从 Recorder 生成报告 — 唯一聚合入口
static func from_recorder(recorder: EventRecorder, won: bool, battle_duration: float) -> SimulationReport:
	var report := SimulationReport.new()
	report.win = won
	report.duration = battle_duration

	for e in recorder.events:
		match e.type:
			"damage_dealt":
				# 伤害施加者判断: actor_id 不是 player 的 → Phase 1 暂归为 unknown source
				# 所有伤害算入 total_damage_dealt (敌人受到的总伤害 = 玩家输出)
				report.total_damage_dealt += e.payload.get("amount", 0)
			"damage_taken":
				# Phase 1 遗留: 如果还有 damage_taken 类型事件, 按 target_id 分类
				if e.target_id == "player":
					report.total_damage_taken += e.payload.get("amount", 0)
			"qi_generated":
				if e.actor_id == "player":
					report.total_qi_generated += e.payload.get("amount", 0)
			"qi_consumed":
				if e.actor_id == "player":
					report.total_qi_consumed += e.payload.get("amount", 0)
			"qi_wasted_estimated":
				if e.actor_id == "player":
					report.total_qi_wasted_estimated += e.payload.get("amount", 0)
			"card_played":
				report.cards_played += 1
			"technique_activated":
				report.techniques_activated += 1

	# Track max qi from qi state snapshots
	for e in recorder.of_type("qi_state"):
		if e.actor_id == "player":
			var qi: float = e.payload.get("new_qi", 0.0)
			if qi > report.max_qi_reached:
				report.max_qi_reached = qi

	# Player damage taken (from damage_taken events with target_id="player")
	for e in recorder.of_type("damage_taken"):
		if e.target_id == "player":
			report.total_damage_taken += e.payload.get("amount", 0)

	# Preserve raw events for Phase 2 analysis
	report.raw_events = recorder.events.duplicate()
	return report


## 生成多行文本摘要
func to_text() -> String:
	var lines: PackedStringArray = []
	lines.append("=== Simulation Report ===")
	lines.append("Win: %s" % win)
	lines.append("Duration: %.1fs" % duration)
	lines.append("DPS: %.1f" % (total_damage_dealt / max(duration, 0.01)))
	lines.append("Damage Dealt: %.0f | Taken: %.0f" % [total_damage_dealt, total_damage_taken])
	lines.append("Qi Generated: %.0f | Consumed: %.0f | Wasted(est): %.0f" % [total_qi_generated, total_qi_consumed, total_qi_wasted_estimated])
	if total_qi_generated > 0:
		lines.append("Qi Utilization: %.0f%%" % (100.0 * total_qi_consumed / total_qi_generated))
	lines.append("Max Qi: %.0f" % max_qi_reached)
	lines.append("Cards Played: %d | Techniques: %d" % [cards_played, techniques_activated])
	lines.append("Events Recorded: %d" % raw_events.size())
	return "\n".join(lines)
