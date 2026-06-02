# ============================================================
# 大周天 — BattleContext
# Resolver 执行时所需的战斗上下文
# 传入所有不可变的环境状态
# ============================================================
class_name BattleContext
extends RefCounted


## 当前回合数
var turn_count: int = 0

## 执行方 actor (玩家/敌人 CombatActor)
var actor: Node

## 目标方 actor
var opponent: Node

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


## 获取目标的当前 HP
func get_target_hp() -> int:
	if opponent and opponent.has_method("get_hp"):
		return opponent.get_hp()
	return 0


## 获取目标的当前格挡
func get_target_block() -> int:
	if opponent and opponent.get("current_block") != null:
		return opponent.current_block
	return 0


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
		"turn": return turn_count
		"hand_size": return _get_hand_size()
		"hp": return get_target_hp()
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
		"hp_below":
			return get_target_hp() < int(value)
		"hp_above":
			return get_target_hp() > int(value)
	return false


func _get_hand_size() -> int:
	if actor and actor.has_method("get_hand_size"):
		return actor.get_hand_size()
	return 0
