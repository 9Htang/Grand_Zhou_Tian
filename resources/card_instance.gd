# ============================================================
# 大周天 — CardInstance
# Layer1 卡牌实例 — 玩家持有的"这张卡"
# 只记录身份/升级/来源，不存储数值或效果变化
# ============================================================
@tool
class_name CardInstance
extends Resource


# === 模板引用 ===

## 此实例的唯一标识符 (UUID)
@export var instance_id: String = ""

## 指向的 CardData 模板 id
@export var base_id: String = ""


# === 升级状态 ===

## 当前升级次数 (0 = 原始未升级)
@export var upgrade_level: int = 0

## 选择的分支路径 id，空字符串表示未走分支
@export var upgrade_branch: String = ""


# === 个性化 ===

## 自定义名称覆盖，空字符串表示使用模板 display_name
@export var custom_name: String = ""


# === 来源追踪 ===

## 获取来源描述: "chapter_3_shop" / "breakthrough" / "event_xxx"
@export var acquisition_source: String = ""

## 获取时所在章节
@export var acquired_at_chapter: int = 0


# === 运行时标记 ===

## 通用标记字典: {"conversion_count": 2, "is_cursed": true, ...}
@export var flags: Dictionary = {}

# === 转化系统 — 卡牌实例修改 ===

## 通过转化获得的效果节点，运行时合并到 base_effects
@export var grafted_effects: Array[EffectNode] = []

## 通过转化获得的标签
@export var grafted_tags: Array[String] = []

## 从模板中移除的效果节点 id（不参与运行时）
@export var removed_effect_ids: Array[String] = []

## 元素覆盖，空字符串表示使用模板元素的元素
@export var element_override: String = ""


# ============================================================
# 查询
# ============================================================


## 获取显示名称: 自定义名称 > 模板 display_name
func get_display_name() -> String:
	if not custom_name.is_empty():
		return custom_name
	var data: CardData = CardDatabase.get_card(base_id)
	if data:
		return data.display_name
	return base_id


## 是否已升级
func is_upgraded() -> bool:
	return upgrade_level > 0 or not upgrade_branch.is_empty()


## 生成唯一 instance_id（如果为空）
func ensure_instance_id() -> void:
	if instance_id.is_empty():
		instance_id = "%s_%d" % [base_id, Time.get_unix_time_from_system()]


## 获取有效显示名称（含升级标记）
func get_full_name() -> String:
	var name: String = get_display_name()
	if upgrade_level > 0:
		name += "+%d" % upgrade_level
	if not upgrade_branch.is_empty():
		name += "·%s" % upgrade_branch
	return name


## 获取转化次数，从 flags 读取
func get_conversion_count() -> int:
	return int(flags.get("conversion_count", 0))


## 增加转化次数
func increment_conversion_count() -> void:
	flags["conversion_count"] = get_conversion_count() + 1


## 获取有效元素（覆盖优先于模板）
func get_effective_element() -> String:
	if not element_override.is_empty():
		return element_override
	var data: CardData = CardDatabase.get_card(base_id)
	if data:
		return data.element
	return ""


## 获取有效标签（模板标签 + 嫁接标签 − 需排除的逻辑）
func get_effective_tags() -> Array[String]:
	var data: CardData = CardDatabase.get_card(base_id)
	var tags: Array[String] = []
	if data:
		tags.append_array(data.tags)
	tags.append_array(grafted_tags)
	# 去重
	var seen: Dictionary = {}
	var result: Array[String] = []
	for t: String in tags:
		if not seen.has(t):
			seen[t] = true
			result.append(t)
	return result


## 获取有效效果节点列表（模板效果 − 移除 + 嫁接）
func get_effective_effects() -> Array[EffectNode]:
	var data: CardData = CardDatabase.get_card(base_id)
	var result: Array[EffectNode] = []
	if data:
		for node: EffectNode in data.get_or_build_effects():
			if node.id in removed_effect_ids:
				continue
			result.append(node)
	for node: EffectNode in grafted_effects:
		result.append(node)
	return result
