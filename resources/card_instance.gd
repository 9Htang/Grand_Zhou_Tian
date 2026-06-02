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
