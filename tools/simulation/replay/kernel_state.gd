# ============================================================
# 大周天 — KernelState (内核状态快照)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 战斗内核在某一个时刻的完整可恢复游戏状态。
# 只包含世界状态（rng/player/enemies/deck/vm），
# 不包含回放定位信息（tick/event_index 属于 ReplaySnapshot）。
#
# 所有字段为 Dictionary/Array[Dictionary] — 与运行时对象解耦。
# ============================================================
class_name KernelState
extends RefCounted


## RNG 内部状态
var rng: Dictionary = {}

## 玩家状态: {hp, max_hp, qi, capacity, block, realm, talent, ...}
var player: Dictionary = {}

## 敌人状态: [{hp, max_hp, qi}, ...]
var enemies: Array[Dictionary] = []

## 牌堆状态: 每张卡序列化为 Dictionary
var deck: Dictionary = {}  # {draw: [], hand: [], discard: [], exhaust: []}

## VM 执行状态: 所有值都是可序列化的 Dictionary
var vm: Dictionary = {}  # {ip, stack, event_queue, pending, trigger_stack}


func to_dict() -> Dictionary:
	return {
		"rng": _copy_rng(rng),
		"player": _copy_shallow(player),
		"enemies": _copy_enemies(enemies),
		"deck": _copy_deck(deck),
		"vm": _copy_vm(vm),
	}


static func _copy_rng(d: Dictionary) -> Dictionary:
	return {"seed": d.get("seed", 0), "state": d.get("state", 0), "call_count": d.get("call_count", 0)}


static func _copy_shallow(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d:
		out[k] = d[k]
	return out


static func _copy_enemies(arr: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in arr:
		if e is Dictionary:
			out.append(_copy_shallow(e))
	return out


static func _copy_deck(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in ["draw", "hand", "discard", "exhaust"]:
		var arr: Array = d.get(key, [])
		var copied: Array = []
		for card in arr:
			if card is Dictionary:
				copied.append(_copy_shallow(card))
		out[key] = copied
	return out


static func _copy_vm(d: Dictionary) -> Dictionary:
	return {
		"ip": d.get("ip", 0),
		"stack": _deep_copy_array(d.get("stack", [])),
		"event_queue": _deep_copy_array(d.get("event_queue", [])),
		"pending": _deep_copy_array(d.get("pending", [])),
		"trigger_stack": _deep_copy_array(d.get("trigger_stack", [])),
	}


static func _deep_copy_array(arr: Array) -> Array:
	var out: Array = []
	for v in arr:
		if v is Dictionary:
			out.append(_copy_shallow(v))
		elif v is Array:
			out.append(_deep_copy_array(v))
		else:
			out.append(v)
	return out


## 从当前运行时捕获完整游戏状态
static func capture(p_player, p_enemies: Array, p_deck, p_rng: DeterministicRNG,
		p_vm_ip: int, p_vm_stack: Array,
		p_event_queue: Array, p_pending: Array, p_trigger_stack: Array) -> KernelState:
	var s := KernelState.new()

	# RNG
	s.rng = p_rng.save_state()

	# Player
	s.player = _snap_player(p_player)

	# Enemies
	for e in p_enemies:
		if e:
			s.enemies.append(_snap_enemy(e))
		else:
			s.enemies.append({})

	# Deck — 完整卡牌实例状态，不是只存 ID
	s.deck = {
		"draw": _snap_cards(p_deck.draw_pile),
		"hand": _snap_cards(p_deck.hand),
		"discard": _snap_cards(p_deck.discard_pile),
		"exhaust": _snap_cards(p_deck.exhaust_pile),
	}

	# VM — 全部序列化为数据
	s.vm = {
		"ip": p_vm_ip,
		"stack": p_vm_stack.duplicate(),
		"event_queue": p_event_queue.duplicate(),
		"pending": p_pending.duplicate(),
		"trigger_stack": p_trigger_stack.duplicate(),
	}

	return s


static func _snap_player(p) -> Dictionary:
	return {
		"hp": p.hp, "max_hp": p.max_hp,
		"qi": p.dantian_qi, "capacity": p.dantian_capacity,
		"block": p.current_block,
		"realm": p.get("realm"), "talent": p.get("talent"),
	}


static func _snap_enemy(e) -> Dictionary:
	return {"hp": e.hp, "max_hp": e.max_hp, "qi": e.dantian_qi}


static func _snap_cards(cards: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for c in cards:
		if c == null:
			continue
		result.append({
			"id": c.get("id") if c.get("id") != null else "",
			"card_type": c.get("card_type") if c.get("card_type") != null else 0,
			"cost": c.get("cost") if c.get("cost") != null else 0,
			"behavior": c.get("behavior") if c.get("behavior") != null else 0,
		})
	return result
