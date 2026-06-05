# ============================================================
# 大周天 — EventStream (唯一事件流)
# ============================================================
# 工具层: tools/simulation/events/ — 不属于四层运行时架构
#
# 工业级事件流 — SimulationKernel 的唯一输出。
# 所有派生视图（Report / Replay / AI Dataset / Balance）从此构建。
#
# EventRecorder 降级为此类的兼容别名。
#
# 核心设计:
#   - EventStream = Single Source of Truth
#   - 每条事件带 state_hash_before/after + rng_call_index
#   - 支持按类型/时间/actor/card 多维度查询
# ============================================================
class_name EventStream
extends RefCounted


# ============================================================
# State
# ============================================================

## 全部事件（按时间顺序追加）
var _events: Array[SimulationEvent] = []


# ============================================================
# Public — Emit
# ============================================================

## 发射一条事件到流中
func emit(
	p_time: float, p_type: String,
	p_actor_id: String, p_target_id: String, p_source: String,
	p_payload: Dictionary,
	p_instruction_index: int = -1,
	p_opcode: String = "",
	p_source_card_id: String = "",
	p_hash_before: int = 0, p_hash_after: int = 0,
	p_rng_call: int = 0,
	p_event_id: String = "",
	p_parent_event_id: String = "",
	p_action_id: int = -1,
) -> void:
	var e := SimulationEvent.new()
	e.time = p_time
	e.type = p_type
	e.actor_id = p_actor_id
	e.target_id = p_target_id
	e.source = p_source
	e.payload = p_payload
	e.state_hash_before = p_hash_before
	e.state_hash_after = p_hash_after
	e.rng_call_index = p_rng_call
	e.event_id = p_event_id
	e.parent_event_id = p_parent_event_id
	e.instruction_index = p_instruction_index
	e.opcode = p_opcode
	e.source_card_id = p_source_card_id
	e.action_id = p_action_id
	_events.append(e)


# ============================================================
# Public — Query
# ============================================================

## 返回全部事件
func all() -> Array[SimulationEvent]:
	return _events


## 返回事件总数
func size() -> int:
	return _events.size()


## 按事件类型过滤
func of_type(type: String) -> Array[SimulationEvent]:
	var result: Array[SimulationEvent] = []
	for e in _events:
		if e.type == type:
			result.append(e)
	return result


## 按 actor 过滤
func for_actor(actor_id: String) -> Array[SimulationEvent]:
	var result: Array[SimulationEvent] = []
	for e in _events:
		if e.actor_id == actor_id:
			result.append(e)
	return result


## 按 tick 范围过滤 (time 字段即为模拟时间)
func get_range(tick_start: float, tick_end: float) -> Array[SimulationEvent]:
	var result: Array[SimulationEvent] = []
	for e in _events:
		if e.time >= tick_start and e.time <= tick_end:
			result.append(e)
	return result


## 按来源卡牌过滤
func for_card(card_id: String) -> Array[SimulationEvent]:
	var result: Array[SimulationEvent] = []
	for e in _events:
		if e.source_card_id == card_id:
			result.append(e)
	return result


## 提取 hash 链 — 用于 SimulationVerifier 比对
func get_hashes() -> Array[int]:
	var hashes: Array[int] = []
	for e in _events:
		if e.state_hash_after != 0:
			hashes.append(e.state_hash_after)
	return hashes


# ============================================================
# Public — Mutation
# ============================================================

## 清空全部事件
func clear() -> void:
	_events.clear()


# ============================================================
# Compat — EventRecorder 兼容层
# ============================================================

## 兼容旧 EventRecorder.record() 签名
func record(time: float, type: String, actor_id: String, target_id: String, source: String, payload: Dictionary) -> void:
	emit(time, type, actor_id, target_id, source, payload)
