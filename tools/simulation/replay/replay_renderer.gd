# ============================================================
# 大周天 — ReplayRenderer (回放可视化层)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 消费 ReplayController 产生的事件，驱动战斗 UI 的"重放版本"。
# 不运行游戏逻辑 — 只读事件 + 驱动动画/UI 更新。
#
# 职责:
#   - 接收 SimulationEvent → Presenter 翻译 → 执行 UI 指令
#   - 管理时间轴控件（scrubber + play/pause/step 按钮）
#   - 管理事件列表面板
#   - 可选绑定战斗画面（BattleScene）做视觉同步
#
# 红线:
#   - 绝不做逻辑计算
#   - 不改 simulation state
#   - 不调 kernel
# ============================================================
class_name ReplayRenderer
extends Control


# ============================================================
# Signals
# ============================================================

## 用户拖动时间轴
signal timeline_scrubbed(tick: int)

## 用户点击事件列表中的某条事件
signal event_selected(event_index: int)


# ============================================================
# State
# ============================================================

## 回放控制器
var controller: ReplayController = null

## 事件→UI 翻译器
var presenter: ReplayPresenter = null

## 绑定的战斗画面节点（可选 — 用于视觉同步回放）
var battle_view: Node = null

## 绑定的快照展示器（可选 — 用于 HP/Qi/Buff 等状态同步）
var snapshot_presenter = null  # BattleSnapshotPresenter


# ============================================================
# UI 子组件引用
# ============================================================

## 时间轴滑块
var timeline_slider: HSlider = null

## tick 标签
var tick_label: Label = null

## 播放/暂停按钮
var play_btn: Button = null

## 逐帧前进按钮
var step_btn: Button = null

## 逐帧后退按钮
var step_back_btn: Button = null

## 速度选择器
var speed_option: OptionButton = null

## 事件列表面板
var event_list: ItemList = null

## 状态差异面板
var diff_label: Label = null

## 进度标签
var progress_label: Label = null


# ============================================================
# Public — Bind
# ============================================================

## 绑定控制器
func bind_controller(ctrl: ReplayController) -> void:
	controller = ctrl
	presenter = ReplayPresenter.new()

	# 接线 controller signal → renderer
	if not controller.event_emitted.is_connected(_on_event_emitted):
		controller.event_emitted.connect(_on_event_emitted)
	if not controller.tick_changed.is_connected(_on_tick_changed):
		controller.tick_changed.connect(_on_tick_changed)
	if not controller.play_state_changed.is_connected(_on_play_state_changed):
		controller.play_state_changed.connect(_on_play_state_changed)
	if not controller.replay_finished.is_connected(_on_replay_finished):
		controller.replay_finished.connect(_on_replay_finished)


## 绑定战斗画面（用于视觉同步）
func bind_battle_view(view: Node) -> void:
	battle_view = view


## 绑定快照展示器
func bind_snapshot_presenter(sp) -> void:
	snapshot_presenter = sp


# ============================================================
# Godot — Lifecycle
# ============================================================

func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# === 顶部控制栏 ===
	var toolbar := HBoxContainer.new()
	toolbar.name = "Toolbar"
	toolbar.add_theme_constant_override("separation", 8)
	add_child(toolbar)

	# 播放/暂停
	play_btn = Button.new()
	play_btn.name = "PlayBtn"
	play_btn.text = "▶"
	play_btn.custom_minimum_size = Vector2(40, 32)
	play_btn.pressed.connect(_on_play_pressed)
	toolbar.add_child(play_btn)

	# 逐帧后退
	step_back_btn = Button.new()
	step_back_btn.name = "StepBackBtn"
	step_back_btn.text = "◀◀"
	step_back_btn.custom_minimum_size = Vector2(40, 32)
	step_back_btn.pressed.connect(_on_step_back_pressed)
	toolbar.add_child(step_back_btn)

	# 逐帧前进
	step_btn = Button.new()
	step_btn.name = "StepBtn"
	step_btn.text = "▶▶"
	step_btn.custom_minimum_size = Vector2(40, 32)
	step_btn.pressed.connect(_on_step_pressed)
	toolbar.add_child(step_btn)

	# tick 标签
	tick_label = Label.new()
	tick_label.name = "TickLabel"
	tick_label.text = "Tick: 0 / 0"
	tick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tick_label.custom_minimum_size = Vector2(140, 0)
	toolbar.add_child(tick_label)

	# 速度选择器
	speed_option = OptionButton.new()
	speed_option.name = "SpeedOption"
	speed_option.add_item("0.25x")
	speed_option.add_item("0.5x")
	speed_option.add_item("1x")
	speed_option.add_item("2x")
	speed_option.add_item("4x")
	speed_option.add_item("10x")
	speed_option.selected = 2  # 默认 1x
	speed_option.item_selected.connect(_on_speed_changed)
	toolbar.add_child(speed_option)

	# 进度标签
	progress_label = Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.text = "0%"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(progress_label)

	# === 时间轴滑块 ===
	timeline_slider = HSlider.new()
	timeline_slider.name = "TimelineSlider"
	timeline_slider.min_value = 0.0
	timeline_slider.max_value = 1.0
	timeline_slider.step = 0.001
	timeline_slider.value = 0.0
	timeline_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_slider.value_changed.connect(_on_slider_changed)
	add_child(timeline_slider)

	# === 内容区: 事件列表 + 差异面板 ===
	var content := HSplitContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(content)

	# 事件列表
	event_list = ItemList.new()
	event_list.name = "EventList"
	event_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_list.item_selected.connect(_on_event_item_selected)
	content.add_child(event_list)

	# 状态差异面板
	diff_label = Label.new()
	diff_label.name = "DiffLabel"
	diff_label.text = "[选择事件查看详情]"
	diff_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	diff_label.custom_minimum_size = Vector2(280, 0)
	content.add_child(diff_label)


# ============================================================
# Public — Apply Event (Renderer 接口)
# ============================================================

## 接收事件并驱动 UI（ReplayController 通过 signal 或直接调用此方法）
func apply_event(event: SimulationEvent) -> void:
	if event == null or presenter == null:
		return

	# 1. 翻译为 UI 指令
	var instructions: Array = presenter.translate(event)

	# 2. 执行 UI 指令
	for inst in instructions:
		if inst is ReplayPresenter.UIInstruction:
			_execute_instruction(inst)

	# 3. 追加到事件列表
	if event_list:
		var label: String = _format_event_label(event)
		event_list.add_item(label)
		# 自动滚动到最新
		event_list.ensure_current_is_visible()


# ============================================================
# Internal — UI Instruction Execution
# ============================================================

func _execute_instruction(inst: ReplayPresenter.UIInstruction) -> void:
	match inst.type:
		"float_text":
			_show_float_text(inst)
		"shake":
			_play_shake(inst)
		"flash":
			_play_flash(inst)
		"bar_update":
			_update_bars(inst)
		"card_anim":
			_play_card_anim(inst)
		"buff_refresh":
			_refresh_buffs(inst)
		"qi_pulse":
			_play_qi_pulse(inst)
		"shield_update":
			_update_shield(inst)
		"state_sync":
			_sync_state(inst)
		_:
			pass


# ============================================================
# Internal — Animation Helpers (纯 UI, 无逻辑)
# ============================================================

func _show_float_text(inst: ReplayPresenter.UIInstruction) -> void:
	if battle_view and battle_view.has_method("show_float_text"):
		battle_view.show_float_text(inst.target_id, inst.text, inst.color, inst.duration)


func _play_shake(inst: ReplayPresenter.UIInstruction) -> void:
	if battle_view and battle_view.has_method("shake_target"):
		battle_view.shake_target(inst.target_id, inst.duration)


func _play_flash(inst: ReplayPresenter.UIInstruction) -> void:
	if battle_view and battle_view.has_method("flash_target"):
		battle_view.flash_target(inst.target_id, inst.color, inst.duration)


func _update_bars(inst: ReplayPresenter.UIInstruction) -> void:
	# qi_state → 更新气条
	if battle_view and battle_view.has_method("update_qi_bar"):
		battle_view.update_qi_bar(inst.target_id, inst.extra)


func _play_card_anim(inst: ReplayPresenter.UIInstruction) -> void:
	if battle_view and battle_view.has_method("play_card_anim"):
		battle_view.play_card_anim(inst.extra)


func _refresh_buffs(inst: ReplayPresenter.UIInstruction) -> void:
	if battle_view and battle_view.has_method("refresh_buffs"):
		battle_view.refresh_buffs(inst.target_id)


func _play_qi_pulse(inst: ReplayPresenter.UIInstruction) -> void:
	if battle_view and battle_view.has_method("play_qi_pulse"):
		battle_view.play_qi_pulse(inst.target_id, inst.duration)


func _update_shield(inst: ReplayPresenter.UIInstruction) -> void:
	if battle_view and battle_view.has_method("update_shield"):
		battle_view.update_shield(inst.target_id, inst.value)


func _sync_state(inst: ReplayPresenter.UIInstruction) -> void:
	if battle_view and battle_view.has_method("sync_state"):
		battle_view.sync_state(inst.extra)


# ============================================================
# Internal — Event List Formatting
# ============================================================

func _format_event_label(event: SimulationEvent) -> String:
	var tick_str: String = "T%d" % int(event.time / 0.05) if event.time > 0 else "T0"
	match event.type:
		"card_played":
			return "%s  [出牌] %s" % [tick_str, event.payload.get("card_name", "?")]
		"damage_dealt":
			return "%s  [伤害] %s → %s: -%d" % [tick_str, event.actor_id, event.target_id, event.payload.get("amount", 0)]
		"heal_received":
			return "%s  [治疗] %s: +%d" % [tick_str, event.target_id, event.payload.get("amount", 0)]
		"qi_generated":
			return "%s  [灵气+] %s: +%d" % [tick_str, event.actor_id, event.payload.get("amount", 0)]
		"qi_consumed":
			return "%s  [灵气-] %s: -%d" % [tick_str, event.actor_id, event.payload.get("amount", 0)]
		"qi_wasted_estimated":
			return "%s  [灵气溢] %s: %d" % [tick_str, event.actor_id, event.payload.get("amount", 0)]
		"block_gained":
			return "%s  [格挡] %s: +%d" % [tick_str, event.target_id, event.payload.get("amount", 0)]
		"technique_activated":
			return "%s  [功法开] %s" % [tick_str, event.source]
		"technique_deactivated":
			return "%s  [功法关] %s" % [tick_str, event.source]
		"buffs_updated":
			return "%s  [Buff] %s" % [tick_str, event.actor_id]
		"qi_state":
			return "%s  [气态] %s" % [tick_str, event.actor_id]
		_:
			return "%s  [%s]" % [tick_str, event.type]


# ============================================================
# Callbacks — Controller Signals
# ============================================================

func _on_event_emitted(event: SimulationEvent) -> void:
	apply_event(event)


func _on_tick_changed(tick: int) -> void:
	_update_timeline_display(tick)


func _on_play_state_changed(playing: bool) -> void:
	if play_btn:
		play_btn.text = "⏸" if playing else "▶"


func _on_replay_finished() -> void:
	if play_btn:
		play_btn.text = "↺"  # 循环图标
	if controller and controller.loop:
		# 清空事件列表重新开始
		if event_list:
			event_list.clear()


# ============================================================
# Callbacks — UI Controls
# ============================================================

func _on_play_pressed() -> void:
	if controller == null:
		return
	if controller.is_finished() and not controller.loop:
		controller.stop()
	controller.toggle_play()


func _on_step_pressed() -> void:
	if controller:
		controller.step()


func _on_step_back_pressed() -> void:
	if controller:
		controller.step_back()


func _on_speed_changed(index: int) -> void:
	if controller == null:
		return
	match index:
		0: controller.set_speed(0.25)
		1: controller.set_speed(0.5)
		2: controller.set_speed(1.0)
		3: controller.set_speed(2.0)
		4: controller.set_speed(4.0)
		5: controller.set_speed(10.0)


func _on_slider_changed(value: float) -> void:
	if controller == null:
		return
	var target_tick: int = int(value * float(controller.get_tick_count()))
	controller.seek(target_tick)
	timeline_scrubbed.emit(target_tick)


func _on_event_item_selected(index: int) -> void:
	event_selected.emit(index)
	_update_diff_display(index)


# ============================================================
# Timeline Display Update
# ============================================================

func _update_timeline_display(tick: int) -> void:
	if controller == null:
		return

	var total: int = controller.get_tick_count()
	if tick_label:
		tick_label.text = "Tick: %d / %d" % [tick, max(0, total - 1)]

	var progress: float = controller.get_progress()
	if timeline_slider and not timeline_slider.has_focus():
		# 只在用户未拖动滑块时更新（避免抢夺焦点）
		timeline_slider.set_value_no_signal(progress)

	if progress_label:
		progress_label.text = "%d%%" % int(progress * 100)


# ============================================================
# Diff Display — 单事件详情
# ============================================================

func _update_diff_display(event_list_index: int) -> void:
	if diff_label == null:
		return

	if controller == null or controller.cursor == null or controller.cursor.data == null:
		return

	var events: Array[SimulationEvent] = controller.cursor.data.events.all()
	if event_list_index < 0 or event_list_index >= events.size():
		return

	var e: SimulationEvent = events[event_list_index]
	var lines: PackedStringArray = []

	lines.append("=== 事件详情 ===")
	lines.append("类型: %s" % e.type)
	lines.append("时间: %.2fs" % e.time)
	lines.append("施加者: %s" % e.actor_id)
	lines.append("承受者: %s" % e.target_id)
	lines.append("来源: %s" % e.source)

	if e.source_card_id:
		lines.append("卡牌: %s" % e.source_card_id)
	if e.action_id >= 0:
		lines.append("Action ID: %d" % e.action_id)

	lines.append("")
	lines.append("=== 确定性数据 ===")
	lines.append("hash_before: %d" % e.state_hash_before)
	lines.append("hash_after: %d" % e.state_hash_after)
	lines.append("rng_call: %d" % e.rng_call_index)

	if not e.payload.is_empty():
		lines.append("")
		lines.append("=== Payload ===")
		for key in e.payload:
			lines.append("  %s: %s" % [key, e.payload[key]])

	diff_label.text = "\n".join(lines)
