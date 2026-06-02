# ============================================================
# 大周天 — CardFactory
# 卡牌构建工厂，统一管理从设计时到运行时的所有创建路径
#
# 设计时: CardPropertyBlock → CardData
# 运行时: CardData → CardInstance → CardRuntime
# ============================================================
class_name CardFactory
extends RefCounted


# ============================================================
# 设计时 — CardPropertyBlock → CardData
# ============================================================


## 从属性块生成 CardData（运行时 Resource 实例）
static func create_data(block: CardPropertyBlock) -> CardData:
	var card: CardData = CardData.new()
	_apply_block(card, block)
	return card


## 从属性块生成完整的 CardData（等效于 create_data，命名语义化）
static func create_from_block(block: CardPropertyBlock) -> CardData:
	return create_data(block)


## 批量从属性块数组生成 CardData 数组
static func create_batch(blocks: Array[CardPropertyBlock]) -> Array[CardData]:
	var result: Array[CardData] = []
	for block: CardPropertyBlock in blocks:
		result.append(create_data(block))
	return result


## 刷新已有的 CardData（用于设计时工具）
static func refresh_existing(card: CardData, block: CardPropertyBlock) -> void:
	_apply_block(card, block)


# ============================================================
# 运行时 — CardData → CardInstance
# ============================================================


## 从模板 id 创建 CardInstance
static func create_instance(card_id: String) -> CardInstance:
	var inst: CardInstance = CardInstance.new()
	inst.base_id = card_id
	inst.ensure_instance_id()
	return inst


## 深拷贝 CardInstance
static func clone_instance(inst: CardInstance) -> CardInstance:
	var copy: CardInstance = CardInstance.new()
	copy.instance_id = ""  # 新实例需新 ID
	copy.base_id = inst.base_id
	copy.upgrade_level = inst.upgrade_level
	copy.upgrade_branch = inst.upgrade_branch
	copy.custom_name = inst.custom_name
	copy.acquisition_source = inst.acquisition_source
	copy.acquired_at_chapter = inst.acquired_at_chapter
	copy.flags = inst.flags.duplicate()
	copy.ensure_instance_id()
	return copy


## 升级 CardInstance: 线性升级或分支替换
## 线性: upgrade_level += 1
## 分支: base_id 替换为分支目标模板
static func upgrade_instance(inst: CardInstance, branch: String = "") -> CardInstance:
	var data: CardData = CardDatabase.get_card(inst.base_id)
	if data == null:
		return inst

	if not branch.is_empty():
		# 分支升级: 替换 base_id
		if branch in data.upgrade_branches:
			inst.upgrade_branch = branch
			inst.base_id = branch
			inst.upgrade_level = 0  # 新模板重置线性等级
	else:
		# 线性升级
		if inst.upgrade_level < data.max_upgrade_level:
			inst.upgrade_level += 1

	return inst


## 运行时动态生成: 给定覆盖参数，生成变体 CardInstance
## overrides: Dictionary 记录需要覆盖的属性
static func create_variant(base_id: String, overrides: Dictionary) -> CardInstance:
	var inst: CardInstance = create_instance(base_id)
	# 将 overrides 中的自定义信息存入 flags
	inst.flags["variant_overrides"] = overrides
	if overrides.has("custom_name"):
		inst.custom_name = overrides["custom_name"]
	return inst


# ============================================================
# 运行时 — CardInstance → CardRuntime (战斗工作副本)
# ============================================================


## 从 CardInstance 创建战斗工作副本
## 从 CardData.base_effects 构建初始 EffectGraph
static func create_runtime(inst: CardInstance) -> CardRuntime:
	var data: CardData = CardDatabase.get_card(inst.base_id)
	var rt: CardRuntime = CardRuntime.new()
	rt.base_data = data
	rt.instance = inst
	rt.build_initial_graph()
	rt.rebuild_plan()
	rt.delay_remaining = data.delay_turns if data else 0
	return rt


## 从 CardData id 直接创建 CardRuntime（跳过 CardInstance，用于临时卡/npc）
static func create_runtime_direct(card_id: String) -> CardRuntime:
	var inst: CardInstance = create_instance(card_id)
	return create_runtime(inst)


# ============================================================
# 运行时 — 卡牌实例批量创建
# ============================================================


## 从 id 列表批量创建 CardInstance 数组
static func create_instance_batch(card_ids: Array[String]) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for id: String in card_ids:
		result.append(create_instance(id))
	return result


## 从 CardInstance 数组批量创建 CardRuntime 数组
static func create_runtime_batch(instances: Array[CardInstance]) -> Array[CardRuntime]:
	var result: Array[CardRuntime] = []
	for inst: CardInstance in instances:
		result.append(create_runtime(inst))
	return result


# ============================================================
# Internal
# ============================================================

static func _apply_block(card: CardData, block: CardPropertyBlock) -> void:
	# 基础信息
	card.id = block.id
	card.display_name = block.display_name
	card.card_type = block.card_type
	card.rarity = block.rarity
	card.element = block.element
	card.cost = block.cost
	card.target_type = block.target_type
	card.description = block.description
	card.flavor_text = block.flavor_text
	card.card_art = block.card_art
	card.tags = block.tags.duplicate()
	card.play_condition = block.play_condition

	# 生命周期
	card.behavior = block.behavior
	card.delay_turns = block.delay_turns

	# 数值
	card.damage = block.damage
	card.block = block.block
	card.heal = block.heal
	card.draw_count = block.draw_count
	card.qi_gather_amount = block.qi_gather_amount
	card.qi_regen_mod = block.qi_regen_mod

	# 增益/减益
	card.buff_self = block.buff_self
	card.debuff_enemy = block.debuff_enemy

	# 功法关联
	card.technique_id = block.technique_id

	# 丹药
	card.elixir_use_location = block.elixir_use_location
	card.elixir_effect = block.elixir_effect

	# 容器
	card.container_contents = block.container_contents.duplicate()
	card.container_types = block.container_types.duplicate()

	# 升级 (新字段)
	card.max_upgrade_level = block.max_upgrade_level
	card.damage_per_upgrade = block.damage_per_upgrade
	card.block_per_upgrade = block.block_per_upgrade
	card.heal_per_upgrade = block.heal_per_upgrade
	card.cost_reduce_per_upgrade = block.cost_reduce_per_upgrade
	card.upgrade_branches = block.upgrade_branches.duplicate()

	# 效果图 (新)
	card.base_effects = block.base_effects.duplicate()

	# 旧升级字段 (兼容过渡)
	card.upgrade_damage_bonus = block.upgrade_damage_bonus
	card.upgrade_block_bonus = block.upgrade_block_bonus
	card.upgrade_cost_reduction = block.upgrade_cost_reduction


static func _apply_overrides(card: CardData, overrides: Dictionary) -> void:
	for key: String in overrides:
		var val = overrides[key]
		match key:
			"id": card.id = val
			"display_name": card.display_name = val
			"card_type": card.card_type = val
			"rarity": card.rarity = val
			"cost": card.cost = val
			"target_type": card.target_type = val
			"element": card.element = val
			"description": card.description = val
			"flavor_text": card.flavor_text = val
			"card_art": card.card_art = val
			"tags": card.tags = val
			"play_condition": card.play_condition = val
			"behavior": card.behavior = val
			"delay_turns": card.delay_turns = val
			"damage": card.damage = val
			"block": card.block = val
			"heal": card.heal = val
			"draw_count": card.draw_count = val
			"qi_gather_amount": card.qi_gather_amount = val
			"qi_regen_mod": card.qi_regen_mod = val
			"buff_self": card.buff_self = val
			"debuff_enemy": card.debuff_enemy = val
			"technique_id": card.technique_id = val
			"elixir_use_location": card.elixir_use_location = val
			"elixir_effect": card.elixir_effect = val
			"container_contents": card.container_contents = val
			"container_types": card.container_types = val
			"max_upgrade_level": card.max_upgrade_level = val
			"damage_per_upgrade": card.damage_per_upgrade = val
			"block_per_upgrade": card.block_per_upgrade = val
			"heal_per_upgrade": card.heal_per_upgrade = val
			"cost_reduce_per_upgrade": card.cost_reduce_per_upgrade = val
			"upgrade_branches": card.upgrade_branches = val
			"base_effects": card.base_effects = val
			# 旧字段向后兼容
			"upgrade_damage_bonus": card.upgrade_damage_bonus = val
			"upgrade_block_bonus": card.upgrade_block_bonus = val
			"upgrade_cost_reduction": card.upgrade_cost_reduction = val
