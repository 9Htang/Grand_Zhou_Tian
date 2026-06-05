# ============================================================
# 大周天 — SnapshotService (战斗快照服务 — L2)
# 职责: 从 Actor/Deck 构建 BattleSnapshot 的 domain 数据部分
# 不做: UI 状态标记 (is_selecting_cards, is_input_blocked — 由 L1 追加)
# 红线: 不访问 autoload, 不做 UI, 纯数据映射
# ============================================================
class_name SnapshotService
extends RefCounted


# === Injected References (set by BattleController) ===
var player: PlayerActor = null
var enemies: Array[EnemyActor] = []
var deck_manager: DeckManager = null


# ============================================================
# Public API
# ============================================================


## 构建 BattleSnapshot 的 domain 数据部分
## 返回的 snap 不含 UI 状态标记, 由 L1 调用方追加
func build() -> BattleSnapshot:
	var snap := BattleSnapshot.new()

	# --- Player Vitals ---
	snap.hp = player.hp
	snap.max_hp = player.max_hp
	snap.dantian_qi = player.dantian_qi
	snap.dantian_capacity = player.dantian_capacity
	snap.qi_gather_rate = player.qi_gather_rate
	snap.realm = player.realm

	# --- Deck Info ---
	if deck_manager:
		snap.draw_pile_count = deck_manager.get_draw_pile_count()
		snap.discard_count = deck_manager.get_discard_count()

	# --- Techniques ---
	snap.techniques = player.active_techniques
	snap.talent = player.talent
	snap.technique_pathways = player.technique_pathways

	# --- Meridian ---
	snap.base_meridian = player.base_meridian
	snap.erosion_targets = player.erosion_targets
	snap.max_erosion_targets = player.get_max_erosion_targets()
	snap.is_flow_dry = player.is_flow_dry

	# --- Circuit Pathways ---
	for circuit in player.active_circuits:
		var pathways: Array = circuit.get("pathways", [])
		for pwp in pathways:
			var from_idx: int = pwp.get("from", -1)
			var to_idx: int = pwp.get("to", -1)
			if from_idx >= 0 and to_idx >= 0:
				snap.circuit_pathway_keys.append(str(min(from_idx, to_idx)) + "->" + str(max(from_idx, to_idx)))

	# --- Technique Colors ---
	for tech in player.active_techniques:
		snap.technique_colors[tech.id] = Helpers.color_for_element(tech.get_element_int())

	# --- Buffs ---
	snap.buffs = player.active_buffs

	# --- Enemy Snapshots ---
	for enemy in enemies:
		snap.enemy_snapshots.append({
			"actor": enemy,
			"hp": enemy.hp,
			"current_block": enemy.current_block,
			"statuses": enemy.statuses,
		})

	return snap
