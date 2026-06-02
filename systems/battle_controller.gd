# ============================================================
# 大周天 — BattleController (战斗流程编排器)
# ============================================================
# 职责: FSM驱动、回合流程、系统调度
# 不负责: UI构建/刷新、场景跳转、输入事件
# 所有方法均无 await — 异步延迟由 BattleScreen 处理
# ============================================================
class_name BattleController
extends RefCounted


# === References (set by BattleScreen after creation) ===
var screen: Node = null                       # BattleScreen (CanvasLayer)
var player: PlayerActor = null
var enemies: Array[EnemyActor] = []
var deck_manager: DeckManager = null
var fsm: BattleStateMachine = null
var current_encounter: EncounterData = null
var current_target: int = 0
var _last_collision = null                    # QiCollisionResolver.CollisionResult
var card_trigger_router: CardTriggerRouter = null  # 卡牌触发器路由器
var target_manager: TargetManager = null             # 目标选择调度器

# === Pathway Selection State ===
var pending_technique_card: CardData = null     # 等待路径选择的功法卡
var pathway_selection_from: int = -1            # 路径起点穴位索引

# === 两阶段执行状态 (Resolver.step 遇到 selector 时) ===
var _pending_runtime: CardRuntime = null         # 等待目标选择的执行上下文
var _pending_battle_ctx: BattleContext = null    # 等待中的战斗上下文


# ============================================================
# Initialization
# ============================================================

func initialize(p_screen: Node, p_player: PlayerActor, p_fsm: BattleStateMachine) -> void:
	screen = p_screen
	player = p_player
	fsm = p_fsm


# ============================================================
# Pathway Selection (功法经脉路径选择)
# ============================================================

## 进入路径选择模式 — 功法卡暂不激活，等待玩家点击穴位
func start_pathway_selection(card_data: CardData) -> void:
	pending_technique_card = card_data
	pathway_selection_from = -1


## 玩家点击穴位 — 第一次选起点，第二次选终点
## 返回: -1=无效点击, 0=已选起点等待终点, 1=完成绑定
func select_pathway_node(node_idx: int) -> int:
	if pending_technique_card == null:
		return -1

	if pathway_selection_from < 0:
		# 第一次点击：必须是丹田邻接穴位
		var adjacent: Array = player.get_dantian_adjacent_nodes()
		if not adjacent.has(node_idx):
			return -1
		pathway_selection_from = node_idx
		return 0  # 等待终点选择

	# 第二次点击：终点穴位（不能和起点相同）
	if node_idx == pathway_selection_from:
		return -1
	var card: CardData = pending_technique_card
	bind_technique_to_pathway(card, pathway_selection_from, node_idx)
	pending_technique_card = null
	pathway_selection_from = -1
	return 1  # 完成


## 取消路径选择 — 功法卡回手牌
func cancel_pathway_selection() -> void:
	if pending_technique_card == null:
		return
	deck_manager.cancel_technique(pending_technique_card)
	pending_technique_card = null
	pathway_selection_from = -1


## 绑定功法到路径并激活 + 消耗卡牌
func bind_technique_to_pathway(card: CardData, from_idx: int, to_idx: int) -> void:
	var tech: TechniqueData = TechniqueDatabase.get_technique(card.technique_id)
	if tech == null:
		return
	player.bind_technique_to_pathway(tech.id, from_idx, to_idx)
	player.activate_technique(tech)
	deck_manager.exhaust_card(card)


# ============================================================
# Battle Start / End
# ============================================================

## 加载 encounter 并初始化牌库，踢 FSM 进入 PRE_BATTLE
## 返回: encounter 是否加载成功
func start_battle() -> bool:
	current_encounter = _load_encounter()
	if current_encounter == null:
		return false

	deck_manager = DeckManager.new()
	deck_manager.initialize(player.master_deck.duplicate())

	# 初始化卡牌触发器路由
	var trigger_ctx: BattleContext = BattleContext.new()
	trigger_ctx.actor = player
	trigger_ctx.turn_count = GameManager.turn_count
	card_trigger_router = CardTriggerRouter.new(trigger_ctx)
	deck_manager.trigger_router = card_trigger_router

	# 根据丹田容量初始化经脉路径容量
	if player.base_meridian:
		QiFlowSystem.init_pathway_capacities(player)

	# 初始化目标选择调度器
	target_manager = TargetManager.new()
	target_manager.selection_completed.connect(_on_target_selection_completed)

	fsm.transition_to(BattleStateMachine.BattleState.PRE_BATTLE)
	return true


## 从当前地图节点读取 encounter_id 并加载 EncounterData
func _load_encounter() -> EncounterData:
	var chapter: ChapterData = GameManager.current_chapter_data
	var enc_id: String = "ch1_encounter_1"  # fallback
	if chapter != null:
		var node_idx: int = GameManager.current_map_node_index
		if node_idx >= 0 and node_idx < chapter.map_nodes.size():
			var node = chapter.map_nodes[node_idx]
			if not node.encounter_id.is_empty():
				enc_id = node.encounter_id
	var path: String = "res://resources/encounter_data/" + enc_id + ".tres"
	if ResourceLoader.exists(path):
		return load(path) as EncounterData
	return null


# ============================================================
# Turn Flow (FSM Handlers)
# ============================================================

## TURN_START → PLAYER_TURN
## 聚气 + 法宝被动轮询
func execute_turn_start() -> void:
	QiPoolManager.gather_passive(player)
	ArtifactManager.poll_passive(player, GameManager.turn_count)
	ArtifactManager.on_turn_start(player, GameManager.turn_count)
	ArtifactManager.charge_artifacts(player, player.qi_gather_rate)
	fsm.transition_to(BattleStateMachine.BattleState.PLAYER_TURN)


## PLAYER_TURN → PLAYER_ACTION
## 抽牌（含抽牌惩罚 + 额外抽牌）
func execute_player_turn() -> void:
	var effective_draw: int = deck_manager.get_effective_draw_count(5)
	deck_manager.draw_to_hand_size(effective_draw)
	deck_manager.clear_draw_penalty()

	var extra_draw: float = NodePropertyResolver.get_active_property_total(player, "extra_draw")
	if extra_draw > 0:
		deck_manager.draw_cards(int(extra_draw))

	# 更新触发器上下文的回合计数
	if card_trigger_router and card_trigger_router.context:
		card_trigger_router.context.turn_count = GameManager.turn_count

	fsm.transition_to(BattleStateMachine.BattleState.PLAYER_ACTION)


## QI_CIRCULATION → ENEMY_TURN
## 运行玩家灵气循环，返回碰撞描述文本
func execute_qi_circulation() -> String:
	run_qi_circulation()
	var log_text: String = ""
	if _last_collision and not _last_collision.descriptions.is_empty():
		log_text = "碰撞: " + ", ".join(_last_collision.descriptions)
	fsm.transition_to(BattleStateMachine.BattleState.ENEMY_TURN)
	return log_text


## ENEMY_TURN → ENEMY_ACTION
## 执行所有敌人行动，返回 log 文本
func execute_enemy_turn() -> String:
	var log_entries: Array[String] = []
	for enemy in enemies:
		var actor: EnemyActor = enemy
		if actor == null:
			continue

		# Find EnemyData from the screen's enemy_container
		var data: EnemyData = _find_enemy_data(actor)
		if data == null:
			continue

		var action: EnemyActionData = EnemyAI.select_action(actor, player, data)
		if action == null:
			continue

		log_entries.append(EnemyAI.describe_decision(actor, action))

		# Execute intent via EnemyIntents
		var result_logs: Array[String] = EnemyIntents.execute_intent(action, actor, player)
		log_entries.append_array(result_logs)

	if log_entries.is_empty():
		return "无"
	return ", ".join(log_entries)


## 从 screen 的 enemy_container 中查找敌人对应的 EnemyData
func _find_enemy_data(actor: EnemyActor) -> EnemyData:
	if screen == null:
		return null
	var container: Node = screen.get("enemy_container")
	if container == null:
		return null
	for child in container.get_children():
		var panel_data: EnemyData = child.get_meta("enemy_data")
		if panel_data and child.get_meta("actor") == actor:
			return panel_data
	return null


## ENEMY_QI_CIRCULATION → TURN_END
## 运行敌人灵气循环
func execute_enemy_qi_circulation() -> void:
	for enemy in enemies:
		var actor: EnemyActor = enemy
		if actor == null:
			continue
		if actor.active_techniques.is_empty() or actor.base_meridian == null:
			continue
		if actor.erosion_targets.is_empty():
			EnemyAI.select_erosion_targets(actor)
		run_qi_circulation_for_actor(actor)
	fsm.transition_to(BattleStateMachine.BattleState.TURN_END)


## TURN_END → TURN_START (或 BATTLE_WON/BATTLE_LOST)
## 检查胜负、tick 经脉损伤、清 buff、处理状态、弃牌
func execute_turn_end() -> Dictionary:
	# Check battle end first
	if player.hp <= 0:
		fsm.transition_to(BattleStateMachine.BattleState.BATTLE_LOST)
		return {"state": "lost"}

	var all_dead := true
	for enemy in enemies:
		if enemy.hp > 0:
			all_dead = false
			break
	if all_dead:
		fsm.transition_to(BattleStateMachine.BattleState.BATTLE_WON)
		return {"state": "won"}

	# Tick meridian damage timers
	MeridianDamageSystem.tick_damage_timers(player)
	for enemy in enemies:
		MeridianDamageSystem.tick_damage_timers(enemy)

	# Clear card buffs, reset block
	player.clear_card_buffs()
	player.current_block = 0

	# Process enemy statuses (burn tick / debuff countdown) — handled by screen
	# Consume pending effects
	var pending: Array = player.get_meta("pending_effects", [])
	var pending_log: String = ""
	for effect in pending:
		match effect["type"]:
			"burn":
				pending_log += "灼烧" + str(effect.get("value", 0))
			"draw_card":
				deck_manager.draw_cards(effect["value"])
	player.set_meta("pending_effects", [])

	deck_manager.discard_hand()
	# NOTE: FSM transition to TURN_START happens in BattleScreen after status processing

	return {"state": "continue", "pending_log": pending_log, "pending_effects": pending}


## 战斗胜利 — 同步状态、发奖励、返回跳转目标
func execute_battle_won() -> Dictionary:
	player.save_to_gm()
	GameManager.add_cultivation(current_encounter.cultivation_reward)
	GameManager.gold += current_encounter.gold_reward

	# Check if boss node → go to reward, else → map
	var chapter: ChapterData = GameManager.current_chapter_data
	var is_boss: bool = false
	if chapter != null:
		var current_idx: int = GameManager.current_map_node_index
		if current_idx >= 0 and current_idx < chapter.map_nodes.size():
			var node = chapter.map_nodes[current_idx]
			if node.node_type == 5:  # MapNodeData.NodeType.BOSS
				is_boss = true

	return {"is_boss": is_boss}


## 战斗失败 — 同步状态
func execute_battle_lost() -> void:
	player.save_to_gm()


## 检查胜负条件（卡牌打出后调用）
func check_battle_end() -> int:  # Returns: 0=continue, 1=won, 2=lost
	var all_dead := true
	for enemy in enemies:
		if enemy.hp > 0:
			all_dead = false
			break
	if all_dead:
		fsm.transition_to(BattleStateMachine.BattleState.BATTLE_WON)
		return 1

	if player.hp <= 0:
		fsm.transition_to(BattleStateMachine.BattleState.BATTLE_LOST)
		return 2

	return 0


# ============================================================
# Card Play
# ============================================================

## 打出一张卡牌，返回结果供 UI 处理
func play_card(card_data: CardData) -> Dictionary:
	var result: Dictionary = CardEffects.apply(player, card_data, screen)

	if not result.get("success", false):
		return {"played": false}

	# 功法卡需要选择经脉路径 → 进入两阶段选择
	if result.get("awaiting_pathway", false):
		start_pathway_selection(card_data)
		return {"played": true, "awaiting_pathway": true}

	# 根据行为标记路由卡牌去向
	var destination: String = result.get("destination", "discard")
	match destination:
		"discard":
			deck_manager.play_card(card_data)
		"exhaust":
			deck_manager.exhaust_card(card_data)
		_:
			pass

	# 容器展开：内容物卡牌加入手牌
	var container_cards: Array = result.get("container_cards", [])
	for cc: CardData in container_cards:
		deck_manager.hand.append(cc)

	return {"played": true, "container_cards": container_cards}


# ============================================================
# Resolver-based Effect Execution (base_effects 路径)
# ============================================================


## 使用 Resolver.begin()+step() 执行 base_effects 卡牌
## 支持 selector → TargetManager 两阶段选择
func execute_effect_graph(card_data: CardData) -> Dictionary:
	# 构建 CardRuntime
	var runtime: CardRuntime = CardFactory.create_runtime_direct(card_data.id)
	if runtime.effect_graph.is_empty():
		return {"played": false, "reason": "empty effect graph"}

	var ctx: BattleContext = _build_battle_context()

	# Step 1-6: 初始化
	var init_result: BattleResult = Resolver.begin(runtime, ctx)
	if not init_result.executed:
		return {"played": false, "reason": init_result.failure_reason}

	# Step 7: 循环执行
	return _resolve_loop(runtime, ctx)


func _resolve_loop(runtime: CardRuntime, ctx: BattleContext) -> Dictionary:
	var result: BattleResult = Resolver.step(runtime, ctx)

	if result.waiting:
		# 挂起等待目标选择
		_pending_runtime = runtime
		_pending_battle_ctx = ctx
		target_manager.request(result.selector, ctx)
		return {"played": true, "awaiting_selection": true, "selector": result.selector}

	if result.completed:
		# 完成 → 路由卡牌
		var dest: String = CardEffects._get_destination(runtime.base_data)
		match dest:
			"discard": deck_manager.play_card(runtime.base_data)
			"exhaust": deck_manager.exhaust_card(runtime.base_data)
		return {"played": true}

	# 继续循环（无 selector 时自动执行所有节点）
	if result.executed:
		return _resolve_loop(runtime, ctx)

	return {"played": false, "reason": "unknown state"}


func _on_target_selection_completed(_selector: Dictionary, selected: Array) -> void:
	if _pending_runtime == null:
		return

	# 将选择结果写入 runtime
	var plan: ExecutionPlan = _pending_runtime.execution_plan
	var node_id: String = plan.order[_pending_runtime.step_pc]
	_pending_runtime.selected_targets[node_id] = selected

	# 恢复执行
	var result: Dictionary = _resolve_loop(_pending_runtime, _pending_battle_ctx)

	# 如果不再等待（完成），清理状态
	if not result.get("awaiting_selection", false):
		_pending_runtime = null
		_pending_battle_ctx = null

		if screen and screen.has_method("_on_effect_execution_done"):
			screen._on_effect_execution_done(result)


func _build_battle_context() -> BattleContext:
	var ctx: BattleContext = BattleContext.new()
	ctx.actor = player
	ctx.turn_count = GameManager.turn_count
	ctx.realm = player.realm
	ctx.talent = player.talent
	if not enemies.is_empty():
		ctx.opponent = enemies[current_target]
	return ctx


## 处理卡牌拖放到功法区
func activate_technique_via_card(card_data: CardData) -> Dictionary:
	if card_data.card_type != CardData.CardType.TECHNIQUE:
		return {"success": false}

	var result: Dictionary = CardEffects.apply(player, card_data, screen)
	if result.get("success", false):
		var dest: String = result.get("destination", "discard")
		if dest == "exhaust":
			deck_manager.exhaust_card(card_data)
		else:
			deck_manager.play_card(card_data)
		return {"success": true}
	return {"success": false}


## 取消功法，返回卡牌到手牌
func cancel_technique(tech: TechniqueData) -> bool:
	if not deck_manager.can_cancel(5):
		return false
	player.deactivate_technique(tech)
	var card_id: String = "technique_" + tech.id
	var card: CardData = CardDatabase.get_card(card_id)
	if card:
		deck_manager.cancel_technique(card)
	return true


# ============================================================
# Qi Circulation
# ============================================================

## 对玩家运行完整灵气循环
func run_qi_circulation() -> void:
	run_qi_circulation_for_actor(player)


## 通用灵气循环（玩家或敌人都可用）
func run_qi_circulation_for_actor(actor: CombatActor) -> void:
	var meridian: MeridianMapData = actor.base_meridian
	if meridian == null:
		return

	var techniques: Array = actor.active_techniques

	# 灵气持久流动 — 不清零！回路中的灵气跨回合保持
	# 只清理断流无回路时的微量残留
	if actor.active_circuits.is_empty() and actor.dantian_qi <= 0:
		QiFlowSystem.clear_flow_state(actor)

	# 流量追踪：累积每个穴位本回合流经的灵气量，用于 buff 生成
	var flow_tracker: Dictionary = {}

	# Fluid tick loop: inject -> propagate -> erode -> deliver
	const MAX_TICKS: int = 20
	for _i in range(MAX_TICKS):
		var tick_result: Dictionary = QiFlowSystem.tick(actor, flow_tracker)
		var new_circuits: Array = tick_result.get("circuits_formed", [])
		if not new_circuits.is_empty():
			for circuit in new_circuits:
				actor.circuit_formed.emit(circuit)
		# Unlock feedback — BattleScreen handles UI via screen reference
		var unlocked_names: Array = tick_result.get("nodes_unlocked", [])
		if not unlocked_names.is_empty() and actor is PlayerActor:
			for node_name in unlocked_names:
				for j: int in meridian.nodes.size():
					var mn: MeridianNodeData = meridian.nodes[j]
					if mn and mn.name == node_name:
						if screen and screen.has_method("notify_node_unlocked"):
							screen.notify_node_unlocked(j)
						break
		if tick_result.get("is_dry", false):
			break
		if not tick_result.get("flow_moved", false):
			break

	actor.is_flow_dry = QiPoolManager.get_remaining(actor) <= 0

	# Collect active nodes
	var active_nodes: Array[int] = []
	for i: int in meridian.nodes.size():
		var node: MeridianNodeData = meridian.get_node(i)
		if node and node.current_qi > 0 and node.unlocked and not node.blocked:
			active_nodes.append(i)

	# Collision resolution
	var collision = null
	if techniques.size() >= 2 and not active_nodes.is_empty():
		collision = QiCollisionResolver.resolve_all(techniques, active_nodes, meridian)
		for dmg in collision.damaged_pathways:
			MeridianDamageSystem.damage_pathway(actor, dmg["from"], dmg["to"], dmg.get("turns", 3))

	# Save collision for meridian view (player only)
	if actor is PlayerActor:
		_last_collision = collision

	# Buff generation (linear scaling)
	actor.clear_technique_buffs()

	# 保存卡牌/效果来源的 buff，避免被功法 buff 覆盖
	var card_buffs: Array = []
	for buff in actor.active_buffs:
		card_buffs.append(buff)

	var tech_buffs: Array = TechniqueResolver.resolve_network_buffs(
		techniques, meridian, actor.node_base_buffs, collision, flow_tracker
	)
	# 合并功法 buff + 卡牌 buff，功法在前（优先消费）
	tech_buffs.append_array(card_buffs)
	actor.active_buffs = tech_buffs

	# Consume generated buffs (含功法 + 卡牌)
	_consume_buffs(actor, tech_buffs)

	ArtifactManager.on_qi_circulate(actor)


## 消费运环生成的 buff
func _consume_buffs(actor: CombatActor, buffs: Array) -> void:
	for buff in buffs:
		match buff.name:
			"burn":
				# Player-originated burn applies to enemies
				if actor is PlayerActor:
					for enemy in enemies:
						EnemyStatusSystem.apply(enemy, "burn:" + str(buff.value) + ":2")
			"draw_card":
				if actor is PlayerActor:
					deck_manager.draw_cards(buff.value)
			"heal":
				actor.heal(buff.value)
			"block":
				actor.current_block += buff.value
			"energy_up":
				actor.add_qi(buff.value)
			"energy_down":
				actor.spend_qi(buff.value)
			"self_damage":
				actor.take_damage(buff.value)


# ============================================================
# Target Selection
# ============================================================

## 获取当前目标的 EnemyActor（供 CardEffects 调用）
func get_target_enemy() -> EnemyActor:
	if enemies.is_empty():
		return null
	if current_target >= enemies.size():
		current_target = 0
	return enemies[current_target]
