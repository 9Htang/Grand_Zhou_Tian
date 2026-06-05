# ============================================================
# 大周天 — BattleContext
# Resolver 执行时所需的战斗上下文
# 传入所有不可变的环境状态
# ============================================================
class_name BattleContext
extends RefCounted


## 即时制: 战斗经过秒数 (替代回合数)
var elapsed_seconds: float = 0.0

## 确定性 RNG（由 Bootstrapper 注入，null = 使用全局随机）
var rng: DeterministicRNG = null

## 执行方 actor (玩家/敌人 CombatActor)
var actor: Node

## 所有敌人列表（用于多目标选择和 Provider 枚举）
var enemies: Array = []

## 牌库管理器引用 — 供 Provider 枚举卡牌
var deck: RefCounted = null

## RunModifier — 本局永久修正 (EffectOperator[])
var run_modifiers: Array = []

## BattleModifier — 本场临时修正 (EffectOperator[])
var battle_modifiers: Array = []

## 玩家境界
var realm: int = 1

## 玩家天资
var talent: int = 2

## 已解锁穴位列表
var unlocked_nodes: Array[String] = []

## 已激活功法 id 列表
var active_technique_ids: Array[String] = []

# === 即时制新增引用 (Phase 1: 字段声明, 暂未使用) ===
## 效果队列引用 — 串行执行 EffectProgram
var effect_queue: RefCounted = null

## 冷却管理引用 — 卡牌冷却门控
var cooldown_mgr: RefCounted = null

## 敌人计时系统引用 — 独立行动定时
var enemy_timer: RefCounted = null

## 事件流 — VM opcode emit 的唯一出口（live battle 时由 Bootstrapper 注入）
var event_stream: EventStream = null

## 当前 tick 编号 — 由 BattleController._on_clock_tick 推进
## VM opcode 使用 ctx.current_tick * tick_rate 计算事件时间
var current_tick: int = 0


## 检查条件: 是否满足打出条件
func check_condition(condition: String) -> bool:
	if condition.is_empty():
		return true
	for cond: String in condition.split(";"):
		cond = cond.strip_edges()
		if not _check_single(cond):
			return false
	return true


func _check_single(cond: String) -> bool:
	if ">=" in cond:
		var parts: PackedStringArray = cond.split(">=")
		return _get_stat(parts[0].strip_edges()) >= int(parts[1].strip_edges())
	elif "<=" in cond:
		var parts: PackedStringArray = cond.split("<=")
		return _get_stat(parts[0].strip_edges()) <= int(parts[1].strip_edges())
	elif ":" in cond:
		var parts: PackedStringArray = cond.split(":")
		return _check_has(parts[0].strip_edges(), parts[1].strip_edges())
	return true


func _get_stat(key: String) -> int:
	match key:
		"realm": return realm
		"talent": return talent
		"elapsed": return int(elapsed_seconds)
		"hand_size": return _get_hand_size()
	return 0


func _check_has(key: String, value: String) -> bool:
	match key:
		"has_technique":
			return value in active_technique_ids
		"node_unlocked":
			return value in unlocked_nodes
		"has_tag":
			# 由调用方在 Resolver 中扩展
			return false
	return false


func _get_hand_size() -> int:
	if actor and actor.has_method("get_hand_size"):
		return actor.get_hand_size()
	return 0
