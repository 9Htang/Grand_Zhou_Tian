# ============================================================
# 大周天 — Event Screen (奇遇事件)
# 纯代码构建 UI，无需 .tscn 编排
# ============================================================
extends Control

# ── 动态创建的节点 ──
var _title_label: Label
var _desc_label: Label
var _choices_vbox: VBoxContainer
var _result_label: Label
var _continue_btn: Button

var _current_event: Dictionary = {}
var _full_description: String = ""
var _awaiting_result: bool = false


# ============================================================
# Lifecycle
# ============================================================

func _ready() -> void:
	_build_background()
	_select_event()
	_build_ui()


# ============================================================
# 背景 / 装饰
# ============================================================

func _build_background() -> void:
	# 全屏暗色背景
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 顶部装饰光带（紫色）— 自适应视口宽度
	var header_bar := ColorRect.new()
	header_bar.color = Color(0.5, 0.2, 0.6, 0.3)
	header_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_bar.custom_minimum_size.y = 3
	add_child(header_bar)

	# 底部装饰光带（金色）— 自适应视口宽度
	var footer_bar := ColorRect.new()
	footer_bar.color = Color(0.9, 0.8, 0.4, 0.15)
	footer_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer_bar.custom_minimum_size.y = 1
	add_child(footer_bar)


# ============================================================
# 事件选择
# ============================================================

func _select_event() -> void:
	var events: Array = _get_default_events()
	if events.is_empty():
		_current_event = _get_fallback_event()
	else:
		var idx: int = randi() % events.size()
		_current_event = events[idx] as Dictionary


# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	var m_h: int = UIHelpers.pad_h(self) * 2
	var m_v: int = UIHelpers.pad_v(self) * 2

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", m_h)
	margin.add_theme_constant_override("margin_right", m_h)
	margin.add_theme_constant_override("margin_top", m_v)
	margin.add_theme_constant_override("margin_bottom", m_v)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIHelpers.pct_h(0.02, self))
	margin.add_child(vbox)

	# ── 标题 ──
	_title_label = Label.new()
	_title_label.text = _current_event.get("display_name", "未知奇遇")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", UIHelpers.font_title(self))
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.3, 0.15, 0.0, 0.5))
	vbox.add_child(_title_label)

	# ── 装饰分隔线 ──
	var sep := ColorRect.new()
	sep.color = Color(0.5, 0.2, 0.6, 0.35)
	sep.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.25, self)), 2.0)
	vbox.add_child(sep)

	# ── 描述文字（带打字延迟效果） ──
	_desc_label = Label.new()
	_desc_label.text = ""
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.add_theme_font_size_override("font_size", UIHelpers.font_medium(self))
	_desc_label.add_theme_color_override("font_color", Color(0.78, 0.73, 0.73))
	_desc_label.custom_minimum_size.y = float(UIHelpers.pct_h(0.125, self))
	vbox.add_child(_desc_label)

	_full_description = _current_event.get("description", "四周一片寂静……")

	# ── 打字延迟计时器 ──
	var typing_timer := Timer.new()
	typing_timer.one_shot = true
	typing_timer.timeout.connect(_reveal_description)
	add_child(typing_timer)
	typing_timer.start(0.4)

	# ── 选项区域 ──
	_choices_vbox = VBoxContainer.new()
	_choices_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(_choices_vbox)
	_build_choices()

	# ── 结果文字（初始隐藏） ──
	_result_label = Label.new()
	_result_label.text = ""
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_result_label.add_theme_font_size_override("font_size", UIHelpers.font_medium(self))
	_result_label.add_theme_color_override("font_color", Color(0.88, 0.82, 0.68))
	_result_label.visible = false
	vbox.add_child(_result_label)

	# 弹性空间，把继续按钮推到底部
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND
	vbox.add_child(spacer)

	# ── 继续按钮（初始隐藏） ──
	_continue_btn = Button.new()
	_continue_btn.text = "继续"
	_continue_btn.custom_minimum_size = Vector2(float(UIHelpers.pct_w(0.16, self)), float(UIHelpers.pct_h(0.06, self)))
	_continue_btn.add_theme_font_size_override("font_size", UIHelpers.font_large(self))
	_continue_btn.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	_continue_btn.visible = false
	_continue_btn.pressed.connect(_on_continue_pressed)

	# 居中放置按钮
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_child(_continue_btn)
	vbox.add_child(btn_hbox)


func _reveal_description() -> void:
	_desc_label.text = _full_description


# ============================================================
# 选项构建
# ============================================================

func _build_choices() -> void:
	var choices: Array = _current_event.get("choices", [])
	if choices.is_empty():
		var no_choice := Button.new()
		no_choice.text = "离开此地"
		no_choice.custom_minimum_size.y = UIHelpers.pct_h(0.06, self)
		no_choice.pressed.connect(_on_no_choice)
		_choices_vbox.add_child(no_choice)
		return

	for choice in choices:
		_choices_vbox.add_child(_create_choice_button(choice as Dictionary))


func _create_choice_button(choice: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size.y = UIHelpers.pct_h(0.067, self)
	btn.add_theme_font_size_override("font_size", UIHelpers.font_medium(self))
	btn.text = _build_choice_text(choice)

	# 检查条件与消耗
	var req_met: bool = _check_requirement(choice.get("requirements", ""))
	var can_afford: bool = _check_cost(choice.get("cost", ""))

	var disabled: bool = not req_met or not can_afford
	btn.disabled = disabled

	if disabled:
		btn.modulate = Color(0.4, 0.4, 0.4)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.1, 0.2)
		style.border_width_left = 1; style.border_width_right = 1; style.border_width_top = 1; style.border_width_bottom = 1
		style.border_color = Color(0.3, 0.2, 0.4)
		style.corner_radius_top_left = 6; style.corner_radius_top_right = 6; style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", style)
	else:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.12, 0.25)
		style.border_width_left = 2; style.border_width_right = 2; style.border_width_top = 2; style.border_width_bottom = 2
		style.border_color = Color(0.55, 0.22, 0.75)
		style.corner_radius_top_left = 6; style.corner_radius_top_right = 6; style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", style)

		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(0.3, 0.18, 0.35)
		hover.border_width_left = 2; hover.border_width_right = 2; hover.border_width_top = 2; hover.border_width_bottom = 2
		hover.border_color = Color(0.7, 0.3, 0.9)
		hover.corner_radius_top_left = 6; hover.corner_radius_top_right = 6; hover.corner_radius_bottom_left = 6; hover.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("hover", hover)

		btn.pressed.connect(_on_choice_selected.bind(choice))

	return btn


# ============================================================
# 选项文字构建（带条件 / 消耗提示）
# ============================================================

func _build_choice_text(choice: Dictionary) -> String:
	var text: String = choice.get("text", "未知选项")
	var hints: Array[String] = []

	# 条件不足检查
	var req: String = choice.get("requirements", "")
	if not req.is_empty() and not _check_requirement(req):
		hints.append("条件不足")

	# 消耗描述
	var cost: String = choice.get("cost", "")
	if not cost.is_empty():
		var desc: String = _describe_cost(cost)
		if not desc.is_empty():
			hints.append(desc)

	if hints.is_empty():
		return text
	return text + "  （" + "，".join(hints) + "）"


# ============================================================
# 条件判定
# ============================================================

func _check_requirement(req: String) -> bool:
	if req.is_empty():
		return true
	# 格式: "key>=value"
	var parts: PackedStringArray = req.split(">=")
	if parts.size() < 2:
		return true
	var key: String = parts[0].strip_edges()
	var expected: int = int(parts[1].strip_edges())
	var current: int = _get_player_stat(key)
	return current >= expected


func _get_player_stat(key: String) -> int:
	match key:
		"realm":      return GameManager.realm
		"talent":     return GameManager.talent
		"dantian_qi": return GameManager.dantian_qi
		"gold":       return GameManager.gold
		"hp":         return GameManager.player_hp
	return 0


# ============================================================
# 消耗检查
# ============================================================

func _check_cost(cost: String) -> bool:
	if cost.is_empty():
		return true
	var parts: PackedStringArray = cost.split(":", false)
	if parts.size() < 2:
		return true
	var key: String = parts[0].strip_edges()
	var value_str: String = parts[1].strip_edges()
	var value: int = int(value_str)

	# 正数（获得）始终可支付
	if value >= 0:
		return true

	var abs_val: int = abs(value)
	match key:
		"hp":
			return GameManager.player_hp > abs_val
		"dantian_qi":
			return GameManager.dantian_qi >= abs_val
		"gold":
			return GameManager.gold >= abs_val
		"remove_card":
			return not GameManager.master_deck.is_empty()
	return true


func _describe_cost(cost: String) -> String:
	if cost.is_empty():
		return ""
	var parts: PackedStringArray = cost.split(":", false)
	if parts.size() < 2:
		return ""
	var key: String = parts[0].strip_edges()
	var value_str: String = parts[1].strip_edges()

	# 特殊处理 remove_card
	if key == "remove_card":
		return "随机移除一张卡牌"

	var value: int = int(value_str)
	if value >= 0:
		return ""

	var abs_val: int = abs(value)
	var names := {
		"hp": "气血",
		"dantian_qi": "灵气",
		"gold": "金币",
	}
	var display_name: String = names.get(key, key)
	return "消耗" + display_name + " " + str(abs_val)


# ============================================================
# 消耗执行
# ============================================================

func _apply_cost(cost: String) -> void:
	if cost.is_empty():
		return
	var parts: PackedStringArray = cost.split(":", false)
	if parts.size() < 2:
		return
	var key: String = parts[0].strip_edges()
	var value_str: String = parts[1].strip_edges()

	match key:
		"hp":
			var value: int = int(value_str)
			if value < 0:
				GameManager.take_damage(abs(value))
		"dantian_qi":
			var value: int = int(value_str)
			if value < 0:
				GameManager.spend_qi(abs(value))
			else:
				GameManager.add_qi(value)
		"gold":
			var value: int = int(value_str)
			GameManager.gold += value
		"remove_card":
			GameManager.remove_card(value_str)


# ============================================================
# 选择处理
# ============================================================

func _on_choice_selected(choice: Dictionary) -> void:
	_awaiting_result = true

	# 清除选项
	for child in _choices_vbox.get_children():
		child.queue_free()

	# 先执行消耗
	var cost: String = choice.get("cost", "")
	_apply_cost(cost)

	# 解析效果与结果文本
	var effects: Array[String] = []
	var result_text: String = ""

	var random_outcomes: Array = choice.get("random_outcomes", [])
	if not random_outcomes.is_empty():
		var outcome: Dictionary = _pick_weighted_outcome(random_outcomes)
		for e in outcome.get("effects", []): effects.append(str(e))
		result_text = outcome.get("text", "")
	else:
		for e in choice.get("effects", []): effects.append(str(e))
		result_text = choice.get("result_text", "")

	if result_text.is_empty() and not effects.is_empty():
		result_text = "你做出了选择……"

	# 应用效果
	if not effects.is_empty():
		EffectResolver.apply_all(GameManager, effects)

	# 显示结果
	_result_label.text = result_text
	_result_label.visible = true
	_continue_btn.visible = true

	# 确保描述文字已显示
	_desc_label.text = _full_description


func _pick_weighted_outcome(outcomes: Array) -> Dictionary:
	if outcomes.is_empty():
		return {"text": "", "effects": []}
	if outcomes.size() == 1:
		return outcomes[0] as Dictionary

	var total_weight: int = 0
	for o in outcomes:
		total_weight += int((o as Dictionary).get("weight", 1))

	if total_weight <= 0:
		return outcomes[0] as Dictionary

	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for o in outcomes:
		cumulative += int((o as Dictionary).get("weight", 1))
		if roll < cumulative:
			return o as Dictionary

	return outcomes[-1] as Dictionary


func _on_no_choice() -> void:
	_result_label.text = "你转身离开了这里。"
	_result_label.visible = true
	_continue_btn.visible = true


func _on_continue_pressed() -> void:
	SceneManager.switch_to_scene("res://scenes/chapter_map/chapter_map.tscn")


# ============================================================
# 默认事件数据（当 .tres 资源不存在时使用）
# ============================================================

func _get_default_events() -> Array:
	return [
		{
			"id": "gu_dong_qi_yu",
			"display_name": "古洞奇遇",
			"description": "你发现了一个古老的洞府，洞口闪烁着微光，似乎隐藏着某种机缘。洞府深处隐约传来阵阵灵气波动，但空气中弥漫着一丝危险的气息……",
			"choices": [
				{
					"text": "进入探索",
					"cost": "hp:-5",
					"random_outcomes": [
						{"weight": 3, "text": "你在洞府深处发现了一柄古剑，剑身泛着寒光！", "effects": ["gain_artifact:random"]},
						{"weight": 1, "text": "洞府中弥漫着毒瘴，你急忙退出，却已中毒……", "effects": ["damage:10"]},
						{"weight": 2, "text": "你找到了一些散落的灵石，收获颇丰。", "effects": ["gold:15"]}
					]
				},
				{
					"text": "谨慎绕行",
					"effects": ["gold:10"],
					"result_text": "你选择谨慎地绕过洞府，在路边捡到了一些散落的灵石。"
				}
			]
		},
		{
			"id": "xian_ren_yi_fu",
			"display_name": "仙人遗府",
			"description": "一座废弃的仙人洞府矗立在前方，石门半掩。石壁上刻着残缺的功法文字，虽然年代久远，仍能感受到其中的玄奥气息。府内似乎还藏着不少宝物……",
			"choices": [
				{
					"text": "研习功法",
					"requirements": "realm>=2",
					"random_outcomes": [
						{"weight": 1, "text": "你领悟了一式残招，心有所悟！", "effects": ["gain_card:attack_basic"]},
						{"weight": 1, "text": "石壁上的功法让你对修炼有了新的理解。", "effects": ["gain_card:qi_gathering"]},
						{"weight": 1, "text": "你从残谱中习得了一式防御之术。", "effects": ["gain_card:defense_basic"]}
					]
				},
				{
					"text": "搜寻宝物",
					"effects": ["gold:20"],
					"result_text": "你在洞府中翻找，发现了一些前人遗留的金币。"
				},
				{
					"text": "强行破禁",
					"cost": "hp:-15",
					"effects": ["talent_up:1"],
					"result_text": "你强行冲破禁制，虽然受了些伤，但似乎激发了自身的潜力！"
				}
			]
		},
		{
			"id": "ling_yao_yuan",
			"display_name": "灵药园",
			"description": "一片隐秘的灵药园出现在你面前，药香扑鼻。园中各类灵草郁郁葱葱，一看便知是上品。若能善加利用，必大有裨益。",
			"choices": [
				{
					"text": "采集灵药",
					"effects": ["heal:20"],
					"result_text": "你小心翼翼地采集了数株灵药，药力入体，伤势恢复了不少。"
				},
				{
					"text": "炼制丹药",
					"requirements": "talent>=3",
					"effects": ["gain_card:attack_basic", "gain_card:defense_basic"],
					"result_text": "你以灵药为材，就地炼制丹药。丹成之时，药香四溢！"
				}
			]
		}
	]


func _get_fallback_event() -> Dictionary:
	return {
		"id": "xiu_xi",
		"display_name": "休憩",
		"description": "你找到了一处安静的地方，稍作休息。",
		"choices": [
			{
				"text": "继续前进",
				"effects": [],
				"result_text": "你恢复了精神，继续前行。"
			}
		]
	}
