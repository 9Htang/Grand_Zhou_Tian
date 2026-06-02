# ============================================================
# 大周天 — BattleResult
# Resolver.resolve() 的输出
# 包含结算后的所有效果数据 + debug trace
# ============================================================
class_name BattleResult
extends RefCounted


# === 结算数值 ===

## 造成的伤害总量
var damage_dealt: int = 0

## 获得的格挡量
var block_gained: int = 0

## 恢复的生命值
var heal_done: int = 0

## 施加的状态效果 [{type: "burn", value: 3, turns: 2}, ...]
var status_applied: Array = []

## 抽取的卡牌数
var cards_drawn: int = 0

## 聚集的灵气量
var qi_gathered: int = 0

## 灵气恢复修正
var qi_regen_delta: float = 0.0


# === 元信息 ===

## 是否成功执行（条件未满足为 false）
var executed: bool = true

## 执行失败原因（条件未满足等）
var failure_reason: String = ""


# === Debug Trace ===

## 每一步的输出日志: ["Step1: built graph with 3 nodes", "Step2: applied +2 damage from upgrade", ...]
var trace: Array[String] = []


func add_trace(msg: String) -> void:
	trace.append(msg)


func get_trace_text() -> String:
	return "\n".join(trace)
