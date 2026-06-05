# ============================================================
# 大周天 — EffectVM
# 确定性执行内核 — 游戏唯一效果执行器
#
# 职责 (仅 3 项):
#   1. 读 EffectInstruction
#   2. 通过 EffectContext 调领域服务
#   3. 控制执行流 (jump / if / repeat)
#
# 红线 (永久禁止):
#   ❌ 访问 ctx.actor / ctx.battle_ctx 的任何属性或方法
#   ❌ 查系统 (CardDatabase / MeridianRegistry / DeckManager)
#   ❌ 规则判断 (hp < 50% / has_buff / pathway_exists)
#   ❌ 解析 selector / target
#
# 架构:
#   EffectProgram → EffectVM → EffectContext → Domain Services → Runtime State
# ============================================================
class_name EffectVM
extends RefCounted


## 执行完整 EffectProgram
static func execute(program: EffectProgram, ctx: EffectContext) -> void:
	var ip: int = 0
	while ip < program.instructions.size():
		var ins: EffectInstruction = program.instructions[ip]
		execute_instruction(ins, ctx)
		ip += 1
		if ins.jump >= 0:
			ip = ins.jump


## v3.0: 指令对象化执行 — 每个指令自己负责 execute + trace + emit event
## 与 execute() 的区别: 指令通过自己的 execute(ctx) 方法执行，
## 自动触发 _before / _do_execute / _after 钩子。
static func execute_instructions(program: EffectProgram, ctx: EffectContext) -> void:
	var ip: int = 0
	while ip < program.instructions.size():
		var ins: EffectInstruction = program.instructions[ip]
		ctx.current_ip = ip
		ins.execute(ctx)  # 指令自己负责全部行为（含 trace/event/rng）
		ip += 1
		if ins.jump >= 0:
			ip = ins.jump


## 执行单条指令 — 唯一入口，战斗/地图统一
static func execute_instruction(ins: EffectInstruction, ctx: EffectContext) -> void:
	match ins.opcode:
		EffectOpcode.Code.DAMAGE:
			print("[EffectVM.DAMAGE] value=%d targets=%d primary=%s" % [ins.value, ctx.targets.size(), ctx.primary_target])
			if not ctx.targets.is_empty():
				for target in ctx.targets:
					print("[EffectVM.DAMAGE] → %s hp=%d" % [target.get("display_name") if target.get("display_name") != null else "?", target.get("hp") if target.get("hp") != null else -1])
					ctx.combat.damage_to(ins.value, target)
			elif ctx.primary_target:
				ctx.combat.damage_to(ins.value, ctx.primary_target)

		EffectOpcode.Code.BLOCK:
			ctx.combat.add_block(ins.value)

		EffectOpcode.Code.HEAL:
			ctx.combat.heal_actor(ins.value)

		EffectOpcode.Code.DRAW:
			ctx.combat.draw_cards(ins.value)

		EffectOpcode.Code.APPLY_STATUS:
			_exec_apply_status(ins, ctx)

		EffectOpcode.Code.QI_GATHER:
			ctx.qi.gather_qi(ins.value)

		EffectOpcode.Code.QI_RESTORE:
			ctx.qi.add_qi(ins.value)

		EffectOpcode.Code.SPEND_QI:
			ctx.qi.spend_qi(ins.value)

		EffectOpcode.Code.DANTIAN_UP:
			ctx.meridian.increase_dantian(ins.value)

		EffectOpcode.Code.PATHWAY_UP:
			_exec_pathway_up(ins, ctx)

		EffectOpcode.Code.MAX_HP_UP:
			ctx.combat.increase_max_hp(ins.value)

		EffectOpcode.Code.GATHER_UP:
			ctx.qi.add_gather_bonus(ins.value)

		EffectOpcode.Code.TALENT_UP:
			ctx.progression.increase_talent(ins.value)
			ctx.trace("TALENT_UP +%d" % ins.value)

		EffectOpcode.Code.SELF_DAMAGE:
			ctx.combat.damage_actor(ins.value)

		EffectOpcode.Code.UNLOCK_NODE:
			ctx.meridian.unlock_node(ins.meta.get("node_arg", "random"))

		EffectOpcode.Code.REPAIR_PATH:
			ctx.meridian.repair_pathway(ins.meta.get("repair_arg", ""))

		EffectOpcode.Code.GAIN_CARD:
			ctx.deck.gain_card(ins.meta.get("card_id", ""))

		EffectOpcode.Code.REMOVE_CARD:
			ctx.deck.remove_card(ins.meta.get("card_id", "random"))

		EffectOpcode.Code.UPGRADE_CARD:
			ctx.deck.upgrade_card(ins.meta.get("card_id", "random"))

		EffectOpcode.Code.TRANSFORM_CARD:
			ctx.deck.transform_random()

		EffectOpcode.Code.DUPLICATE_CARD:
			ctx.deck.duplicate_random()

		EffectOpcode.Code.GAIN_ARTIFACT:
			ctx.artifact.gain_artifact(ins.meta.get("artifact_id", "random"))

		EffectOpcode.Code.GOLD:
			ctx.progression.add_gold(ins.value)
			ctx.trace("GOLD +%d" % ins.value)

		EffectOpcode.Code.CLEANSE_ALL:
			ctx.status.cleanse_all()

		EffectOpcode.Code.JUMP_IF:
			# 条件跳转: meta["condition"] 非空且满足时设置 jump
			# 由 execute() 循环处理 ip = ins.jump
			pass

		EffectOpcode.Code.APPLY_STRENGTH:
			if ctx.primary_target:
				var current: int = ctx.primary_target.get("strength") if ctx.primary_target.get("strength") != null else 0
				ctx.primary_target.set("strength", current + ins.value)
				ctx.trace("APPLY_STRENGTH +%d" % ins.value)

		EffectOpcode.Code.SET_ENEMY_HP:
			if ctx.primary_target:
				ctx.primary_target.set("hp", max(0, ins.value))
				ctx.trace("SET_ENEMY_HP %d" % ins.value)

		_:
			ctx.trace("EffectVM: unknown opcode %d — skip" % ins.opcode)


# ============================================================
# Internal — 需要遍历 meta 的 opcode
# ============================================================


static func _exec_apply_status(ins: EffectInstruction, ctx: EffectContext) -> void:
	var status_type: String = ins.meta.get("status_type", "")
	var turns: int = ins.meta.get("turns", 2)
	var status_name: String = ins.meta.get("name", "")
	var subtype: String = ins.meta.get("subtype", "")

	match status_type:
		"burn", "vulnerable", "weak", "stun":
			if ctx.is_battle():
				ctx.status.apply_battle_status(status_type, ins.value, turns)
			else:
				ctx.status.add_pending(status_type, "", ins.value)

		"buff":
			if ctx.is_battle():
				ctx.status.apply_buff(status_name, ins.value, turns)
			else:
				ctx.status.add_permanent_buff(status_name, ins.value, turns)

		"debuff":
			if ctx.is_battle():
				ctx.status.apply_debuff(status_name, ins.value, turns)
			else:
				ctx.status.add_pending("debuff", status_name, ins.value)

		"cleanse":
			if ctx.is_battle():
				ctx.status.apply_cleanse(ins.value)

		_:
			if subtype == "burn":
				ctx.status.add_pending("burn", "", ins.value)
			elif subtype == "debuff":
				ctx.status.add_pending("debuff", status_name, ins.value)
			elif subtype == "buff":
				ctx.status.add_permanent_buff(status_name, ins.value, turns)
			else:
				ctx.trace("EffectVM: APPLY_STATUS unknown subtype '%s' — skip" % status_type)


static func _exec_pathway_up(ins: EffectInstruction, ctx: EffectContext) -> void:
	var selected: Array = ins.meta.get("selected", [])
	if selected.is_empty():
		ctx.trace("EffectVM: PATHWAY_UP — no pathway selected, skip")
		return

	for target: Dictionary in selected:
		var from_idx: int = target.get("from", -1)
		var to_idx: int = target.get("to", -1)
		if from_idx < 0 or to_idx < 0:
			continue
		ctx.meridian.modify_pathway(from_idx, to_idx, ins.value)
