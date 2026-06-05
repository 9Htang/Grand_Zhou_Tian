# ============================================================
# 大周天 — CurioFactory
# 奇物工厂：佩戴即生效，可选主动技能
# ============================================================
class_name CurioFactory
extends RefCounted


## 创建纯被动奇物
static func create_passive(id: String, display_name: String, description: String,
		passive_effects: Array[String]) -> CurioData:
	var curio: CurioData = CurioData.new()
	curio.id = id
	curio.display_name = display_name
	curio.description = description
	curio.passive_effects = passive_effects.duplicate()
	return curio


## 创建带主动技能的奇物
static func create_with_active(id: String, display_name: String, description: String,
		passive_effects: Array[String],
		active_cost: int, active_effect: String, active_desc: String = "") -> CurioData:
	var curio: CurioData = CurioData.new()
	curio.id = id
	curio.display_name = display_name
	curio.description = description
	curio.passive_effects = passive_effects.duplicate()
	curio.active_skill_cost = active_cost
	curio.active_skill_effect = active_effect
	curio.active_skill_description = active_desc
	return curio


## 从属性字典生成奇物
static func create_from_dict(data: Dictionary) -> CurioData:
	var curio: CurioData = CurioData.new()
	curio.id = data.get("id", "")
	curio.display_name = data.get("display_name", "")
	curio.description = data.get("description", "")
	curio.passive_effects = data.get("passive_effects", [])
	curio.active_skill_cost = data.get("active_skill_cost", 0)
	curio.active_skill_effect = data.get("active_skill_effect", "")
	curio.active_skill_description = data.get("active_skill_description", "")
	return curio
