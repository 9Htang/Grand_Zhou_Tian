# ============================================================
# 大周天 — ScreenTransition (墨迹场景过渡)
# ============================================================
# CanvasLayer 墨汁晕开/收缩过渡效果
# 用法:
#   var t := ScreenTransition.new()
#   add_child(t)
#   await t.fade_out()    # 墨迹覆盖屏幕
#   # ... 切换场景 ...
#   t.fade_in()           # 墨迹收缩揭示新场景
# ============================================================
class_name ScreenTransition
extends CanvasLayer


enum TransitionStyle {
	INK_WASH,     # 墨迹晕开（从中心圆扩散）
	FADE_BLACK,   # 纯黑淡入淡出
	INK_DROP,     # 从上到下墨迹流淌（alpha模拟）
}


var _color_rect: ColorRect


func _ready() -> void:
	layer = 200  # Above everything

	_color_rect = ColorRect.new()
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.color = GameColors.BG_VOID
	_color_rect.modulate.a = 0.0  # Start transparent
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_color_rect)


## 墨迹覆盖屏幕 (fade to black)
func fade_out(duration: float = 0.5, style: TransitionStyle = TransitionStyle.INK_WASH) -> Signal:
	match style:
		TransitionStyle.INK_WASH:
			return _ink_wash_out(duration)
		TransitionStyle.FADE_BLACK:
			return _simple_fade(0.0, 1.0, duration)
		TransitionStyle.INK_DROP:
			return _ink_drop_out(duration)
		_:
			return _simple_fade(0.0, 1.0, duration)


## 墨迹收缩揭示 (fade from black)
func fade_in(duration: float = 0.5, style: TransitionStyle = TransitionStyle.INK_WASH) -> Signal:
	match style:
		TransitionStyle.INK_WASH:
			return _simple_fade(1.0, 0.0, duration)
		TransitionStyle.FADE_BLACK:
			return _simple_fade(1.0, 0.0, duration)
		TransitionStyle.INK_DROP:
			return _ink_drop_in(duration)
		_:
			return _simple_fade(1.0, 0.0, duration)


# ============================================================
# 简单淡入淡出
# ============================================================

func _simple_fade(from_a: float, to_a: float, duration: float) -> Signal:
	_color_rect.color = GameColors.BG_VOID
	_color_rect.modulate.a = from_a
	var t := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(_color_rect, "modulate:a", to_a, duration)
	return t.finished


# ============================================================
# 墨迹晕开（从中心扩散的多层圆）
# ============================================================

func _ink_wash_out(duration: float) -> Signal:
	_clear_circles()
	_color_rect.modulate.a = 1.0
	var viewport_size: Vector2
	if _color_rect.get_viewport():
		viewport_size = _color_rect.get_viewport_rect().size
	else:
		viewport_size = Vector2(1280, 720)
	_create_ink_circles(viewport_size, duration)

	# Fallback timer — guard against get_tree() returning null
	var tree: SceneTree = _color_rect.get_tree()
	if tree:
		return tree.create_timer(duration).timeout
	# Fallback: tween-based timer (works even outside tree)
	var fallback := create_tween()
	return fallback.tween_interval(duration).finished


func _ink_drop_out(duration: float) -> Signal:
	# Use alpha ramp with quick early rise to simulate drop
	_color_rect.modulate.a = 0.0
	_color_rect.color = GameColors.BG_VOID
	var t := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_color_rect, "modulate:a", 1.0, duration)
	return t.finished


func _ink_drop_in(duration: float) -> Signal:
	_color_rect.modulate.a = 1.0
	_color_rect.color = GameColors.BG_VOID
	var t := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_color_rect, "modulate:a", 0.0, duration * 0.7)
	return t.finished


# ============================================================
# Ink circle helpers
# ============================================================

func _create_ink_circles(vp_size: Vector2, total_duration: float) -> void:
	var center: Vector2 = vp_size * 0.5
	var max_size: float = vp_size.length() * 0.8

	for i in range(4):
		var circle := ColorRect.new()
		circle.color = GameColors.BG_VOID
		circle.size = Vector2.ZERO
		circle.position = center
		circle.pivot_offset = Vector2.ZERO
		circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(circle)

		var delay: float = i * 0.06
		var dur: float = total_duration - delay
		var t := create_tween()
		t.tween_interval(delay)
		t.tween_property(circle, "size", Vector2(max_size, max_size), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
		t.parallel().tween_property(circle, "position", center - Vector2(max_size * 0.5, max_size * 0.5), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
		t.finished.connect(circle.queue_free, CONNECT_ONE_SHOT)


func _clear_circles() -> void:
	for child in get_children():
		if child != _color_rect:
			child.queue_free()
