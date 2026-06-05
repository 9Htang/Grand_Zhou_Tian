# ============================================================
# 大周天 — CardForgeResult
# 锻造操作结果 — Domain → Controller → UI 的数据载体
#
# 职责: 携带锻造结果的结构化数据，供 BattleController 决策
#       和 BattleScreen 展示。Domain Service 不直接操作 UI。
# ============================================================
class_name CardForgeResult
extends RefCounted


## 是否成功
var success: bool = false

## 锻造类型: "pass_torch" / "swap_li"
var forge_type: String = ""

## 提取的特性（薪火相传: 从祭品提取的）
var extracted_trait: Dictionary = {}

## 添加的特性（薪火相传成功: 加到受体上的；离火易象: A→B 的特性）
var added_trait: Dictionary = {}

## 移除的特性（失败时丢失的特性）
var removed_trait: Dictionary = {}

## 人类可读结果消息
var message: String = ""

## 受影响的卡牌 id（用于 UI 刷新）
var affected_card_ids: Array[String] = []


# ============================================================
# Factory
# ============================================================


static func success_pass_torch(extracted: Dictionary, applied: Dictionary, card_a_name: String, card_b_name: String) -> CardForgeResult:
	var r := CardForgeResult.new()
	r.success = true
	r.forge_type = "pass_torch"
	r.extracted_trait = extracted
	r.added_trait = applied
	r.message = "%s 的特性「%s」→ %s" % [card_a_name, extracted.get("display_name", "?"), card_b_name]
	return r


static func failure_pass_torch(lost: Dictionary, card_b_name: String) -> CardForgeResult:
	var r := CardForgeResult.new()
	r.success = false
	r.forge_type = "pass_torch"
	r.removed_trait = lost
	if lost.is_empty():
		r.message = "%s 无特性可失，转化无效果" % card_b_name
	else:
		r.message = "%s 失去特性「%s」" % [card_b_name, lost.get("display_name", "?")]
	return r


static func success_swap_li(trait_a: Dictionary, trait_b: Dictionary, card_a_name: String, card_b_name: String) -> CardForgeResult:
	var r := CardForgeResult.new()
	r.success = true
	r.forge_type = "swap_li"
	r.extracted_trait = trait_a
	r.added_trait = trait_b
	r.message = "%s「%s」↔ %s「%s」" % [card_a_name, trait_a.get("display_name", "?"), card_b_name, trait_b.get("display_name", "?")]
	return r


static func failure_swap_li(trait_a: Dictionary, trait_b: Dictionary) -> CardForgeResult:
	var r := CardForgeResult.new()
	r.success = false
	r.forge_type = "swap_li"
	r.removed_trait = trait_a
	r.message = "两张卡各失去目标特性"
	return r


static func cancelled() -> CardForgeResult:
	var r := CardForgeResult.new()
	r.success = false
	r.message = "已取消"
	return r
