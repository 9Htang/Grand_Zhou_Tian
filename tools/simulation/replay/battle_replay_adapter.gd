# ============================================================
# 大周天 — BattleReplayAdapter (战斗回放适配器)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 将 SimulationEvent 流翻译为 BattleSnapshot 兼容的 UI 状态。
# 核心思想: Event Sourcing — 从初始状态出发，逐事件累加状态变化。
#
# 职责:
#   - 维护"虚拟"战斗状态（HP/Qi/Block/Buff）
#   - process_event() 消费单事件并更新状态
#   - seek(tick) 通过重放到目标 tick 重建状态
#   - to_snapshot() 产出 BattleSnapshot 兼容数据
#
# 红线:
#   - 不改真实 Actor 状态
#   - 不运行战斗逻辑
#   - 不做动画
# ============================================================
class_name BattleReplayAdapter
extends RefCounted


# ============================================================
# Virtual State — Player
# ============================================================

var player_hp: int = 0
var player_max_hp: int = 0
var player_qi: int = 0
var player_qi_capacity: int = 0
var player_block: int = 0
var player_qi_gather_rate: int = 0
var player_realm: int = 1
var player_techniques: Array = []          # 活跃功法名列表
var player_buffs: Array = []               # buff 名列表


# ============================================================
# Virtual State — Enemies
# ============================================================

## {enemy_id: {hp, max_hp, qi, block, techniques, buffs}}
var enemy_states: Dictionary = {}


# ============================================================
# State — Internal
# ============================================================

var _run: SimulationRun = null
var _events: Array[SimulationEvent] = []
var _current_tick: int = 0
var _event_index: int = 0
var _tick_rate: float = 0.05

## seek 缓存 — 每 N ticks 存一个快照，加速 seek
const CACHE_INTERVAL: int = 50
var _seek_cache: Dictionary = {}  # {tick: state_dict}

## 预建快照缓存 — bind() 时一次性构建全部 tick 的状态
## _snapshots[tick] = {player: {...}, enemies: [{...}]}
var _snapshots: Array[Dictionary] = []


# ============================================================
# Public — Initialize
# ============================================================

## 设置玩家初始状态
func set_player_initial(hp: int, max_hp: int, qi: int, qi_cap: int, qi_rate: int = 0, realm: int = 1) -> void:
	player_hp = hp
	player_max_hp = max_hp
	player_qi = qi
	player_qi_capacity = qi_cap
	player_qi_gather_rate = qi_rate
	player_realm = realm
	player_block = 0
	player_techniques.clear()
	player_buffs.clear()


## 注册敌人初始状态
func register_enemy(enemy_id: String, hp: int, max_hp: int, qi: int = 0) -> void:
	enemy_states[enemy_id] = {
		"hp": hp,
		"max_hp": max_hp,
		"qi": qi,
		"block": 0,
		"techniques": [],
		"buffs": [],
	}


## 绑定 SimulationRun 并预建全部快照缓存
func bind(run: SimulationRun) -> void:
	_run = run
	_events = run.events.all()
	_tick_rate = run.config.tick_rate if run.config and run.config.tick_rate > 0.0 else 0.05
	_current_tick = 0
	_event_index = 0
	_seek_cache.clear()
	_snapshots.clear()

	# 预建全部 tick 快照 — O(n) 单次扫描，后续 O(1) 查询
	_build_all_snapshots()

	# 重置到 tick 0 初始状态
	seek(0)


# ============================================================
# Public — Event Processing
# ============================================================

## 消费单条事件，更新虚拟状态
func process_event(event: SimulationEvent) -> void:
	if event == null:
		return

	match event.type:
		"damage_dealt", "damage_taken":
			_apply_damage(event)
		"heal_received":
			_apply_heal(event)
		"qi_generated":
			_apply_qi_generated(event)
		"qi_consumed":
			_apply_qi_consumed(event)
		"block_gained":
			_apply_block(event)
		"technique_activated":
			_apply_technique_on(event)
		"technique_deactivated":
			_apply_technique_off(event)
		"buffs_updated":
			_apply_buffs(event)
		_:
			pass  # qi_state / qi_wasted_estimated 不影响状态


func _apply_damage(event: SimulationEvent) -> void:
	var amount: int = event.payload.get("amount", 0)
	var target: String = event.target_id

	if target == "player":
		# 先扣护盾
		var blocked: int = min(amount, player_block)
		player_block -= blocked
		player_hp -= (amount - blocked)
		player_hp = max(0, player_hp)
	elif enemy_states.has(target):
		var es: Dictionary = enemy_states[target]
		var blocked: int = min(amount, es.get("block", 0))
		es["block"] = es["block"] - blocked
		es["hp"] = es["hp"] - (amount - blocked)
		es["hp"] = max(0, es["hp"])


func _apply_heal(event: SimulationEvent) -> void:
	var amount: int = event.payload.get("amount", 0)
	var target: String = event.target_id

	if target == "player":
		player_hp = min(player_hp + amount, player_max_hp)
	elif enemy_states.has(target):
		var es: Dictionary = enemy_states[target]
		es["hp"] = min(es["hp"] + amount, es["max_hp"])


func _apply_qi_generated(event: SimulationEvent) -> void:
	var amount: int = event.payload.get("amount", 0)
	var actor: String = event.actor_id

	if actor == "player":
		player_qi = min(player_qi + amount, player_qi_capacity)
	elif enemy_states.has(actor):
		var es: Dictionary = enemy_states[actor]
		es["qi"] = es["qi"] + amount


func _apply_qi_consumed(event: SimulationEvent) -> void:
	var amount: int = event.payload.get("amount", 0)
	var actor: String = event.actor_id

	if actor == "player":
		player_qi = max(0, player_qi - amount)
	elif enemy_states.has(actor):
		var es: Dictionary = enemy_states[actor]
		es["qi"] = max(0, es["qi"] - amount)


func _apply_block(event: SimulationEvent) -> void:
	var amount: int = event.payload.get("amount", 0)
	var target: String = event.target_id

	if target == "player":
		player_block += amount
	elif enemy_states.has(target):
		var es: Dictionary = enemy_states[target]
		es["block"] = es.get("block", 0) + amount


func _apply_technique_on(event: SimulationEvent) -> void:
	var actor: String = event.actor_id
	if actor == "player":
		if not player_techniques.has(event.source):
			player_techniques.append(event.source)
	elif enemy_states.has(actor):
		var es: Dictionary = enemy_states[actor]
		var techs: Array = es.get("techniques", [])
		if not techs.has(event.source):
			techs.append(event.source)


func _apply_technique_off(event: SimulationEvent) -> void:
	var actor: String = event.actor_id
	if actor == "player":
		player_techniques.erase(event.source)
	elif enemy_states.has(actor):
		var es: Dictionary = enemy_states[actor]
		var techs: Array = es.get("techniques", [])
		techs.erase(event.source)


func _apply_buffs(event: SimulationEvent) -> void:
	# buffs_updated 的 payload 可能包含完整 buff 列表
	var actor: String = event.actor_id
	var buff_list: Array = event.payload.get("buffs", [])
	if actor == "player":
		if not buff_list.is_empty():
			player_buffs = buff_list.duplicate()
	elif enemy_states.has(actor):
		if not buff_list.is_empty():
			var es: Dictionary = enemy_states[actor]
			es["buffs"] = buff_list.duplicate()


# ============================================================
# Public — Seek (重放到目标 tick)
# ============================================================

## 跳转到指定 tick（从预建快照恢复 — O(1)）
func seek(target_tick: int) -> void:
	if _snapshots.is_empty():
		return

	target_tick = clampi(target_tick, 0, _snapshots.size() - 1)
	_current_tick = target_tick

	# 从预建快照恢复虚拟状态
	var snap: Dictionary = _snapshots[target_tick]
	_restore_from_snapshot(snap)


# ============================================================
# Public — Query
# ============================================================

## 当前 tick
func get_current_tick() -> int:
	return _current_tick


## 产出 UI 兼容的状态字典（可直接喂给 HP/Qi bar）
func get_player_vitals() -> Dictionary:
	return {
		"hp": player_hp,
		"max_hp": player_max_hp,
		"qi": player_qi,
		"capacity": player_qi_capacity,
		"block": player_block,
		"qi_gather_rate": player_qi_gather_rate,
		"realm": player_realm,
	}


## 产出敌人状态列表
func get_enemy_vitals() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy_id in enemy_states:
		var es: Dictionary = enemy_states[enemy_id]
		result.append({
			"id": enemy_id,
			"hp": es.get("hp", 0),
			"max_hp": es.get("max_hp", 0),
			"qi": es.get("qi", 0),
			"block": es.get("block", 0),
		})
	return result


## 获取状态差异（当前 tick vs 上一 tick）
func get_diff() -> Dictionary:
	return {
		"player": get_player_vitals(),
		"enemies": get_enemy_vitals(),
		"tick": _current_tick,
	}


## 获取指定 tick 的完整状态快照 — O(1)
func get_snapshot(tick: int) -> Dictionary:
	if _snapshots.is_empty():
		return {}
	tick = clampi(tick, 0, _snapshots.size() - 1)
	return _snapshots[tick]


## 获取当前 live 状态的快照（与缓存快照同格式 — 用于实时播放时推送 UI）
func get_live_snapshot() -> Dictionary:
	return _capture_state(_current_tick)


## 缓存中的 tick 总数
func tick_count() -> int:
	return _snapshots.size()


# ============================================================
# Internal — Snapshot Building
# ============================================================

## 单次 O(n) 扫描全部事件，在每个 tick 边界保存状态快照
func _build_all_snapshots() -> void:
	if _events.is_empty():
		return

	var max_tick: int = int(_events[_events.size() - 1].time / _tick_rate)

	# 保存 tick 0 的初始状态
	_snapshots.append(_capture_state(0))

	var current_tick: int = 0
	for e in _events:
		var e_tick: int = int(e.time / _tick_rate)

		# tick 边界 — 保存上一 tick 结束时的状态
		while current_tick < e_tick:
			current_tick += 1
			_snapshots.append(_capture_state(current_tick))

		# 应用事件
		_process_event_internal(e)

	# 补齐尾部 tick
	while current_tick < max_tick:
		current_tick += 1
		_snapshots.append(_capture_state(current_tick))


## 内部事件处理 — 不触发缓存操作
func _process_event_internal(event: SimulationEvent) -> void:
	match event.type:
		"damage_dealt", "damage_taken":
			_apply_damage(event)
		"heal_received":
			_apply_heal(event)
		"qi_generated":
			_apply_qi_generated(event)
		"qi_consumed":
			_apply_qi_consumed(event)
		"block_gained":
			_apply_block(event)
		"technique_activated":
			_apply_technique_on(event)
		"technique_deactivated":
			_apply_technique_off(event)
		"buffs_updated":
			_apply_buffs(event)


## 捕获当前虚拟状态为快照字典
func _capture_state(tick: int) -> Dictionary:
	var enemy_list: Array[Dictionary] = []
	for enemy_id in enemy_states:
		var es: Dictionary = enemy_states[enemy_id]
		enemy_list.append({
			"id": enemy_id,
			"hp": es.get("hp", 0),
			"max_hp": es.get("max_hp", 0),
			"qi": es.get("qi", 0),
			"block": es.get("block", 0),
		})

	return {
		"tick": tick,
		"player": {
			"hp": player_hp,
			"max_hp": player_max_hp,
			"qi": player_qi,
			"capacity": player_qi_capacity,
			"block": player_block,
			"qi_gather_rate": player_qi_gather_rate,
			"realm": player_realm,
		},
		"enemies": enemy_list,
	}


## 从快照字典恢复虚拟状态
func _restore_from_snapshot(snap: Dictionary) -> void:
	var p: Dictionary = snap.get("player", {})
	player_hp = p.get("hp", player_hp)
	player_max_hp = p.get("max_hp", player_max_hp)
	player_qi = p.get("qi", player_qi)
	player_qi_capacity = p.get("capacity", player_qi_capacity)
	player_block = p.get("block", player_block)
	player_qi_gather_rate = p.get("qi_gather_rate", player_qi_gather_rate)
	player_realm = p.get("realm", player_realm)

	var enemies: Array = snap.get("enemies", [])
	for entry in enemies:
		var eid: String = entry.get("id", "")
		if eid.is_empty() or not enemy_states.has(eid):
			continue
		var es: Dictionary = enemy_states[eid]
		es["hp"] = entry.get("hp", es.get("hp", 0))
		es["max_hp"] = entry.get("max_hp", es.get("max_hp", 0))
		es["qi"] = entry.get("qi", es.get("qi", 0))
		es["block"] = entry.get("block", 0)


# ============================================================
# Internal — Cache
# ============================================================

func _save_cache(tick: int) -> void:
	_seek_cache[tick] = {
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"player_qi": player_qi,
		"player_qi_capacity": player_qi_capacity,
		"player_block": player_block,
		"player_qi_gather_rate": player_qi_gather_rate,
		"player_realm": player_realm,
		"player_techniques": player_techniques.duplicate(),
		"player_buffs": player_buffs.duplicate(),
		"enemy_states": enemy_states.duplicate(true),
		"_event_index": _event_index,
	}


func _restore_cache(data: Dictionary) -> void:
	player_hp = data.get("player_hp", 0)
	player_max_hp = data.get("player_max_hp", 0)
	player_qi = data.get("player_qi", 0)
	player_qi_capacity = data.get("player_qi_capacity", 0)
	player_block = data.get("player_block", 0)
	player_qi_gather_rate = data.get("player_qi_gather_rate", 0)
	player_realm = data.get("player_realm", 1)
	player_techniques = data.get("player_techniques", []).duplicate()
	player_buffs = data.get("player_buffs", []).duplicate()
	enemy_states = data.get("enemy_states", {}).duplicate(true)
