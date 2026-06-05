# ============================================================
# 大周天 — Qi Flow System (灵气流体蔓延引擎)
# ============================================================
# 连通器模型：灵气从丹田注入，穴位到传播阈值后向下一级泄漏
# 窄经=流速快/承载少，宽经=流速慢/承载多
# 回路形成后触发回灌，丹田断流后残余灵气衰减
# 冲刷目标经脉权重×4，灵气集中流向玩家选择的穴位
# technique_qi 按功法归属追踪 — 用于经脉图可视化
# ============================================================
class_name QiFlowSystem
extends RefCounted


# ============================================================
# Public API
# ============================================================


## 初始化经脉路径容量（战斗开始时调用）
## 算法: 丹田容量 × (宽度占比) × 随机扰动(0.8~1.2)
##   每条路径的容量 = dantian_capacity × (path_width / total_width) × variation
##   窄经(0.3): 容量小流速快, 宽经(2.0): 容量大流速慢
##   扰动基于 from_node/to_node 的确定性哈希，同一经脉地图每次结果一致
static func init_pathway_capacities(gm: Node) -> void:
	if gm == null or gm.base_meridian == null:
		return

	var meridian: MeridianMapData = gm.base_meridian
	var dantian_cap: float = float(gm.dantian_capacity)
	if dantian_cap <= 0:
		dantian_cap = 10.0

	# 计算总宽度
	var total_width: float = 0.0
	for pw in meridian.pathways:
		if pw == null:
			continue
		total_width += pw.width

	if total_width <= 0.0:
		return

	# 为每条路径计算容量
	for pw in meridian.pathways:
		if pw == null:
			continue
		# 宽度占比
		var share: float = pw.width / total_width
		# 确定性扰动 (基于路径端点生成 0.8~1.2 的变异)
		var seed: int = (pw.from_node * 7 + pw.to_node * 13) % 100
		var variation: float = 0.8 + float(seed) / 100.0 * 0.4
		# 基础容量 = 丹田 × 占比 × 扰动，不低于 1.0
		# 例: 丹田10, 4条等宽经脉 → 每条 ≈ 2.0~3.0, 总计 ≈ 8~12
		var base: float = dantian_cap * share * variation
		base = maxf(1.0, base)
		# 设置
		pw.base_capacity = base
		pw.max_capacity = base
		pw.capacity_bonus = 0.0  # 每场战斗重置加权

## 执行一次流体推进 tick
## 返回: {circuits_formed: Array, flow_moved: bool, is_dry: bool}
static func tick(gm: Node, flow_tracker: Dictionary = {}) -> Dictionary:
	if gm == null or gm.base_meridian == null:
		return {"circuits_formed": [], "flow_moved": false, "is_dry": true, "flow_this_tick": {}}

	var meridian: MeridianMapData = gm.base_meridian
	var result: Dictionary = {"circuits_formed": [], "flow_moved": false, "is_dry": false, "flow_this_tick": flow_tracker}

	# 1. 丹田注入灵气到相邻穴位 (含溢出冲穴)
	var inject_result: Dictionary = _inject_from_dantian(gm, meridian)
	var injected: bool = inject_result.get("injected", false)
	var overflow_unlocked: Array[String] = inject_result.get("nodes_unlocked", [])
	if not overflow_unlocked.is_empty():
		result["nodes_unlocked"] = overflow_unlocked
		result["flow_moved"] = true

	# 2. 穴位→经脉泄漏（传播阶段）
	var leaked: bool = _propagate_nodes_to_pathways(gm, meridian)

	# 3. 冲刷锁穴（在输送之前，此时 pathway 中还有灵气）
	var unlocked_nodes: Array[String] = _apply_erosion(gm, meridian)
	if not unlocked_nodes.is_empty():
		# 与溢出冲穴结果合并, 不覆盖
		var merged: Array[String] = []
		merged.append_array(overflow_unlocked)
		merged.append_array(unlocked_nodes)
		result["nodes_unlocked"] = merged
		result["flow_moved"] = true

	# 4. 经脉→目标穴位输送
	var delivered: bool = _deliver_pathways_to_nodes(gm, meridian, flow_tracker)

	result["flow_moved"] = injected or leaked or delivered or result["flow_moved"]

	# 5. 断流衰减（仅在丹田干涸且无活跃回路时；回路返回丹田使其不易干涸）
	if gm.dantian_qi <= 0:
		var has_active_circuits: bool = not gm.active_circuits.is_empty()
		if not has_active_circuits:
			var decayed: bool = _decay_residual(gm, meridian)
			result["flow_moved"] = result["flow_moved"] or decayed
		result["is_dry"] = _is_network_dry(gm, meridian)

	# 6. 回路检测
	var new_circuits: Array[Dictionary] = _detect_new_circuits(gm, meridian)
	if not new_circuits.is_empty():
		result["circuits_formed"] = new_circuits
		for circuit in new_circuits:
			_resolve_circuit_recharge(gm, meridian, circuit)

	# 7. 清理 technique_qi 中接近零的条目
	_clean_technique_qi(meridian)

	return result


## 将丹田灵气转移到相邻穴位（灵气从丹田流入经脉）
static func inject(gm: Node, amount: float) -> void:
	if gm == null or gm.base_meridian == null:
		return

	var draw: float = min(gm.dantian_qi, amount)
	gm.dantian_qi -= draw

	if draw <= 0:
		return

	var meridian: MeridianMapData = gm.base_meridian
	var dantian: MeridianNodeData = meridian.get_node(meridian.dantian_node_index)
	if dantian == null:
		gm.dantian_qi += draw
		return

	var active_neighbors: Array[int] = []
	for conn: int in dantian.connections:
		var cn: MeridianNodeData = meridian.get_node(conn)
		if cn and cn.unlocked and not cn.blocked:
			active_neighbors.append(conn)

	if active_neighbors.is_empty():
		gm.dantian_qi += draw
		return

	var per_node: float = draw / float(active_neighbors.size())
	var tech_weights: Dictionary = _calc_technique_injection_weights(gm)
	for idx: int in active_neighbors:
		var node: MeridianNodeData = meridian.nodes[idx]
		node.current_qi = min(node.capacity, node.current_qi + per_node)
		# 按功法权重分配归属
		if not tech_weights.is_empty():
			for tech_id: String in tech_weights:
				var tech_share: float = per_node * tech_weights[tech_id]
				if tech_share > 0.001:
					var existing: float = node.technique_qi.get(tech_id, 0.0)
					node.technique_qi[tech_id] = existing + tech_share


## 从经脉抽取灵气（功法出牌时调用）
static func draw_from_meridian(gm: Node, amount: float) -> float:
	if gm == null or gm.base_meridian == null:
		return 0.0

	var meridian: MeridianMapData = gm.base_meridian
	var drawn: float = 0.0

	var from_dantian: float = min(gm.dantian_qi, amount)
	gm.dantian_qi -= from_dantian
	drawn += from_dantian
	amount -= from_dantian

	if amount <= 0:
		return drawn

	var total_pathway_qi: float = 0.0
	for pw in meridian.pathways:
		total_pathway_qi += pw.current_qi

	if total_pathway_qi <= 0:
		return drawn

	for pw in meridian.pathways:
		var qi_before: float = pw.current_qi
		var share: float = amount * (pw.current_qi / total_pathway_qi)
		var taken: float = min(pw.current_qi, share)
		pw.current_qi -= taken
		drawn += taken
		# 按比例扣除功法归属
		if taken > 0 and not pw.technique_qi.is_empty():
			_decay_technique_qi(pw.technique_qi, taken, qi_before)

	var total_node_qi: float = 0.0
	for node in meridian.nodes:
		if node.current_qi > 0 and node.unlocked and not node.blocked:
			total_node_qi += node.current_qi

	if total_node_qi <= 0:
		return drawn

	var remaining: float = amount - (drawn - from_dantian)
	if remaining <= 0:
		return drawn

	for node in meridian.nodes:
		if node.current_qi <= 0 or not node.unlocked or node.blocked:
			continue
		var qi_before: float = node.current_qi
		var share: float = remaining * (node.current_qi / total_node_qi)
		var taken: float = min(node.current_qi, share)
		node.current_qi -= taken
		drawn += taken
		# 按比例扣除功法归属
		if taken > 0 and not node.technique_qi.is_empty():
			_decay_technique_qi(node.technique_qi, taken, qi_before)

	return drawn


## 获取穴位当前灵气量
static func get_node_qi(gm: Node, node_index: int) -> float:
	if gm == null or gm.base_meridian == null:
		return 0.0
	var node: MeridianNodeData = gm.base_meridian.get_node(node_index)
	if node:
		return node.current_qi
	return 0.0


## 获取路径当前灵气量
static func get_pathway_qi(gm: Node, from_idx: int, to_idx: int) -> float:
	if gm == null or gm.base_meridian == null:
		return 0.0
	for pw in gm.base_meridian.pathways:
		if (pw.from_node == from_idx and pw.to_node == to_idx) or \
		   (pw.from_node == to_idx and pw.to_node == from_idx):
			return pw.current_qi
	return 0.0


## 清除所有穴位/经脉中的灵气（回合结束后调用）
static func clear_flow_state(gm: Node) -> void:
	if gm == null or gm.base_meridian == null:
		return
	for node in gm.base_meridian.nodes:
		node.current_qi = 0.0
		node.technique_qi = {}
	for pw in gm.base_meridian.pathways:
		pw.current_qi = 0.0
		pw.technique_qi = {}


## 检测当前所有回路（委托给 CircuitDetector）
static func detect_circuits(gm: Node) -> Array[Dictionary]:
	if gm == null or gm.base_meridian == null:
		return []
	return CircuitDetector.find_circuits(gm.base_meridian)


# ============================================================
# Internal: Injection
# ============================================================

static func _inject_from_dantian(gm: Node, meridian: MeridianMapData) -> Dictionary:
	## 丹田溢出冲穴阈值: 灵气超过此比例时超出部分直接冲刷锁穴
	const OVERFLOW_RATIO: float = 0.8

	if gm.dantian_qi <= 0:
		return {"injected": false, "nodes_unlocked": []}

	var dantian_idx: int = meridian.dantian_node_index
	var dantian: MeridianNodeData = meridian.get_node(dantian_idx)
	if dantian == null:
		return {"injected": false, "nodes_unlocked": []}

	# === 丹田溢出冲穴: 灵气超过 80% 容量时, 超出部分直接冲刷锁穴 ===
	var erosion_targets: Array = gm.get("erosion_targets")
	if erosion_targets == null:
		erosion_targets = []
	var overflow_threshold: int = int(float(gm.dantian_capacity) * OVERFLOW_RATIO)
	var overflow_unlocked: Array[String] = []
	if gm.dantian_qi > overflow_threshold and not erosion_targets.is_empty():
		var overflow: float = float(gm.dantian_qi - overflow_threshold)
		# 溢出灵气从丹田扣除, 直接推进 erosion_progress
		gm.dantian_qi -= int(overflow)
		overflow_unlocked = _apply_overflow_erosion(gm, meridian, overflow, erosion_targets)

	# 收集丹田邻接穴位（已解锁且未阻塞的活路径）
	var active_neighbors: Array[int] = []
	for conn: int in dantian.connections:
		var cn: MeridianNodeData = meridian.get_node(conn)
		if cn and cn.unlocked and not cn.blocked:
			active_neighbors.append(conn)

	if active_neighbors.is_empty():
		return {"injected": false, "nodes_unlocked": overflow_unlocked}

	var inject_total: float = min(gm.dantian_qi, gm.dantian_pressure * 1.0)
	if inject_total <= 0:
		return {"injected": false, "nodes_unlocked": overflow_unlocked}

	gm.dantian_qi -= inject_total

	# === 按功法路径绑定分配注入 ===
	var tech_weights: Dictionary = _calc_technique_injection_weights(gm)
	var technique_pathways: Dictionary = gm.get("technique_pathways")
	if technique_pathways == null:
		technique_pathways = {}

	var injected: bool = false
	var allocated_qi: float = 0.0
	var unbound_weight: float = 0.0  # 未绑定功法的总权重

	if not tech_weights.is_empty():
		# 第一轮：有路径绑定的功法 → 只注入到绑定起点对应的路径
		for tech_id: String in tech_weights:
			var binding: Dictionary = technique_pathways.get(tech_id, {})
			var start_node: int = binding.get("from", -1)
			if start_node < 0 or not (start_node in active_neighbors):
				# 无绑定或起点不可达 → 累积到未绑定权重
				unbound_weight += tech_weights[tech_id]
				continue

			var pw: MeridianPathwayData = _find_pathway(meridian, dantian_idx, start_node)
			if pw == null or pw.blocked:
				unbound_weight += tech_weights[tech_id]
				continue

			var tech_share: float = inject_total * tech_weights[tech_id]
			# 冲刷目标加权
			if start_node in erosion_targets:
				tech_share *= 4.0
			var space: float = (pw.max_capacity + pw.capacity_bonus) - pw.current_qi
			var capped: float = min(tech_share, max(0.0, space))
			if capped > 0.001:
				pw.current_qi += capped
				pw.technique_qi[tech_id] = pw.technique_qi.get(tech_id, 0.0) + capped
				allocated_qi += tech_share  # 按原始份额计数（防止超额）
				injected = true

	# 第二轮：未绑定功法 + 无路径的权重 → 按旧逻辑分配到所有邻接路径
	var remaining: float = inject_total - allocated_qi
	if remaining > 0.001:
		# 计算所有邻接路径的权重分配
		var total_weight: float = 0.0
		for idx: int in active_neighbors:
			var pw: MeridianPathwayData = _find_pathway(meridian, dantian_idx, idx)
			if pw and not pw.blocked:
				var w: float = pw.width
				if idx in erosion_targets:
					w *= 4.0
				total_weight += w

		if total_weight > 0:
			for idx: int in active_neighbors:
				var pw: MeridianPathwayData = _find_pathway(meridian, dantian_idx, idx)
				if pw == null or pw.blocked:
					continue
				var w: float = pw.width
				if idx in erosion_targets:
					w *= 4.0
				var share: float = remaining * (w / total_weight)
				var space: float = (pw.max_capacity + pw.capacity_bonus) - pw.current_qi
				var capped_share: float = min(share, max(0.0, space))
				pw.current_qi += capped_share
				# 未绑定功法的 qi 按权重分配
				if capped_share > 0 and unbound_weight > 0:
					for tech_id: String in tech_weights:
						var binding: Dictionary = technique_pathways.get(tech_id, {})
						if binding.get("from", -1) >= 0:
							continue  # 已绑定的跳过
						var tech_share: float = capped_share * tech_weights[tech_id]
						if tech_share > 0.001:
							pw.technique_qi[tech_id] = pw.technique_qi.get(tech_id, 0.0) + tech_share
				injected = true

	return {"injected": injected, "nodes_unlocked": overflow_unlocked}


# ============================================================
# Internal: Propagation (Node → Pathway)
# ============================================================

static func _propagate_nodes_to_pathways(gm: Node, meridian: MeridianMapData) -> bool:
	var propagated: bool = false

	for i: int in meridian.nodes.size():
		var node: MeridianNodeData = meridian.nodes[i]
		if node == null or not node.unlocked or node.blocked:
			continue
		if node.current_qi <= 0:
			continue

		var threshold_qi: float = node.capacity * node.spread_threshold
		if node.current_qi < threshold_qi:
			continue

		var source_qi_before: float = node.current_qi
		var overflow: float = source_qi_before - threshold_qi
		node.current_qi = threshold_qi

		var active_connections: Array[int] = []
		for conn: int in node.connections:
			var cn: MeridianNodeData = meridian.get_node(conn)
			if cn and not cn.blocked:
				var pw: MeridianPathwayData = _find_pathway(meridian, i, conn)
				if pw and not pw.blocked:
					active_connections.append(conn)

		if active_connections.is_empty():
			node.current_qi += overflow
			continue

		var total_weight: float = 0.0
		for conn: int in active_connections:
			var pw: MeridianPathwayData = _find_pathway(meridian, i, conn)
			total_weight += pw.width

		for conn: int in active_connections:
			var pw: MeridianPathwayData = _find_pathway(meridian, i, conn)
			var share: float = overflow * (pw.width / total_weight)
			var space: float = (pw.max_capacity + pw.capacity_bonus) - pw.current_qi
			var add: float = min(share, max(0.0, space))
			pw.current_qi += add
			# 按比例转移功法归属
			if add > 0 and not node.technique_qi.is_empty():
				_transfer_technique_qi(node.technique_qi, pw.technique_qi, add, source_qi_before)
			if add > 0:
				propagated = true

	return propagated


# ============================================================
# Internal: Delivery (Pathway → Node)
# ============================================================

static func _deliver_pathways_to_nodes(gm: Node, meridian: MeridianMapData, flow_tracker: Dictionary = {}) -> bool:
	var delivered: bool = false
	var dantian_idx: int = meridian.dantian_node_index

	for pw in meridian.pathways:
		if pw == null or pw.current_qi <= 0 or pw.blocked or pw.damaged:
			continue

		var flow_rate: float = gm.dantian_pressure / max(0.2, pw.width)
		var transfer: float = min(pw.current_qi, flow_rate)

		if transfer <= 0:
			continue

		var target: MeridianNodeData = meridian.get_node(pw.to_node)
		if target == null or not target.unlocked or target.blocked:
			continue

		var space: float = target.capacity - target.current_qi
		var actual: float = min(transfer, max(0.0, space))
		if actual <= 0:
			continue

		var pw_qi_before: float = pw.current_qi
		pw.current_qi -= actual

		# 回路返回：若目标为丹田节点，灵气返回丹田池
		if pw.to_node == dantian_idx:
			var dantian_space: float = float(gm.dantian_capacity - gm.dantian_qi)
			var return_amount: float = min(actual, dantian_space)
			gm.dantian_qi += int(return_amount)
			# 超出丹田容量的部分进入节点
			var excess: float = actual - return_amount
			if excess > 0.0:
				target.current_qi = min(target.capacity, target.current_qi + excess)
				# 记录流经量用于 buff 生成
				flow_tracker[pw.to_node] = flow_tracker.get(pw.to_node, 0.0) + excess
				if not pw.technique_qi.is_empty():
					_transfer_technique_qi(pw.technique_qi, target.technique_qi, excess, pw_qi_before)
		else:
			target.current_qi = min(target.capacity, target.current_qi + actual)
			# 记录流经量用于 buff 生成
			flow_tracker[pw.to_node] = flow_tracker.get(pw.to_node, 0.0) + actual
			# 按比例转移功法归属
			if actual > 0 and not pw.technique_qi.is_empty():
				_transfer_technique_qi(pw.technique_qi, target.technique_qi, actual, pw_qi_before)
		delivered = true

	return delivered


# ============================================================
# Internal: Erosion (灵气冲刷锁穴)
# ============================================================

## 对玩家标记的锁穴施加冲刷（由 gm.erosion_targets 控制）
## 冲刷完成穴位解锁后自动从目标列表中移除
## 冲刷速率 = pathway.current_qi x (1.0 / width) x 3.0
static func _apply_erosion(gm: Node, meridian: MeridianMapData) -> Array[String]:
	var unlocked: Array[String] = []
	var targets: Array = gm.get("erosion_targets")
	if targets == null or targets.is_empty():
		return unlocked

	for target_idx in targets:
		var target: MeridianNodeData = meridian.get_node(target_idx)
		if target == null or target.unlocked or target.blocked:
			continue

		var total_erosion: float = 0.0
		for pw in meridian.pathways:
			if pw == null or pw.current_qi <= 0.01 or pw.blocked or pw.damaged:
				continue

			var connects_target: bool = (pw.from_node == target_idx or pw.to_node == target_idx)
			if not connects_target:
				continue

			var other_idx: int = pw.to_node if pw.from_node == target_idx else pw.from_node
			var other: MeridianNodeData = meridian.get_node(other_idx)
			if other == null or not other.unlocked:
				continue

			var erosion_rate: float = pw.current_qi * (1.0 / max(0.2, pw.width)) * 3.0
			var applied: float = min(pw.current_qi, erosion_rate)
			var pw_qi_before: float = pw.current_qi
			pw.current_qi -= applied
			total_erosion += applied
			# 按比例扣除功法归属
			if applied > 0 and not pw.technique_qi.is_empty():
				_decay_technique_qi(pw.technique_qi, applied, pw_qi_before)

		if total_erosion <= 0:
			continue

		target.erosion_progress += total_erosion
		if target.erosion_progress >= target.erosion_threshold:
			if gm.has_method("unlock_meridian_node"):
				gm.unlock_meridian_node(target.name)
			else:
				target.unlocked = true
			target.erosion_progress = target.erosion_threshold
			unlocked.append(target.name)
			gm.erosion_targets.erase(target_idx)
			if gm.has_signal("erosion_targets_changed"):
				gm.erosion_targets_changed.emit()

	return unlocked


## 丹田溢出冲穴: 丹田灵气超过 80% 容量时, 超出部分直接分配给锁穴目标
## overflow: 超出 80% 阈值的灵气量 (已从 dantian_qi 中扣除)
## 分配权重: 每个冲穴目标按其连通路径的总宽度占所有目标的比例分配
static func _apply_overflow_erosion(gm: Node, meridian: MeridianMapData, overflow: float, targets: Array) -> Array[String]:
	var unlocked: Array[String] = []
	if overflow <= 0.0 or targets.is_empty():
		return unlocked

	# 计算每个冲穴目标的权重 (连通路径宽度总和)
	var weights: Dictionary = {}  # {target_idx: total_width}
	var total_weight: float = 0.0
	for target_idx in targets:
		var target: MeridianNodeData = meridian.get_node(target_idx)
		if target == null or target.unlocked or target.blocked:
			continue
		var w: float = 0.0
		for pw in meridian.pathways:
			if pw == null or pw.blocked or pw.damaged:
				continue
			var connects: bool = (pw.from_node == target_idx or pw.to_node == target_idx)
			if not connects:
				continue
			var other_idx: int = pw.to_node if pw.from_node == target_idx else pw.from_node
			var other: MeridianNodeData = meridian.get_node(other_idx)
			if other == null or not other.unlocked:
				continue
			w += pw.width
		if w > 0.0:
			weights[target_idx] = w
			total_weight += w

	if total_weight <= 0.0:
		return unlocked

	# 按权重分配溢出灵气, 直接推进 erosion_progress
	for target_idx in weights:
		var share: float = overflow * (weights[target_idx] / total_weight)
		var target: MeridianNodeData = meridian.get_node(target_idx)
		if target == null:
			continue
		target.erosion_progress += share
		# 检查是否达到解锁阈值
		if target.erosion_progress >= target.erosion_threshold:
			if gm.has_method("unlock_meridian_node"):
				gm.unlock_meridian_node(target.name)
			else:
				target.unlocked = true
			target.erosion_progress = target.erosion_threshold
			gm.erosion_targets.erase(target_idx)
			if gm.has_signal("erosion_targets_changed"):
				gm.erosion_targets_changed.emit()
			unlocked.append(target.name)

	return unlocked


# ============================================================
# Internal: Dry / Decay
# ============================================================

static func _decay_residual(gm: Node, meridian: MeridianMapData) -> bool:
	var decayed: bool = false
	var decay_rate: float = 0.15

	var protected_nodes: Array[int] = []
	for circuit in gm.active_circuits:
		var nodes: Array = circuit.get("nodes", [])
		for n in nodes:
			if n is int:
				protected_nodes.append(n)

	for i: int in meridian.nodes.size():
		if i in protected_nodes:
			continue
		var node: MeridianNodeData = meridian.nodes[i]
		if node and node.current_qi > 0:
			var qi_before: float = node.current_qi
			var loss: float = node.current_qi * decay_rate
			node.current_qi = max(0.0, node.current_qi - loss)
			if loss > 0 and not node.technique_qi.is_empty():
				_decay_technique_qi(node.technique_qi, loss, qi_before)
			decayed = true

	for pw in meridian.pathways:
		if pw.current_qi > 0:
			var qi_before: float = pw.current_qi
			var loss: float = pw.current_qi * decay_rate * 2.0
			pw.current_qi = max(0.0, pw.current_qi - loss)
			if loss > 0 and not pw.technique_qi.is_empty():
				_decay_technique_qi(pw.technique_qi, loss, qi_before)
			decayed = true

	return decayed


static func _is_network_dry(gm: Node, meridian: MeridianMapData) -> bool:
	if gm.dantian_qi > 0:
		return false
	for node in meridian.nodes:
		if node.current_qi > 0.01:
			return false
	for pw in meridian.pathways:
		if pw.current_qi > 0.01:
			return false
	return true


# ============================================================
# Internal: Circuit Detection & Recharge
# ============================================================

static func _detect_new_circuits(gm: Node, meridian: MeridianMapData) -> Array[Dictionary]:
	var all_circuits: Array[Dictionary] = CircuitDetector.find_circuits(meridian)
	var new_circuits: Array[Dictionary] = []

	var known_keys: Dictionary = {}
	for c in gm.active_circuits:
		var key: String = _circuit_key(c)
		known_keys[key] = true

	for c in all_circuits:
		var key: String = _circuit_key(c)
		if not known_keys.has(key):
			if _is_circuit_charged(c, meridian):
				new_circuits.append(c)
				gm.active_circuits.append(c)

	return new_circuits


static func _resolve_circuit_recharge(gm: Node, meridian: MeridianMapData, circuit: Dictionary) -> void:
	"""回路形成 → 丹田沿回路把未满穴位灌满"""
	var nodes: Array = circuit.get("nodes", [])
	if nodes.is_empty():
		return

	var total_width: float = 0.0
	var pw_count: int = 0
	for i: int in nodes.size():
		var from_idx: int = nodes[i]
		var to_idx: int = nodes[(i + 1) % nodes.size()]
		var pw: MeridianPathwayData = _find_pathway(meridian, from_idx, to_idx)
		if pw:
			total_width += pw.width
			pw_count += 1

	var avg_width: float = total_width / max(1, pw_count)
	var recharge_power: float = gm.dantian_pressure * avg_width * 0.5
	# 从丹田抽取灵气（灵气守恒），不凭空生成
	var draw: float = min(float(gm.dantian_qi), recharge_power)
	gm.dantian_qi -= int(draw)
	if draw <= 0.0:
		return

	# 收集回路中各功法的已有归属权重
	var circuit_tech_weights: Dictionary = {}
	for i: int in nodes.size():
		var idx: int = nodes[i]
		if idx == meridian.dantian_node_index:
			continue
		var cn: MeridianNodeData = meridian.get_node(idx)
		if cn and not cn.technique_qi.is_empty():
			for tech_id: String in cn.technique_qi:
				circuit_tech_weights[tech_id] = circuit_tech_weights.get(tech_id, 0.0) + cn.technique_qi[tech_id]

	for i: int in nodes.size():
		var idx: int = nodes[i]
		if idx == meridian.dantian_node_index:
			continue
		var node: MeridianNodeData = meridian.get_node(idx)
		if node == null:
			continue
		var deficit: float = node.capacity - node.current_qi
		if deficit > 0:
			var fill: float = min(deficit, draw)
			node.current_qi += fill
			# 按回路已有归属权重分配
			_attribute_circuit_fill(node, fill, circuit_tech_weights, gm)
			draw -= fill
			if draw <= 0:
				break


static func _is_circuit_charged(circuit: Dictionary, meridian: MeridianMapData) -> bool:
	var nodes: Array = circuit.get("nodes", [])
	for idx in nodes:
		if idx == meridian.dantian_node_index:
			continue
		var node: MeridianNodeData = meridian.get_node(idx)
		if node == null:
			return false
		var threshold: float = node.capacity * node.spread_threshold
		if node.current_qi < threshold:
			return false
	return true


static func _circuit_key(circuit: Dictionary) -> String:
	var nodes = circuit.get("nodes", [])
	return CircuitDetector.normalize_circuit_key(nodes)


# ============================================================
# Internal: Helpers
# ============================================================

static func _find_pathway(meridian: MeridianMapData, from_idx: int, to_idx: int) -> MeridianPathwayData:
	return meridian.find_pathway(from_idx, to_idx)


## 计算各活跃功法从丹田注入灵气的权重（按 pressure_mod 归一化）
static func _calc_technique_injection_weights(gm: Node) -> Dictionary:
	var weights: Dictionary = {}
	var techniques: Array = gm.get("active_techniques")
	if techniques == null or techniques.is_empty():
		return weights
	var total_weight: float = 0.0
	for tech in techniques:
		var w: float = tech.get("pressure_mod")
		if w <= 0:
			w = 1.0
		weights[tech.get("id")] = w
		total_weight += w
	if total_weight <= 0.0:
		return {}
	# 归一化
	for tech_id in weights:
		weights[tech_id] = weights[tech_id] / total_weight
	return weights


## 清理 technique_qi 字典中接近零的条目，防止字典膨胀
static func _clean_technique_qi(meridian: MeridianMapData) -> void:
	var threshold: float = 0.001
	for node in meridian.nodes:
		var to_remove: Array[String] = []
		for k: String in node.technique_qi:
			if node.technique_qi[k] <= threshold:
				to_remove.append(k)
		for k: String in to_remove:
			node.technique_qi.erase(k)
	for pw in meridian.pathways:
		var to_remove: Array[String] = []
		for k: String in pw.technique_qi:
			if pw.technique_qi[k] <= threshold:
				to_remove.append(k)
		for k: String in to_remove:
			pw.technique_qi.erase(k)


## 按比例从源 technique_qi 转移灵气到目标 technique_qi
static func _transfer_technique_qi(
	src_tech_qi: Dictionary,
	dst_tech_qi: Dictionary,
	amount_moved: float,
	source_qi_before: float
) -> void:
	if amount_moved <= 0.0 or source_qi_before <= 0.001 or src_tech_qi.is_empty():
		return
	for tech_id: String in src_tech_qi:
		var src_amount: float = src_tech_qi[tech_id]
		if src_amount <= 0.001:
			continue
		var proportion: float = src_amount / source_qi_before
		var transfer: float = amount_moved * proportion
		src_tech_qi[tech_id] = max(0.0, src_amount - transfer)
		dst_tech_qi[tech_id] = dst_tech_qi.get(tech_id, 0.0) + transfer


## 按比例从 technique_qi 中扣除灵气（无目标，纯消耗）
static func _decay_technique_qi(tech_qi: Dictionary, amount: float, qi_before: float) -> void:
	if amount <= 0.0 or qi_before <= 0.001 or tech_qi.is_empty():
		return
	for tech_id: String in tech_qi:
		var src_amount: float = tech_qi[tech_id]
		if src_amount <= 0.001:
			continue
		var proportion: float = src_amount / qi_before
		var deduction: float = amount * proportion
		tech_qi[tech_id] = max(0.0, src_amount - deduction)


## 为回路回灌分配功法归属
static func _attribute_circuit_fill(node: MeridianNodeData, fill: float, circuit_tech_weights: Dictionary, gm: Node) -> void:
	if fill <= 0:
		return
	if circuit_tech_weights.is_empty():
		# 无已有归属 → 均匀分配给活跃功法
		var techniques: Array = gm.get("active_techniques")
		if techniques != null and not techniques.is_empty():
			var per_tech: float = fill / float(techniques.size())
			for tech in techniques:
				var tid: String = tech.get("id")
				node.technique_qi[tid] = node.technique_qi.get(tid, 0.0) + per_tech
		return

	var total_weight: float = 0.0
	for v in circuit_tech_weights.values():
		total_weight += v
	if total_weight > 0.0:
		for tech_id: String in circuit_tech_weights:
			var share: float = fill * (circuit_tech_weights[tech_id] / total_weight)
			node.technique_qi[tech_id] = node.technique_qi.get(tech_id, 0.0) + share
