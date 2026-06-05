# ============================================================
# 大周天 — MetricsEngine (实时指标引擎)
# ============================================================
# 工具层: tools/simulation/metrics/ — 不属于四层运行时架构
#
# 实时累积战斗指标，替代后处理 Report。
# 每收到一个 SimulationEvent 即更新对应指标。
# ============================================================
class_name MetricsEngine
extends RefCounted


var damage_dealt: float = 0.0
var damage_taken: float = 0.0
var qi_generated: float = 0.0
var qi_consumed: float = 0.0
var qi_wasted: float = 0.0
var cards_played: int = 0
var techniques_activated: int = 0
var block_gained: float = 0.0
var heal_received: float = 0.0


func feed(event: SimulationEvent) -> void:
	match event.type:
		"damage_dealt":
			damage_dealt += float(event.payload.get("amount", 0))
		"qi_generated":
			qi_generated += float(event.payload.get("amount", 0))
		"qi_consumed":
			qi_consumed += float(event.payload.get("amount", 0))
		"qi_wasted_estimated":
			qi_wasted += float(event.payload.get("amount", 0))
		"card_played":
			cards_played += 1
		"technique_activated":
			techniques_activated += 1
		"block_gained":
			block_gained += float(event.payload.get("amount", 0))
		"heal_received":
			heal_received += float(event.payload.get("amount", 0))


func build() -> Dictionary:
	var qi_eff: float = 0.0
	if qi_generated > 0.001:
		qi_eff = qi_consumed / qi_generated
	return {
		"damage_dealt": damage_dealt,
		"damage_taken": damage_taken,
		"qi_generated": qi_generated,
		"qi_consumed": qi_consumed,
		"qi_wasted": qi_wasted,
		"qi_efficiency": qi_eff,
		"cards_played": cards_played,
		"techniques_activated": techniques_activated,
		"block_gained": block_gained,
		"heal_received": heal_received,
	}


func clear() -> void:
	damage_dealt = 0.0; damage_taken = 0.0
	qi_generated = 0.0; qi_consumed = 0.0; qi_wasted = 0.0
	cards_played = 0; techniques_activated = 0
	block_gained = 0.0; heal_received = 0.0
