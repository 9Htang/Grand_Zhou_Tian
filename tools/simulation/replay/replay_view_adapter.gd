# ============================================================
# 大周天 — ReplayViewAdapter (回放 UI 适配器)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 将 SimulationEvent 映射为 BattleScene 上的动画调用。
# 不做任何逻辑 — 纯 Event → Animation Call 转发。
#
# 事件→动画映射:
#   "card_played"        → play_card_anim(event.payload)
#   "damage_dealt"       → play_damage_anim(event.target_id, amount)
#   "qi_generated"       → play_qi_anim(event.actor_id, amount)
#   "qi_consumed"        → play_qi_anim(event.actor_id, -amount)
#   "heal_received"      → play_heal_anim(event.actor_id, amount)
#   "technique_activated" → play_technique_anim(event.source)
#
# 所有调用用 has_method() 守卫 — 动画方法不存在时优雅降级。
# ============================================================
class_name ReplayViewAdapter
extends RefCounted


## 将事件应用到场景节点
func apply_event(event: SimulationEvent, scene: Node) -> void:
	if scene == null or event == null:
		return

	match event.type:
		"card_played":
			if scene.has_method("play_card_anim"):
				scene.play_card_anim(event.payload)

		"damage_dealt":
			var amount: int = event.payload.get("amount", 0)
			if scene.has_method("play_damage_anim"):
				scene.play_damage_anim(event.target_id, amount)

		"qi_generated":
			var qi_amount: int = event.payload.get("amount", 0)
			if scene.has_method("play_qi_anim"):
				scene.play_qi_anim(event.actor_id, qi_amount)

		"qi_consumed":
			var qi_cost: int = event.payload.get("amount", 0)
			if scene.has_method("play_qi_anim"):
				scene.play_qi_anim(event.actor_id, -qi_cost)

		"heal_received":
			var heal_amount: int = event.payload.get("amount", 0)
			if scene.has_method("play_heal_anim"):
				scene.play_heal_anim(event.actor_id, heal_amount)

		"technique_activated":
			if scene.has_method("play_technique_anim"):
				scene.play_technique_anim(event.source)

		_:
			pass  # 不支持的事件类型 — 静默跳过
