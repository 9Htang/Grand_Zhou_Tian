# ============================================================
# 大周天 — EventController (事件流程编排器)
# ============================================================
# L1 Systems Layer — 纯流程调度
#
# 职责: 事件流程调度 + 服务调用
# 红线: 不做决策 / 不调 UI / 不构建 Context / 纯数据进出
#
# 流程:
#   start_event()  → EventDatabase → RequirementChecker+CostResolver 预检 → 返回显示数据
#   select_choice() → RequirementChecker → CostResolver.apply →
#                    WeightedRandom.pick → EffectResolver.apply_all → EventResult
#
# 依赖 (L1→L2 委托):
#   EventDatabase       — 事件资源加载 + 随机选取
#   RequirementChecker  — 条件验证
#   CostResolver        — 消耗验证 + 执行 + 描述
#   WeightedRandom      — 加权随机选取
#   EffectResolver      — 效果字符串执行
# ============================================================
class_name EventController
extends RefCounted


## 当前展示的事件
var current_event: EventData = null


# ============================================================
# 事件启动 — 返回显示数据给 Screen
# ============================================================

## 启动事件流程
## event_id: 空字符串 = 随机事件
## 返回: {display_name, description, choices: [{index, text, disabled, hint}]}
func start_event(event_id: String = "") -> Dictionary:
	if event_id.is_empty():
		current_event = EventDatabase.get_random_event()
	else:
		current_event = EventDatabase.get_event(event_id)

	if current_event == null:
		current_event = EventDatabase.get_random_event()

	var choices_data: Array = []
	for i: int in current_event.choices.size():
		var choice: EventChoiceData = current_event.choices[i]
		choices_data.append(_build_choice_display(choice, i))

	return {
		"display_name": current_event.display_name,
		"description": current_event.description,
		"choices": choices_data,
	}


# ============================================================
# 选择执行 — 返回结果给 Screen
# ============================================================

## 执行玩家选择
## 完整流程: 条件检查 → 消耗检查 → 消耗执行 → 随机结果 → 效果执行
func select_choice(choice_index: int) -> EventResult:
	var result := EventResult.new()

	if current_event == null:
		result.success = false
		result.text = "没有可执行的事件"
		return result

	if choice_index < 0 or choice_index >= current_event.choices.size():
		result.success = false
		result.text = "无效的选择"
		return result

	var choice: EventChoiceData = current_event.choices[choice_index]

	# 1. 条件检查
	if not RequirementChecker.check(choice.requirements):
		result.success = false
		result.text = "条件不足，无法执行此选项"
		return result

	# 2. 消耗检查
	if not CostResolver.can_pay(choice.cost):
		result.success = false
		result.text = "消耗不足以支付此选项"
		return result

	# 3. 消耗执行
	CostResolver.apply(choice.cost)

	# 4. 随机结果 / 固定效果
	if not choice.random_outcomes.is_empty():
		var outcome: Dictionary = WeightedRandom.pick(choice.random_outcomes)
		result.effects = outcome.get("effects", [])
		result.text = outcome.get("text", "")
	else:
		result.effects = choice.effects.duplicate()
		result.text = choice.result_text

	# 5. 效果执行（委托 EffectResolver 兼容层）
	if not result.effects.is_empty():
		EffectResolver.apply_all(GameManager, result.effects)

	# 6. 默认文本
	if result.text.is_empty() and not result.effects.is_empty():
		result.text = "你做出了选择……"

	result.success = true
	return result


# ============================================================
# 查询 — 只读
# ============================================================

## 获取当前事件的选择数量
func get_choice_count() -> int:
	if current_event == null:
		return 0
	return current_event.choices.size()


# ============================================================
# Internal
# ============================================================

## 构建单个选项的 UI 展示数据
func _build_choice_display(choice: EventChoiceData, index: int) -> Dictionary:
	var disabled: bool = false
	var hints: Array[String] = []

	# 条件检查
	if not choice.requirements.is_empty():
		if not RequirementChecker.check(choice.requirements):
			disabled = true
			hints.append("条件不足")

	# 消耗检查
	if not choice.cost.is_empty():
		var cost_desc: String = CostResolver.describe(choice.cost)
		if not cost_desc.is_empty():
			if not disabled and not CostResolver.can_pay(choice.cost):
				disabled = true
			hints.append(cost_desc)

	return {
		"index": index,
		"text": choice.text,
		"disabled": disabled,
		"hint": "，".join(hints),
	}
