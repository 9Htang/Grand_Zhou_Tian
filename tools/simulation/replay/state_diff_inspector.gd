# ============================================================
# 大周天 — StateDiffInspector (状态差异检查器)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 逐 tick 状态对比器 — 用于调试和验证确定性。
# 提供:
#   - Hash 链可视化（tick→hash 映射）
#   - 相邻 tick 事件对比
#   - 两个 SimulationRun 的全量差异分析（利用 StateDiff）
#   - 单 tick 内事件统计
#
# 典型用法:
#   1. 回放时实时显示当前 tick 的 hash
#   2. 对比原始 run 和回放 run 的 hash 链
#   3. 当 hash 分歧时定位第一个分歧 tick
# ============================================================
class_name StateDiffInspector
extends Control


# ============================================================
# State
# ============================================================

## 主运行数据
var primary_run: SimulationRun = null

## 对比运行数据（可选 — 例如回放 run）
var secondary_run: SimulationRun = null

## 当前关注的 tick
var current_tick: int = 0


# ============================================================
# UI References
# ============================================================

var _hash_chain_container: Control = null
var _diff_text: Label = null
var _tick_info_label: Label = null
var _hash_match_label: Label = null


# ============================================================
# Godot — Lifecycle
# ============================================================

func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "InspectorLayout"
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	# === 标题 ===
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "=== State Diff Inspector ==="
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	# === Hash 匹配状态 ===
	_hash_match_label = Label.new()
	_hash_match_label.name = "HashMatchLabel"
	_hash_match_label.text = "Hash: --"
	vbox.add_child(_hash_match_label)

	# === Tick 信息 ===
	_tick_info_label = Label.new()
	_tick_info_label.name = "TickInfoLabel"
	_tick_info_label.text = "Tick: --"
	vbox.add_child(_tick_info_label)

	# === Hash 链滚动容器 ===
	var hash_scroll := ScrollContainer.new()
	hash_scroll.name = "HashScroll"
	hash_scroll.custom_minimum_size = Vector2(0, 80)
	hash_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hash_scroll)

	_hash_chain_container = HBoxContainer.new()
	_hash_chain_container.name = "HashChain"
	_hash_chain_container.add_theme_constant_override("separation", 1)
	hash_scroll.add_child(_hash_chain_container)

	# === 差异文本 ===
	var diff_scroll := ScrollContainer.new()
	diff_scroll.name = "DiffScroll"
	diff_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(diff_scroll)

	_diff_text = Label.new()
	_diff_text.name = "DiffText"
	_diff_text.text = "[等待数据...]"
	_diff_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	diff_scroll.add_child(_diff_text)


# ============================================================
# Public — Bind
# ============================================================

## 绑定主 SimulationRun
func bind_run(run: SimulationRun) -> void:
	primary_run = run
	_refresh_hash_chain()


## 绑定对比 SimulationRun（用于 A/B 对比）
func bind_secondary(run: SimulationRun) -> void:
	secondary_run = run
	_check_hash_match()


## 显示指定 tick 的状态
func show_tick(tick: int) -> void:
	current_tick = tick
	_update_tick_info()
	_update_diff_display()
	_highlight_current_hash()


# ============================================================
# Internal — Hash Chain
# ============================================================

func _refresh_hash_chain() -> void:
	if _hash_chain_container == null:
		return

	# 清空
	for child in _hash_chain_container.get_children():
		child.queue_free()

	if primary_run == null:
		return

	var hashes: Array[int] = primary_run.state_hashes
	if hashes.is_empty():
		return

	# 为每个 tick 创建一个小色块（hash 可视化）
	for i in range(hashes.size()):
		var hash_val: int = hashes[i]
		var block := ColorRect.new()
		block.name = "Hash_%d" % i
		block.custom_minimum_size = Vector2(6, 20)
		# 用 hash 的低 24 位生成颜色
		var r: float = float((hash_val >> 16) & 0xFF) / 255.0
		var g: float = float((hash_val >> 8) & 0xFF) / 255.0
		var b: float = float(hash_val & 0xFF) / 255.0
		block.color = Color(r, g, b, 0.8)
		block.tooltip_text = "Tick %d: %d" % [i, hash_val]
		_hash_chain_container.add_child(block)

	_check_hash_match()


func _check_hash_match() -> void:
	if _hash_match_label == null:
		return

	if primary_run == null:
		_hash_match_label.text = "Hash: 无数据"
		return

	if secondary_run == null:
		_hash_match_label.text = "Hash 链: %d ticks" % primary_run.state_hashes.size()
		return

	# A/B 对比
	var a: Array[int] = primary_run.state_hashes
	var b: Array[int] = secondary_run.state_hashes

	if a.size() != b.size():
		_hash_match_label.text = "Hash: ❌ 长度不匹配 (%d vs %d)" % [a.size(), b.size()]
		return

	var first_bad: int = -1
	for i in range(a.size()):
		if a[i] != b[i]:
			first_bad = i
			break

	if first_bad < 0:
		_hash_match_label.text = "Hash: ✅ 全部 %d ticks 一致" % a.size()
	else:
		_hash_match_label.text = "Hash: ❌ 分歧在 Tick %d" % first_bad


func _highlight_current_hash() -> void:
	if _hash_chain_container == null:
		return

	for child in _hash_chain_container.get_children():
		if child is ColorRect:
			var tick_str: String = child.name.trim_prefix("Hash_")
			var tick: int = tick_str.to_int()
			if tick == current_tick:
				child.custom_minimum_size = Vector2(12, 24)  # 高亮当前 tick
			else:
				child.custom_minimum_size = Vector2(6, 20)


# ============================================================
# Internal — Tick Info
# ============================================================

func _update_tick_info() -> void:
	if _tick_info_label == null or primary_run == null:
		return

	var lines: PackedStringArray = []
	lines.append("Tick: %d / %d" % [current_tick, max(0, primary_run.state_hashes.size() - 1)])

	# 当前 tick 的 hash
	if current_tick >= 0 and current_tick < primary_run.state_hashes.size():
		lines.append("Hash: %d" % primary_run.state_hashes[current_tick])

	# 当前 tick 的事件统计
	var events: Array[SimulationEvent] = primary_run.events.all()
	var tick_events: Array[SimulationEvent] = []
	var tick_rate: float = primary_run.config.tick_rate if primary_run.config and primary_run.config.tick_rate > 0.0 else 0.05
	for e in events:
		if int(e.time / tick_rate) == current_tick:
			tick_events.append(e)

	lines.append("事件数: %d" % tick_events.size())

	# 按类型统计
	var type_counts: Dictionary = {}
	for e in tick_events:
		var t: String = e.type
		type_counts[t] = type_counts.get(t, 0) + 1
	for type_key in type_counts:
		lines.append("  %s: %d" % [type_key, type_counts[type_key]])

	_tick_info_label.text = "\n".join(lines)


# ============================================================
# Internal — Diff Display
# ============================================================

func _update_diff_display() -> void:
	if _diff_text == null or primary_run == null:
		return

	# 如果有两个 run，做全量对比
	if secondary_run != null:
		_show_ab_diff()
		return

	# 否则显示当前 tick 的事件
	_show_tick_events()


func _show_tick_events() -> void:
	var lines: PackedStringArray = []
	lines.append("=== Tick %d 事件 ===" % current_tick)

	var events: Array[SimulationEvent] = primary_run.events.all()
	var tick_rate: float = primary_run.config.tick_rate if primary_run.config and primary_run.config.tick_rate > 0.0 else 0.05
	var count: int = 0

	for e in events:
		if int(e.time / tick_rate) == current_tick:
			lines.append("")
			lines.append("[%s] %s → %s" % [e.type, e.actor_id, e.target_id])
			lines.append("  source: %s" % e.source)
			if e.source_card_id:
				lines.append("  card: %s" % e.source_card_id)
			if not e.payload.is_empty():
				for key in e.payload:
					lines.append("  %s: %s" % [key, e.payload[key]])
			count += 1

	if count == 0:
		lines.append("(无事件)")

	_diff_text.text = "\n".join(lines)


func _show_ab_diff() -> void:
	var lines: PackedStringArray = []
	lines.append("=== A/B 对比 (原始 vs 回放) ===")
	lines.append("")

	var a_hashes: Array[int] = primary_run.state_hashes
	var b_hashes: Array[int] = secondary_run.state_hashes
	var limit: int = max(a_hashes.size(), b_hashes.size())

	var divergences: int = 0
	for i in range(limit):
		var ha: int = a_hashes[i] if i < a_hashes.size() else -1
		var hb: int = b_hashes[i] if i < b_hashes.size() else -1
		if ha != hb:
			lines.append("Tick %d: ❌ %d ≠ %d" % [i, ha, hb])
			divergences += 1
			if divergences >= 20:
				lines.append("... (已截断，共 %d+ 处分歧)" % divergences)
				break

	if divergences == 0:
		lines.append("✅ 全部 %d ticks hash 一致" % limit)

	_diff_text.text = "\n".join(lines)
