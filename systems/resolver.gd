# ============================================================
# 大周天 — Resolver
# 唯一卡牌效果执行器 — 固定 8 步流水线
#
# 1. validate graph      — 校验 EffectGraph 完整性
# 2. apply instance mods — CardInstance 升级修正
# 3. apply run mods      — 法宝/穴位/功法修正
# 4. apply battle mods   — buff/debuff 修正
# 5. apply operators     — swap/remove/transform...
# 6. build plan          — 构建 ExecutionPlan
# 7. execute effects     — 逐节点 dispatch
# 8. produce result      — 返回 BattleResult
# ============================================================
class_name Resolver
extends RefCounted


# ============================================================
# 主入口
# ============================================================


## 执行完整 8 步流水线
static func resolve(card: CardRuntime, context: BattleContext) -> BattleResult:
	var result: BattleResult = BattleResult.new()

	# Step 1: 校验
	if card.effect_graph.is_empty():
		result.executed = false
		result.failure_reason = "empty graph"
		result.add_trace("Step1: empty graph — abort")
		return result
	result.add_trace("Step1: graph with %d nodes valid" % card.effect_graph.size())

	# Step 2: 应用 Instance 升级修正
	_apply_instance_mods(card, context, result)

	# Step 3: 应用 RunModifier
	_apply_run_mods(card, context, result)

	# Step 4: 应用 BattleModifier
	_apply_battle_mods(card, context, result)

	# Step 5: 应用 Operators
	_apply_operators(card, context, result)

	# Step 6: 构建 ExecutionPlan
	_plan(card, result)

	# Step 7: 执行效果
	_execute(card, context, result)

	# Step 8: 产出
	result.executed = true
	result.add_trace("Step8: resolve complete — dmg=%d block=%d heal=%d" % [result.damage_dealt, result.block_gained, result.heal_done])
	return result


# ============================================================
# Step 2: Instance Mods
# ============================================================


static func _apply_instance_mods(card: CardRuntime, context: BattleContext, result: BattleResult) -> void:
	if card.instance == null:
		return
	var inst: CardInstance = card.instance
	var data: CardData = card.base_data
	if data == null:
		return

	var level: int = inst.upgrade_level
	if level <= 0:
		return

	# 线性升级: 按 per_upgrade × level 叠加到所有 node
	var ops: Array = []
	if data.damage_per_upgrade != 0:
		ops.append(EffectOperator.select_by_type("damage"))
		ops.append(EffectOperator.modify_value("damage", data.damage_per_upgrade * level))
	if data.block_per_upgrade != 0:
		ops.append(EffectOperator.select_by_type("block"))
		ops.append(EffectOperator.modify_value("block", data.block_per_upgrade * level))
	if data.heal_per_upgrade != 0:
		ops.append(EffectOperator.select_by_type("heal"))
		ops.append(EffectOperator.modify_value("heal", data.heal_per_upgrade * level))
	if data.cost_reduce_per_upgrade != 0:
		# cost 修正由 get_effective_cost() 处理，这里记录
		pass

	EffectOperator.apply_all(card.effect_graph, ops)
	result.add_trace("Step2: applied upgrade L%d — +dam%d +blk%d +heal%d" % [level, data.damage_per_upgrade * level, data.block_per_upgrade * level, data.heal_per_upgrade * level])


# ============================================================
# Step 3: Run Modifiers
# ============================================================


static func _apply_run_mods(card: CardRuntime, context: BattleContext, result: BattleResult) -> void:
	if context.run_modifiers.is_empty():
		return
	EffectOperator.apply_all(card.effect_graph, context.run_modifiers)
	result.add_trace("Step3: applied %d run modifiers" % context.run_modifiers.size())


# ============================================================
# Step 4: Battle Modifiers
# ============================================================


static func _apply_battle_mods(card: CardRuntime, context: BattleContext, result: BattleResult) -> void:
	if context.battle_modifiers.is_empty():
		return
	EffectOperator.apply_all(card.effect_graph, context.battle_modifiers)
	result.add_trace("Step4: applied %d battle modifiers" % context.battle_modifiers.size())


# ============================================================
# Step 5: Operators
# ============================================================


static func _apply_operators(card: CardRuntime, context: BattleContext, result: BattleResult) -> void:
	if card.temp_modifiers.is_empty():
		return
	EffectOperator.apply_all(card.effect_graph, card.temp_modifiers)
	result.add_trace("Step5: applied %d operators" % card.temp_modifiers.size())


# ============================================================
# Step 6: Build Execution Plan
# ============================================================


static func _plan(card: CardRuntime, result: BattleResult) -> void:
	card.rebuild_plan()
	result.add_trace("Step6: execution plan — %s" % str(card.execution_plan.order))


# ============================================================
# Step 7: Execute Effects
# ============================================================


static func _execute(card: CardRuntime, context: BattleContext, result: BattleResult) -> void:
	var plan: ExecutionPlan = card.execution_plan
	if plan.order.is_empty():
		return

	for node_id: String in plan.order:
		var node: EffectNode = card.effect_graph.get_node(node_id)
		if node == null:
			result.add_trace("Step7: node %s not found — skip" % node_id)
			continue
		_dispatch(node, context, result)
		result.add_trace("Step7: executed %s(%s)=%d" % [node.type, node.id, node.value])


# ============================================================
# Dispatch — 效果分发
# ============================================================


static func _dispatch(node: EffectNode, context: BattleContext, result: BattleResult) -> void:
	match node.type:
		"damage":
			# 伤害 = 基础值 (后续由 DamageCalculation 修正)
			var dmg: int = node.value
			if context.opponent and context.opponent.has_method("take_damage"):
				context.opponent.take_damage(dmg)
			result.damage_dealt += dmg

		"block":
			var blk: int = node.value
			if context.actor and context.actor.get("current_block") != null:
				context.actor.current_block += blk
			result.block_gained += blk

		"heal":
			var heal: int = node.value
			if context.actor and context.actor.has_method("heal"):
				context.actor.heal(heal)
			result.heal_done += heal

		"draw":
			var draw: int = node.value
			if context.actor and context.actor.has_method("draw_cards"):
				context.actor.draw_cards(draw)
			result.cards_drawn += draw

		"qi_gather":
			result.qi_gathered += node.value

		"burn", "vulnerable", "weak", "stun":
			var status: Dictionary = {
				"type": node.type,
				"value": node.value,
				"turns": node.meta.get("turns", 2)
			}
			result.status_applied.append(status)

		"buff":
			var name: String = node.meta.get("name", "")
			if not name.is_empty():
				result.status_applied.append({
					"type": "buff",
					"name": name,
					"value": node.value,
					"turns": node.meta.get("turns", 1)
				})

		"debuff":
			var name: String = node.meta.get("name", "")
			if not name.is_empty():
				result.status_applied.append({
					"type": "debuff",
					"name": name,
					"value": node.value,
					"turns": node.meta.get("turns", 1)
				})

		"cleanse":
			# 清负面效果 — 由上层 battle_screen 处理
			result.status_applied.append({
				"type": "cleanse",
				"count": node.value
			})

		_:
			result.add_trace("Step7: unknown type '%s' — skip" % node.type)
