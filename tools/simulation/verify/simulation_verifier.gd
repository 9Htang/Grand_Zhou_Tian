# ============================================================
# 大周天 — SimulationVerifier (运行一致性验证)
# ============================================================
# 工具层: tools/simulation/verify/ — 不属于四层运行时架构
#
# 比较两次 SimulationRun 是否完全一致。
# CI 级核心工具 — 同 seed 两次运行必须逐字段匹配。
# ============================================================
class_name SimulationVerifier
extends RefCounted


## 比较两次运行是否完全一致
## 返回 {match: bool, reason: String, ...}
static func verify(a: SimulationRun, b: SimulationRun) -> Dictionary:
	# 1. Hash 链一致性（第一个不同 tick 即问题点）
	if a.state_hashes != b.state_hashes:
		for i in range(min(a.state_hashes.size(), b.state_hashes.size())):
			if a.state_hashes[i] != b.state_hashes[i]:
				return {
					"match": false,
					"reason": "state_hash_diverged",
					"first_divergence_tick": i,
					"a_hash": a.state_hashes[i],
					"b_hash": b.state_hashes[i],
				}
		return {
			"match": false,
			"reason": "state_hash_count_mismatch",
			"a_count": a.state_hashes.size(),
			"b_count": b.state_hashes.size(),
		}

	# 2. RNG 调用次数一致
	if a.rng_call_count != b.rng_call_count:
		return {
			"match": false,
			"reason": "rng_call_divergence",
			"a_count": a.rng_call_count,
			"b_count": b.rng_call_count,
		}

	# 3. 事件流长度一致
	if a.events.size() != b.events.size():
		return {
			"match": false,
			"reason": "event_count_mismatch",
			"a_count": a.events.size(),
			"b_count": b.events.size(),
		}

	# 4. 最终状态一致
	if a.final_player_state != b.final_player_state:
		return {"match": false, "reason": "final_player_state_mismatch"}

	# 5. 胜负一致
	if a.win != b.win:
		return {"match": false, "reason": "win_result_mismatch"}

	return {"match": true}
