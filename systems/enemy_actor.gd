# ============================================================
# 大周天 — EnemyActor (敌人战斗角色)
# 继承 CombatActor，添加敌人专属状态与方法
# ============================================================
class_name EnemyActor
extends CombatActor


# === Signals ===
signal statuses_changed(statuses: Dictionary)


# === Enemy Fields ===
var display_name: String = ""
var ai_strategy: String = "balanced"

# === Status ===
var statuses: Dictionary = {}    # burn/vulnerable/weak, etc.
var strength: int = 0


# ============================================================
# Initialization
# ============================================================

func initialize_from_data(data: EnemyData) -> void:
	hp = data.max_hp
	max_hp = data.max_hp
	display_name = data.display_name
	realm = data.realm
	ai_strategy = data.ai_strategy

	dantian_capacity = data.dantian_capacity
	dantian_pressure = data.dantian_pressure
	qi_gather_rate = data.qi_gather_rate
	talent = data.talent

	if not data.meridian_id.is_empty():
		base_meridian = MeridianRegistry.get_meridian(data.meridian_id)

	for tech_id in data.initial_techniques:
		var tech: TechniqueData = TechniqueDatabase.get_technique(tech_id)
		if tech:
			active_techniques.append(tech)
