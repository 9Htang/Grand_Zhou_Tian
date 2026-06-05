# ============================================================
# 大周天 — RuntimeSyncService
# GameManager ↔ RuntimeState ↔ CombatActor 双向同步
# 替代旧的 load_from_gm() / save_to_gm() 30字段逐字段复制
# ============================================================
class_name RuntimeSyncService
extends RefCounted


## 从 GameManager 加载到 PlayerActor
static func load_player(gm: Node, player: PlayerActor) -> void:
	player.hp = gm.player_hp
	player.max_hp = gm.player_max_hp
	player.dantian_qi = gm.dantian_qi
	player.dantian_capacity = gm.dantian_capacity
	player.dantian_pressure = gm.get("dantian_pressure") if gm.get("dantian_pressure") != null else 0.0
	player.qi_gather_rate = gm.qi_gather_rate
	player.current_block = gm.current_block
	player.realm = gm.realm
	player.talent = gm.talent
	player.gold = gm.gold
	player.cultivation = gm.cultivation
	player.cultivation_to_next = gm.cultivation_to_next

	player.active_techniques = gm.active_techniques.duplicate()
	player.active_buffs = gm.active_buffs.duplicate()
	player.master_deck = gm.master_deck.duplicate()

	player.base_meridian = gm.base_meridian
	player.active_circuits = (gm.get("active_circuits") if gm.get("active_circuits") != null else []).duplicate()
	player.erosion_targets = (gm.get("erosion_targets") if gm.get("erosion_targets") != null else []).duplicate()
	player.damaged_pathways = (gm.get("damaged_pathways") if gm.get("damaged_pathways") != null else {}).duplicate()
	player.node_base_buffs = (gm.get("node_base_buffs") if gm.get("node_base_buffs") != null else {}).duplicate()
	player.is_flow_dry = gm.get("is_flow_dry") if gm.get("is_flow_dry") != null else true

	player.artifacts = (gm.get("artifacts") if gm.get("artifacts") != null else []).duplicate()


## 从 PlayerActor 保存回 GameManager
static func save_player(player: PlayerActor, gm: Node) -> void:
	gm.player_hp = player.hp
	gm.player_max_hp = player.max_hp
	gm.dantian_qi = player.dantian_qi
	gm.dantian_capacity = player.dantian_capacity
	gm.set("dantian_pressure", player.dantian_pressure)
	gm.qi_gather_rate = player.qi_gather_rate
	gm.current_block = player.current_block
	gm.realm = player.realm
	gm.talent = player.talent
	gm.gold = player.gold
	gm.cultivation = player.cultivation
	gm.cultivation_to_next = player.cultivation_to_next

	gm.active_techniques = player.active_techniques.duplicate()
	gm.active_buffs = player.active_buffs.duplicate()

	gm.set("active_circuits", player.active_circuits.duplicate())
	gm.set("erosion_targets", player.erosion_targets.duplicate())
	gm.set("damaged_pathways", player.damaged_pathways.duplicate())
	gm.set("node_base_buffs", player.node_base_buffs.duplicate())
	gm.set("is_flow_dry", player.is_flow_dry)

	gm.set("artifacts", player.artifacts.duplicate())
