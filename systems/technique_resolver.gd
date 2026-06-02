# ============================================================
# 大周天 — Technique Resolver (功法-穴位反应 → 线性缩放buff)
# ============================================================
# 功法经过穴位时，根据 node_reactions 生成临时buff
# buff 数值与穴位当前灵气量线性挂钩
# ============================================================
class_name TechniqueResolver
extends RefCounted


class ResolvedBuff:
	var name: String = ""
	var value: int = 0
	var element: String = ""
	var source: String = ""
	var modifier: float = 1.0
	## 剩余持续回合数: 0=永久/手动清除, >0=每回合结束递减
	var turns_remaining: int = 0


## 解析单个穴位-功法反应，线性缩放
## qi_amount: 穴位当前灵气量
## node_base_buffs: 穴位永久基底buff
## collision_modifier: 碰撞修正（相生/相克）
static func resolve_node(
	technique: TechniqueData,
	node: MeridianNodeData,
	qi_amount: float,
	node_base_buffs: Dictionary = {},
	collision_modifier: float = 1.0
) -> Array:
	var buffs: Array = []

	# 功法-穴位反应 (node_reactions 按元素匹配)
	var reaction: String = technique.node_reactions.get(node.element, "")
	if not reaction.is_empty():
		var rb: ResolvedBuff = _parse_buff(reaction)
		rb.source = "technique"
		rb.modifier = collision_modifier
		rb.element = node.element
		# Negative effects (self_damage, energy_down) are flat — not scaled by qi flow.
		# Positive effects scale with qi amount, capped at node.capacity to prevent
		# flow_tracker accumulation from creating absurd values (e.g. 50+ self_damage).
		if rb.name == "self_damage" or rb.name == "energy_down":
			rb.value = max(1, int(ceil(float(rb.value) * collision_modifier)))
		else:
			var scaled_qi: float = min(qi_amount, node.capacity)
			rb.value = int(ceil(float(rb.value) * scaled_qi * collision_modifier))
			rb.value = max(1, rb.value)  # 至少为1
		buffs.append(rb)

	# 穴位永久基底buff
	var base_buff: String = node_base_buffs.get(node.name, "")
	if not base_buff.is_empty():
		var bb: ResolvedBuff = _parse_buff(base_buff)
		bb.source = "base"
		bb.element = node.element
		# 基底buff: cap qi_amount to node.capacity (same rationale as technique reactions)
		var scaled_qi_base: float = min(qi_amount, node.capacity)
		bb.value = int(ceil(float(bb.value) * scaled_qi_base))
		bb.value = max(1, bb.value)
		buffs.append(bb)

	return buffs


## 对整个经脉网络上所有有灵气的穴位解析buff
## active_nodes: 有灵气的穴位索引列表
## collision: QiCollisionResolver.CollisionResult
static func resolve_network_buffs(
	techniques: Array,
	meridian: MeridianMapData,
	node_base_buffs: Dictionary = {},
	collision = null,
	flow_tracker: Dictionary = {}
) -> Array:
	var all_buffs: Array = []

	for i: int in techniques.size():
		var tech: TechniqueData = techniques[i]
		if tech == null:
			continue

		for node_idx: int in meridian.nodes.size():
			var node: MeridianNodeData = meridian.get_node(node_idx)
			if node == null or not node.unlocked or node.blocked:
				continue
			if node.current_qi <= 0:
				continue

			# 获取碰撞修正
			var collision_mod: float = 1.0
			if collision:
				var node_mods: Dictionary = collision.node_modifiers.get(node_idx, {})
				collision_mod = node_mods.get(i, 1.0)

			# 优先用流经量（连续流动模型），无流量时回退到存量
			var qi_amount: float = flow_tracker.get(node_idx, node.current_qi)

			# Bug 6 fix: collision_mod from node_modifiers already accounts for collision scaling.
			# Removing qi_boost/qi_dampen double-application (was 1.5x × 1.5x = 2.25x instead of 1.5x).
			# qi_boost/qi_dampen remain available in CollisionResult for flow physics if needed.

			var buffs: Array = resolve_node(tech, node, qi_amount, node_base_buffs, collision_mod)
			all_buffs.append_array(buffs)

	return all_buffs


## 检查功法相生
static func check_synergy(a: TechniqueData, b: TechniqueData) -> bool:
	var ea: int = a.get_element_int()
	var eb: int = b.get_element_int()
	return Constants.ELEMENT_GENERATES.get(ea) == eb


## 获取相生加成
static func get_synergy_bonus(a: TechniqueData, b: TechniqueData) -> Dictionary:
	if check_synergy(a, b):
		return {"synergy": true, "qi_boost": 1.5, "buff_multiplier": 1.5}
	if check_synergy(b, a):
		return {"synergy": true, "qi_boost": 1.5, "buff_multiplier": 1.5}
	return {"synergy": false, "qi_boost": 1.0, "buff_multiplier": 1.0}


# ============================================================
# Internal
# ============================================================

static func _parse_buff(raw: String) -> ResolvedBuff:
	var rb: ResolvedBuff = ResolvedBuff.new()
	var parts: PackedStringArray = raw.split(":")
	if parts.size() >= 3 and parts[0] == "buff":
		# "buff:strength:3" → name="strength", value=3
		rb.name = parts[1]
		rb.value = int(parts[2])
	elif parts.size() >= 2:
		rb.name = parts[0]
		rb.value = int(parts[1])
	elif parts.size() == 1:
		rb.name = parts[0]
		rb.value = 1
	return rb
