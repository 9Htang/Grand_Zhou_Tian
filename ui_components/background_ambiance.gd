# ============================================================
# 大周天 — Background Ambiance (背景氛围)
# ============================================================
# 古风墨色背景 + 飘浮灵气粒子 + 微光呼吸
# 用于战斗/菜单等主要场景的背景装饰
# ============================================================
class_name BackgroundAmbiance
extends Control


@export var particle_count: int = 30
@export var particle_speed: float = 0.3
@export var particle_size_range: Vector2 = Vector2(1.5, 4.0)

# Ink-wash corner vignette
var _vignette: ColorRect
var _particles: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Deep ink-colored background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = GameColors.BG_VOID
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Subtle radial gradient center glow (via large soft ColorRect)
	var center_glow := ColorRect.new()
	center_glow.set_anchors_preset(Control.PRESET_CENTER)
	center_glow.size = Vector2(600, 400)
	center_glow.position = Vector2(-300, -200)
	center_glow.modulate = Color(0.2, 0.18, 0.35, 0.04)
	center_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_glow)

	# Initialize particles
	var viewport := get_viewport_rect().size if get_viewport() else Vector2(1280, 720)
	for _i in range(particle_count):
		_particles.append({
			"pos": Vector2(randf() * viewport.x, randf() * viewport.y),
			"size": randf_range(particle_size_range.x, particle_size_range.y),
			"speed": randf_range(particle_speed * 0.5, particle_speed * 1.5),
			"wobble": randf() * TAU,
			"alpha": randf_range(0.15, 0.5),
			"color_phase": randf() * TAU,
		})


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var vp_size: Vector2 = size

	# Ink-wash corner vignette (darker corners)
	var vignette_color := Color(0, 0, 0.02, 0.3)
	var vignette_radius: float = min(vp_size.x, vp_size.y) * 0.65

	# Draw simple corner shadows to create depth
	for corner in [
		Vector2(0, 0),
		Vector2(vp_size.x, 0),
		Vector2(0, vp_size.y),
		Vector2(vp_size.x, vp_size.y),
	]:
		var dir: Vector2 = (vp_size * 0.5 - corner).normalized()
		for i in range(8):
			var t: float = i / 7.0
			var r: float = vignette_radius * (1.0 - t * 0.7)
			var alpha: float = 0.15 * (1.0 - t)
			draw_circle(corner + dir * r * 0.3, r, Color(0, 0, 0.02, alpha))

	# Draw floating qi particles
	for p in _particles:
		var px: float = p["pos"].x + sin(_time * p["speed"] + p["wobble"]) * 15.0
		var py: float = p["pos"].y + cos(_time * p["speed"] * 0.7 + p["wobble"]) * 12.0

		# Drift upward + wrap (write back to persist)
		py -= _time * p["speed"] * 8.0
		var vp_h: float = vp_size.y
		while py < -10:
			py += vp_h + 20
		while py > vp_h + 10:
			py -= vp_h + 20
		p["pos"].y = py

		# Color oscillates between soft blue and soft gold
		var ct: float = sin(_time * 0.3 + p["color_phase"]) * 0.5 + 0.5
		var particle_color := Color(
			lerpf(0.2, 0.7, ct),
			lerpf(0.4, 0.6, ct),
			lerpf(0.9, 0.3, ct),
			p["alpha"],
		)

		draw_circle(Vector2(px, py), p["size"], particle_color)

		# Subtle glow around each particle
		draw_circle(Vector2(px, py), p["size"] * 2.5, Color(particle_color.r, particle_color.g, particle_color.b, p["alpha"] * 0.15))


## 重新生成粒子位置（用于窗口大小变化）
func refresh_particles() -> void:
	var vp := get_viewport_rect().size if get_viewport() else Vector2(1280, 720)
	for p in _particles:
		p["pos"] = Vector2(randf() * vp.x, randf() * vp.y)
	queue_redraw()
