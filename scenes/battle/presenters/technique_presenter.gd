# ============================================================
# 大周天 — TechniquePresenter (功法展示 — L0)
# 职责: technique_area 的差分刷新 + 点击事件
# 红线: 不调 controller, 点击事件通过 Callable 外抛
# ============================================================
class_name TechniquePresenter
extends RefCounted

## 功法标签容器
var technique_area: HBoxContainer
## 功法点击回调 (technique: TechniqueData) → void
var _on_clicked: Callable


## 注入依赖
func setup(p_technique_area: HBoxContainer, p_on_clicked: Callable) -> void:
	technique_area = p_technique_area
	_on_clicked = p_on_clicked


## 根据快照差分刷新功法标签
func apply(snap: BattleSnapshot) -> void:
	var techs: Array = snap.techniques
	var old_count: int = technique_area.get_child_count()
	var has_empty_slot: bool = techs.size() < snap.talent
	var new_count: int = techs.size() + (1 if has_empty_slot else 0)

	# 移除多余节点
	while technique_area.get_child_count() > new_count:
		var child := technique_area.get_child(technique_area.get_child_count() - 1)
		technique_area.remove_child(child)
		child.queue_free()

	# 更新或创建功法标签
	for i: int in techs.size():
		var tech: TechniqueData = techs[i]
		var element_color: Color = Helpers.color_for_element(tech.get_element_int())
		var label_text: String = tech.display_name + " (" + tech.element + ")"
		if i < old_count:
			var label := technique_area.get_child(i) as Label
			if label:
				label.text = label_text
				label.add_theme_color_override("font_color", element_color)
		else:
			var label := Label.new()
			label.text = label_text
			label.add_theme_color_override("font_color", element_color)
			label.add_theme_font_size_override("font_size", 13)
			label.mouse_filter = Control.MOUSE_FILTER_STOP
			label.gui_input.connect(_on_label_gui_input.bind(tech))
			technique_area.add_child(label)

	# 空位占位符
	if has_empty_slot:
		var slot_idx: int = techs.size()
		if slot_idx < old_count:
			var slot_label := technique_area.get_child(slot_idx) as Label
			if slot_label:
				slot_label.text = "[空位]"
		else:
			var empty := Label.new()
			empty.text = "[空位]"
			empty.add_theme_color_override("font_color", GameColors.TEXT_DIM)
			technique_area.add_child(empty)


## 功法标签点击 → 外抛给 BattleScreen
func _on_label_gui_input(event: InputEvent, tech: TechniqueData) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_clicked.call(tech)
