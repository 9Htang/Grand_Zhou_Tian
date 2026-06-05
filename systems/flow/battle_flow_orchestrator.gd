# ============================================================
# 大周天 — BattleFlowOrchestrator (战斗流程编排器 — L2)
# 职责: 卡牌行为分类 + 路由决策 + Context 构建时机控制
# 唯一入口 play_card() — 处理所有卡牌类型 (功法/丹药/法宝/容器/锻造/通用)
# L1 调用 play_card() → 得到 FlowResult → 转发给 BattleScreen
# L1 不再知道: pathway/forge/container 的存在, Context 生命周期
# ============================================================
class_name BattleFlowOrchestrator
extends RefCounted


# ============================================================
# FlowResult — 告诉 L1 "发生了什么", 而非 "该怎么做"
# ============================================================

class FlowResult:
	## 卡牌是否成功打出
	var played: bool = false
	## 流程类型: ""=失败 | "normal"=普通 | "pathway"=路径选择 | "forge"=锻造
	var flow_type: String = ""
	## 锻造类型 (仅 forge 流程)
	var forge_type: String = ""

	## 转为 BattleScreen 兼容的 Dictionary
	func to_dict() -> Dictionary:
		var d: Dictionary = {"played": played, "success": played}
		match flow_type:
			"pathway":
				d["awaiting_pathway"] = true
			"forge":
				d["awaiting_forge"] = true
				d["forge_type"] = forge_type
		return d


# ============================================================
# Injected References (由 BattleBootstrapper 注入)
# ============================================================

var player: PlayerActor = null
## TODO: screen 引用仅用于 _handle_technique_overflow — 应改为 signal
var screen: Node = null
var deck_manager: DeckManager = null
var forge_service: ForgeService = null
var pathway_service: PathwayService = null
var card_play_service: CardPlayService = null
var context_factory: BattleContextFactory = null


# ============================================================
# Card Play — 唯一入口 (所有卡牌类型)
# ============================================================


## 打出卡牌: 行为分类 → 路由到正确的 L2 Service
## elapsed_seconds: 即时制战斗经过秒数 (由调用方从 GameManager 读取后传入)
## 返回 FlowResult — L1 不解析内部字段, 直接 to_dict() 转发
func play_card(card_data: CardData, elapsed_seconds: float) -> FlowResult:
	# 1. 检查打出条件
	if not card_data.play_condition.is_empty():
		if not _check_play_condition(card_data):
			return FlowResult.new()

	# 2. 穴位特性: 减灵气消耗
	var qi_eff: float = NodePropertyResolver.get_active_property_total(player, "qi_efficiency")
	var effective_cost: int = max(0, card_data.cost - int(qi_eff))

	if not QiPoolManager.can_afford(player, effective_cost):
		return FlowResult.new()

	QiPoolManager.spend(player, effective_cost)
	ArtifactManager.trigger(player.artifacts, player, ArtifactManager.Trigger.ON_CARD_PLAY, {"card": card_data})

	# 3. 确定卡牌去向
	var destination: String = _get_destination(card_data)
	var flow := FlowResult.new()
	flow.played = true

	# 4. 功法卡: 经脉路径选择 或 直接激活
	if card_data.behavior == CardData.CardBehavior.TECHNIQUE:
		var tech_result: Dictionary = _handle_technique(card_data)
		if tech_result.get("awaiting_pathway", false):
			pathway_service.start_selection(card_data)
			flow.flow_type = "pathway"
			return flow
		# 直接激活 (敌人/无路径系统) → 卡牌消耗
		deck_manager.exhaust_card(card_data)
		flow.flow_type = "normal"
		return flow

	# 5. 丹药卡: 应用 elixir_effect 字符串
	if card_data.card_type == CardData.CardType.ELIXIR:
		_handle_elixir(card_data)

	# 6. 法宝卡: 挂载/充能
	if card_data.behavior in [CardData.CardBehavior.MOUNT_ARTIFACT, CardData.CardBehavior.CHARGE_ARTIFACT]:
		_handle_artifact_card(card_data)

	# 7. 持续增益技能: 挂载到 GameManager
	if card_data.behavior == CardData.CardBehavior.PERSISTENT_SKILL:
		if player.has_method("add_persistent_skill"):
			player.add_persistent_skill(card_data)

	# 8. 容器型: 展开内容物
	var container_cards: Array[CardData] = []
	if card_data.behavior == CardData.CardBehavior.CONTAINER:
		container_cards = _expand_container(card_data)

	# 9. 锻造型: 消耗卡牌 + 启动锻造多步选择
	if card_data.behavior == CardData.CardBehavior.FORGE:
		var forge_type: String = card_data.elixir_effect
		if forge_type.is_empty():
			forge_type = card_data.id
		deck_manager.exhaust_card(card_data)
		forge_service.start_forge(card_data, forge_type)
		flow.flow_type = "forge"
		flow.forge_type = forge_type
		return flow

	# 10. 容器内容物加入手牌
	for cc in container_cards:
		deck_manager.hand.append(cc)

	# 11. 通用卡牌 → 效果执行流水线
	var ctx: BattleContext = context_factory.build(elapsed_seconds)
	card_play_service.execute(card_data, destination, ctx)
	flow.flow_type = "normal"
	return flow


# ============================================================
# Play Condition 检查
# ============================================================


## 检查卡牌打出条件
## 格式: "realm>=N;talent>=N;has_technique:id" (分号分隔)
func _check_play_condition(card_data: CardData) -> bool:
	var condition: String = card_data.play_condition
	if condition.is_empty():
		return true

	for cond: String in condition.split(";"):
		cond = cond.strip_edges()
		if cond.begins_with("has_technique:"):
			var tech_id: String = cond.trim_prefix("has_technique:")
			var has_it: bool = false
			for tech in player.active_techniques:
				var td: TechniqueData = tech as TechniqueData
				if td and td.id == tech_id:
					has_it = true
					break
			if not has_it:
				return false
		elif cond.begins_with("realm>="):
			var val: int = int(cond.trim_prefix("realm>="))
			if player.realm < val:
				return false
		elif cond.begins_with("talent>="):
			var val: int = int(cond.trim_prefix("talent>="))
			if player.talent < val:
				return false

	return true


# ============================================================
# Destination Mapping
# ============================================================


## 根据行为标记返回卡牌去向
## NORMAL→discard, 其余→exhaust
func _get_destination(card_data: CardData) -> String:
	match card_data.behavior:
		CardData.CardBehavior.NORMAL: return "discard"
		CardData.CardBehavior.TECHNIQUE: return "exhaust"
		CardData.CardBehavior.PERSISTENT_SKILL: return "exhaust"
		CardData.CardBehavior.MOUNT_ARTIFACT: return "exhaust"
		CardData.CardBehavior.CHARGE_ARTIFACT: return "exhaust"
		CardData.CardBehavior.CONTAINER: return "exhaust"
		CardData.CardBehavior.FORGE: return "exhaust"
	return "discard"


# ============================================================
# Technique — 功法激活协议
# ============================================================


## 处理功法卡打出
## 返回 {"awaiting_pathway": bool}
func _handle_technique(card_data: CardData) -> Dictionary:
	var tech: TechniqueData = TechniqueDatabase.get_technique(card_data.technique_id)
	if not tech:
		return {"awaiting_pathway": false}

	# 功法槽已满 → 通知 UI 选择替换
	if player.active_techniques.size() >= player.talent:
		if screen and screen.has_method("_handle_technique_overflow"):
			screen._handle_technique_overflow(tech)
		return {"awaiting_pathway": false}

	# 检查是否需要经脉路径选择
	if player.has_method("get_dantian_adjacent_nodes"):
		var available: Array = player.get_dantian_adjacent_nodes()
		if available.is_empty():
			player.activate_technique(tech)
			return {"awaiting_pathway": false}
		return {"awaiting_pathway": true}

	# 无路径系统 (敌人/旧数据) → 直接激活
	player.activate_technique(tech)
	return {"awaiting_pathway": false}


# ============================================================
# Elixir — 丹药效果
# ============================================================


## 应用丹药效果字符串 (通过旧 DSL 兼容层)
func _handle_elixir(card_data: CardData) -> void:
	if card_data.elixir_effect.is_empty():
		return
	if card_data.elixir_use_location == 0 or card_data.elixir_use_location == 2:
		EffectResolver.apply(player, card_data.elixir_effect)


# ============================================================
# Artifact Card — 主动法宝牌
# ============================================================


## 法宝卡处理: 挂载 或 充能
func _handle_artifact_card(card_data: CardData) -> void:
	match card_data.behavior:
		CardData.CardBehavior.MOUNT_ARTIFACT:
			_apply_mount_artifact(card_data)
		CardData.CardBehavior.CHARGE_ARTIFACT:
			_apply_charge_artifact(card_data)


## 挂载型法宝: 打出后挂载到遗物栏
func _apply_mount_artifact(card_data: CardData) -> void:
	var art: ArtifactData = ArtifactRegistry.get_artifact(card_data.id)
	if not art:
		art = ArtifactData.new()
		art.id = card_data.id
		art.display_name = card_data.display_name
		art.description = card_data.description
		art.artifact_type = "active_mount"
		art.trigger = "always"
		art.qi_per_turn = card_data.cost
		art.effect = card_data.elixir_effect
	player.artifacts.append(art)


## 充能型法宝: 消耗充能进行免费攻击
func _apply_charge_artifact(card_data: CardData) -> void:
	var art: ArtifactData = ArtifactRegistry.get_artifact(card_data.id)
	if art and art.charge_stored >= art.charge_cost:
		art.charge_stored -= art.charge_cost
		if not card_data.elixir_effect.is_empty():
			EffectResolver.apply(player, card_data.elixir_effect)


# ============================================================
# Container — 容器展开
# ============================================================


## 展开容器: 将内容物卡牌加入手牌
func _expand_container(card_data: CardData) -> Array[CardData]:
	var result: Array[CardData] = []
	for content_id: String in card_data.container_contents:
		var content_card: CardData = CardDatabase.get_card(content_id)
		if content_card:
			result.append(content_card)
	return result
