# ============================================================
# 大周天 — Resolver
# 纯调度器 — Graph → Operator → Plan → Compile → VM
#
# 职责:
#   1. validate — 校验 EffectGraph 完整性
#   2. compile — 应用全部修正 + 构建执行计划 + 编译为字节码
#   3. step — 单步执行 EffectProgram 指令（通过 EffectVM）
#   4. result — 返回 BattleResult
#
# 修正应用已迁移至 EffectCompiler.compile_with_mods()
# ============================================================
class_name Resolver
extends RefCounted


## 执行完整流水线（无 selector 时一键执行）
static func resolve(card: CardRuntime, context: BattleContext) -> BattleResult:
	begin(card, context)

	var max_steps: int = card.execution_plan.order.size()
	for _i in range(max_steps):
		var result: BattleResult = step(card, context)
		if result.completed or result.waiting:
			return result

	var final_result: BattleResult = BattleResult.new()
	final_result.completed = true
	final_result.executed = true
	return final_result


## 初始化：编译 EffectGraph → EffectProgram
static func begin(card: CardRuntime, context: BattleContext) -> BattleResult:
	var result: BattleResult = BattleResult.new()

	# Step 1: 校验
	if card.effect_graph.is_empty():
		result.executed = false
		result.failure_reason = "empty graph"
		result.add_trace("Resolver: empty graph — abort")
		return result
	result.add_trace("Resolver: graph with %d nodes valid" % card.effect_graph.size())

	# Step 2: 构建执行计划
	card.rebuild_plan()

	# Step 3: 按计划顺序收集节点
	var ordered_nodes: Array[EffectNode] = []
	for node_id: String in card.execution_plan.order:
		var node: EffectNode = card.effect_graph.get_node(node_id)
		if node:
			ordered_nodes.append(node)

	# Step 4: 编译（含修正应用 — instance/run/battle/temp modifiers）
	var instance_mods: Array = []
	if card.instance and card.base_data:
		var level: int = card.instance.upgrade_level
		var operator_levels: Array = card.base_data.upgrade_operators
		for i: int in range(min(level, operator_levels.size())):
			var level_ops: Array = operator_levels[i]
			if not level_ops.is_empty():
				instance_mods.append_array(level_ops)

	var effective_node_order: Array[String] = []
	card.effect_program = EffectCompiler.compile_with_mods(
		ordered_nodes,
		instance_mods,
		context.run_modifiers,
		context.battle_modifiers,
		card.temp_modifiers,
		effective_node_order
	)
	# 修正可能添加/删除节点 → 用编译后节点 ID 重建计划，确保 plan.order.size() == program.size()
	card.execution_plan = ExecutionPlan.from_node_ids(effective_node_order)
	result.add_trace("Resolver: plan=%s → compiled %d instructions" % [str(card.execution_plan.order), card.effect_program.size()])

	# 重置执行游标
	card.step_pc = 0
	card.selected_targets.clear()

	result.executed = true
	return result


## 单步执行一条指令
## completed: 所有指令已执行完毕
## waiting: 遇到 selector 需要玩家选择目标
static func step(card: CardRuntime, context: BattleContext) -> BattleResult:
	var result: BattleResult = BattleResult.new()
	var plan: ExecutionPlan = card.execution_plan
	var program: EffectProgram = card.effect_program

	if program == null or program.is_empty() or card.step_pc >= program.size() or card.step_pc >= plan.order.size():
		result.completed = true
		result.executed = true
		result.add_trace("Resolver: complete — dmg=%d block=%d heal=%d" % [result.damage_dealt, result.block_gained, result.heal_done])
		return result

	var node_id: String = plan.order[card.step_pc]
	var ins: EffectInstruction = program.instructions[card.step_pc]
	if ins == null:
		result.add_trace("Resolver: instruction at pc=%d not found — skip" % card.step_pc)
		card.step_pc += 1
		result.completed = card.step_pc >= program.size()
		return result

	# 检查是否需要目标选择（优先使用 TargetSpec）
	var needs_sel: bool = (ins.target != null and ins.target.needs_selection()) or not ins.selector.is_empty()
	print("[Resolver.step] op=%s needs_sel=%s target_type=%d selector=%s" % [EffectOpcode.name_of(ins.opcode), needs_sel, ins.target.type if ins.target else -1, ins.selector])
	if needs_sel:
		if card.selected_targets.has(node_id):
			print("[Resolver.step] has selected targets for %s: %s" % [node_id, card.selected_targets[node_id]])
			ins.meta["selected"] = card.selected_targets[node_id]
			var targets: Array[Node] = _extract_selected_targets(ins.meta["selected"])
			print("[Resolver.step] extracted targets: %d nodes" % targets.size())
			var primary: Node = targets[0] if not targets.is_empty() else null
			var ectx: EffectContext = EffectContext.new()
			ectx.init_battle(context.actor, primary, targets, context, result)
			###
			if context.event_stream:
				ectx.events = context.event_stream
				ectx.current_tick = context.current_tick
			EffectVM.execute_instruction(ins, ectx)
			result.add_trace("Resolver: executed %s(%s)=%d (with selection)" % [EffectOpcode.name_of(ins.opcode), node_id, ins.value])
			card.step_pc += 1
			result.completed = card.step_pc >= program.size()
			return result

		# 无目标 → 请求选择
		result.waiting = true
		result.selector = ins.selector.duplicate() if not ins.selector.is_empty() else {"type": "enemy", "count": ins.target.count if ins.target else 1}
		result.add_trace("Resolver: awaiting selection for %s — target=%d" % [node_id, ins.target.type if ins.target else -1])
		print("[Resolver.step] waiting — selector=%s" % result.selector)
		return result

	# 无需选择 → 直接解析目标并执行
	var targets: Array[Node] = TargetResolver.resolve(ins.target, context)
	print("[Resolver.step] direct execute — targets=%d" % targets.size())
	# 如果 TargetResolver 返回空（如 SELF 但 actor=null），回退到旧逻辑
	if targets.is_empty() and ins.target == null:
		targets = _resolve_targets_fallback(context)
	var primary: Node = targets[0] if not targets.is_empty() else null
	var ectx: EffectContext = EffectContext.new()
	ectx.init_battle(context.actor, primary, targets, context, result)
	if context.event_stream:
		ectx.events = context.event_stream
		ectx.current_tick = context.current_tick
	EffectVM.execute_instruction(ins, ectx)
	result.add_trace("Resolver: executed %s(%s)=%d" % [EffectOpcode.name_of(ins.opcode), node_id, ins.value])
	card.step_pc += 1
	result.completed = card.step_pc >= program.size()
	return result


# ============================================================
# Internal
# ============================================================


## 从 selected 数组提取 Node 列表 — [{actor: Node}, ...] → [Node]
static func _extract_selected_targets(selected: Array) -> Array[Node]:
	var out: Array[Node] = []
	for entry in selected:
		var actor: Node = entry.get("actor") if typeof(entry) == TYPE_DICTIONARY else entry
		if actor:
			out.append(actor)
	return out


## Fallback: 所有存活敌人（TargetSpec 未设置时使用）
static func _resolve_targets_fallback(context: BattleContext) -> Array[Node]:
	var enemies: Array[Node] = []
	for e in context.enemies:
		if e and e.get("hp") != null and e.hp > 0:
			enemies.append(e)
	return enemies
