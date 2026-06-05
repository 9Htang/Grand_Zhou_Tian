# ============================================================
# 大周天 — EnemyTimerSystem (敌人独立计时器 — L2)
# ============================================================
# 四层定位: L2 Domain Layer — 代替 EnemyTurnService 的统一回合循环
#
# 职责:
#   - 每个敌人维护独立的 action_timer 和 qi_timer
#   - 每 tick 递减计时器
#   - 计时器到期时触发 AI 决策并执行
#
# 红线:
#   ❌ 不操作 UI (通过 signal 通知)
#   ❌ 不持有 EnemyData (通过 _data_map 引用)
# ============================================================
class_name EnemyTimerSystem
extends RefCounted


## 发射: 敌人行动就绪
signal enemy_action_ready(enemy: EnemyActor, action: EnemyActionData)

## 发射: 敌人灵气循环就绪
signal enemy_qi_circulation_ready(enemy: EnemyActor)


# === 内部数据 ===

## 每个敌人的计时器: { EnemyActor: { action: float, qi: float, action_interval: float, qi_interval: float } }
var _timers: Dictionary = {}

## EnemyActor → EnemyData 映射
var _data_map: Dictionary = {}

## 玩家引用 (供 AI 的 opponent 参数)
var player: PlayerActor = null

## 灵气循环服务引用 (由 Bootstrapper 注入)
var qi_circulation: QiCirculationService = null

## 确定性 RNG（由 Bootstrapper 注入，null = 使用全局 randf）
var rng: DeterministicRNG = null

## 即时制: 暂停标志 (Phase 4)
var paused: bool = false


## 默认行动间隔 (秒)
const DEFAULT_ACTION_INTERVAL: float = 4.0

## 默认灵气循环间隔 (秒)
const DEFAULT_QI_INTERVAL: float = 3.0

## 行动间隔随机浮动范围 (±)
const ACTION_VARIANCE: float = 0.8


## 注册敌人
func add_enemy(actor: EnemyActor, data: EnemyData) -> void:
	_data_map[actor] = data
	var action_interval: float = data.get("action_cooldown") if data.get("action_cooldown") != null else DEFAULT_ACTION_INTERVAL
	if action_interval <= 0.0:
		action_interval = DEFAULT_ACTION_INTERVAL

	# 随机初始偏移, 防止多个敌人同时行动
	var initial_offset: float = (rng.randf() if rng else randf()) * action_interval
	_timers[actor] = {
		"action": initial_offset,
		"qi": (rng.randf() if rng else randf()) * DEFAULT_QI_INTERVAL,
		"action_interval": action_interval,
		"qi_interval": DEFAULT_QI_INTERVAL,
	}


## 移除敌人
func remove_enemy(actor: EnemyActor) -> void:
	_timers.erase(actor)
	_data_map.erase(actor)


## 清空所有敌人
func clear_all() -> void:
	_timers.clear()
	_data_map.clear()


## 每 tick 递减所有计时器
func tick(delta: float) -> void:
	if paused:
		return
	var dead_enemies: Array[EnemyActor] = []

	for actor in _timers:
		if actor == null or actor.hp <= 0:
			dead_enemies.append(actor)
			continue

		var t: Dictionary = _timers[actor]
		t["action"] = max(0.0, t["action"] - delta)
		t["qi"] = max(0.0, t["qi"] - delta)

		# 行动计时器到期
		if t["action"] <= 0.0:
			var data: EnemyData = _data_map.get(actor)
			if data:
				var action: EnemyActionData = EnemyAI.select_action(actor, player, data, rng)
				if action:
					enemy_action_ready.emit(actor, action)
			# 重置计时器 (带随机浮动)
			var variance: float = ((rng.randf() if rng else randf()) - 0.5) * 2.0 * ACTION_VARIANCE * t["action_interval"]
			t["action"] = max(0.5, t["action_interval"] + variance)

		# 灵气循环计时器到期
		if t["qi"] <= 0.0:
			if actor.active_techniques.size() > 0 and actor.base_meridian != null:
				enemy_qi_circulation_ready.emit(actor)
			t["qi"] = t["qi_interval"]


	# 清理死亡敌人
	for dead in dead_enemies:
		_timers.erase(dead)
		_data_map.erase(dead)


## 获取敌人的行动计时器进度 [0, 1] (供 UI 渲染进度条)
func get_action_progress(actor: EnemyActor) -> float:
	if not _timers.has(actor):
		return 0.0
	var t: Dictionary = _timers[actor]
	var interval: float = t["action_interval"]
	if interval <= 0.0:
		return 1.0
	return 1.0 - (t["action"] / interval)


## 获取敌人数据
func get_enemy_data(actor: EnemyActor) -> EnemyData:
	return _data_map.get(actor)
