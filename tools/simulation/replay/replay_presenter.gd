# ============================================================
# 大周天 — ReplayPresenter (事件→UI 映射层)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 将 SimulationEvent 翻译为 UI 指令 (UIInstruction)。
# 纯映射层 — 不修改游戏状态，不运行逻辑，只产出渲染指令。
#
# 设计原则:
#   - 输入: SimulationEvent (不可变)
#   - 输出: UIInstruction (纯数据，描述"画什么")
#   - 不做动画 — 动画由 ReplayRenderer / UI 层负责
#   - 通过 signal 输出，与具体 UI 解耦
#
# 事件→指令映射:
#   "card_played"           → CARD_PLAYED (卡牌飞行)
#   "damage_dealt"          → FLOAT_TEXT (-N, 红色) + SHAKE
#   "heal_received"         → FLOAT_TEXT (+N, 绿色) + GLOW
#   "qi_generated"          → FLOAT_TEXT (+N, 蓝色) + QI_PULSE
#   "qi_consumed"           → FLOAT_TEXT (-N, 淡蓝)
#   "block_gained"          → FLOAT_TEXT (+N, 灰色) + SHIELD_UPDATE
#   "technique_activated"   → BUFF_ICON (激活)
#   "technique_deactivated" → BUFF_ICON (停用)
#   "buffs_updated"         → BUFF_REFRESH
#   "qi_state"              → QI_BAR_UPDATE
#   "qi_wasted_estimated"   → FLOAT_TEXT (灰色, 浪费提醒)
# ============================================================
class_name ReplayPresenter
extends RefCounted


# ============================================================
# UIInstruction — 单条渲染指令
# ============================================================

## UI 渲染指令
class UIInstruction:
	## 指令类型: "float_text" | "shake" | "flash" | "bar_update" | "card_anim" | "buff_refresh" | "qi_pulse" | "shield_update" | "state_sync"
	var type: String = ""

	## 目标实体: "player" | "enemy_0" | "enemy_1" | ...
	var target_id: String = ""

	## 数值（伤害/治疗/护盾/灵气量）
	var value: int = 0

	## 显示文本
	var text: String = ""

	## 颜色
	var color: Color = Color.WHITE

	## 动画时长（秒）
	var duration: float = 0.5

	## 来源卡牌 ID（用于卡牌动画）
	var source_card_id: String = ""

	## 扩展数据
	var extra: Dictionary = {}

	func _init(p_type: String = "", p_target: String = "", p_value: int = 0) -> void:
		type = p_type
		target_id = p_target
		value = p_value


# ============================================================
# Signals (for Node-based usage)
# ============================================================

## 当事件被翻译为 UI 指令时发射
signal instruction_ready(instruction: UIInstruction)

## 当事件需要批量更新状态时发射（如 qi_state）
signal state_sync_requested(state_data: Dictionary)


# ============================================================
# Public — Main Entry
# ============================================================

## 将一条 SimulationEvent 翻译为 UI 指令数组
func translate(event: SimulationEvent) -> Array[UIInstruction]:
	if event == null:
		return []

	match event.type:
		"card_played":
			return _translate_card_played(event)
		"damage_dealt":
			return _translate_damage(event)
		"damage_taken":
			return _translate_damage(event)
		"heal_received":
			return _translate_heal(event)
		"qi_generated":
			return _translate_qi_generated(event)
		"qi_consumed":
			return _translate_qi_consumed(event)
		"qi_wasted_estimated":
			return _translate_qi_wasted(event)
		"qi_state":
			return _translate_qi_state(event)
		"block_gained":
			return _translate_block(event)
		"technique_activated":
			return _translate_technique_on(event)
		"technique_deactivated":
			return _translate_technique_off(event)
		"buffs_updated":
			return _translate_buffs(event)
		_:
			return []


## 翻译并发射 signal（Node 模式下使用）
func translate_and_emit(event: SimulationEvent) -> void:
	var instructions: Array[UIInstruction] = translate(event)
	for inst in instructions:
		instruction_ready.emit(inst)


# ============================================================
# Event Translators
# ============================================================

func _translate_card_played(event: SimulationEvent) -> Array[UIInstruction]:
	var inst := UIInstruction.new("card_anim", event.actor_id)
	inst.source_card_id = event.source_card_id
	inst.text = event.payload.get("card_name", "")
	inst.extra = event.payload.duplicate()
	return [inst]


func _translate_damage(event: SimulationEvent) -> Array[UIInstruction]:
	var amount: int = event.payload.get("amount", 0)
	var result: Array[UIInstruction] = []

	# 1. 浮动伤害数字
	var ft := UIInstruction.new("float_text", event.target_id, amount)
	ft.text = "-%d" % amount
	ft.color = Color(0.9, 0.2, 0.15)  # 红色
	ft.duration = 0.8
	result.append(ft)

	# 2. 目标震动
	var shake := UIInstruction.new("shake", event.target_id)
	shake.duration = 0.2
	result.append(shake)

	# 3. 目标闪烁
	var flash := UIInstruction.new("flash", event.target_id)
	flash.color = Color(0.9, 0.2, 0.15, 0.3)
	flash.duration = 0.15
	result.append(flash)

	return result


func _translate_heal(event: SimulationEvent) -> Array[UIInstruction]:
	var amount: int = event.payload.get("amount", 0)
	var result: Array[UIInstruction] = []

	var ft := UIInstruction.new("float_text", event.target_id, amount)
	ft.text = "+%d" % amount
	ft.color = Color(0.2, 0.8, 0.3)  # 绿色
	ft.duration = 0.8
	result.append(ft)

	var glow := UIInstruction.new("flash", event.target_id)
	glow.color = Color(0.2, 0.8, 0.3, 0.2)
	glow.duration = 0.3
	result.append(glow)

	return result


func _translate_qi_generated(event: SimulationEvent) -> Array[UIInstruction]:
	var amount: int = event.payload.get("amount", 0)
	var result: Array[UIInstruction] = []

	var ft := UIInstruction.new("float_text", event.actor_id, amount)
	ft.text = "+%d 气" % amount
	ft.color = Color(0.3, 0.5, 0.95)  # 蓝色
	ft.duration = 0.6
	result.append(ft)

	var pulse := UIInstruction.new("qi_pulse", event.actor_id)
	pulse.duration = 0.3
	result.append(pulse)

	return result


func _translate_qi_consumed(event: SimulationEvent) -> Array[UIInstruction]:
	var amount: int = event.payload.get("amount", 0)
	var ft := UIInstruction.new("float_text", event.actor_id, amount)
	ft.text = "-%d 气" % amount
	ft.color = Color(0.5, 0.6, 0.9)  # 淡蓝
	ft.duration = 0.6
	return [ft]


func _translate_qi_wasted(event: SimulationEvent) -> Array[UIInstruction]:
	var amount: int = event.payload.get("amount", 0)
	var ft := UIInstruction.new("float_text", event.actor_id, amount)
	ft.text = "溢 %d" % amount
	ft.color = Color(0.5, 0.5, 0.5)  # 灰色
	ft.duration = 0.5
	return [ft]


func _translate_qi_state(event: SimulationEvent) -> Array[UIInstruction]:
	# qi_state 是完整快照 — 直接要求 UI 同步
	var sync := UIInstruction.new("bar_update", event.actor_id)
	sync.extra = event.payload.duplicate()
	return [sync]


func _translate_block(event: SimulationEvent) -> Array[UIInstruction]:
	var amount: int = event.payload.get("amount", 0)
	var result: Array[UIInstruction] = []

	var ft := UIInstruction.new("float_text", event.target_id, amount)
	ft.text = "+%d 护" % amount
	ft.color = Color(0.7, 0.7, 0.75)  # 灰白
	ft.duration = 0.6
	result.append(ft)

	var shield := UIInstruction.new("shield_update", event.target_id)
	shield.value = amount
	result.append(shield)

	return result


func _translate_technique_on(event: SimulationEvent) -> Array[UIInstruction]:
	var inst := UIInstruction.new("buff_refresh", event.actor_id)
	inst.text = event.source
	inst.extra = {"activated": true}
	return [inst]


func _translate_technique_off(event: SimulationEvent) -> Array[UIInstruction]:
	var inst := UIInstruction.new("buff_refresh", event.actor_id)
	inst.text = event.source
	inst.extra = {"activated": false}
	return [inst]


func _translate_buffs(event: SimulationEvent) -> Array[UIInstruction]:
	var inst := UIInstruction.new("buff_refresh", event.actor_id)
	inst.extra = event.payload.duplicate()
	return [inst]


# ============================================================
# Static — Batch Translate
# ============================================================

## 批量翻译事件数组
static func translate_all(events: Array[SimulationEvent]) -> Array[UIInstruction]:
	var presenter := ReplayPresenter.new()
	var result: Array[UIInstruction] = []
	for e in events:
		if e:
			result.append_array(presenter.translate(e))
	return result
