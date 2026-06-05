# ============================================================
# 大周天 — EffectCompiler
# 卡牌效果编译器 — EffectNode (AST) → EffectProgram (Bytecode)
#
# 职责:
#   1. 遍历 EffectNode 数组，为每个节点生成 EffectInstruction
#   2. opcode 解析: 优先使用 node.opcode，为 0 时通过 node.type 字符串推导
#   3. 状态效果展开: burn/vulnerable/weak/stun → APPLY_STATUS + meta["status_type"]
#   4. 返回不可变的 EffectProgram 供 EffectVM 执行
#
# 这是从"数据驱动执行"到"编译器驱动卡牌系统"的关键转换点。
# ============================================================
class_name EffectCompiler
extends RefCounted


## 从 EffectNode 数组编译为 EffectProgram
static func compile(nodes: Array[EffectNode]) -> EffectProgram:
	var instructions: Array[EffectInstruction] = []
	for node: EffectNode in nodes:
		var ins: EffectInstruction = compile_node(node)
		instructions.append(ins)
	return EffectProgram.from_array(instructions)


## 从 EffectGraph 编译为 EffectProgram
static func compile_graph(graph: EffectGraph) -> EffectProgram:
	return compile(graph.nodes)


## 编译单个 EffectNode → EffectInstruction（v3.0: 按 opcode 创建子类实例）
static func compile_node(node: EffectNode) -> EffectInstruction:
	var opcode: int = node.opcode if node.opcode != 0 else EffectOpcode.from_type(node.type)
	var ins: EffectInstruction

	# 按 opcode 创建对应子类实例
	match opcode:
		EffectOpcode.Code.DAMAGE:
			ins = OpDamage.new()
		EffectOpcode.Code.BLOCK:
			ins = OpBlock.new()
		EffectOpcode.Code.HEAL:
			ins = OpHeal.new()
		EffectOpcode.Code.DRAW:
			ins = OpDraw.new()
		EffectOpcode.Code.APPLY_STATUS:
			ins = OpApplyStatus.new()
		EffectOpcode.Code.QI_GATHER:
			ins = OpQiGather.new()
		EffectOpcode.Code.SPEND_QI:
			ins = OpSpendQi.new()
		_:
			# 未创建子类的 opcode: 使用基类（兜底到 EffectVM 静态 match）
			ins = EffectInstruction.new()

	# 填充字段
	ins.opcode = opcode
	ins.value = node.value
	ins.meta = node.meta.duplicate()
	ins.selector = node.selector.duplicate()
	if node.target:
		ins.target = node.target.duplicate_spec()

	# 状态效果展开: 将原始 type 字符串注入 meta["status_type"]
	if ins.opcode == EffectOpcode.Code.APPLY_STATUS:
		if not ins.meta.has("status_type"):
			# 从 type 字符串推导具体状态类型
			match node.type:
				"burn", "vulnerable", "weak", "stun":
					ins.meta["status_type"] = node.type
					if not ins.meta.has("turns"):
						ins.meta["turns"] = 2
				"buff":
					ins.meta["status_type"] = "buff"
					if not ins.meta.has("turns"):
						ins.meta["turns"] = 1
				"debuff":
					ins.meta["status_type"] = "debuff"
					if not ins.meta.has("turns"):
						ins.meta["turns"] = 1
				"cleanse":
					ins.meta["status_type"] = "cleanse"
				_:
					ins.meta["status_type"] = node.type

	return ins


## 从 CardData.base_effects 编译 (便捷方法)
static func compile_from_card(card: CardData) -> EffectProgram:
	return compile(card.base_effects)


## 编译触发器效果图 — 返回 Dictionary{String: EffectProgram}
static func compile_triggers(trigger_effects: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in trigger_effects:
		var effects: Array = trigger_effects[key]
		if not effects.is_empty():
			result[key] = compile(effects)
	return result


## 编译前在 AST 上应用全部修正 (Resolver Steps 2-5 合并到这里)
## out_node_order: 输出参数 — 编译后最终的节点 ID 列表，调用方用于同步 ExecutionPlan
## 注意: GDScript 默认数组参数在每次调用时共享，调用方必须传入新数组
static func compile_with_mods(
	nodes: Array[EffectNode],
	instance_mods: Array = [],
	run_mods: Array = [],
	battle_mods: Array = [],
	temp_mods: Array = [],
	out_node_order: Array = []
) -> EffectProgram:
	var graph: EffectGraph = EffectGraph.from_array(nodes)
	if not instance_mods.is_empty():
		EffectOperator.apply_all(graph, instance_mods)
	if not run_mods.is_empty():
		EffectOperator.apply_all(graph, run_mods)
	if not battle_mods.is_empty():
		EffectOperator.apply_all(graph, battle_mods)
	if not temp_mods.is_empty():
		EffectOperator.apply_all(graph, temp_mods)
	# 收集编译后最终的节点 ID 顺序（用于同步 ExecutionPlan）
	for node: EffectNode in graph.nodes:
		out_node_order.append(node.id)
	return compile_graph(graph)
