# ============================================================
# 大周天 — Providers (目标提供者体系)
# 统一接口: get_targets(selector, battle) → Array
# 每个 Provider 负责一种目标类型的合法目标枚举
# ============================================================


# ============================================================
# BaseProvider — 抽象基类
# ============================================================

class_name BaseProvider
extends RefCounted


## 返回合法目标列表
## selector: EffectNode.selector — {"type": "...", "count": 1, ...}
## battle: BattleContext — 当前战斗上下文
## 返回: Array[Dictionary] — 每个 target 包含标识字段
func get_targets(selector: Dictionary, battle: BattleContext) -> Array:
	return []


# ============================================================
# PathProvider — 经脉路径
# ============================================================

class PathProvider extends RefCounted:
	## 返回可操作的经脉路径列表
	## target: {"from": int, "to": int, "from_name": str, "to_name": str, "capacity": float, "width": float}
	func get_targets(selector: Dictionary, battle: BattleContext) -> Array:
		var result: Array = []
		if battle == null or battle.actor == null:
			return result

		var gm: Node = battle.actor
		if not gm.has_method("get") or gm.get("base_meridian") == null:
			return result

		var meridian: MeridianMapData = gm.base_meridian
		for pw in meridian.pathways:
			if pw == null:
				continue
			# 筛出可操作的路径: 未损坏 && 未阻塞
			if pw.damaged or pw.blocked:
				continue
			var from_node: MeridianNodeData = meridian.get_node(pw.from_node)
			var to_node: MeridianNodeData = meridian.get_node(pw.to_node)
			result.append({
				"from": pw.from_node,
				"to": pw.to_node,
				"from_name": from_node.name if from_node else "?",
				"to_name": to_node.name if to_node else "?",
				"capacity": pw.max_capacity,
				"base_capacity": pw.base_capacity,
				"width": pw.width,
				"current_qi": pw.current_qi,
			})
		return result


# ============================================================
# NodeProvider — 穴位
# ============================================================

class NodeProvider extends RefCounted:
	## 返回可操作的穴位列表
	## target: {"idx": int, "name": str, "unlocked": bool, "blocked": bool, ...}
	func get_targets(selector: Dictionary, battle: BattleContext) -> Array:
		var result: Array = []
		if battle == null or battle.actor == null:
			return result

		var gm: Node = battle.actor
		if not gm.has_method("get") or gm.get("base_meridian") == null:
			return result

		var meridian: MeridianMapData = gm.base_meridian
		for i: int in meridian.nodes.size():
			var node: MeridianNodeData = meridian.get_node(i)
			if node == null:
				continue
			# 默认: 返回未阻塞的穴位（解锁和未解锁都返回，由 Validator 决定）
			if node.blocked:
				continue
			result.append({
				"idx": i,
				"name": node.name,
				"unlocked": node.unlocked,
				"blocked": node.blocked,
				"current_qi": node.current_qi,
				"capacity": node.capacity,
				"element": node.element,
				"erosion_progress": node.erosion_progress,
			})
		return result


# ============================================================
# CardProvider — 卡牌 (手牌/抽牌堆/弃牌堆/耗尽堆)
# ============================================================

class CardProvider extends RefCounted:
	## selector.pool: "hand" / "draw" / "discard" / "exhaust" / "all"
	## target: {"card": CardData, "zone": str, "index": int}
	func get_targets(selector: Dictionary, battle: BattleContext) -> Array:
		var result: Array = []
		if battle == null:
			return result

		var pool: String = selector.get("pool", "hand")

		# deck_manager 通过 battle.actor 间接访问 — 由 BattleScreen 提供
		# v1: 返回空，后续由 BattleController 注入 deck 引用后实现
		return result


# ============================================================
# EnemyProvider — 敌人
# ============================================================

class EnemyProvider extends RefCounted:
	## target: {"actor": EnemyActor, "hp": int, "block": int, "index": int}
	func get_targets(selector: Dictionary, battle: BattleContext) -> Array:
		var result: Array = []
		if battle == null or battle.opponent == null:
			return result

		# 单敌人: 直接返回 opponent
		var opp: Node = battle.opponent
		result.append({
			"actor": opp,
			"hp": opp.get("hp") if opp.get("hp") != null else 0,
			"block": opp.get("current_block") if opp.get("current_block") != null else 0,
			"index": 0,
		})
		return result


# ============================================================
# FieldProvider — 卡牌字段 (damage/cost/block/draw/...)
# ============================================================

class FieldProvider extends RefCounted:
	## target: {"field": str} — 字段名
	func get_targets(selector: Dictionary, battle: BattleContext) -> Array:
		# 返回可操作的卡牌字段列表
		var fields: Array = [
			{"field": "damage", "label": "伤害"},
			{"field": "block", "label": "格挡"},
			{"field": "heal", "label": "治疗"},
			{"field": "cost", "label": "消耗"},
			{"field": "draw_count", "label": "抽牌"},
			{"field": "qi_gather_amount", "label": "聚气"},
		]
		return fields


# ============================================================
# EffectNodeProvider — 效果节点 (用于删除/复制/插入/交换)
# ============================================================

class EffectNodeProvider extends RefCounted:
	## 返回当前卡牌 EffectGraph 中的 EffectNode 列表
	## 需要 card_runtime 引用 — v1 返回空
	func get_targets(selector: Dictionary, battle: BattleContext) -> Array:
		return []


# ============================================================
# TechniqueProvider — 功法
# ============================================================

class TechniqueProvider extends RefCounted:
	## target: {"technique": TechniqueData, "id": str}
	func get_targets(selector: Dictionary, battle: BattleContext) -> Array:
		var result: Array = []
		if battle == null or battle.actor == null:
			return result

		var techniques: Array = battle.actor.get("active_techniques")
		if techniques == null:
			return result

		for tech in techniques:
			var td: TechniqueData = tech
			if td == null:
				continue
			result.append({
				"technique": td,
				"id": td.id,
				"display_name": td.display_name,
			})
		return result


