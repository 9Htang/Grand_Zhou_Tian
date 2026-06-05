# ============================================================
# 大周天 — Enemy Intents (敌人意图执行)
# 所有游戏状态访问统一经过 EffectContext → Domain Service
# ============================================================
class_name EnemyIntents
extends RefCounted


## 加权随机选择敌人行动
static func select_action(enemy_data: EnemyData) -> EnemyActionData:
	if enemy_data.actions.is_empty():
		return null

	var total_weight := 0
	for action in enemy_data.actions:
		total_weight += action.weight

	if total_weight == 0:
		return enemy_data.actions[0]

	var roll := randi() % total_weight
	var cumulative := 0
	for action in enemy_data.actions:
		cumulative += action.weight
		if roll < cumulative:
			return action

	return enemy_data.actions[-1]


## 获取意图展示文本
static func get_intent_text(action: EnemyActionData) -> String:
	match action.intent:
		0: return "攻击 %d" % action.damage
		1: return "连击 %d×2" % action.damage
		2: return "防御 %d" % action.block
		3: return "强化"
		4: return "削弱"
		5: return "封穴"
		6: return "断脉"
		7: return "吸灵"
	return "?"


## 通过 EnemyAI 选择行动
static func select_action_weighted(actor: EnemyActor, opponent: CombatActor, data: EnemyData) -> EnemyActionData:
	return EnemyAI.select_action(actor, opponent, data)


## 获取意图图标颜色
static func get_intent_color(intent: int) -> Color:
	match intent:
		0, 1: return Color(1, 0, 0)
		2: return Color(0.118, 0.565, 1)
		3: return Color(0, 1, 0)
		4: return Color(0.5, 0, 0.5)
		5, 6: return Color(1, 0.5, 0)
		7: return Color(0, 1, 1)
	return Color(0.5, 0.5, 0.5)


## 执行敌人行动意图 — 通过 EffectContext 访问所有域
## ctx.actor=玩家(受击方), ctx.primary_target=敌人(行动方)
static func execute_intent(action: EnemyActionData, ctx: EffectContext) -> Array[String]:
	var logs: Array[String] = []

	# 检查敌人弱势状态
	var weak_amount: int = 0
	if ctx.enemy.has_status("weak"):
		weak_amount = ctx.enemy.get_status_amount("weak")

	match action.intent:
		EnemyActionData.IntentType.ATTACK, EnemyActionData.IntentType.ATTACK_MULTI:
			var raw_dmg: int = action.damage + ctx.enemy.get_strength()
			var dmg: int = DamageCalculation.enemy_damage(
				raw_dmg, ctx.query.get_actor_realm(), ctx.query.get_opponent_realm())

			if ctx.query.actor_has_buff("vulnerable"):
				dmg = int(float(dmg) * 1.5)

			dmg = max(0, dmg - weak_amount)
			ctx.enemy.damage_player(dmg)
			logs.append(ctx.enemy.get_display_name() + " 攻击造成 " + str(dmg) + " 伤害")

			var counter_val: float = ctx.query.get_actor_node_property("counter")
			if counter_val > 0.0:
				ctx.enemy.set_hp(max(0, ctx.enemy.get_hp() - int(counter_val)))
				logs.append(" 反击 " + str(int(counter_val)))

			var reflect_pct: float = ctx.query.get_actor_node_property("reflect")
			if reflect_pct > 0.0:
				var reflect_dmg: int = max(1, int(float(dmg) * reflect_pct / 100.0))
				ctx.enemy.set_hp(max(0, ctx.enemy.get_hp() - reflect_dmg))
				logs.append(" 反伤 " + str(reflect_dmg))

		EnemyActionData.IntentType.DEFEND:
			ctx.enemy.add_block(action.block)
			logs.append(ctx.enemy.get_display_name() + " 防御 +" + str(action.block))

		EnemyActionData.IntentType.BUFF_SELF:
			if not action.buff_self.is_empty():
				var parts: PackedStringArray = action.buff_self.split(":")
				if parts.size() >= 2:
					match parts[0]:
						"strength":
							ctx.enemy.add_strength(int(parts[1]))
							logs.append(ctx.enemy.get_display_name() + " 力量 +" + parts[1])
						_:
							logs.append(ctx.enemy.get_display_name() + " 强化")
				else:
					logs.append(ctx.enemy.get_display_name() + " 强化")
			else:
				logs.append(ctx.enemy.get_display_name() + " 强化")

		EnemyActionData.IntentType.DEBUFF_PLAYER:
			if not action.debuff_player.is_empty():
				var parts: PackedStringArray = action.debuff_player.split(":")
				if parts.size() >= 2:
					match parts[0]:
						"weak":
							ctx.query.add_buff_to_actor("weak", int(parts[1]), "enemy")
							logs.append(ctx.enemy.get_display_name() + " 虚弱玩家 (-" + parts[1] + " 伤害)")
						"energy_down":
							ctx.enemy.drain_player_qi(int(parts[1]))
							logs.append(ctx.enemy.get_display_name() + " 吸取灵气 " + parts[1])
						_:
							logs.append(ctx.enemy.get_display_name() + " 削弱玩家")
			else:
				logs.append(ctx.enemy.get_display_name() + " 削弱玩家")

		EnemyActionData.IntentType.SEAL_MERIDIAN:
			var sealed: String = ctx.enemy.seal_meridian_node()
			if not sealed.is_empty():
				logs.append(ctx.enemy.get_display_name() + " 封穴 " + sealed)
			else:
				logs.append(ctx.enemy.get_display_name() + " 封穴 (无有效目标)")

		EnemyActionData.IntentType.DAMAGE_PATHWAY:
			var pw: Dictionary = ctx.enemy.damage_meridian_pathway()
			if not pw.is_empty():
				logs.append(ctx.enemy.get_display_name() + " 断脉 " + str(pw["from"]) + "->" + str(pw["to"]))
			else:
				logs.append(ctx.enemy.get_display_name() + " 断脉 (无经脉)")

		EnemyActionData.IntentType.DRAIN_QI:
			var drain_amount: int = action.damage
			if drain_amount <= 0:
				drain_amount = 3
			var actual: float = ctx.enemy.drain_qi(float(drain_amount))
			logs.append(ctx.enemy.get_display_name() + " 吸灵 " + str(int(actual)) + " 点")
			if not action.debuff_player.is_empty():
				var parts: PackedStringArray = action.debuff_player.split(":")
				if parts.size() >= 2 and parts[0] == "energy_down":
					ctx.enemy.drain_player_qi(int(parts[1]))

		_:
			logs.append(ctx.enemy.get_display_name() + " " + get_intent_text(action))

	return logs
