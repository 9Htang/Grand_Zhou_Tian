# ============================================================
# 大周天 — ReplayExporter (录像导出器)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 将 SimulationRun + BattleReplayAdapter 序列化为纯数据字典。
# 零 Node/Actor 引用 — 全部 primitive types。
#
# 导出格式 (v1):
#   {
#     "version": 1,
#     "engine_version": "4.6.3",
#     "seed": int,
#     "config": {...},
#     "initial_state": {player: {...}, enemies: [...]},
#     "actions": [{id, tick, type, card_id, hand_index, target}],
#     "events": [{tick, time, type, actor_id, target_id, source, payload}],
#     "state_hashes": [int, ...],
#     "snapshots": [{tick, player: {...}, enemies: [...]}],
#     "metrics": {total_damage, total_qi, ...},
#     "result": {win, total_ticks, rng_call_count}
#   }
#
# 使用:
#   var data = ReplayExporter.export(run, adapter)
#   ReplayExporter.save_to_file(data, "user://replays/battle_001.replay")
# ============================================================
class_name ReplayExporter
extends RefCounted


const FORMAT_VERSION: int = 1


# ============================================================
# Public — Export
# ============================================================

## 导出 SimulationRun + BattleReplayAdapter 为可序列化字典
static func export(run: SimulationRun, adapter: BattleReplayAdapter = null) -> Dictionary:
	if run == null:
		push_error("ReplayExporter.export(): run is null")
		return {}

	var data: Dictionary = {}

	# === Header ===
	data["version"] = FORMAT_VERSION
	data["engine_version"] = _engine_version_string()
	data["exported_at"] = Time.get_datetime_string_from_system() if Time else ""
	data["seed"] = run.seed

	# === Config ===
	data["config"] = _export_config(run)

	# === Initial State (from adapter snapshot at tick 0, or final state as fallback) ===
	data["initial_state"] = _export_initial_state(run, adapter)

	# === Actions ===
	data["actions"] = _export_actions(run)

	# === Events ===
	data["events"] = _export_events(run)

	# === State Hashes ===
	data["state_hashes"] = run.state_hashes.duplicate() if run.state_hashes else []

	# === Snapshots (from adapter cache) ===
	data["snapshots"] = _export_snapshots(adapter)

	# === Metrics ===
	data["metrics"] = run.metrics.duplicate() if run.metrics else {}

	# === Result ===
	data["result"] = {
		"win": run.win,
		"total_ticks": run.total_ticks,
		"rng_call_count": run.rng_call_count,
		"final_player_state": run.final_player_state.duplicate() if run.final_player_state else {},
		"final_enemy_states": run.final_enemy_states.duplicate(true) if run.final_enemy_states else [],
	}

	return data


# ============================================================
# Public — File I/O
# ============================================================

## 保存导出数据到 .replay 文件
static func save_to_file(data: Dictionary, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ReplayExporter: cannot write to %s" % path)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


## 导出并一步保存
static func export_to_file(run: SimulationRun, path: String, adapter: BattleReplayAdapter = null) -> bool:
	var data := export(run, adapter)
	if data.is_empty():
		return false
	return save_to_file(data, path)


# ============================================================
# Internal — Config
# ============================================================

static func _export_config(run: SimulationRun) -> Dictionary:
	if run.config == null:
		return {}

	return {
		"encounter_id": run.config.encounter_id,
		"tick_rate": run.config.tick_rate,
		"duration": run.config.duration,
		"auto_play_enabled": run.config.auto_play_enabled,
		"draw_interval": run.config.draw_interval,
		"draw_count": run.config.draw_count,
	}


# ============================================================
# Internal — Initial State
# ============================================================

static func _export_initial_state(run: SimulationRun, adapter: BattleReplayAdapter) -> Dictionary:
	# 优先从 adapter 的 tick 0 快照获取
	if adapter:
		var snap0: Dictionary = adapter.get_snapshot(0)
		if not snap0.is_empty():
			return {
				"player": snap0.get("player", {}),
				"enemies": snap0.get("enemies", []),
			}

	# 降级: 使用 SimulationRun 的最终状态（不完美，但保证不崩）
	var player: Dictionary = {
		"hp": run.final_player_state.get("hp", 0),
		"max_hp": run.final_player_state.get("max_hp", 0),
		"qi": run.final_player_state.get("qi", 0),
		"capacity": run.final_player_state.get("capacity", 0),
		"block": 0,
	}

	var enemies: Array[Dictionary] = []
	for i in run.final_enemy_states.size():
		var es: Dictionary = run.final_enemy_states[i]
		enemies.append({
			"id": "enemy_%d" % i,
			"hp": es.get("hp", 0),
			"max_hp": es.get("max_hp", 0),
			"qi": es.get("qi", 0),
			"block": 0,
		})

	return {
		"player": player,
		"enemies": enemies,
	}


# ============================================================
# Internal — Actions
# ============================================================

static func _export_actions(run: SimulationRun) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for action_dict in run.actions:
		if action_dict == null:
			continue
		result.append({
			"id": action_dict.get("id", -1),
			"tick": action_dict.get("tick", 0),
			"type": action_dict.get("type", "SKIP"),
			"card_id": action_dict.get("card_id", ""),
			"hand_index": action_dict.get("card_index", action_dict.get("hand_index", -1)),
			"target": action_dict.get("target_index", action_dict.get("target", -1)),
		})

	return result


# ============================================================
# Internal — Events
# ============================================================

static func _export_events(run: SimulationRun) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	var events: Array[SimulationEvent] = run.events.all()
	for e in events:
		if e == null:
			continue
		var tick_rate: float = run.config.tick_rate if run.config and run.config.tick_rate > 0.0 else 0.05
		result.append({
			"tick": int(e.time / tick_rate),
			"time": e.time,
			"type": e.type,
			"actor_id": e.actor_id,
			"target_id": e.target_id,
			"source": e.source,
			"source_card_id": e.source_card_id,
			"action_id": e.action_id,
			"state_hash_before": e.state_hash_before,
			"state_hash_after": e.state_hash_after,
			"rng_call_index": e.rng_call_index,
			"payload": e.payload.duplicate(),
		})

	return result


# ============================================================
# Internal — Snapshots
# ============================================================

static func _export_snapshots(adapter: BattleReplayAdapter) -> Array[Dictionary]:
	if adapter == null:
		return []

	var result: Array[Dictionary] = []
	var count: int = adapter.tick_count()

	# 每 N 个 tick 存一个快照（平衡文件大小和 seek 性能）
	const SNAPSHOT_INTERVAL: int = 10
	for i in range(0, count, SNAPSHOT_INTERVAL):
		var snap: Dictionary = adapter.get_snapshot(i)
		if snap.is_empty():
			continue
		result.append(snap)

	# 确保最后一个 tick 被保存
	if count > 0 and count % SNAPSHOT_INTERVAL != 1:
		var last: Dictionary = adapter.get_snapshot(count - 1)
		if not last.is_empty():
			result.append(last)

	return result


# ============================================================
# Internal — Helpers
# ============================================================

static func _engine_version_string() -> String:
	var v: Dictionary = Engine.get_version_info()
	return "%d.%d.%d" % [v.get("major", 4), v.get("minor", 6), v.get("patch", 3)]
