# ============================================================
# 大周天 — MeridianRuntime
# 经脉状态纯容器 — 不包含任何业务逻辑
# ============================================================
class_name MeridianRuntime
extends RefCounted


## 经脉底图
var base_meridian: MeridianMapData = null

## 活跃回路 [{nodes: Array, technique_id: String}, ...]
var active_circuits: Array[Dictionary] = []

## 冲刷目标穴位索引
var erosion_targets: Array[int] = []

## 受损经脉 {pathway_key: remaining_turns}
var damaged_pathways: Dictionary = {}

## 穴位永久基底buff {node_name: [{name, value}, ...]}
var node_base_buffs: Dictionary = {}

## 灵气流是否干涸
var is_flow_dry: bool = true

## 丹田压力
var dantian_pressure: float = 0.0

## 冲刷上限加成 {source_id: amount}
var erosion_bonuses: Dictionary = {}

## 聚气加成 {source_id: amount}
var qi_gather_bonuses: Dictionary = {}


## 从 GameManager 复制经脉状态
func copy_from(gm: Node) -> void:
	base_meridian = gm.get("base_meridian")
	active_circuits = (gm.get("active_circuits") if gm.get("active_circuits") != null else []).duplicate()
	erosion_targets = (gm.get("erosion_targets") if gm.get("erosion_targets") != null else []).duplicate()
	damaged_pathways = (gm.get("damaged_pathways") if gm.get("damaged_pathways") != null else {}).duplicate()
	node_base_buffs = (gm.get("node_base_buffs") if gm.get("node_base_buffs") != null else {}).duplicate()
	is_flow_dry = gm.get("is_flow_dry") if gm.get("is_flow_dry") != null else true
	dantian_pressure = gm.get("dantian_pressure") if gm.get("dantian_pressure") != null else 0.0


## 同步到 CombatActor
func sync_to(actor: CombatActor) -> void:
	actor.base_meridian = base_meridian
	actor.active_circuits = active_circuits.duplicate()
	actor.erosion_targets = erosion_targets.duplicate()
	actor.damaged_pathways = damaged_pathways.duplicate()
	actor.node_base_buffs = node_base_buffs.duplicate()
	actor.is_flow_dry = is_flow_dry
	actor.dantian_pressure = dantian_pressure


## 从 CombatActor 回读
func sync_from(actor: CombatActor) -> void:
	base_meridian = actor.base_meridian
	active_circuits = actor.active_circuits.duplicate()
	erosion_targets = actor.erosion_targets.duplicate()
	damaged_pathways = actor.damaged_pathways.duplicate()
	node_base_buffs = actor.node_base_buffs.duplicate()
	is_flow_dry = actor.is_flow_dry
	dantian_pressure = actor.dantian_pressure
