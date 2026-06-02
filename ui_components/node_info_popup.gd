# ============================================================
# 大周天 — Node Info Popup (穴位信息弹窗)
# ============================================================
# 单击穴位时弹出，显示穴位详细信息 + 特性中文解释
# 点击 ✕ 或弹窗外区域关闭
# ============================================================
class_name NodeInfoPopup
extends CanvasLayer


var _node: MeridianNodeData
var _node_idx: int = -1

const ELEMENT_COLORS := {
	"火": Color(0.9, 0.3, 0.2),
	"水": Color(0.2, 0.4, 0.9),
	"木": Color(0.2, 0.8, 0.3),
	"金": Color(0.9, 0.8, 0.2),
	"土": Color(0.8, 0.6, 0.3),
}
const ELEMENT_ICONS := {
	"火": "🔥", "水": "💧", "木": "🌿", "金": "⚙️", "土": "🪨",
}

const PROPERTY_DESCRIPTIONS := {
	"multi_target":      "攻击牌命中全体敌人",
	"apply_burn":        "攻击附带{0}点灼烧伤害，持续2回合",
	"apply_vulnerable":  "攻击附带易伤效果{0}回合（受伤×1.5）",
	"apply_weak":        "攻击附带虚弱效果{0}回合（敌人伤害-1）",
	"extra_draw":        "回合开始多抽{0}张牌",
	"qi_efficiency":     "出牌消耗减少{0}点灵气",
	"life_steal":        "造成伤害的{0}%转化为治疗",
	"reflect":           "受到伤害时反弹{0}%给攻击者",
	"pierce":            "攻击无视{0}点格挡",
	"counter":           "受到攻击时反击{0}点伤害",
	"double_strike":     "每回合首张攻击牌打出两次",
	"splash":            "攻击对相邻敌人造成{0}%溅射伤害",
}


func show_info(idx: int, node: MeridianNodeData) -> void:
	_node = node
	_node_idx = idx
	_build_ui()
	show()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	layer = 90

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.35)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_bg_clicked)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(270, 320)
	var ctrl := CenterContainer.new()
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.add_child(panel)
	add_child(ctrl)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	# --- Header ---
	var header := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = _node.name
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.7, 1))
	header.add_child(name_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.pressed.connect(func(): hide(); queue_free())
	header.add_child(close_btn)
	vbox.add_child(header)

	# --- Element ---
	var elem_str: String = _node.element
	if elem_str.is_empty():
		elem_str = "无属性"
	var elem_label := Label.new()
	elem_label.text = "%s %s" % [ELEMENT_ICONS.get(_node.element, ""), elem_str]
	elem_label.add_theme_font_size_override("font_size", 14)
	elem_label.add_theme_color_override("font_color", ELEMENT_COLORS.get(_node.element, Color(0.7, 0.7, 0.7)))
	vbox.add_child(elem_label)

	# --- Status ---
	var status_label := Label.new()
	if _node.unlocked:
		status_label.text = "🔓 已解锁"
		status_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3))
	else:
		status_label.text = "🔒 锁定"
		status_label.add_theme_color_override("font_color", Color(0.9, 0.55, 0.2))
	if _node.blocked:
		status_label.text += " · 🚫阻塞"
	status_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(status_label)

	# --- Qi bar + text ---
	_add_section_title(vbox, "灵气")
	var qi_label := Label.new()
	qi_label.text = "%.1f / %.0f" % [_node.current_qi, _node.capacity]
	qi_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(qi_label)

	var qi_bar_bg := ColorRect.new()
	qi_bar_bg.color = Color(0.12, 0.12, 0.18)
	qi_bar_bg.custom_minimum_size = Vector2(220, 10)
	vbox.add_child(qi_bar_bg)
	var qi_ratio: float = clamp(_node.current_qi / max(1.0, _node.capacity), 0.0, 1.0)
	var qi_bar_fill := ColorRect.new()
	qi_bar_fill.color = ELEMENT_COLORS.get(_node.element, Color(0.5, 0.5, 0.5))
	qi_bar_fill.custom_minimum_size = Vector2(220 * qi_ratio, 10)
	qi_bar_fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	qi_bar_bg.add_child(qi_bar_fill)

	# --- Properties ---
	_add_section_title(vbox, "穴位特性")
	if not _node.properties.is_empty():
		for p in _node.properties:
			_add_property_row(vbox, p)
	else:
		var none := Label.new()
		none.text = "  (无特性)"
		none.add_theme_font_size_override("font_size", 11)
		none.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		vbox.add_child(none)

	# --- Erosion (locked nodes only) ---
	if not _node.unlocked and _node.erosion_threshold > 0:
		_add_section_title(vbox, "冲穴进度")
		var erosion_pct: int = int(clamp(_node.erosion_progress / _node.erosion_threshold * 100.0, 0.0, 100.0))
		var erosion_label := Label.new()
		erosion_label.text = "%.1f / %.0f (%d%%)" % [_node.erosion_progress, _node.erosion_threshold, erosion_pct]
		erosion_label.add_theme_font_size_override("font_size", 12)
		erosion_label.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0))
		vbox.add_child(erosion_label)

		var hint := Label.new()
		hint.text = "💡 双击此穴位标记/取消冲穴目标"
		hint.add_theme_font_size_override("font_size", 10)
		hint.add_theme_color_override("font_color", Color(0.45, 0.65, 0.45))
		vbox.add_child(hint)

	# --- Stats row ---
	_add_section_title(vbox, "参数")
	var info_text: String = "容量: %.0f  传播阈值: %d%%  传播: %.1f" % [_node.capacity, int(_node.spread_threshold * 100), _node.capacity * _node.spread_threshold]
	var info_label := Label.new()
	info_label.text = info_text
	info_label.add_theme_font_size_override("font_size", 10)
	info_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	vbox.add_child(info_label)

	# --- Connections ---
	var conn_names: Array[String] = []
	var mer: MeridianMapData = GameManager.base_meridian
	if mer:
		for c in _node.connections:
			var cn: MeridianNodeData = mer.get_node(c)
			if cn:
				var icon: String = ELEMENT_ICONS.get(cn.element, "")
				conn_names.append(icon + cn.name)
	if not conn_names.is_empty():
		var conn_label := Label.new()
		conn_label.text = "相邻: " + "  ".join(conn_names)
		conn_label.add_theme_font_size_override("font_size", 10)
		conn_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(conn_label)


# ============================================================
# Helpers
# ============================================================

func _add_section_title(parent: VBoxContainer, title: String) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.65, 0.8))
	parent.add_child(lbl)


func _add_property_row(parent: VBoxContainer, prop: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	# Property name badge
	var name_badge := Label.new()
	var parts: PackedStringArray = prop.split(":")
	var prop_name: String = parts[0]
	var prop_param: String = parts[1] if parts.size() >= 2 else ""
	name_badge.text = "▸ %s" % prop_name
	name_badge.add_theme_font_size_override("font_size", 11)
	name_badge.add_theme_color_override("font_color", Color(0.3, 0.85, 0.85))
	row.add_child(name_badge)

	# Description
	parent.add_child(row)

	var desc: String = PROPERTY_DESCRIPTIONS.get(prop_name, "")
	if not desc.is_empty():
		desc = desc.replace("{0}", prop_param)
		var desc_label := Label.new()
		desc_label.text = "    %s" % desc
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
		parent.add_child(desc_label)


func _on_bg_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide()
		queue_free()
