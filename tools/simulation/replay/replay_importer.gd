# ============================================================
# 大周天 — ReplayImporter (录像导入器)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 从 .replay 文件重建 SimulationRun + 初始状态。
# 产出的 SimulationRun 可直接喂给 ReplayViewer.load_replay()。
#
# 使用:
#   var result = ReplayImporter.load("user://replays/battle_001.replay")
#   if result:
#       viewer.setup_player(result.initial_player)
#       viewer.setup_enemies(result.initial_enemies)
#       viewer.load_replay(result.run)
#       viewer.play()
#
# 关键保证:
#   - 零 Node/Actor 引用
#   - EventStream 完整重建
#   - 初始状态独立返回（SimulationRun 只有 final state）
# ============================================================
class_name ReplayImporter
extends RefCounted


# ============================================================
# ImportResult — 导入产物
# ============================================================

class ImportResult:
	var run: SimulationRun = null
	var initial_player: Dictionary = {}
	var initial_enemies: Array[Dictionary] = []
	var version: int = 0
	var seed: int = 0
	var config: Dictionary = {}
	var metrics: Dictionary = {}
	var result_info: Dictionary = {}

	func is_valid() -> bool:
		return run != null


# ============================================================
# Public — Load
# ============================================================

## 从 .replay 文件加载并重建 SimulationRun
static func load(path: String) -> ImportResult:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ReplayImporter: cannot open %s" % path)
		return null

	var text := file.get_as_text()
	file.close()

	var data: Dictionary = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("ReplayImporter: invalid JSON in %s" % path)
		return null

	return build(data)


## 从已解析的 Dictionary 重建（用于网络传输或内存导入）
static func build(data: Dictionary) -> ImportResult:
	if data.is_empty():
		return null

	var result := ImportResult.new()

	# === Header ===
	result.version = data.get("version", 0)
	result.seed = data.get("seed", 0)
	result.config = data.get("config", {})
	result.metrics = data.get("metrics", {})
	result.result_info = data.get("result", {})

	# === Initial State ===
	var init: Dictionary = data.get("initial_state", {})
	result.initial_player = init.get("player", {})
	result.initial_enemies = init.get("enemies", [])

	# === Build SimulationRun ===
	result.run = _build_run(data)

	return result


# ============================================================
# Internal — Build SimulationRun
# ============================================================

static func _build_run(data: Dictionary) -> SimulationRun:
	var run := SimulationRun.new()

	# --- Meta ---
	run.seed = data.get("seed", 0)
	run.replay_version = data.get("version", 1)

	# --- Config ---
	run.config = _build_config(data.get("config", {}))

	# --- Events (重建 EventStream) ---
	run.events = _build_event_stream(data.get("events", []), run.config.tick_rate)

	# --- Actions ---
	run.actions = _build_actions(data.get("actions", []))

	# --- State Hashes ---
	var hashes: Array = data.get("state_hashes", [])
	run.state_hashes = hashes
	run.total_ticks = hashes.size() if not hashes.is_empty() else data.get("result", {}).get("total_ticks", 0)

	# --- Result Info ---
	var result_info: Dictionary = data.get("result", {})
	run.win = result_info.get("win", false)
	run.rng_call_count = result_info.get("rng_call_count", 0)
	run.final_player_state = result_info.get("final_player_state", {}).duplicate()
	run.final_enemy_states = result_info.get("final_enemy_states", []).duplicate(true)

	# --- Metrics ---
	run.metrics = data.get("metrics", {}).duplicate()

	return run


# ============================================================
# Internal — Config
# ============================================================

static func _build_config(cfg: Dictionary) -> SimulationConfig:
	var config := SimulationConfig.new()
	if cfg.is_empty():
		return config

	config.encounter_id = cfg.get("encounter_id", config.encounter_id)
	config.tick_rate = cfg.get("tick_rate", config.tick_rate)
	config.duration = cfg.get("duration", config.duration)
	config.auto_play_enabled = cfg.get("auto_play_enabled", config.auto_play_enabled)
	config.draw_interval = cfg.get("draw_interval", config.draw_interval)
	config.draw_count = cfg.get("draw_count", config.draw_count)
	return config


# ============================================================
# Internal — Event Stream
# ============================================================

static func _build_event_stream(events: Array, tick_rate: float) -> EventStream:
	var stream := EventStream.new()

	for entry in events:
		if entry == null:
			continue

		stream.emit(
			entry.get("time", 0.0),
			entry.get("type", ""),
			entry.get("actor_id", ""),
			entry.get("target_id", ""),
			entry.get("source", ""),
			entry.get("payload", {}),
			-1,  # instruction_index
			"",  # opcode
			entry.get("source_card_id", ""),
			entry.get("state_hash_before", 0),
			entry.get("state_hash_after", 0),
			entry.get("rng_call_index", 0),
			"",  # event_id (reconstructed)
			"",  # parent_event_id
			entry.get("action_id", -1),
		)

	return stream


# ============================================================
# Internal — Actions
# ============================================================

static func _build_actions(raw: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for entry in raw:
		if entry == null:
			continue
		result.append({
			"id": entry.get("id", -1),
			"tick": entry.get("tick", 0),
			"type": entry.get("type", ""),
			"card_id": entry.get("card_id", ""),
			"card_index": entry.get("hand_index", entry.get("card_index", -1)),
			"target_index": entry.get("target", entry.get("target_index", -1)),
		})

	return result


# ============================================================
# Public — Convenience: Load + Setup Viewer
# ============================================================

## 一步加载并配置 ReplayViewer
static func load_into_viewer(path: String, viewer: ReplayViewer) -> bool:
	var result := load(path)
	if result == null or not result.is_valid():
		return false

	# 设置初始状态
	var p: Dictionary = result.initial_player
	if not p.is_empty():
		viewer.setup_player(
			p.get("hp", 100), p.get("max_hp", 100),
			p.get("qi", 0), p.get("capacity", 50),
			p.get("qi_gather_rate", 0), p.get("realm", 1)
		)

	# 注册敌人
	for enemy_entry in result.initial_enemies:
		viewer.setup_enemy(
			enemy_entry.get("id", ""),
			enemy_entry.get("hp", 0),
			enemy_entry.get("max_hp", 0),
			enemy_entry.get("qi", 0)
		)

	# 加载
	viewer.load_replay(result.run)
	return true
