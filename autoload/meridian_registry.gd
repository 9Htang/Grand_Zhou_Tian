extends Node

var _cache: Dictionary = {}
var _all_ids: Array[String] = []


func _ready() -> void:
	_create_defaults()
	_load_all()


func _create_defaults() -> void:
	# ============================================================
	# 放射式经脉图 — 丹田居中，穴位环形展开
	# ============================================================
	# 布局: Center(R=0) → Ring1(R=1-4) → Ring2(R=5-8)
	#
	#         [百会](5:土)
	#        /    |    \
	#  [玉枕](8:金) | [夹脊](6:木)
	#       \   |   /
	#  [膻中](4:金)─[丹田](0)─[命门](2:火)
	#       /   |   \
	#  [会阴](7:水) | [神阙](1:土)
	#        \   |   /
	#         [气海](3:水)
	#
	# 初始只解锁丹田；点击相邻已解锁穴位的节点解锁

	var _new_node = func(nm: String, el: String, x: float, y: float, conns: Array, ul: bool = false) -> MeridianNodeData:
		var nd := MeridianNodeData.new()
		nd.name = nm; nd.element = el
		nd.position = Vector2(x, y)
		nd.connections = conns
		nd.unlocked = ul
		return nd

	# --- Small Circuit (简化版，兼容旧ID) ---
	var sc := MeridianMapData.new()
	sc.id = "small_circuit"
	sc.display_name = "小周天经脉"
	sc.is_circular = false
	sc.dantian_node_index = 0

	sc.nodes = [
		_new_node.call("丹田", "", 0.50, 0.50, [1, 2, 3, 4], true),     # 0: center
		_new_node.call("神阙", "土", 0.50, 0.28, [0, 2, 4, 5]),          # 1: top
		_new_node.call("命门", "火", 0.72, 0.50, [0, 1, 3, 5, 6]),       # 2: right
		_new_node.call("气海", "水", 0.50, 0.72, [0, 2, 4, 6, 7]),       # 3: bottom
		_new_node.call("膻中", "金", 0.28, 0.50, [0, 1, 3, 7, 8]),       # 4: left
		_new_node.call("百会", "土", 0.77, 0.23, [1, 2, 6, 8]),          # 5: ring2 top-right
		_new_node.call("夹脊", "木", 0.77, 0.77, [2, 3, 5, 7]),          # 6: ring2 bottom-right
		_new_node.call("会阴", "水", 0.23, 0.77, [3, 4, 6, 8]),          # 7: ring2 bottom-left
		_new_node.call("玉枕", "金", 0.23, 0.23, [4, 1, 5, 7]),          # 8: ring2 top-left
	]
	# 冲刷阈值：一环近丹田(30)，二环远端(60)，丹田已解锁设999
	sc.nodes[0].erosion_threshold = 999.0
	for _ri in range(1, 5):
		sc.nodes[_ri].erosion_threshold = 30.0
	for _ri in range(5, 9):
		sc.nodes[_ri].erosion_threshold = 60.0
	sc.pathways = _make_pathways(sc.nodes)
	_cache["small_circuit"] = sc
	_all_ids.append("small_circuit")

	# --- Grand Circuit (完整版，兼容旧ID) ---
	var gc := MeridianMapData.new()
	gc.id = "grand_circuit"
	gc.display_name = "大周天经脉"
	gc.is_circular = true
	gc.dantian_node_index = 0
	# Same layout, but all nodes start unlocked for grand circuit
	gc.nodes = [
		_new_node.call("丹田", "", 0.50, 0.50, [1, 2, 3, 4], true),
		_new_node.call("神阙", "土", 0.50, 0.28, [0, 2, 4, 5], true),
		_new_node.call("命门", "火", 0.72, 0.50, [0, 1, 3, 5, 6], true),
		_new_node.call("气海", "水", 0.50, 0.72, [0, 2, 4, 6, 7], true),
		_new_node.call("膻中", "金", 0.28, 0.50, [0, 1, 3, 7, 8], true),
		_new_node.call("百会", "土", 0.77, 0.23, [1, 2, 6, 8], true),
		_new_node.call("夹脊", "木", 0.77, 0.77, [2, 3, 5, 7], true),
		_new_node.call("会阴", "水", 0.23, 0.77, [3, 4, 6, 8], true),
		_new_node.call("玉枕", "金", 0.23, 0.23, [4, 1, 5, 7], true),
	]
	# 冲刷阈值（大周天全解锁，但仍赋阈值兼容未来锁定场景）
	gc.nodes[0].erosion_threshold = 999.0
	for _ri in range(1, 5):
		gc.nodes[_ri].erosion_threshold = 30.0
	for _ri in range(5, 9):
		gc.nodes[_ri].erosion_threshold = 60.0
	gc.pathways = _make_pathways(gc.nodes)
	_cache["grand_circuit"] = gc
	_all_ids.append("grand_circuit")


func _make_pathways(nodes: Array[MeridianNodeData]) -> Array[MeridianPathwayData]:
	var result: Array[MeridianPathwayData] = []
	var seen: Dictionary = {}

	# Width map: (min_idx, max_idx) → width
	var width_map := {
		"(0,1)": 1.0, "(0,2)": 1.5, "(0,3)": 1.0, "(0,4)": 0.6,
		"(1,2)": 1.2, "(1,4)": 0.8, "(1,5)": 0.7, "(1,8)": 1.1,
		"(2,3)": 1.3, "(2,5)": 1.4, "(2,6)": 1.0,
		"(3,4)": 0.9, "(3,6)": 1.2, "(3,7)": 0.8,
		"(4,7)": 1.0, "(4,8)": 0.5,
		"(5,6)": 1.4, "(5,8)": 0.5,
		"(6,7)": 1.0, "(7,8)": 1.3,
	}

	for i: int in nodes.size():
		for conn: int in nodes[i].connections:
			# Deduplicate: only one pathway per undirected edge
			var a: int = min(i, conn)
			var b: int = max(i, conn)
			var key: String = str(a) + "→" + str(b)
			if seen.has(key):
				continue
			seen[key] = true

			var pw := MeridianPathwayData.new()
			pw.from_node = i
			pw.to_node = conn
			pw.damaged = false
			# Assign width from map, capacity proportional to width
			var wkey: String = "(%d,%d)" % [a, b]
			pw.width = width_map.get(wkey, 1.0)
			pw.max_capacity = 5.0 * pw.width
			pw.current_qi = 0.0
			pw.blocked = false
			result.append(pw)
	return result


func _load_all() -> void:
	var dir: String = "res://resources/meridian_map_data/"
	var dir_access: DirAccess = DirAccess.open(dir)
	if dir_access == null:
		return
	dir_access.list_dir_begin()
	var file_name: String = dir_access.get_next()
	while file_name != "":
		if not dir_access.current_is_dir() and file_name.ends_with(".tres"):
			# Skip if already created by _create_defaults()
			var base_id: String = file_name.replace(".tres", "")
			if not _cache.has(base_id):
				var mm: MeridianMapData = load(dir + file_name)
				if mm and not mm.id.is_empty():
					_cache[mm.id] = mm
					_all_ids.append(mm.id)
		file_name = dir_access.get_next()
	dir_access.list_dir_end()


func get_meridian(id: String) -> MeridianMapData:
	return _cache.get(id)


func get_all_meridians() -> Array[MeridianMapData]:
	var result: Array[MeridianMapData] = []
	for v in _cache.values():
		result.append(v)
	return result


func get_all_ids() -> Array[String]:
	return _all_ids.duplicate()
