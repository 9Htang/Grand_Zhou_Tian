# ============================================================
# 大周天 — DeckService (卡牌域)
# 职责: 卡牌增删改 + 转化锻造 + 特性提取/交换 + 成功率
# 实例方法 (ctx 模式): EffectVM 调用
# 静态方法: BattleController 锻造流程调用
# ============================================================
class_name DeckService
extends RefCounted


# ============================================================
# Instance — EffectVM 调用 (EffectContext 模式)
# ============================================================

var _ctx: EffectContext = null


## 获得卡牌 — 加入玩家牌库
func gain_card(card_id: String) -> void:
	var target: Node = _ctx.actor
	if target and target.has_method("add_card_to_deck"):
		target.add_card_to_deck(card_id)


## 移除卡牌 — 从玩家牌库删除
func remove_card(card_id: String) -> void:
	var target: Node = _ctx.actor
	if target and target.has_method("remove_card"):
		target.remove_card(card_id)


## 升级卡牌
func upgrade_card(card_id: String) -> void:
	var target: Node = _ctx.actor
	if target and target.has_method("upgrade_card"):
		target.upgrade_card(card_id)


## 随机变换一张卡牌
func transform_random() -> void:
	var target: Node = _ctx.actor
	if target and target.has_method("transform_random_card"):
		target.transform_random_card()


## 随机复制一张卡牌
func duplicate_random() -> void:
	var target: Node = _ctx.actor
	if target and target.has_method("duplicate_random_card"):
		target.duplicate_random_card()


# ============================================================
# Static — 卡牌锻造 / 特性转化
# ============================================================


# Feature Type Constants

const FEATURE_EFFECT: String = "effect"
const FEATURE_TAG: String = "tag"
const FEATURE_ELEMENT: String = "element"
const FEATURE_COST: String = "cost"


# ============================================================
# Feature Enumeration
# ============================================================


## 获取 CardInstance 所有可提取的特性列表
## shenshi: 神识值，越高 → 排除低价值特性，池子越小越精准
static func get_extractable_features(inst: CardInstance, shenshi: int = 0) -> Array[Dictionary]:
	var features: Array[Dictionary] = []
	var data: CardData = CardDatabase.get_card(inst.base_id)
	if data == null:
		return features

	# 效果节点特性 — 从有效效果中提取
	for node: EffectNode in inst.get_effective_effects():
		features.append({
			"type": FEATURE_EFFECT,
			"node": node,
			"node_id": node.id,
			"display_name": _describe_effect_node(node),
			"category": _category_of_effect(node.type),
		})

	# 标签特性 — 从有效标签中提取
	for tag: String in inst.get_effective_tags():
		features.append({
			"type": FEATURE_TAG,
			"tag": tag,
			"display_name": "标签·%s" % tag,
			"category": "tag",
		})

	# 元素特性 — 仅当卡牌有元素时
	var element: String = inst.get_effective_element()
	if not element.is_empty():
		features.append({
			"type": FEATURE_ELEMENT,
			"element": element,
			"display_name": "元素·%s" % element,
			"category": "element",
		})

	# 神识过滤
	if shenshi >= 3:
		var filtered: Array[Dictionary] = []
		for f: Dictionary in features:
			var cat: String = f.get("category", "")
			if cat in ["tag"] and _is_generic_tag(f.get("tag", "")):
				continue
			filtered.append(f)
		features = filtered
	if shenshi >= 6:
		var filtered: Array[Dictionary] = []
		for f: Dictionary in features:
			if f.get("type") in [FEATURE_EFFECT, FEATURE_ELEMENT]:
				filtered.append(f)
		features = filtered

	return features


## 从实例随机提取一个特性
static func extract_random_feature(inst: CardInstance, shenshi: int = 0) -> Dictionary:
	var pool: Array[Dictionary] = get_extractable_features(inst, shenshi)
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()]


# ============================================================
# Feature Application / Removal
# ============================================================


## 将特性应用到目标 CardInstance
static func apply_feature(inst: CardInstance, feature: Dictionary) -> bool:
	if feature.is_empty():
		return false

	var ftype: String = feature.get("type", "")
	match ftype:
		FEATURE_EFFECT:
			var node: EffectNode = feature.get("node")
			if node == null:
				return false
			var copy_node: EffectNode = node.duplicate_node()
			copy_node.id = "graft_%d_%d" % [Time.get_unix_time_from_system(), randi()]
			inst.grafted_effects.append(copy_node)
			return true
		FEATURE_TAG:
			var tag: String = feature.get("tag", "")
			if tag.is_empty():
				return false
			if tag not in inst.grafted_tags:
				inst.grafted_tags.append(tag)
			return true
		FEATURE_ELEMENT:
			var elem: String = feature.get("element", "")
			if elem.is_empty():
				return false
			inst.element_override = elem
			return true
		FEATURE_COST:
			return false

	return false


## 从实例随机移除一个特性，返回被移除的特性字典
static func remove_random_feature(inst: CardInstance) -> Dictionary:
	var features: Array[Dictionary] = get_extractable_features(inst)
	if features.is_empty():
		return {}

	var target: Dictionary = features[randi() % features.size()]
	if remove_specific_feature(inst, target):
		return target
	return {}


## 移除指定特性
static func remove_specific_feature(inst: CardInstance, feature: Dictionary) -> bool:
	if feature.is_empty():
		return false

	var ftype: String = feature.get("type", "")
	match ftype:
		FEATURE_EFFECT:
			var node_id: String = feature.get("node_id", "")
			if node_id.is_empty():
				return false
			for i: int in range(inst.grafted_effects.size()):
				if inst.grafted_effects[i].id == node_id:
					inst.grafted_effects.remove_at(i)
					return true
			if node_id not in inst.removed_effect_ids:
				inst.removed_effect_ids.append(node_id)
			return true
		FEATURE_TAG:
			var tag: String = feature.get("tag", "")
			if tag.is_empty():
				return false
			var idx: int = inst.grafted_tags.find(tag)
			if idx >= 0:
				inst.grafted_tags.remove_at(idx)
			return true
		FEATURE_ELEMENT:
			inst.element_override = ""
			return true

	return false


# ============================================================
# Feature Swap
# ============================================================


## 交换两个实例的指定特性
static func swap_features(inst_a: CardInstance, feature_a: Dictionary, inst_b: CardInstance, feature_b: Dictionary) -> bool:
	if feature_a.is_empty() or feature_b.is_empty():
		return false

	var fa_type: String = feature_a.get("type", "")
	var fb_type: String = feature_b.get("type", "")

	if fa_type != fb_type:
		return false  # 不同类型不能互换

	var ok_a: bool = remove_specific_feature(inst_a, feature_a)
	var ok_b: bool = remove_specific_feature(inst_b, feature_b)
	if not ok_a or not ok_b:
		return false

	var apply_ok1: bool = apply_feature(inst_b, feature_a)
	var apply_ok2: bool = apply_feature(inst_a, feature_b)

	return apply_ok1 and apply_ok2


# ============================================================
# Success Rate
# ============================================================


## 计算转化成功率，返回百分比整数 [0, 100]
static func calculate_success_rate(base_rate: int, luck: int, conversion_count: int, clamp_min: int, clamp_max: int) -> int:
	var rate: int = base_rate + luck * 2 - conversion_count * 10
	return clampi(rate, clamp_min, clamp_max)


## 执行成功率判定，返回 true=成功
static func roll_success(base_rate: int, luck: int, conversion_count: int, clamp_min: int, clamp_max: int) -> bool:
	var rate: int = calculate_success_rate(base_rate, luck, conversion_count, clamp_min, clamp_max)
	var roll: int = randi() % 100 + 1
	return roll <= rate


# ============================================================
# Internal Helpers
# ============================================================


static func _describe_effect_node(node: EffectNode) -> String:
	match node.type:
		"damage": return "伤害+%d" % node.value
		"block": return "格挡+%d" % node.value
		"heal": return "治疗+%d" % node.value
		"draw": return "抽牌+%d" % node.value
		"qi_restore": return "灵气恢复+%d" % node.value
		"qi_gather": return "聚气+%d" % node.value
		"buff": return "增益·%s" % node.meta.get("name", "?")
		"burn": return "灼烧+%d" % node.value
		"vulnerable": return "易伤+%d" % node.value
		"weak": return "虚弱+%d" % node.value
		"cleanse": return "净化+%d" % node.value
		"unlock_node": return "解锁穴位"
		"repair_pathway": return "修复经脉"
		"pathway_capacity_up": return "经脉扩容+%d" % node.value
		"max_hp_up": return "生命上限+%d" % node.value
		_: return "%s+%d" % [node.type, node.value]


static func _category_of_effect(etype: String) -> String:
	match etype:
		"damage", "burn": return "offense"
		"block", "heal", "max_hp_up": return "defense"
		"buff", "qi_restore", "qi_gather": return "utility"
		"draw", "pathway_capacity_up", "unlock_node", "repair_pathway": return "utility"
		_: return "other"


static func _is_generic_tag(tag: String) -> bool:
	var generic: Array[String] = ["基础", "入门", "普通"]
	return tag in generic
