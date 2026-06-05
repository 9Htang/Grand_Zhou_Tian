# ============================================================
# 大周天 — IntentCompiler
# EnemyActionData → EffectProgram 编译器
# 统一敌人意图和玩家卡牌走同一条 EffectVM 管道
# ============================================================
class_name IntentCompiler
extends RefCounted


## 编译敌人行动为 EffectProgram
static func compile(action: EnemyActionData) -> EffectProgram:
	var ins: Array[EffectInstruction] = []

	match action.intent:
		EnemyActionData.IntentType.ATTACK, EnemyActionData.IntentType.ATTACK_MULTI:
			ins.append_array(_build_attack(action))
		EnemyActionData.IntentType.DEFEND:
			ins.append(_build_instruction(EffectOpcode.Code.BLOCK, action.block))
		EnemyActionData.IntentType.BUFF_SELF:
			ins.append_array(_build_buff_self(action))
		EnemyActionData.IntentType.DEBUFF_PLAYER:
			ins.append_array(_build_debuff_player(action))
		EnemyActionData.IntentType.SEAL_MERIDIAN:
			ins.append(_build_instruction(EffectOpcode.Code.UNLOCK_NODE, 0, {"node_arg": "block_seal"}))
		EnemyActionData.IntentType.DAMAGE_PATHWAY:
			ins.append(_build_instruction(EffectOpcode.Code.REPAIR_PATH, 0, {"repair_arg": "damage_random"}))
		EnemyActionData.IntentType.DRAIN_QI:
			ins.append_array(_build_drain_qi(action))

	return EffectProgram.from_array(ins)


# ============================================================
# 各意图类型的指令序列
# ============================================================


static func _build_attack(action: EnemyActionData) -> Array[EffectInstruction]:
	var result: Array[EffectInstruction] = []

	# 力量加成的伤害（在运行时由 EffectVM 通过 ctx.enemy 查询）
	var ins: EffectInstruction = EffectInstruction.new()
	ins.opcode = EffectOpcode.Code.DAMAGE
	ins.value = action.damage
	ins.meta["source"] = "enemy"
	result.append(ins)

	return result


static func _build_buff_self(action: EnemyActionData) -> Array[EffectInstruction]:
	var result: Array[EffectInstruction] = []
	if not action.buff_self.is_empty():
		var parts: PackedStringArray = action.buff_self.split(":")
		if parts.size() >= 2 and parts[0] == "strength":
			var ins: EffectInstruction = EffectInstruction.new()
			ins.opcode = EffectOpcode.Code.APPLY_STRENGTH
			ins.value = int(parts[1])
			result.append(ins)
	return result


static func _build_debuff_player(action: EnemyActionData) -> Array[EffectInstruction]:
	var result: Array[EffectInstruction] = []
	if not action.debuff_player.is_empty():
		var parts: PackedStringArray = action.debuff_player.split(":")
		if parts.size() >= 2:
			match parts[0]:
				"weak":
					var ins: EffectInstruction = EffectInstruction.new()
					ins.opcode = EffectOpcode.Code.APPLY_STATUS
					ins.meta["status_type"] = "debuff"
					ins.meta["name"] = "weak"
					ins.meta["subtype"] = "debuff"
					ins.value = int(parts[1])
					result.append(ins)
				"energy_down":
					var ins: EffectInstruction = EffectInstruction.new()
					ins.opcode = EffectOpcode.Code.SPEND_QI
					ins.value = int(parts[1])
					result.append(ins)
	return result


static func _build_drain_qi(action: EnemyActionData) -> Array[EffectInstruction]:
	var result: Array[EffectInstruction] = []
	var drain_amount: int = action.damage
	if drain_amount <= 0:
		drain_amount = 3
	var ins: EffectInstruction = EffectInstruction.new()
	ins.opcode = EffectOpcode.Code.SPEND_QI
	ins.value = drain_amount
	result.append(ins)
	return result


# ============================================================
# 辅助
# ============================================================


static func _build_instruction(opcode: int, value: int, meta: Dictionary = {}) -> EffectInstruction:
	var ins: EffectInstruction = EffectInstruction.new()
	ins.opcode = opcode
	ins.value = value
	ins.meta = meta.duplicate()
	return ins
