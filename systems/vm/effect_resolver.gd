# ============================================================
# 大周天 — EffectResolver
# 字符串 DSL 解析器 — 唯一职责：解析 "cmd:arg1:arg2:..."
# 所有执行逻辑已迁移至 EffectVM → GameAPI
#
# 这是旧字符串 DSL 的兼容层。新卡牌应使用 EffectNode AST。
# ============================================================
class_name EffectResolver
extends RefCounted


## 解析并执行单条效果字符串
## 格式: "cmd:arg1:arg2:..."
## 例: "heal:5" / "damage:3" / "buff:attack_up:3:2" / "gain_artifact:random"
static func apply(gm: Node, effect: String) -> void:
	if effect.is_empty():
		return
	var parts: PackedStringArray = effect.split(":")
	if parts.is_empty():
		return
	var cmd: String = parts[0]
	var args: PackedStringArray = []
	for i in range(1, parts.size()):
		args.append(parts[i])

	var opcode: int = EffectOpcode.from_string_cmd(cmd)
	if opcode < 0:
		printerr("EffectResolver: unknown command '", cmd, "' in effect '", effect, "'")
		return

	# 构建 EffectInstruction → 创建 EffectContext → 委托 EffectVM
	var ins: EffectInstruction = _build_instruction(opcode, cmd, args)
	var ectx: EffectContext = EffectContext.new()
	ectx.init_map(gm)
	EffectVM.execute_instruction(ins, ectx)


## 批量解析并执行
static func apply_all(gm: Node, effects: Array[String]) -> void:
	for e in effects:
		apply(gm, e)


# ============================================================
# Internal — 字符串 → EffectInstruction
# ============================================================


static func _build_instruction(opcode: int, cmd: String, args: PackedStringArray) -> EffectInstruction:
	var ins: EffectInstruction = EffectInstruction.new()
	ins.opcode = opcode

	match opcode:
		EffectOpcode.Code.HEAL:
			ins.value = _arg_int(args, 0, 0)

		EffectOpcode.Code.BLOCK:
			ins.value = _arg_int(args, 0, 1)

		EffectOpcode.Code.MAX_HP_UP:
			ins.value = _arg_int(args, 0, 0)

		EffectOpcode.Code.QI_RESTORE, EffectOpcode.Code.SPEND_QI:
			ins.value = _arg_int(args, 0, 0)

		EffectOpcode.Code.DANTIAN_UP:
			ins.value = _arg_int(args, 0, 0)

		EffectOpcode.Code.GATHER_UP:
			ins.value = _arg_int(args, 0, 0)

		EffectOpcode.Code.TALENT_UP:
			ins.value = _arg_int(args, 0, 0)

		EffectOpcode.Code.SELF_DAMAGE:
			ins.value = _arg_int(args, 0, 0)

		EffectOpcode.Code.GOLD:
			ins.value = _arg_int(args, 0, 0)

		EffectOpcode.Code.UNLOCK_NODE:
			ins.meta["node_arg"] = args[0] if args.size() > 0 else "random"

		EffectOpcode.Code.REPAIR_PATH:
			var rarg: String = args[0] if args.size() > 0 else ""
			if cmd == "repair_all":
				ins.meta["repair_arg"] = "all"
			elif rarg == "random":
				ins.meta["repair_arg"] = "random"
			else:
				ins.meta["repair_arg"] = rarg

		EffectOpcode.Code.GAIN_CARD:
			ins.meta["card_id"] = args[0] if args.size() > 0 else ""

		EffectOpcode.Code.REMOVE_CARD:
			ins.meta["card_id"] = args[0] if args.size() > 0 else "random"

		EffectOpcode.Code.UPGRADE_CARD:
			ins.meta["card_id"] = args[0] if args.size() > 0 else "random"

		EffectOpcode.Code.TRANSFORM_CARD:
			pass  # 无参数

		EffectOpcode.Code.DUPLICATE_CARD:
			pass  # 无参数

		EffectOpcode.Code.GAIN_ARTIFACT:
			ins.meta["artifact_id"] = args[0] if args.size() > 0 else "random"

		EffectOpcode.Code.APPLY_STATUS:
			_build_status_instruction(ins, cmd, args)

		EffectOpcode.Code.DRAW:
			ins.value = _arg_int(args, 0, 1)

		EffectOpcode.Code.CLEANSE_ALL:
			pass  # 无参数

		EffectOpcode.Code.DAMAGE:
			# 地图上下文中 "damage" 映射为 SELF_DAMAGE
			# 如果直接 opcode 是 DAMAGE 则说明是通过其他路径到达
			ins.opcode = EffectOpcode.Code.SELF_DAMAGE
			ins.value = _arg_int(args, 0, 0)

	return ins


## 构建状态效果的 EffectInstruction
## 处理: buff/debuff/attack_up/defense_up/burn/draw_card
static func _build_status_instruction(ins: EffectInstruction, cmd: String, args: PackedStringArray) -> void:
	match cmd:
		"buff":
			if args.size() >= 2:
				ins.meta["status_type"] = "buff"
				ins.meta["name"] = args[0]
				ins.value = int(args[1])
				ins.meta["turns"] = int(args[2]) if args.size() >= 3 else 0

		"debuff":
			ins.meta["status_type"] = "debuff"
			ins.meta["subtype"] = "debuff"
			ins.meta["name"] = args[0] if args.size() > 0 else ""
			ins.value = _arg_int(args, 1, 1)

		"attack_up":
			ins.meta["status_type"] = "buff"
			ins.meta["name"] = "attack_up"
			ins.value = _arg_int(args, 0, 1)

		"defense_up":
			ins.meta["status_type"] = "buff"
			ins.meta["name"] = "defense_up"
			ins.value = _arg_int(args, 0, 1)

		"burn":
			ins.meta["status_type"] = "burn"
			ins.meta["subtype"] = "burn"
			ins.value = _arg_int(args, 0, 1)

		"draw_card":
			ins.meta["status_type"] = "draw"
			ins.value = _arg_int(args, 0, 1)

		"energy_up":
			ins.opcode = EffectOpcode.Code.QI_RESTORE
			ins.value = _arg_int(args, 0, 0)

		"energy_down":
			ins.opcode = EffectOpcode.Code.SPEND_QI
			ins.value = _arg_int(args, 0, 0)

		_:
			# 未知状态命令 → 保持 APPLY_STATUS
			ins.meta["status_type"] = cmd
			ins.value = _arg_int(args, 0, 1)


static func _arg_int(args: PackedStringArray, index: int, default: int) -> int:
	if index < args.size():
		return int(args[index])
	return default
