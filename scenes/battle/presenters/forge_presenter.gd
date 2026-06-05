# ============================================================
# 大周天 — ForgePresenter (锻造 UI — L0)
# 职责: 锻造提示、结果弹窗、特性选择弹窗的显示/清理
# 红线: 不调 controller.target_manager (通过 Callable 外抛)
# ============================================================
class_name ForgePresenter
extends RefCounted

## 父节点 (用于添加弹窗)
var screen_node: Node
## 回合提示标签
var turn_label: Label
## 锻造提示标签 (临时)
var forge_hint_label: Label = null
## 特性选择弹窗
var _forge_feature_popup: Control = null
## 特性选中回调 (feature: Dictionary) → void → 通常路由到 controller.target_manager.submit_target()
var _on_feature_selected: Callable
## 取消回调
var _on_cancelled: Callable


## 注入依赖
func setup(
	p_screen: Node,
	p_turn_label: Label,
	p_on_feature_selected: Callable,
	p_on_cancelled: Callable,
) -> void:
	screen_node = p_screen
	turn_label = p_turn_label
	_on_feature_selected = p_on_feature_selected
	_on_cancelled = p_on_cancelled


## 显示锻造提示文字（纯表现层）
func show_forge_hint(hint: String) -> void:
	_remove_forge_hint()
	forge_hint_label = Label.new()
	forge_hint_label.name = "ForgeHintLabel"
	forge_hint_label.text = hint
	forge_hint_label.add_theme_color_override("font_color", GameColors.ACCENT_GOLD_BRIGHT)
	forge_hint_label.add_theme_font_size_override("font_size", UIHelpers.scale_font(18, screen_node))
	forge_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	forge_hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	forge_hint_label.position = Vector2(0, 60)
	screen_node.add_child(forge_hint_label)


## 显示锻造结果弹窗 — 委托给 ForgePopup 组件
func show_forge_result(result: CardForgeResult) -> void:
	var popup: ForgePopup = ForgePopup.new(result)
	screen_node.add_child(popup)


func remove_forge_hint() -> void:
	if forge_hint_label:
		forge_hint_label.queue_free()
		forge_hint_label = null


func _remove_forge_hint() -> void:
	remove_forge_hint()


## 清除锻造 UI 元素（提示标签、特性弹窗）
func clear_forge_ui() -> void:
	_remove_forge_hint()
	_close_feature_popup()
	turn_label.text = "已取消锻造"


## 显示特性选择弹窗 — 委托给 TraitSelector 组件
func _show_feature_selection_popup(features: Array) -> void:
	_close_feature_popup()
	if features.is_empty():
		turn_label.text = "无可选特性"
		return
	var selector: TraitSelector = TraitSelector.new(features, "选择特性")
	selector.trait_selected.connect(_on_feature_selected)
	selector.cancelled.connect(_on_cancelled)
	screen_node.add_child(selector)
	_forge_feature_popup = selector


func _close_feature_popup() -> void:
	if _forge_feature_popup:
		_forge_feature_popup.queue_free()
		_forge_feature_popup = null
