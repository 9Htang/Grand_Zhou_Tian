# ============================================================
# 大周天 — Qi Collision Resolver (五行碰撞结算 — 流体模型适配)
# ============================================================
# 多股灵气在穴位/经脉相遇时的五行生克结算
# 流体模型下：相生→流量/灵气增强；相克→经脉损伤+灵气减弱
# ============================================================
class_name QiCollisionResolver
extends RefCounted


class CollisionResult:
	var node_modifiers: Dictionary = {}       # {node_idx: {tech_idx: float}}
	var qi_boost: Dictionary = {}             # {node_idx: float} — 相生灵气增强
	var qi_dampen: Dictionary = {}            # {node_idx: float} — 相克灵气减弱
	var damaged_pathways: Array[Dictionary] = []  # [{from, to, turns}]
	var descriptions: Array[String] = []


## Resolve collision between two elements at a specific node.
## Returns modified qi multiplier for buff calculation.
static func resolve_at_node(element_a: int, element_b: int) -> Dictionary:
	"""
	Returns: {a_modifier: float, b_modifier: float, qi_multiplier: float, description: String}
	Bug 8 fix: removed dead params node_qi/node_element — never used.
	Bug 9 fix: 相生时生者倍率1.3, 被生者倍率1.7 (不对称 — 被生者收益更大).
	"""
	var result: Dictionary = {
		"a_modifier": 1.0,
		"b_modifier": 1.0,
		"qi_multiplier": 1.0,
		"description": "",
	}

	if element_a == 0 or element_b == 0:
		return result

	var relation: int = Constants.get_element_relation(element_a, element_b)
	if relation == Constants.ElementRelation.NEUTRAL or relation == Constants.ElementRelation.SAME:
		return result

	match relation:
		Constants.ElementRelation.GENERATES:
			# a生b: a(生者)收益小, b(被生者)收益大
			result["a_modifier"] = 1.3
			result["b_modifier"] = 1.7
			result["qi_multiplier"] = 1.5
			result["description"] = "%s 生 %s — 灵气流动倍增!" % [
				Constants.element_name(element_a),
				Constants.element_name(element_b)
			]

		Constants.ElementRelation.GENERATED_BY:
			# b生a: a(被生者)收益大, b(生者)收益小
			result["a_modifier"] = 1.7
			result["b_modifier"] = 1.3
			result["qi_multiplier"] = 1.5
			result["description"] = "%s 生 %s — 灵气流动倍增!" % [
				Constants.element_name(element_b),
				Constants.element_name(element_a)
			]

		Constants.ElementRelation.OVERCOMES:
			# a克b: a(克者)保持, b(被克者)减弱
			result["a_modifier"] = 1.0
			result["b_modifier"] = 0.5
			result["qi_multiplier"] = 0.7
			result["description"] = "%s 克 %s — 灵气相冲减弱!" % [
				Constants.element_name(element_a),
				Constants.element_name(element_b)
			]

		Constants.ElementRelation.OVERCOME_BY:
			# b克a: a(被克者)减弱, b(克者)保持
			result["a_modifier"] = 0.5
			result["b_modifier"] = 1.0
			result["qi_multiplier"] = 0.7
			result["description"] = "%s 克 %s — 灵气相冲减弱!" % [
				Constants.element_name(element_b),
				Constants.element_name(element_a)
			]

	return result


## Resolve collision between two elements on a pathway.
## Returns damage info.
static func resolve_at_pathway(element_a: int, element_b: int, from_idx: int, to_idx: int) -> Dictionary:
	"""
	Returns: {should_damage: bool, damage_turns: int, description: String}
	"""
	var result: Dictionary = {
		"should_damage": false,
		"damage_turns": 3,
		"description": "",
	}

	if element_a == 0 or element_b == 0:
		return result

	var relation: int = Constants.get_element_relation(element_a, element_b)
	if relation == Constants.ElementRelation.NEUTRAL or relation == Constants.ElementRelation.SAME:
		return result

	if relation == Constants.ElementRelation.OVERCOMES or relation == Constants.ElementRelation.OVERCOME_BY:
		result["should_damage"] = true
		result["description"] = "%s 克 %s — 经脉受损!" % [
			Constants.element_name(element_a),
			Constants.element_name(element_b)
		]

	return result


## Resolve all collisions among active techniques at nodes with qi.
## Bug 2&3 fix: qi_boost/qi_dampen accumulate multiplicatively instead of overwriting.
## Bug 7 fix: use technique_qi to check if both techniques actually have qi at each node.
static func resolve_all(
	techniques: Array,
	active_nodes: Array,  # node indices with qi
	meridian: MeridianMapData
) -> CollisionResult:
	var cr: CollisionResult = CollisionResult.new()

	if techniques.size() < 2:
		return cr

	for i: int in techniques.size():
		for j: int in range(i + 1, techniques.size()):
			var tech_i = techniques[i]
			var tech_j = techniques[j]
			var tid_i: String = tech_i.get("id") if typeof(tech_i) == TYPE_OBJECT else ""
			var tid_j: String = tech_j.get("id") if typeof(tech_j) == TYPE_OBJECT else ""
			var elem_a: int = tech_i.get_element_int()
			var elem_b: int = tech_j.get_element_int()

			# Check nodes with qi from BOTH techniques (Bug 7 fix)
			for node_idx: int in active_nodes:
				var node: MeridianNodeData = meridian.get_node(node_idx)
				if node == null:
					continue

				# Bug 7: Only trigger collision if both techniques have qi at this node
				var tech_qi: Dictionary = node.technique_qi if node.technique_qi else {}
				if not tid_i.is_empty() and not tid_j.is_empty():
					var qi_i: float = tech_qi.get(tid_i, 0.0)
					var qi_j: float = tech_qi.get(tid_j, 0.0)
					if qi_i <= 0.001 or qi_j <= 0.001:
						continue

				var r: Dictionary = resolve_at_node(elem_a, elem_b)
				if r["qi_multiplier"] != 1.0:
					# Bug 3 fix: merge into existing dict instead of replacing
					if not cr.node_modifiers.has(node_idx):
						cr.node_modifiers[node_idx] = {}
					# Bug 3 fix: multiply with existing modifier (accumulate)
					var existing_i: float = cr.node_modifiers[node_idx].get(i, 1.0)
					var existing_j: float = cr.node_modifiers[node_idx].get(j, 1.0)
					cr.node_modifiers[node_idx][i] = existing_i * r["a_modifier"]
					cr.node_modifiers[node_idx][j] = existing_j * r["b_modifier"]

					# Bug 2 fix: accumulate multiplicatively instead of overwriting
					if r["qi_multiplier"] > 1.0:
						var prev_boost: float = cr.qi_boost.get(node_idx, 1.0)
						cr.qi_boost[node_idx] = prev_boost * r["qi_multiplier"]
					else:
						var prev_dampen: float = cr.qi_dampen.get(node_idx, 1.0)
						cr.qi_dampen[node_idx] = prev_dampen * r["qi_multiplier"]

					if not r["description"].is_empty():
						cr.descriptions.append(r["description"])

			# Check pathway collisions (apply damage)
			# Bug 7 fix: Only damage pathways where both techniques' qi flows
			for pw in meridian.pathways:
				if pw.current_qi <= 0:
					continue

				# Check if both techniques have qi on this pathway
				var pw_tech_qi: Dictionary = pw.technique_qi if pw.technique_qi else {}
				if not tid_i.is_empty() and not tid_j.is_empty():
					var pw_qi_i: float = pw_tech_qi.get(tid_i, 0.0)
					var pw_qi_j: float = pw_tech_qi.get(tid_j, 0.0)
					if pw_qi_i <= 0.001 or pw_qi_j <= 0.001:
						continue

				var rp: Dictionary = resolve_at_pathway(elem_a, elem_b, pw.from_node, pw.to_node)
				if rp["should_damage"]:
					cr.damaged_pathways.append({
						"from": pw.from_node,
						"to": pw.to_node,
						"turns": rp["damage_turns"],
					})
					if not rp["description"].is_empty():
						cr.descriptions.append(rp["description"])

	return cr
