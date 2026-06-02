# ============================================================
# 大周天 — EquipmentFactory
# 装备工厂：头/身/裤/脚/武器
# ============================================================
class_name EquipmentFactory
extends RefCounted


## 创建装备
static func create(id: String, display_name: String, description: String,
		slot: int, rarity: int = 0,
		hp_bonus: int = 0, block_bonus: int = 0,
		qi_regen_bonus: int = 0, divine_sense_bonus: int = 0,
		effects: Array[String] = []) -> EquipmentData:
	var eq: EquipmentData = EquipmentData.new()
	eq.id = id
	eq.display_name = display_name
	eq.description = description
	eq.slot = slot
	eq.rarity = rarity
	eq.hp_bonus = hp_bonus
	eq.block_bonus = block_bonus
	eq.qi_regen_bonus = qi_regen_bonus
	eq.divine_sense_bonus = divine_sense_bonus
	eq.effects = effects.duplicate()
	return eq


## 从属性字典生成装备
static func create_from_dict(data: Dictionary) -> EquipmentData:
	var eq: EquipmentData = EquipmentData.new()
	eq.id = data.get("id", "")
	eq.display_name = data.get("display_name", "")
	eq.description = data.get("description", "")
	eq.slot = data.get("slot", 0)
	eq.rarity = data.get("rarity", 0)
	eq.hp_bonus = data.get("hp_bonus", 0)
	eq.block_bonus = data.get("block_bonus", 0)
	eq.qi_regen_bonus = data.get("qi_regen_bonus", 0)
	eq.divine_sense_bonus = data.get("divine_sense_bonus", 0)
	eq.effects = data.get("effects", [])
	return eq
