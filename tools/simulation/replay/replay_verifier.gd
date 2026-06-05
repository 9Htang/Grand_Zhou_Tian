# ============================================================
# 大周天 — ReplayVerifier (回放一致性验证)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 比较原始 SimulationRun 与回放 SimulationRun 的完全一致性。
# 比 SimulationVerifier 更严格 — 逐事件比对 type/source_card_id/action_id。
#
# 验证维度:
#   - state_hashes 链一致
#   - rng_call_count 一致
#   - actions 数量一致
#   - events 数量一致
#   - 事件三元组 (type + source_card_id + action_id) 逐条一致
#   - action_id 绑定完整性
# ============================================================
class_name ReplayVerifier
extends RefCounted


class VerifyResult:
	var hashes_match: bool = false
	var rng_match: bool = false
	var events_count_match: bool = false
	var actions_match: bool = false
	var action_index_monotonic: bool = false
	var fingerprints_match: bool = false
	var action_id_binding_complete: bool = false
	var state_diff: StateDiff.DiffResult = null  # hash 不一致时填充

	var first_hash_divergence: int = -1
	var first_fingerprint_divergence: int = -1

	var total_checks_passed: int = 0
	var total_checks: int = 0


## 比较两次运行
static func verify(original: SimulationRun, replay: SimulationRun) -> VerifyResult:
	var r := VerifyResult.new()

	# 1. State hashes
	r.hashes_match = original.state_hashes == replay.state_hashes
	if not r.hashes_match:
		r.first_hash_divergence = _find_hash_divergence(original.state_hashes, replay.state_hashes)
		# 生成结构差异 — hash 不一致时提供具体分歧定位
		var a_state := _final_state_dict(original)
		var b_state := _final_state_dict(replay)
		r.state_diff = StateDiff.compare_dicts(a_state, b_state)

	# 2. RNG call count
	r.rng_match = original.rng_call_count == replay.rng_call_count

	# 3. Actions count
	r.actions_match = original.actions.size() == replay.actions.size()

	# 4. Events count
	r.events_count_match = original.events.size() == replay.events.size()

	# 5. Event fingerprint comparison — 包含 type+actor+card+payload 完整比对
	var a_events: Array[SimulationEvent] = original.events.all()
	var b_events: Array[SimulationEvent] = replay.events.all()
	var limit: int = min(a_events.size(), b_events.size())

	r.fingerprints_match = true
	for i in range(limit):
		if a_events[i].fingerprint() != b_events[i].fingerprint():
			r.fingerprints_match = false
			if r.first_fingerprint_divergence < 0:
				r.first_fingerprint_divergence = i
			break

	# 6. action_id binding — 所有 card_played 事件必须有 action_id
	var action_events: int = 0
	var bound_events: int = 0
	for e in b_events:
		if e.type == "card_played":
			action_events += 1
			if e.action_id >= 0:
				bound_events += 1
	r.action_id_binding_complete = (bound_events == action_events) and action_events > 0

	# 7. action_index 单调性 — 回放时的 action.id 必须严格递增
	r.action_index_monotonic = _is_strictly_increasing(original.actions) and _is_strictly_increasing(replay.actions)

	# Tally
	r.total_checks = 7
	var pass_count: int = 0
	if r.hashes_match: pass_count += 1
	if r.rng_match: pass_count += 1
	if r.actions_match: pass_count += 1
	if r.action_index_monotonic: pass_count += 1
	if r.events_count_match: pass_count += 1
	if r.fingerprints_match: pass_count += 1
	if r.action_id_binding_complete: pass_count += 1
	r.total_checks_passed = pass_count

	return r


static func _find_hash_divergence(a: Array[int], b: Array[int]) -> int:
	for i in range(min(a.size(), b.size())):
		if a[i] != b[i]:
			return i
	return -1


## 从 SimulationRun 提取最终状态（已是纯数据，不重建 runtime）
## SimulationRun.final_player_state / final_enemy_states 在 create() 时已从实际状态序列化
static func _final_state_dict(run: SimulationRun) -> Dictionary:
	return {
		"player": run.final_player_state,
		"enemies": run.final_enemy_states,
		"deck": {},
		"vm": {},
	}


## action.id 严格递增
static func _is_strictly_increasing(actions: Array[Dictionary]) -> bool:
	if actions.size() < 2:
		return true
	var prev: int = actions[0].get("id", -1)
	for i in range(1, actions.size()):
		var cur: int = actions[i].get("id", -1)
		if cur <= prev:
			return false
		prev = cur
	return true


## 生成可读的验证摘要
static func to_text(r: VerifyResult) -> String:
	var lines: PackedStringArray = []
	lines.append("[ReplayVerifier] %d/%d checks passed" % [r.total_checks_passed, r.total_checks])
	lines.append("  hashes_match:         %s" % _pass_fail(r.hashes_match))
	lines.append("  rng_match:            %s" % _pass_fail(r.rng_match))
	lines.append("  actions_match:        %s" % _pass_fail(r.actions_match))
	lines.append("  action_index_monot:   %s" % _pass_fail(r.action_index_monotonic))
	lines.append("  events_count:         %s" % _pass_fail(r.events_count_match))
	lines.append("  fingerprints_match:   %s" % _pass_fail(r.fingerprints_match))
	lines.append("  action_id_binding:    %s" % _pass_fail(r.action_id_binding_complete))
	if r.first_hash_divergence >= 0:
		lines.append("  first_hash_div:      tick %d" % r.first_hash_divergence)
	if r.first_fingerprint_divergence >= 0:
		lines.append("  first_fp_div:        event %d" % r.first_fingerprint_divergence)
	if r.state_diff and r.state_diff.has_diff:
		lines.append("")
		lines.append(StateDiff.to_text(r.state_diff))
	return "\n".join(lines)


static func _pass_fail(b: bool) -> String:
	return "PASS" if b else "FAIL"
