# ============================================================
# 大周天 — CardEffects (卡牌效果结算)
# ============================================================
class_name CardEffects
extends RefCounted


## 结算卡牌效果，返回 Dictionary:
##   success: bool — 是否成功打出
##   destination: String — "discard" / "exhaust" / "none"
##   container_cards: Array[CardData] — CONTAINER 型展开的卡牌
static func apply(gm: Node, card: CardData, battle_context: Node) -> Dictionary:
	# 穴位特性：减灵气消耗
	var qi_eff: float = NodePropertyResolver.get_active_property_total(gm, "qi_efficiency")
	var effective_cost: int = max(0, card.cost - int(qi_eff))

	if not QiPoolManager.can_afford(gm, effective_cost):
		return {"success": false, "destination": "", "container_cards": []}

	QiPoolManager.spend(gm, effective_cost)
	ArtifactManager.trigger(gm.artifacts, gm, ArtifactManager.Trigger.ON_CARD_PLAY, {"card": card})

	# 根据行为标记决定目标
	var destination: String = _get_destination(card)

	match card.card_type:
		CardData.CardType.ATTACK: _apply_attack(gm, card, battle_context)
		CardData.CardType.DEFENSE: _apply_defense(gm, card, battle_context)
		CardData.CardType.SKILL: _apply_skill(gm, card, battle_context)
		CardData.CardType.TECHNIQUE: _apply_technique(gm, card, battle_context)
		CardData.CardType.QI_GATHER: _apply_qi_gather(gm, card, battle_context)
		CardData.CardType.ELIXIR: _apply_elixir(gm, card, battle_context)
		CardData.CardType.ARTIFACT_CARD: _apply_artifact_card(gm, card, battle_context)

	# 容器型：展开内容物
	var container_cards: Array[CardData] = []
	if card.behavior == CardData.CardBehavior.CONTAINER:
		container_cards = _expand_container(gm, card)

	return {"success": true, "destination": destination, "container_cards": container_cards}


## 根据行为标记返回卡牌去向
static func _get_destination(card: CardData) -> String:
	match card.behavior:
		CardData.CardBehavior.NORMAL: return "discard"
		CardData.CardBehavior.TECHNIQUE: return "exhaust"
		CardData.CardBehavior.PERSISTENT_SKILL: return "exhaust"
		CardData.CardBehavior.MOUNT_ARTIFACT: return "exhaust"
		CardData.CardBehavior.CHARGE_ARTIFACT: return "exhaust"
		CardData.CardBehavior.CONTAINER: return "exhaust"
	return "discard"


# ============================================================
# Attack
# ============================================================

static func _apply_attack(gm: Node, card: CardData, ctx: Node) -> void:
	var base_dmg: int = card.damage
	for tech: TechniqueData in gm.active_techniques:
		base_dmg = int(float(base_dmg) * tech.attack_multiplier)

	base_dmg = DamageCalculation.calculate(base_dmg, gm.realm, gm.active_buffs)

	var has_multi: bool = NodePropertyResolver.has_active_property(gm, "multi_target")
	var targets_all: bool = has_multi or card.target_type == CardData.TargetType.ALL_ENEMIES

	var enemies: Array = ctx.enemies
	var targets: Array = enemies if targets_all else [ctx.get_target_enemy()]

	var pierce: float = NodePropertyResolver.get_active_property_total(gm, "pierce")

	for target in targets:
		if target == null:
			continue
		var hp: int = target.hp
		var block: int = target.current_block
		var final_dmg: int = base_dmg

		var effective_block: int = max(0, block - int(pierce))

		if effective_block > 0:
			var reduced: int = min(final_dmg, effective_block)
			target.current_block = block - reduced
			final_dmg -= reduced
		else:
			target.current_block = 0

		target.hp = max(0, hp - final_dmg)

		_apply_node_debuffs_on_hit(gm, target, ctx)

		var life_steal_pct: float = NodePropertyResolver.get_active_property_total(gm, "life_steal")
		if life_steal_pct > 0.0:
			var heal_amount: int = max(1, int(float(final_dmg) * life_steal_pct))
			gm.heal(heal_amount)

		for tech: TechniqueData in gm.active_techniques:
			if not tech.attack_bonus.is_empty():
				_apply_bonus(gm, tech.attack_bonus, target, ctx)


# ============================================================
# Defense
# ============================================================

static func _apply_defense(gm: Node, card: CardData, _ctx: Node) -> void:
	var base_block: int = card.block
	for tech: TechniqueData in gm.active_techniques:
		base_block = int(float(base_block) * tech.defense_multiplier)
	base_block += _sum_buffs(gm.active_buffs, "defense_up")
	gm.current_block += base_block


# ============================================================
# Skill
# ============================================================

static func _apply_skill(gm: Node, card: CardData, ctx: Node) -> void:
	if card.heal > 0:
		gm.heal(card.heal)
	if card.draw_count > 0:
		if ctx.has_method("draw_cards"):
			ctx.draw_cards(card.draw_count)
	if not card.buff_self.is_empty():
		gm.add_buff(card.buff_self)
	if not card.debuff_enemy.is_empty():
		var target: Node = ctx.get_target_enemy()
		if target and ctx.has_method("add_enemy_status"):
			ctx.add_enemy_status(target, card.debuff_enemy)

	# 持续增益技能：挂载到 GameManager
	if card.behavior == CardData.CardBehavior.PERSISTENT_SKILL:
		if gm.has_method("add_persistent_skill"):
			gm.add_persistent_skill(card)


# ============================================================
# Technique
# ============================================================

static func _apply_technique(gm: Node, card: CardData, ctx: Node) -> void:
	var tech: TechniqueData = TechniqueDatabase.get_technique(card.technique_id)
	if not tech:
		return
	if gm.active_techniques.size() >= gm.talent:
		ctx._handle_technique_overflow(tech)
		return
	gm.activate_technique(tech)


# ============================================================
# Qi Gather
# ============================================================

static func _apply_qi_gather(gm: Node, card: CardData, _ctx: Node) -> void:
	QiPoolManager.gather_active(gm, card.qi_gather_amount)


# ============================================================
# Elixir
# ============================================================

static func _apply_elixir(gm: Node, card: CardData, _ctx: Node) -> void:
	if card.elixir_effect.is_empty():
		return
	if card.elixir_use_location == 0 or card.elixir_use_location == 2:
		EffectResolver.apply(gm, card.elixir_effect)
	if card.heal > 0:
		gm.heal(card.heal)


# ============================================================
# Artifact Card (主动法宝牌)
# ============================================================

static func _apply_artifact_card(gm: Node, card: CardData, ctx: Node) -> void:
	match card.behavior:
		CardData.CardBehavior.MOUNT_ARTIFACT:
			_apply_mount_artifact(gm, card)
		CardData.CardBehavior.CHARGE_ARTIFACT:
			_apply_charge_artifact(gm, card)
		CardData.CardBehavior.CONTAINER:
			pass  # 容器展开在主 apply 中处理
		_:
			pass


## 挂载型法宝：打出后挂载到遗物栏
static func _apply_mount_artifact(gm: Node, card: CardData) -> void:
	var art: ArtifactData = ArtifactRegistry.get_artifact(card.id)
	if not art:
		# 没有预定义法宝数据，从卡牌数据即时创建
		art = ArtifactData.new()
		art.id = card.id
		art.display_name = card.display_name
		art.description = card.description
		art.artifact_type = "active_mount"
		art.trigger = "always"
		art.qi_per_turn = card.cost
		art.effect = card.elixir_effect
	gm.artifacts.append(art)


## 充能型法宝：消耗充能进行免费攻击
static func _apply_charge_artifact(gm: Node, card: CardData) -> void:
	var art: ArtifactData = ArtifactRegistry.get_artifact(card.id)
	if art and art.charge_stored >= art.charge_cost:
		art.charge_stored -= art.charge_cost
		if not card.elixir_effect.is_empty():
			EffectResolver.apply(gm, card.elixir_effect)


## 展开容器：将内容物卡牌加入手牌
static func _expand_container(gm: Node, card: CardData) -> Array[CardData]:
	var result: Array[CardData] = []
	for content_id: String in card.container_contents:
		var content_card: CardData = CardDatabase.get_card(content_id)
		if content_card:
			result.append(content_card)
	return result


# ============================================================
# Helpers
# ============================================================

static func _sum_buffs(buffs: Array, buff_name: String) -> int:
	var total: int = 0
	for buff in buffs:
		if buff.name == buff_name:
			total += int(buff.value)
	return total


## 穴位特性：攻击命中时对目标施加 debuff
static func _apply_node_debuffs_on_hit(gm: Node, target: Node, ctx: Node) -> void:
	if not ctx.has_method("add_enemy_status"):
		return

	var burn_total: float = NodePropertyResolver.get_active_property_total(gm, "apply_burn")
	if burn_total > 0.0:
		ctx.add_enemy_status(target, "burn:%d:2" % int(burn_total))

	var vuln_total: float = NodePropertyResolver.get_active_property_total(gm, "apply_vulnerable")
	if vuln_total > 0.0:
		ctx.add_enemy_status(target, "vulnerable:%d" % int(vuln_total))

	var weak_total: float = NodePropertyResolver.get_active_property_total(gm, "apply_weak")
	if weak_total > 0.0:
		ctx.add_enemy_status(target, "weak:1:%d" % int(weak_total))


## 技法攻击奖励
static func _apply_bonus(gm: Node, bonus_str: String, target: Node, ctx: Node) -> void:
	var parts: PackedStringArray = bonus_str.split(":")
	if parts.size() < 2:
		return
	match parts[0]:
		"burn":
			if ctx.has_method("add_enemy_status"):
				var turns: int = int(parts[2]) if parts.size() >= 3 else 2
				ctx.add_enemy_status(target, "burn:%s:%d" % [parts[1], turns])
		"block":
			gm.current_block += int(parts[1])
