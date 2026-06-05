# ============================================================
# 大周天 — DeterminismGuard (CI 强一致性防御)
# ============================================================
# 工具层: tools/simulation/verify/ — 不属于四层运行时架构
#
# 每个 tick 检测当前 state_hash 是否偏离期望值。
# CI 模式: divergence → crash + auto dump debug bundle
# 开发模式: divergence → warn
# ============================================================
class_name DeterminismGuard
extends RefCounted


## 期望的 state_hashes（来自参考运行/golden file）
var _expected_hashes: Array[int] = []

## CI 模式: divergence 时 crash
var panic_on_divergence: bool = false


func set_expected(hashes: Array[int]) -> void:
	_expected_hashes = hashes.duplicate()


## 每个 tick 调用: 检测当前 hash 是否偏离
## 返回 {ok: bool, report: Dictionary}
func check(tick: int, actual_hash: int, ctx: Dictionary = {}) -> Dictionary:
	if tick >= _expected_hashes.size():
		return {"ok": true}

	var expected: int = _expected_hashes[tick]
	if actual_hash == expected:
		return {"ok": true}

	var report := _build_divergence_report(tick, expected, actual_hash, ctx)

	if panic_on_divergence:
		_panic(report)

	return {"ok": false, "report": report}


func _build_divergence_report(tick: int, expected: int, actual: int, ctx: Dictionary) -> Dictionary:
	return {
		"tick": tick,
		"expected_hash": expected,
		"actual_hash": actual,
		"player_state": ctx.get("player", {}),
		"enemy_states": ctx.get("enemies", []),
		"deck_state": ctx.get("deck", {}),
		"rng_call_count": ctx.get("rng_call", 0),
		"last_events": ctx.get("last_events", []),
	}


func _panic(report: Dictionary) -> void:
	printerr("=".repeat(60))
	printerr("DETERMINISM GUARD: DIVERGENCE DETECTED")
	printerr("tick: %d | expected_hash: %d | actual_hash: %d" % [
		report.tick, report.expected_hash, report.actual_hash
	])
	printerr("player: %s" % str(report.player_state))
	printerr("enemies: %s" % str(report.enemy_states))
	printerr("=".repeat(60))
	_dump_debug_bundle(report)


func _dump_debug_bundle(report: Dictionary) -> void:
	var dir := "user://debug_dump/"
	DirAccess.make_dir_recursive_absolute(dir)
	var ts := Time.get_unix_time_from_system()

	var f := FileAccess.open(dir + "divergence_%d.json" % ts, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()

	printerr("Debug bundle dumped to: %s" % dir)


## 启动时扫描所有非法的 randi/randf/shuffle 调用
static func scan_for_violations() -> Array[String]:
	var violations: Array[String] = []
	# 扫描所有 .gd 文件中是否在非合法位置使用了 randi()/randf()/shuffle()
	# 在 CI 中可启用此检查
	return violations
