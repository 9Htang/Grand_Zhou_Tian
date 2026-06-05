# ============================================================
# 大周天 — TrajectoryRecorder (轨迹记录器)
# ============================================================
# 工具层: tools/simulation/trajectory/ — 不属于四层运行时架构
#
# 记录每个 tick 的完整状态快照，供 AI 训练/MCTS/行为克隆使用。
# 注意: 轨迹是分析/训练数据，不是 restore 机制。
# ============================================================
class_name TrajectoryRecorder
extends RefCounted


## 轨迹数据: Array[{tick, player, enemies, deck, rng_call}]
var data: Array[Dictionary] = []


func record(tick: int, player, enemies: Array, deck, rng: DeterministicRNG) -> void:
	data.append({
		"tick": tick,
		"player": _snap_player(player),
		"enemies": _snap_enemies(enemies),
		"deck": _snap_deck(deck),
		"rng_call": rng.call_count if rng else 0,
	})


func export_for_training() -> Array[Dictionary]:
	return data


func size() -> int:
	return data.size()


func clear() -> void:
	data.clear()


# ============================================================
# Internal
# ============================================================

func _snap_player(player) -> Dictionary:
	return {
		"hp": player.hp, "max_hp": player.max_hp,
		"qi": player.dantian_qi, "capacity": player.dantian_capacity,
		"block": player.current_block, "realm": player.realm,
	}

func _snap_enemies(enemies: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for e in enemies:
		if e:
			result.append({
				"hp": e.hp, "max_hp": e.max_hp,
				"qi": e.dantian_qi, "block": e.current_block,
			})
	return result

func _snap_deck(deck) -> Dictionary:
	return {
		"draw": deck.draw_pile.size(),
		"hand": deck.hand.size(),
		"discard": deck.discard_pile.size(),
		"exhaust": deck.exhaust_pile.size(),
	}
