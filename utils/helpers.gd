# ============================================================
# 大周天 — Helper Functions
# ============================================================

class_name Helpers extends RefCounted


# --- Random ---

static func pick_random(arr: Array):
	if arr.is_empty():
		return null
	return arr[randi() % arr.size()]


static func pick_weighted(items: Array, weight_key: String = "weight"):
	var total := 0
	for item in items:
		total += int(item.get(weight_key))
	if total == 0:
		return pick_random(items)
	var roll := randi() % total
	var cumulative := 0
	for item in items:
		cumulative += int(item.get(weight_key))
		if roll < cumulative:
			return item
	return items[-1]


static func shuffle(arr: Array) -> Array:
	var result := arr.duplicate()
	result.shuffle()
	return result


static func sample(arr: Array, count: int) -> Array:
	var pool := arr.duplicate()
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))


# --- Math ---

static func clamp_val(v: int, lo: int, hi: int) -> int:
	return max(lo, min(hi, v))


static func clampf(v: float, lo: float, hi: float) -> float:
	return maxf(lo, minf(hi, v))


# --- Array / Dictionary ---

static func dict_get(d: Dictionary, key, default = null):
	return d.get(key, default)


static func ensure_array(val) -> Array:
	if val is Array:
		return val
	return [val]


# --- String Parsing for Effects ---

static func parse_effect(effect: String) -> Dictionary:
	"""
	Parse a colon-delimited effect string into a dict.
	"heal:15" -> {cmd="heal", args=["15"]}
	"buff:strength:2" -> {cmd="buff", args=["strength", "2"]}
	"""
	var parts := effect.split(":")
	if parts.is_empty():
		return {"cmd": "", "args": []}
	return {"cmd": parts[0], "args": parts.slice(1)}


# --- Visual ---

static func color_for_element(element: int) -> Color:
	match element:
		1: return GameColors.FIRE
		2: return GameColors.WATER
		3: return GameColors.WOOD
		4: return GameColors.METAL
		5: return GameColors.EARTH
	return Color(0.5, 0.5, 0.5)


static func color_for_card_type(card_type: int) -> Color:
	return GameColors.card_type_color(card_type)
