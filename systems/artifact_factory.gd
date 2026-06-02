# ============================================================
# 大周天 — ArtifactFactory
# 法宝工厂：PASSIVE / ACTIVE_MOUNT / ACTIVE_CHARGE / ACTIVE_CONTAINER
# ============================================================
class_name ArtifactFactory
extends RefCounted


## 创建被动型法宝（类似遗物，每回合消耗灵气）
static func create_passive(id: String, display_name: String, description: String,
		trigger: String, qi_per_turn: int, effect: String,
		condition: String = "") -> ArtifactData:
	var art: ArtifactData = ArtifactData.new()
	art.id = id
	art.display_name = display_name
	art.description = description
	art.artifact_type = "passive"
	art.trigger = trigger
	art.qi_per_turn = qi_per_turn
	art.effect = effect
	art.condition = condition
	return art


## 创建挂载型法宝（打出后挂载到遗物栏，每回合消耗灵气）
static func create_mount(id: String, display_name: String, description: String,
		trigger: String, qi_per_turn: int, effect: String,
		condition: String = "") -> ArtifactData:
	var art: ArtifactData = ArtifactData.new()
	art.id = id
	art.display_name = display_name
	art.description = description
	art.artifact_type = "active_mount"
	art.trigger = trigger
	art.qi_per_turn = qi_per_turn
	art.effect = effect
	art.condition = condition
	return art


## 创建充能型法宝（日常积蓄灵气，打出时免费，后需重新充能）
static func create_charge(id: String, display_name: String, description: String,
		charge_cost: int, effect: String) -> ArtifactData:
	var art: ArtifactData = ArtifactData.new()
	art.id = id
	art.display_name = display_name
	art.description = description
	art.artifact_type = "active_charge"
	art.charge_cost = charge_cost
	art.charge_stored = 0
	art.effect = effect
	art.trigger = "on_card_play"  # 充能型打出时触发
	return art


## 创建容器型法宝（储物戒指类，存储物品）
static func create_container(id: String, display_name: String, description: String,
		slots: int, types: Array[String], contents: Array[String] = []) -> ArtifactData:
	var art: ArtifactData = ArtifactData.new()
	art.id = id
	art.display_name = display_name
	art.description = description
	art.artifact_type = "active_container"
	art.container_slots = slots
	art.container_types = types.duplicate()
	art.container_contents = contents.duplicate()
	art.trigger = "on_card_play"
	return art


## 从属性字典批量生成法宝
static func create_from_dict(data: Dictionary) -> ArtifactData:
	var art: ArtifactData = ArtifactData.new()
	var atype: String = data.get("artifact_type", "passive")
	art.id = data.get("id", "")
	art.display_name = data.get("display_name", "")
	art.description = data.get("description", "")
	art.artifact_type = atype
	art.qi_per_turn = data.get("qi_per_turn", 0)
	art.charge_cost = data.get("charge_cost", 0)
	art.charge_stored = data.get("charge_stored", 0)
	art.container_slots = data.get("container_slots", 0)
	art.container_types = data.get("container_types", [])
	art.container_contents = data.get("container_contents", [])
	art.trigger = data.get("trigger", "always")
	art.effect = data.get("effect", "")
	art.condition = data.get("condition", "")
	return art
