# ============================================================
# 大周天 — SimulationRunner (模拟战斗主循环)
# ============================================================
# 工具层: tools/simulation/ — 不属于四层运行时架构
#
# 调用真实战斗系统 (BattleBootstrapper → Services → VM → Runtime)。
# 不做任何战斗计算 — 只做调度、delta 适配、事件采集、自动 AI。
#
# 原则:
#   模拟器必须调用真实战斗系统 — player.play_card() 而非自己算伤害
#   Actor state signal → Runner delta 适配 → EventRecorder → Report
#   事件以施加者为中心: actor_id=谁做的, target_id=对谁做的
# ============================================================
class_name SimulationRunner
extends RefCounted


# ============================================================
# Constants
# ============================================================

## 默认 Tick 步长 (20 TPS)
const DEFAULT_TICK: float = 0.05

## 初始手牌数
const INITIAL_HAND_SIZE: int = 5

## 状态日志输出间隔 (tick 数)
const LOG_INTERVAL: int = 20


# ============================================================
# State
# ============================================================

## 事件采集器
var _recorder: EventRecorder = null

## Actor 状态缓存: {actor_id: {"hp": int, "qi": int}}
var _state_cache: Dictionary = {}

## 当前战斗时间 (秒)
var _current_time: float = 0.0

## Tick 序号 (用于每 N tick 的慢速操作)
var _tick_number: int = 0

## 玩家引用 (供信号 handler 使用, 不用 .bind)
var _player: PlayerActor = null

## 灵气循环引用 (供信号 handler 使用)
var _qi_circulation: QiCirculationService = null

## win_loss_monitor 发出的终止标志
var _battle_ended: bool = false


# ============================================================
# Public API
# ============================================================


## 运行单场模拟
## player: 玩家角色 (从 GameManager 或测试夹具获取)
## config: 模拟参数 (遭遇ID、时长、种子等)
## 返回 SimulationReport
func run(player: PlayerActor, config: SimulationConfig) -> SimulationReport:
	_recorder = EventRecorder.new()
	_state_cache.clear()
	_current_time = 0.0
	_tick_number = 0
	_battle_ended = false
	_player = player

	# 1. 固定随机种子 — 创建确定性 RNG
	var _rng := DeterministicRNG.new(config.seed)

	# 2. 创建 MockScreen — 满足 screen 接口的空壳
	var screen := MockScreen.new()

	# 3. 标准 Bootstrapper — 创建全部 L2 Service，注入 RNG
	var fsm := BattleStateMachine.new()
	var br: BattleBootstrapper.BootResult = BattleBootstrapper.bootstrap(screen, player, fsm, 0.0, _rng, config.encounter_id)
	if br == null:
		return _empty_report(false)

	# 从 config 配置自动抽牌参数
	if config.draw_interval > 0.0:
		br.auto_draw_system.draw_interval = config.draw_interval
	br.auto_draw_system.draw_count = config.draw_count if config.draw_count > 0 else 1

	_qi_circulation = br.qi_circulation

	# 4. 从 EncounterData 创建敌人
	var enemies: Array[EnemyActor] = _spawn_enemies(br)

	# 5. 将敌人注入到需要它们的 Service
	_wire_enemies_to_services(br, enemies)

	# 6. 注册敌人到计时器系统
	_register_enemy_timers(br, enemies)

	# 7. 初始抽牌
	br.deck_manager.draw_cards(INITIAL_HAND_SIZE)

	# 8. 接线 Recorder 到所有 Actor 信号 (delta 适配层)
	_wire_recorder("player", player)
	for i in enemies.size():
		_wire_recorder("enemy_" + str(i), enemies[i])

	# 9. 接线敌人行动信号 — 不用 .bind(), handler 直接读 _player / _qi_circulation
	if not br.enemy_timer_system.enemy_action_ready.is_connected(_on_enemy_action):
		br.enemy_timer_system.enemy_action_ready.connect(_on_enemy_action)
	if not br.enemy_timer_system.enemy_qi_circulation_ready.is_connected(_on_enemy_qi):
		br.enemy_timer_system.enemy_qi_circulation_ready.connect(_on_enemy_qi)

	# 10. 接线胜负信号 (提前终止)
	if not br.win_loss_monitor.battle_ended.is_connected(_on_battle_ended):
		br.win_loss_monitor.battle_ended.connect(_on_battle_ended)

	# 11. 初始化状态缓存
	_cache_actor_state("player", player)
	for i in enemies.size():
		_cache_actor_state("enemy_" + str(i), enemies[i])

	# 12. 主循环
	var tick_rate: float = config.tick_rate if config.tick_rate > 0.0 else DEFAULT_TICK

	while _current_time < config.duration:
		# 驱动时钟 (advance 是统一业务入口)
		br.battle_clock.advance(tick_rate)

		# Tick 分发 — 复制 BattleController._on_clock_tick 的调度逻辑
		_tick_systems(player, enemies, br, tick_rate)

		# 自动出牌
		if config.auto_play_enabled:
			_auto_play(player, br)

		_current_time += tick_rate
		_tick_number += 1

		# 每 tick 检查 qi 浪费
		_estimate_qi_waste("player", player, tick_rate)
		for i in enemies.size():
			_estimate_qi_waste("enemy_" + str(i), enemies[i], tick_rate)

		# 每 LOG_INTERVAL tick 输出状态快照
		if _tick_number % LOG_INTERVAL == 0:
			_log_state(br)

		# 提前终止检测
		if _battle_ended:
			break
		if player.hp <= 0:
			break
		if _all_enemies_dead(enemies):
			break

	# 断开信号 (避免内存泄漏)
	_disconnect_all(player, enemies, br)

	# 13. 生成报告
	var won := player.hp > 0 and _all_enemies_dead(enemies)
	return SimulationReport.from_recorder(_recorder, won, _current_time)


# ============================================================
# Enemy Spawning
# ============================================================


func _spawn_enemies(br: BattleBootstrapper.BootResult) -> Array[EnemyActor]:
	var enemies: Array[EnemyActor] = []
	if br.encounter == null:
		return enemies

	# enemy_ids → EnemyData (与 battle_flow_view.spawn_enemies 相同流程)
	for enemy_id in br.encounter.enemy_ids:
		var enemy_data: EnemyData = EnemyDatabase.get_enemy(enemy_id)
		if enemy_data == null:
			push_warning("SimulationRunner: enemy not found — %s" % enemy_id)
			continue
		var enemy := EnemyActor.new()
		enemy.name = "EnemyActor_" + enemy_data.display_name
		enemy.initialize_from_data(enemy_data)
		enemies.append(enemy)

	return enemies


# ============================================================
# Service Wiring
# ============================================================


func _wire_enemies_to_services(br: BattleBootstrapper.BootResult, enemies: Array[EnemyActor]) -> void:
	br.context_factory.enemies = enemies
	br.snapshot_service.enemies = enemies
	br.win_loss_monitor.set_enemies(enemies)


func _register_enemy_timers(br: BattleBootstrapper.BootResult, enemies: Array[EnemyActor]) -> void:
	if br.encounter == null:
		return
	for i in enemies.size():
		if i < br.encounter.enemy_ids.size():
			var enemy_data: EnemyData = EnemyDatabase.get_enemy(br.encounter.enemy_ids[i])
			if enemy_data:
				br.enemy_timer_system.add_enemy(enemies[i], enemy_data)


# ============================================================
# Tick Dispatch
# ============================================================


func _tick_systems(player: PlayerActor, enemies: Array[EnemyActor], br: BattleBootstrapper.BootResult, delta: float) -> void:
	# 1. 灵气连续回复
	QiRegenSystem.tick_actor(player, delta)
	QiRegenSystem.tick_enemies(enemies, delta)

	# 2. 灵气流动
	if br.qi_circulation:
		br.qi_circulation.run_one_tick(player)
		for enemy in enemies:
			if enemy and enemy.hp > 0 and enemy.active_techniques.size() > 0:
				br.qi_circulation.run_one_tick(enemy)

	# 3. 卡牌冷却递减
	if br.cooldown_manager:
		var expired: Array[String] = br.cooldown_manager.tick(delta)
		br.deck_manager.process_expired_cooldowns(expired)

	# 4. 敌人计时器递减 (内部调用 EnemyAI.select_action + 发射信号)
	if br.enemy_timer_system:
		br.enemy_timer_system.tick(delta)

	# 5. Buff 实时衰减 (每 4 ticks ≈ 1s 执行一次)
	if _tick_number % BattleClock.TICKS_PER_SECOND == 0:
		var clock_delta: float = delta * float(BattleClock.TICKS_PER_SECOND)
		RealtimeBuffSystem.tick_player_buffs(player, clock_delta)
		RealtimeBuffSystem.tick_enemy_statuses(enemies, clock_delta)

	# 6. 效果队列推进
	if br.effect_queue:
		br.effect_queue.execute_next(delta)

	# 7. 每秒慢速检测 (法宝/胜负)
	if _tick_number > 0 and _tick_number % int(1.0 / max(delta, 0.001)) == 0:
		ArtifactManager.poll_passive(player, _tick_number)
		ArtifactManager.charge_artifacts(player, player.qi_gather_rate)
		br.win_loss_monitor.check()


# ============================================================
# Auto-Play AI (贪心: 打出第一张可用的手牌)
# ============================================================


func _auto_play(player: PlayerActor, br: BattleBootstrapper.BootResult) -> void:
	var hand: Array[CardData] = br.deck_manager.hand
	if hand.is_empty():
		return

	for card in hand:
		if card == null:
			continue
		# 通过 FlowOrchestrator 打出 (真实战斗路径)
		var result: BattleFlowOrchestrator.FlowResult = br.flow_orchestrator.play_card(card, _current_time)
		if result.flow_type == "pathway":
			_auto_complete_pathway(player, br)
		if result.played:
			_recorder.record(_current_time, "card_played", "player", "", card.id, {
	"card_name": card.display_name, "cost": card.cost,
	"hand_index": hand.find(card), "target_index": -1,
	"source_type": "INPUT"
})
			return  # 每 tick 最多打一张


## 自动完成功法路径选择: 起点=第一个丹田邻接节点, 终点=第一个可用节点
func _auto_complete_pathway(player: PlayerActor, br: BattleBootstrapper.BootResult) -> void:
	var adjacent: Array = player.get_dantian_adjacent_nodes()
	if adjacent.is_empty():
		br.pathway_service.cancel()
		return

	var from_idx: int = adjacent[0]
	br.pathway_service.select_node(from_idx)  # 返回 0=等待终点

	# 选第一个非起点的已解锁节点作为终点
	var mer: MeridianMapData = player.base_meridian
	if mer:
		for node in mer.nodes:
			if node and node.unlocked and node.id != from_idx:
				br.pathway_service.select_node(node.id)  # 返回 1=完成绑定
				return

	# 无可用终点 → 取消
	br.pathway_service.cancel()


# ============================================================
# Signal Wiring — Delta Adaptation Layer
# ============================================================


func _wire_recorder(actor_id: String, actor: CombatActor) -> void:
	if not actor.hp_changed.is_connected(_on_hp_changed.bind(actor_id, actor)):
		actor.hp_changed.connect(_on_hp_changed.bind(actor_id, actor))
	if not actor.qi_changed.is_connected(_on_qi_changed.bind(actor_id, actor)):
		actor.qi_changed.connect(_on_qi_changed.bind(actor_id, actor))
	if not actor.technique_activated.is_connected(_on_technique_activated):
		actor.technique_activated.connect(_on_technique_activated.bind(actor_id))
	if not actor.buffs_updated.is_connected(_on_buffs_updated):
		actor.buffs_updated.connect(_on_buffs_updated.bind(actor_id))


func _cache_actor_state(actor_id: String, actor: CombatActor) -> void:
	_state_cache[actor_id] = {"hp": actor.hp, "qi": actor.dantian_qi}


func _on_hp_changed(_new_hp: int, _max_hp: int, actor_id: String, actor: CombatActor) -> void:
	var prev: Dictionary = _state_cache.get(actor_id, {"hp": actor.hp, "qi": actor.dantian_qi})
	var prev_hp: int = prev.get("hp", actor.hp)
	var delta: int = actor.hp - prev_hp
	_state_cache[actor_id]["hp"] = actor.hp

	if delta < 0:
		# 此 actor 受到伤害 — 施害者未知 (Phase 1 限制)
		# 如果 actor 是 enemy → 伤害来自 player; 如果 actor 是 player → 伤害来自 enemy
		_recorder.record(_current_time, "damage_dealt", "", actor_id, "", {"amount": -delta, "new_hp": actor.hp})
	elif delta > 0:
		_recorder.record(_current_time, "heal_received", actor_id, actor_id, "", {"amount": delta, "new_hp": actor.hp})


func _on_qi_changed(_new_qi: int, _max_qi: int, actor_id: String, actor: CombatActor) -> void:
	var prev: Dictionary = _state_cache.get(actor_id, {"hp": actor.hp, "qi": actor.dantian_qi})
	var prev_qi: int = prev.get("qi", actor.dantian_qi)
	var delta: int = actor.dantian_qi - prev_qi
	_state_cache[actor_id]["qi"] = actor.dantian_qi

	# qi_state snapshot — 用于追踪最高灵气值
	_recorder.record(_current_time, "qi_state", actor_id, "", "", {"new_qi": actor.dantian_qi, "max_qi": actor.dantian_capacity})

	if delta < 0:
		_recorder.record(_current_time, "qi_consumed", actor_id, "", "", {"amount": -delta, "new_qi": actor.dantian_qi})
	elif delta > 0:
		_recorder.record(_current_time, "qi_generated", actor_id, "", "", {"amount": delta, "new_qi": actor.dantian_qi})


func _on_technique_activated(tech: TechniqueData, actor_id: String) -> void:
	_recorder.record(_current_time, "technique_activated", actor_id, "", tech.id, {"tech_name": tech.display_name})


func _on_buffs_updated(buffs: Array, actor_id: String) -> void:
	_recorder.record(_current_time, "buffs_updated", actor_id, "", "", {"buff_count": buffs.size()})


# ============================================================
# Qi Waste Estimation (Phase 1 近似)
# ============================================================


func _estimate_qi_waste(actor_id: String, actor: CombatActor, tick_rate: float) -> void:
	if actor.dantian_qi >= actor.dantian_capacity and actor.qi_gather_rate > 0:
		var waste: float = actor.qi_gather_rate * tick_rate
		if waste > 0.0:
			_recorder.record(_current_time, "qi_wasted_estimated", actor_id, "", "qi_regen", {"amount": waste})


# ============================================================
# Enemy Signal Handlers (不用 .bind — 读成员 _player / _qi_circulation)
# ============================================================


func _on_enemy_action(enemy: EnemyActor, action: EnemyActionData) -> void:
	# 与 BattleController._on_enemy_action_ready 一致
	var intent_ctx := BattleContext.new()
	intent_ctx.actor = _player
	var ectx := EffectContext.new()
	var targets: Array[Node] = [_player]  # enemy action 目标是玩家
	ectx.init_battle(_player, enemy, targets, intent_ctx, null)
	EnemyIntents.execute_intent(action, ectx)


func _on_enemy_qi(enemy: EnemyActor) -> void:
	if enemy.erosion_targets.is_empty():
		EnemyAI.select_erosion_targets(enemy)
	if _qi_circulation:
		_qi_circulation.run_one_tick(enemy)


# ============================================================
# Battle End Handler
# ============================================================


func _on_battle_ended(_outcome: int) -> void:
	_battle_ended = true


# ============================================================
# State Logging
# ============================================================


func _log_state(br: BattleBootstrapper.BootResult) -> void:
	var p := _player
	var hand_ids: PackedStringArray = []
	for c in br.deck_manager.hand:
		if c:
			hand_ids.append(c.id)

	var enemy_states: PackedStringArray = []
	for i in br.context_factory.enemies.size():
		var e: EnemyActor = br.context_factory.enemies[i]
		if e:
			enemy_states.append("%s(hp=%d/%d qi=%d/%d)" % [e.display_name, e.hp, e.max_hp, e.dantian_qi, e.dantian_capacity])

	print("[SIM] t=%.1fs tick=%d | player hp=%d/%d qi=%d/%d block=%d | hand(%d)=[%s] | enemies: %s" % [
		_current_time, _tick_number,
		p.hp, p.max_hp, p.dantian_qi, p.dantian_capacity, p.current_block,
		hand_ids.size(), ", ".join(hand_ids),
		", ".join(enemy_states)
	])


# ============================================================
# Helpers
# ============================================================


func _setup_rng(seed_val: int) -> void:
	seed(seed_val)


func _all_enemies_dead(enemies: Array[EnemyActor]) -> bool:
	for enemy in enemies:
		if enemy and enemy.hp > 0:
			return false
	return enemies.size() > 0


func _disconnect_all(player: PlayerActor, enemies: Array[EnemyActor], br: BattleBootstrapper.BootResult) -> void:
	if player.hp_changed.is_connected(_on_hp_changed):
		player.hp_changed.disconnect(_on_hp_changed)
	if player.qi_changed.is_connected(_on_qi_changed):
		player.qi_changed.disconnect(_on_qi_changed)
	if player.technique_activated.is_connected(_on_technique_activated):
		player.technique_activated.disconnect(_on_technique_activated)
	if player.buffs_updated.is_connected(_on_buffs_updated):
		player.buffs_updated.disconnect(_on_buffs_updated)

	for enemy in enemies:
		if enemy == null:
			continue
		if enemy.hp_changed.is_connected(_on_hp_changed):
			enemy.hp_changed.disconnect(_on_hp_changed)
		if enemy.qi_changed.is_connected(_on_qi_changed):
			enemy.qi_changed.disconnect(_on_qi_changed)
		if enemy.technique_activated.is_connected(_on_technique_activated):
			enemy.technique_activated.disconnect(_on_technique_activated)
		if enemy.buffs_updated.is_connected(_on_buffs_updated):
			enemy.buffs_updated.disconnect(_on_buffs_updated)

	if br.enemy_timer_system.enemy_action_ready.is_connected(_on_enemy_action):
		br.enemy_timer_system.enemy_action_ready.disconnect(_on_enemy_action)
	if br.enemy_timer_system.enemy_qi_circulation_ready.is_connected(_on_enemy_qi):
		br.enemy_timer_system.enemy_qi_circulation_ready.disconnect(_on_enemy_qi)
	if br.win_loss_monitor.battle_ended.is_connected(_on_battle_ended):
		br.win_loss_monitor.battle_ended.disconnect(_on_battle_ended)


func _empty_report(won: bool) -> SimulationReport:
	var report := SimulationReport.new()
	report.win = won
	return report
