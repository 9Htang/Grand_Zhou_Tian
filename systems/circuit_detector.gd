# ============================================================
# 大周天 — Circuit Detector (图论回路检测)
# ============================================================
# 以丹田为起终点的简单环检测（Hamiltonian-like 约束）
# 简单环: 起点=终点=丹田，中间节点不重复
# ============================================================
class_name CircuitDetector
extends RefCounted


## 找以丹田为起终点的所有简单环
## 返回: [{nodes: [0,1,5,2], pathways: [{from,to},...], length: int}]
static func find_circuits(meridian: MeridianMapData) -> Array[Dictionary]:
	return _find_circuits_impl(meridian)


## 判断某穴位是否在任意回路中
static func is_node_in_circuit(meridian: MeridianMapData, node_idx: int) -> bool:
	var circuits: Array = find_circuits(meridian)
	for c in circuits:
		var nodes: Array = c.get("nodes", [])
		if node_idx in nodes:
			return true
	return false


## 获取节点参与的所有回路
static func get_node_circuits(meridian: MeridianMapData, node_idx: int) -> Array[Dictionary]:
	var circuits: Array = find_circuits(meridian)
	var result: Array[Dictionary] = []
	for c in circuits:
		var nodes: Array = c.get("nodes", [])
		if node_idx in nodes:
			result.append(c)
	return result


# ============================================================
# Internal
# ============================================================

static func _find_circuits_impl(meridian: MeridianMapData) -> Array[Dictionary]:
	var circuits: Array[Dictionary] = []
	if meridian == null or meridian.nodes.is_empty():
		return circuits

	var dantian_idx: int = meridian.dantian_node_index
	var dantian_node: MeridianNodeData = meridian.get_node(dantian_idx)
	if dantian_node == null:
		return circuits

	# 用于去重：记录已找到的回路（标准化key）
	var seen: Dictionary = {}

	# DFS 从丹田的每个邻居出发
	for start_neighbor: int in dantian_node.connections:
		var sn: MeridianNodeData = meridian.get_node(start_neighbor)
		if sn == null or not sn.unlocked or sn.blocked:
			continue

		var visited: Array[int] = [dantian_idx]
		var path: Array[int] = [start_neighbor]
		var dfs_visited: Array[int] = []
		dfs_visited.append_array(visited)
		dfs_visited.append(start_neighbor)
		_dfs(meridian, dantian_idx, start_neighbor, dfs_visited, path, circuits, seen)

	return circuits


static func _dfs(
	meridian: MeridianMapData,
	dantian_idx: int,
	current: int,
	visited: Array[int],
	path: Array[int],
	circuits: Array[Dictionary],
	seen: Dictionary
) -> void:
	var node: MeridianNodeData = meridian.get_node(current)
	if node == null:
		return

	for neighbor: int in node.connections:
		# 回到丹田 → 形成回路（需至少2个中间节点）
		if neighbor == dantian_idx and path.size() >= 2:
			var circuit_nodes: Array[int] = [dantian_idx]
			circuit_nodes.append_array(path)
			var circuit_key: String = normalize_circuit_key(circuit_nodes)
			if not seen.has(circuit_key):
				seen[circuit_key] = true
				circuits.append(_build_circuit_dict(meridian, circuit_nodes))
			continue

		# 跳过已访问且非丹田的节点
		if neighbor in visited:
			continue

		var nn: MeridianNodeData = meridian.get_node(neighbor)
		if nn == null or not nn.unlocked or nn.blocked:
			continue

		# 继续 DFS
		visited.append(neighbor)
		path.append(neighbor)
		_dfs(meridian, dantian_idx, neighbor, visited, path, circuits, seen)
		path.pop_back()
		visited.erase(neighbor)


static func _build_circuit_dict(meridian: MeridianMapData, nodes: Array[int]) -> Dictionary:
	var pathways: Array[Dictionary] = []
	for i: int in nodes.size():
		var from_idx: int = nodes[i]
		var to_idx: int = nodes[(i + 1) % nodes.size()]
		pathways.append({"from": from_idx, "to": to_idx})

	# 统计元素构成
	var element_count: Dictionary = {}
	for idx in nodes:
		var n: MeridianNodeData = meridian.get_node(idx)
		if n and not n.element.is_empty():
			var el: String = n.element
			element_count[el] = element_count.get(el, 0) + 1

	return {
		"nodes": nodes,
		"pathways": pathways,
		"length": nodes.size(),
		"element_count": element_count,
	}


## 标准化回路key用于去重（忽略起点和方向）
static func normalize_circuit_key(nodes: Array) -> String:
	# nodes: [0, 1, 5, 2] → 标准化为最小字典序
	# 确保所有元素为 int
	var clean: Array[int] = []
	for x in nodes:
		clean.append(int(x))
	var n: int = clean.size()
	if n <= 1:
		return ""

	# 去掉首尾的 dantian（如果存在）
	var core: Array[int] = []
	core.append_array(clean)
	if core.size() > 1 and core[0] == core[core.size() - 1]:
		core.pop_back()

	# 找最小元素的位置
	var min_val: int = core[0]
	var min_idx: int = 0
	for i: int in core.size():
		if core[i] < min_val:
			min_val = core[i]
			min_idx = i

	# 从最小位置正向
	var forward: String = ""
	for i: int in core.size():
		forward += str(core[(min_idx + i) % core.size()]) + ","

	# 从最小位置反向
	var reversed_core: Array[int] = []
	for i: int in core.size():
		reversed_core.append(core[(min_idx - i + core.size()) % core.size()])

	var backward: String = ""
	for v in reversed_core:
		backward += str(v) + ","

	# 返回字典序较小的
	if forward < backward:
		return forward
	return backward
