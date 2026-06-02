# ============================================================
# 大周天 — Meridian View (经脉图可视化 — 功法分色 + 生克效果)
# ============================================================
# 灵气水流动画、穴位填充度、回路高亮、断流警告
# 出牌阶段点击锁穴标记冲刷目标、穴位解锁扩散光晕
# 锁穴冲刷进度百分比直接显示在圆圈内
# technique_qi 按功法归属 — 三层粒子模型:
#   Layer1 (50%): 各功法独立色粒子
#   Layer2 (30%): 融合色粒子 (Color.lerp)
#   Layer3 (20%): 生克效果粒子 (金色相生/暗红相克)
# ============================================================
extends Control

signal node_clicked(index: int, node: MeridianNodeData)
signal node_double_clicked(index: int, node: MeridianNodeData)

# Double-tap detection
var _last_tap_idx: int = -1
var _last_tap_time: int = 0
var _tap_sequence: int = 0

var _meridian: MeridianMapData
var _node_radius: float = 14.0
var _center_radius: float = 20.0
var _font_size: int = 10
var _progress_font_size: int = 12

# Element -> color mapping (unused now, kept for reference)
const ELEMENT_COLORS := {
	"火": Color(0.9, 0.3, 0.2),
	"水": Color(0.2, 0.4, 0.9),
	"木": Color(0.2, 0.8, 0.3),
	"金": Color(0.9, 0.8, 0.2),
	"土": Color(0.8, 0.6, 0.3),
	"":  Color(1.0, 1.0, 1.0),
}

# Flow animation
var _flow_particles: Array[Dictionary] = []
var _spark_particles: Array[Dictionary] = []    # 相克火花
var _glow_particles: Array[Dictionary] = []     # 相生光点
var _particle_count_per_pathway: int = 4
var _circuit_pathway_keys: Array[String] = []
var _is_dry: bool = false
var _erosion_targets: Array[int] = []
var _max_targets: int = 0

# Unlock animation: {node_index: start_time_ms}
var _unlock_anims: Dictionary = {}
const UNLOCK_ANIM_DURATION_MS: int = 800

# Per-technique visualization
var _technique_colors: Dictionary = {}           # {technique_id: Color}
var _collision_boost_nodes: Dictionary = {}       # {node_idx: float} 相生
var _collision_dampen_nodes: Dictionary = {}      # {node_idx: float} 相克
var _collision_damaged_pathways: Dictionary = {}  # {"from->to": true} 相克受损
var _intersection_nodes: Array[int] = []          # 中性交汇穴位
var _frontier_nodes: Array[int] = []              # 断流前沿


func set_meridian(m: MeridianMapData) -> void:
	_meridian = m
	queue_redraw()


func set_circuit_pathways(keys: Array[String]) -> void:
	_circuit_pathway_keys = keys
	queue_redraw()


func set_dry(dry: bool) -> void:
	_is_dry = dry
	queue_redraw()


func set_erosion_targets(targets: Array[int]) -> void:
	_erosion_targets = targets
	queue_redraw()


func set_max_targets(max_count: int) -> void:
	_max_targets = max_count
	queue_redraw()


func set_technique_colors(colors: Dictionary) -> void:
	_technique_colors = colors
	queue_redraw()


## 接收碰撞数据用于生克可视化
func set_collision_data(collision) -> void:
	_collision_boost_nodes.clear()
	_collision_dampen_nodes.clear()
	_collision_damaged_pathways.clear()
	if collision == null:
		queue_redraw()
		return

	# qi_boost: {node_idx: float} — 相生穴位
	var boost: Dictionary = collision.qi_boost
	if not boost.is_empty():
		for key in boost:
			_collision_boost_nodes[int(key)] = boost[key]

	# qi_dampen: {node_idx: float} — 相克穴位
	var dampen: Dictionary = collision.qi_dampen
	if not dampen.is_empty():
		for key in dampen:
			_collision_dampen_nodes[int(key)] = dampen[key]

	# damaged_pathways: [{from, to, turns}] — 相克受损经脉
	var damaged: Array = collision.damaged_pathways
	for dmg in damaged:
		var a: int = min(dmg.get("from", -1), dmg.get("to", -1))
		var b: int = max(dmg.get("from", -1), dmg.get("to", -1))
		if a >= 0 and b >= 0:
			_collision_damaged_pathways[str(a) + "->" + str(b)] = true

	queue_redraw()


func notify_node_unlocked(node_index: int) -> void:
	_unlock_anims[node_index] = Time.get_ticks_msec()
	queue_redraw()


func _process(delta: float) -> void:
	if _meridian == null:
		return

	var needs_redraw: bool = false
	var now: int = Time.get_ticks_msec()

	# Clean up expired unlock animations
	var expired: Array[int] = []
	for idx in _unlock_anims:
		if now - _unlock_anims[idx] > UNLOCK_ANIM_DURATION_MS:
			expired.append(idx)
	if not expired.is_empty():
		for idx in expired:
			_unlock_anims.erase(idx)
		needs_redraw = true

	# Compute intersection, frontier, and collision info
	_compute_overlay_state()

	# Generate flow particles (three-layer model)
	var new_flow: Array[Dictionary] = []
	var new_spark: Array[Dictionary] = []
	var new_glow: Array[Dictionary] = []

	for pw_idx: int in _meridian.pathways.size():
		var pw: MeridianPathwayData = _meridian.pathways[pw_idx]
		if pw == null or pw.current_qi <= 0.01 or pw.damaged or pw.blocked:
			continue

		var speed: float = 1.0 / max(0.2, pw.width) * 0.3
		var qi_ratio: float = clamp(pw.current_qi / max(1.0, pw.max_capacity), 0.0, 1.0)
		var base_count: int = max(1, int(ceil(_particle_count_per_pathway * qi_ratio)))

		# Determine technique IDs active on this pathway
		var active_techs: Array[String] = []
		if not pw.technique_qi.is_empty():
			for tid: String in pw.technique_qi:
				if pw.technique_qi[tid] > 0.01:
					active_techs.append(tid)

		var is_intersection: bool = active_techs.size() > 1
		var pw_key: String = _make_pw_key(pw.from_node, pw.to_node)
		var is_damaged_path: bool = _collision_damaged_pathways.has(pw_key)

		if is_intersection:
			# === Three-layer particle model ===
			var total_particles: int = base_count * 3
			var color_a: Color = _get_tech_color(active_techs[0])
			var color_b: Color = _get_tech_color(active_techs[1])
			var blend_color: Color = color_a.lerp(color_b, 0.5)

			# Determine sheng-ke for Layer3
			var shengke_color: Color = Color(1, 1, 1, 0.0)  # default: no effect
			var is_sheng: bool = false
			var is_ke: bool = false
			# Check connected nodes for collision data
			var fn: int = pw.from_node
			var tn: int = pw.to_node
			if _collision_dampen_nodes.has(fn) or _collision_dampen_nodes.has(tn):
				is_ke = true
				shengke_color = Color(0.9, 0.1, 0.05)  # 暗红相克
			elif _collision_boost_nodes.has(fn) or _collision_boost_nodes.has(tn):
				is_sheng = true
				shengke_color = Color(1, 0.75, 0.1)  # 金色相生

			for p: int in total_particles:
				var t: float = fmod(float(p) / float(total_particles) + _get_particle_phase(pw_idx, p) + speed * delta, 1.0)
				var layer: int = p % 3
				match layer:
					0:  # Layer1: 各功法独立色
						var tech_id: String = active_techs[p % active_techs.size()]
						new_flow.append({"pw_idx": pw_idx, "t": t, "qi_ratio": qi_ratio, "technique_id": tech_id, "blend": false})
					1:  # Layer2: 融合色
						new_flow.append({"pw_idx": pw_idx, "t": t, "qi_ratio": qi_ratio, "technique_id": "", "blend": true, "blend_color": blend_color})
					2:  # Layer3: 生克效果
						if is_sheng:
							new_glow.append({"pw_idx": pw_idx, "t": t, "color": shengke_color})
						elif is_ke:
							new_spark.append({"pw_idx": pw_idx, "t": t, "color": shengke_color})
						# neutral: no layer3 particle, but we can add a faint white one
						elif _intersection_nodes.has(fn) or _intersection_nodes.has(tn):
							new_glow.append({"pw_idx": pw_idx, "t": t, "color": Color(1, 1, 1, 0.3)})
		elif active_techs.size() == 1:
			# === Single technique: all particles in that color ===
			var tech_id: String = active_techs[0]
			for p: int in base_count:
				var t: float = fmod(float(p) / float(base_count) + _get_particle_phase(pw_idx, p) + speed * delta, 1.0)
				new_flow.append({"pw_idx": pw_idx, "t": t, "qi_ratio": qi_ratio, "technique_id": tech_id, "blend": false})
		else:
			# === No technique attribution: default cyan ===
			for p: int in base_count:
				var t: float = fmod(float(p) / float(base_count) + _get_particle_phase(pw_idx, p) + speed * delta, 1.0)
				new_flow.append({"pw_idx": pw_idx, "t": t, "qi_ratio": qi_ratio, "technique_id": "", "blend": false})

		# Extra spark particles on damaged pathways
		if is_damaged_path:
			for p: int in max(2, base_count):
				var t: float = fmod(float(p) / float(base_count) + _get_particle_phase(pw_idx, p + 100) + speed * 1.5 * delta, 1.0)
				new_spark.append({"pw_idx": pw_idx, "t": t, "color": Color(1, 0.1, 0.05)})

		needs_redraw = true

	_flow_particles = new_flow
	_spark_particles = new_spark
	_glow_particles = new_glow
	if needs_redraw:
		queue_redraw()


func _get_particle_phase(pw_idx: int, p: int) -> float:
	return fmod(float(pw_idx * 37 + p * 13) / 100.0, 1.0)


## Compute intersection nodes, frontier nodes for this frame
func _compute_overlay_state() -> void:
	_intersection_nodes.clear()
	_frontier_nodes.clear()

	if _meridian == null:
		return

	# Intersection: nodes where multiple techniques have Qi
	for i: int in _meridian.nodes.size():
		var node: MeridianNodeData = _meridian.nodes[i]
		if node == null or not node.unlocked or node.blocked:
			continue
		# Skip if collision boost/dampen already covers this node
		if _collision_boost_nodes.has(i) or _collision_dampen_nodes.has(i):
			continue
		if not node.technique_qi.is_empty():
			var active_count: int = 0
			for v in node.technique_qi.values():
				if v > 0.01:
					active_count += 1
			if active_count > 1:
				_intersection_nodes.append(i)

	# Frontier: nodes with Qi but no downstream Qi (when dry)
	if _is_dry:
		for i: int in _meridian.nodes.size():
			var node: MeridianNodeData = _meridian.nodes[i]
			if node == null or not node.unlocked or node.blocked:
				continue
			if node.current_qi <= 0.01:
				continue
			var has_downstream: bool = false
			for conn: int in node.connections:
				var cn: MeridianNodeData = _meridian.get_node(conn)
				if cn and cn.current_qi > 0.01:
					has_downstream = true
					break
			if not has_downstream:
				_frontier_nodes.append(i)


func _draw() -> void:
	if _meridian == null or _meridian.nodes.is_empty():
		return

	var w: float = size.x
	var h: float = size.y
	var now: int = Time.get_ticks_msec()

	# Draw pathways
	for pw_idx: int in _meridian.pathways.size():
		var pw: MeridianPathwayData = _meridian.pathways[pw_idx]
		var fn: MeridianNodeData = _meridian.nodes[pw.from_node]; if fn == null: continue
		var tn: MeridianNodeData = _meridian.nodes[pw.to_node]; if tn == null: continue
		var from_pos: Vector2 = _node_screen_pos(fn, w, h)
		var to_pos: Vector2 = _node_screen_pos(tn, w, h)

		var pw_key: String = _make_pw_key(pw.from_node, pw.to_node)
		var is_damaged_collision: bool = _collision_damaged_pathways.has(pw_key)

		# Determine active technique IDs on this pathway
		var active_techs: Array[String] = []
		if not pw.technique_qi.is_empty():
			for tid: String in pw.technique_qi:
				if pw.technique_qi[tid] > 0.01:
					active_techs.append(tid)

		var pw_color: Color
		var line_w: float = 1.5 + pw.width * 1.5
		var draw_collision_overlay: bool = false
		var overlay_color: Color = Color(1, 1, 1, 0)

		if pw.damaged or is_damaged_collision:
			pw_color = Color(0.7, 0.1, 0.1)
			line_w = 1.5
			if is_damaged_collision:
				draw_collision_overlay = true
				overlay_color = Color(1, 0.1, 0.05, 0.5)
		elif pw.blocked:
			pw_color = Color(0.3, 0.3, 0.3)
		elif fn.unlocked and tn.unlocked:
			if active_techs.size() > 1:
				# Multi-technique: check sheng-ke first
				if _collision_dampen_nodes.has(pw.from_node) or _collision_dampen_nodes.has(pw.to_node):
					pw_color = Color(0.6, 0.2, 0.3, 0.8)
					draw_collision_overlay = true
					overlay_color = Color(0.9, 0.1, 0.05, 0.4)
				elif _collision_boost_nodes.has(pw.from_node) or _collision_boost_nodes.has(pw.to_node):
					pw_color = Color(0.7, 0.6, 0.2, 0.8)
					draw_collision_overlay = true
					overlay_color = Color(1, 0.75, 0.1, 0.4)
				else:
					# Neutral intersection: blend the two technique colors
					var c1: Color = _get_tech_color(active_techs[0])
					var c2: Color = _get_tech_color(active_techs[1])
					pw_color = c1.lerp(c2, 0.5)
					pw_color.a = 0.7
			elif active_techs.size() == 1:
				pw_color = _get_tech_color(active_techs[0])
				pw_color.a = 0.7
			else:
				var qi_brightness: float = clamp(pw.current_qi / max(1.0, pw.max_capacity), 0.05, 1.0)
				pw_color = Color(0.2, 0.5 + qi_brightness * 0.5, 0.8, 0.3 + qi_brightness * 0.7)
		else:
			pw_color = Color(0.15, 0.15, 0.15)

		# Draw main pathway line
		draw_line(from_pos, to_pos, pw_color, line_w)

		# Collision overlay (相克红色/相生金色叠加)
		if draw_collision_overlay:
			draw_line(from_pos, to_pos, overlay_color, line_w + 2.0)

		# Circuit highlight
		if pw_key in _circuit_pathway_keys:
			draw_line(from_pos, to_pos, Color(1.0, 0.85, 0.2, 0.4), line_w + 1.0)

		# Draw flow particles
		_draw_particles(from_pos, to_pos, pw_idx)

		# Draw spark particles (相克)
		for spark in _spark_particles:
			if spark.get("pw_idx", -1) != pw_idx:
				continue
			var spos: Vector2 = from_pos.lerp(to_pos, spark.get("t", 0.0))
			var sc: Color = spark.get("color", Color(1, 0.1, 0.05))
			var offset_x: float = sin(Time.get_ticks_msec() * 0.01 + float(pw_idx) * 2.7) * 3.0
			var offset_y: float = cos(Time.get_ticks_msec() * 0.013 + float(pw_idx) * 1.3) * 3.0
			draw_circle(spos + Vector2(offset_x, offset_y), 1.5, sc)

		# Draw glow particles (相生)
		for glow in _glow_particles:
			if glow.get("pw_idx", -1) != pw_idx:
				continue
			var gpos: Vector2 = from_pos.lerp(to_pos, glow.get("t", 0.0))
			var gc: Color = glow.get("color", Color(1, 0.75, 0.1))
			draw_circle(gpos, 3.0, gc)

	# Draw nodes
	for i: int in _meridian.nodes.size():
		var node: MeridianNodeData = _meridian.nodes[i]; if node == null: continue
		var pos: Vector2 = _node_screen_pos(node, w, h)
		var is_dantian: bool = (i == _meridian.dantian_node_index)
		var r: float = _center_radius if is_dantian else _node_radius

		var fill_ratio: float = 0.0
		if node.capacity > 0:
			fill_ratio = clamp(node.current_qi / node.capacity, 0.0, 1.0)

		# Base fill for locked nodes
		if not node.unlocked and not node.blocked:
			draw_circle(pos, r, Color(0.06, 0.06, 0.10))

		# Unlock animation
		if _unlock_anims.has(i):
			var elapsed: int = now - _unlock_anims[i]
			var t: float = clamp(float(elapsed) / float(UNLOCK_ANIM_DURATION_MS), 0.0, 1.0)
			draw_arc(pos, r + t * 30.0, 0, TAU, 32, Color(1.0, 0.85, 0.2, (1.0 - t) * 0.8), 4.0 - t * 3.0)
			draw_circle(pos, r * (1.0 + t * 0.5), Color(1.0, 0.9, 0.3, (1.0 - t) * 0.6))

		# Fill for unlocked nodes
		if node.unlocked and not node.blocked and fill_ratio > 0.01:
			var fill_color: Color = ELEMENT_COLORS.get(node.element, Color(0.5, 0.5, 0.5))
			if node.element == "":
				fill_color = Color(1.0, 0.85, 0.3)
			fill_color.a = 0.85
			var inner_r: float = r * 0.3
			var fill_r: float = inner_r + (r - inner_r) * fill_ratio
			if fill_r > inner_r + 0.5:
				draw_circle(pos, fill_r, fill_color)

		# Node border
		draw_arc(pos, r + 0.5, 0, TAU, 32, Color(0, 0, 0, 0.6), 1.5)

		# --- Outer ring (priority: 相克 > 相生 > 中性交汇 > 单功法 > 断流) ---
		if node.unlocked:
			if _collision_dampen_nodes.has(i):
				# 相克: crimson crackle ring
				var pulse: float = 0.5 + sin(now * 0.005) * 0.5
				draw_arc(pos, r + 6, 0, TAU, 32, Color(0.9, 0.1, 0.05, pulse * 0.9), 2.5)
				# Jagged inner sparks
				for j in range(4):
					var angle: float = float(j) * TAU / 4.0 + sin(now * 0.003 + j) * 0.3
					var spark_pos: Vector2 = pos + Vector2(cos(angle), sin(angle)) * (r + 3)
					draw_circle(spark_pos, 1.5 + sin(now * 0.008 + j) * 1.0, Color(1, 0.2, 0.1, pulse))
			elif _collision_boost_nodes.has(i):
				# 相生: golden glow ring
				var pulse: float = 0.5 + sin(now * 0.004) * 0.5
				draw_arc(pos, r + 6, 0, TAU, 32, Color(1, 0.75, 0.1, pulse * 0.9), 2.5)
				# Warm diffusion ripple
				var ripple: float = fmod(float(now) / 1000.0, 1.0)
				var ripple_r: float = r + 8 + ripple * 12.0
				draw_arc(pos, ripple_r, 0, TAU, 32, Color(1, 0.75, 0.1, (1.0 - ripple) * 0.4), 1.5)
			elif i in _intersection_nodes:
				# Neutral intersection: white ring + diamond
				var pulse: float = 0.6 + sin(now * 0.004) * 0.4
				draw_arc(pos, r + 4, 0, TAU, 32, Color(1, 1, 1, pulse * 0.7), 2.0)
				var ds: float = 4.0
				var diamond: PackedVector2Array = [
					pos + Vector2(0, -ds),
					pos + Vector2(ds, 0),
					pos + Vector2(0, ds),
					pos + Vector2(-ds, 0),
				]
				draw_colored_polygon(diamond, Color(1, 1, 1, pulse))
			elif _is_dry and not is_dantian:
				# Dry: red ring (existing behavior)
				draw_arc(pos, r + 2, 0, TAU, 32, Color(1.0, 0.3, 0.2, 0.5), 2.0)
			elif fill_ratio > 0.01:
				# Single technique: use technique color or default white
				var ring_color: Color = _get_node_ring_color(i)
				draw_arc(pos, r + 2, 0, TAU, 32, ring_color, 2.0)
			else:
				draw_arc(pos, r + 2, 0, TAU, 32, Color(1.0, 1.0, 1.0, 0.25), 2.0)
		else:
			# Locked node: erosion target pulsing cyan ring
			if i in _erosion_targets:
				var pulse: float = 0.35 + sin(now * 0.003) * 0.25
				draw_arc(pos, r + 5, 0, TAU, 32, Color(0.2, 0.9, 1.0, pulse), 3.0)

		# Frontier marker: red pulse + "断流" label
		if i in _frontier_nodes:
			var pulse: float = 0.6 + sin(now * 0.006) * 0.4
			draw_arc(pos, r + 9, 0, TAU, 32, Color(1.0, 0.2, 0.2, pulse), 2.0)

		# Erosion progress: percentage inside locked node
		if not node.unlocked and not node.blocked and node.erosion_threshold > 0 and (i in _erosion_targets or node.erosion_progress > 0.01):
			var pct: int = int(clamp(node.erosion_progress / node.erosion_threshold * 100.0, 0.0, 100.0))
			var progress_text: String = "%d%%" % pct
			var tx: float = pos.x
			var ty: float = pos.y - _progress_font_size * 0.4
			draw_string(ThemeDB.fallback_font, Vector2(tx, ty), progress_text,
				HORIZONTAL_ALIGNMENT_CENTER, -1, _progress_font_size, Color(1.0, 1.0, 1.0, 1.0))

		# Name label below node
		var label: String = node.name
		if fill_ratio > 0:
			label += " %.1f" % node.current_qi
		elif i in _erosion_targets:
			label += " [冲]"

		var label_color: Color = Color(0.7, 0.7, 0.7)
		if _is_dry and node.unlocked and not is_dantian:
			label_color = Color(0.9, 0.3, 0.2)
		elif _collision_dampen_nodes.has(i):
			label_color = Color(1, 0.2, 0.1)
		elif _collision_boost_nodes.has(i):
			label_color = Color(1, 0.8, 0.2)
		elif i in _intersection_nodes:
			label_color = Color(0.9, 0.7, 1.0)
		elif i in _erosion_targets:
			label_color = Color(0.2, 0.9, 1.0)
		elif not node.unlocked and node.erosion_progress > 0:
			label_color = Color(0.4, 0.7, 1.0)

		draw_string(ThemeDB.fallback_font, pos + Vector2(-r - 2, r + 14), label,
			HORIZONTAL_ALIGNMENT_CENTER, -1, _font_size, label_color)

		# Frontier label
		if i in _frontier_nodes:
			var fpulse: float = 0.6 + sin(now * 0.006) * 0.4
			draw_string(ThemeDB.fallback_font, pos + Vector2(-r - 2, r + 28), "断流",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(1.0, 0.3, 0.2, fpulse))


func _draw_particles(from_pos: Vector2, to_pos: Vector2, pw_idx: int) -> void:
	for particle in _flow_particles:
		if particle.get("pw_idx", -1) != pw_idx:
			continue
		var ppos: Vector2 = from_pos.lerp(to_pos, particle.get("t", 0.0))
		var qr: float = particle.get("qi_ratio", 0.5)
		var tech_id: String = particle.get("technique_id", "")
		var is_blend: bool = particle.get("blend", false)

		var particle_color: Color
		if is_blend:
			particle_color = particle.get("blend_color", Color(0.5, 0.5, 0.5))
			particle_color.a = qr * 0.7
		elif tech_id != "" and _technique_colors.has(tech_id):
			particle_color = _technique_colors[tech_id]
			particle_color.a = qr * 0.85
		else:
			# Default cyan for unattributed Qi
			particle_color = Color(0.3, 0.9, 1.0, qr * 0.5)

		var particle_radius: float = 2.0 + qr * 2.0
		if is_blend:
			particle_radius += 0.5
		draw_circle(ppos, particle_radius, particle_color)


func _node_screen_pos(node, w: float, h: float) -> Vector2:
	return Vector2(node.position.x * w, node.position.y * h)


func _make_pw_key(from_idx: int, to_idx: int) -> String:
	var a: int = min(from_idx, to_idx)
	var b: int = max(from_idx, to_idx)
	return "%d->%d" % [a, b]


## Get the ring color for a node with single-technique Qi
func _get_node_ring_color(node_idx: int) -> Color:
	var node: MeridianNodeData = _meridian.nodes[node_idx]
	if node == null:
		return Color(1, 1, 1, 0.25)

	# If single technique, use its color
	if not node.technique_qi.is_empty():
		var active_ids: Array[String] = []
		for tid: String in node.technique_qi:
			if node.technique_qi[tid] > 0.01:
				active_ids.append(tid)
		if active_ids.size() == 1 and _technique_colors.has(active_ids[0]):
			var c: Color = _technique_colors[active_ids[0]]
			c.a = 0.6
			return c

	return Color(1, 1, 1, 0.6)


## Get color for a technique ID, with fallback
func _get_tech_color(tech_id: String) -> Color:
	if tech_id != "" and _technique_colors.has(tech_id):
		return _technique_colors[tech_id]
	return Color(0.3, 0.9, 1.0)  # default cyan


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _meridian == null:
			return
		var click_pos: Vector2 = event.position
		for i: int in _meridian.nodes.size():
			var node: MeridianNodeData = _meridian.nodes[i]; if node == null: continue
			var pos: Vector2 = _node_screen_pos(node, size.x, size.y)
			var dist: float = click_pos.distance_to(pos)
			var r: float = _center_radius if i == _meridian.dantian_node_index else _node_radius
			if dist <= r + 6:
				_on_node_tapped(i)
				return


func _on_node_tapped(idx: int) -> void:
	var node: MeridianNodeData = _meridian.nodes[idx]
	if node == null:
		return

	var now: int = Time.get_ticks_msec()

	# Double tap: same node within 300ms
	if idx == _last_tap_idx and (now - _last_tap_time) < 300:
		_last_tap_idx = -1
		_tap_sequence += 1
		node_double_clicked.emit(idx, node)
		return

	_last_tap_idx = idx
	_last_tap_time = now
	_tap_sequence += 1
	var my_seq: int = _tap_sequence

	# Wait 300ms; if no double-tap arrived, fire single-tap
	await get_tree().create_timer(0.3).timeout
	if _tap_sequence == my_seq:
		node_clicked.emit(idx, node)
