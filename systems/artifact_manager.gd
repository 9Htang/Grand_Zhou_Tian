class_name ArtifactManager
extends RefCounted

enum Trigger {
	ON_TURN_START = 0,
	ON_CARD_PLAY = 1,
	ON_DAMAGE_TAKEN = 2,
	ON_QI_CIRCULATE = 3,
	ON_BATTLE_START = 4,
	ALWAYS = 5,
	ON_ATTACK_PLAYED = 6,
	ON_DEFENSE_PLAYED = 7,
}


static func trigger(artifacts: Array[ArtifactData], gm: Node, trigger_type: int, context: Dictionary = {}) -> void:
	for artifact: ArtifactData in artifacts:
		if artifact.get_trigger_int() == trigger_type or artifact.get_trigger_int() == Trigger.ALWAYS:
			if not artifact.condition.is_empty():
				if not _check_condition(gm, artifact.condition, context):
					continue
			if not artifact.effect.is_empty():
				EffectResolver.apply(gm, artifact.effect)


static func _check_condition(gm: Node, condition: String, context: Dictionary) -> bool:
	var parts: PackedStringArray = condition.split(":")
	if parts.size() < 2:
		return true
	match parts[0]:
		"hp_below": return gm.player_hp < int(parts[1])
		"hp_above": return gm.player_hp > int(parts[1])
		"realm": return gm.realm >= int(parts[1])
		"talent": return gm.talent >= int(parts[1])
		"has_artifact":
			for a in gm.artifacts:
				if a.id == parts[1]:
					return true
			return false
		"first_turn": return context.get("turn_count", 0) <= 1
	return true


## Convenience wrappers — called from battle_screen / GameManager

static func on_battle_start(gm: Node) -> void:
	trigger(gm.artifacts, gm, Trigger.ON_BATTLE_START)


static func on_turn_start(gm: Node, turn_count: int) -> void:
	trigger(gm.artifacts, gm, Trigger.ON_TURN_START, {"turn_count": turn_count})


static func on_card_play(gm: Node, card: CardData) -> void:
	trigger(gm.artifacts, gm, Trigger.ON_CARD_PLAY, {"card": card})
	if card.card_type == 0:
		trigger(gm.artifacts, gm, Trigger.ON_ATTACK_PLAYED, {"card": card})
	elif card.card_type == 1:
		trigger(gm.artifacts, gm, Trigger.ON_DEFENSE_PLAYED, {"card": card})


static func on_damage_taken(gm: Node, amount: int) -> void:
	trigger(gm.artifacts, gm, Trigger.ON_DAMAGE_TAKEN, {"damage": amount})


static func on_qi_circulate(gm: Node) -> void:
	trigger(gm.artifacts, gm, Trigger.ON_QI_CIRCULATE)


## 被动法宝轮询（每回合在回合开始时调用）
## 按顺序遍历法宝列表，每个被动/挂载型法宝消耗 qi_per_turn 灵气
## 灵气不够则跳过该法宝，继续判断下一个
static func poll_passive(gm: Node, turn_count: int) -> void:
	for artifact: ArtifactData in gm.artifacts:
		if artifact.artifact_type == "passive" or artifact.artifact_type == "active_mount":
			# 检查灵气是否足够
			if artifact.qi_per_turn > 0:
				if not gm.spend_qi(artifact.qi_per_turn):
					continue  # 灵气不够，跳过此法宝
			# 检查触发条件
			if not artifact.condition.is_empty():
				if not _check_condition(gm, artifact.condition, {"turn_count": turn_count}):
					continue
			# 执行法宝效果
			if not artifact.effect.is_empty():
				EffectResolver.apply(gm, artifact.effect)


## 回合开始时为充能型法宝积蓄灵气
static func charge_artifacts(gm: Node, amount: int) -> void:
	for artifact: ArtifactData in gm.artifacts:
		if artifact.artifact_type == "active_charge":
			artifact.charge_stored += amount


## 获取主动法宝对应的卡牌数据（用于生成法宝牌）
static func get_artifact_card(artifact_id: String) -> CardData:
	var art: ArtifactData = ArtifactRegistry.get_artifact(artifact_id)
	if not art:
		return null
	var card: CardData = CardData.new()
	card.id = "artifact_" + art.id
	card.display_name = art.display_name
	card.description = art.description
	card.card_type = CardData.CardType.ARTIFACT_CARD
	card.rarity = CardData.CardRarity.RARE
	card.cost = 0 if art.artifact_type == "active_charge" else art.qi_per_turn
	card.elixir_effect = art.effect

	match art.artifact_type:
		"active_mount": card.behavior = CardData.CardBehavior.MOUNT_ARTIFACT
		"active_charge": card.behavior = CardData.CardBehavior.CHARGE_ARTIFACT
		"active_container": card.behavior = CardData.CardBehavior.CONTAINER
		_: card.behavior = CardData.CardBehavior.NORMAL

	if not art.container_contents.is_empty():
		card.container_contents = art.container_contents.duplicate()
		card.container_types = art.container_types.duplicate()

	return card
