# ============================================================
# 大周天 — ReplayViewer (回放查看器总控)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 回放系统的顶层入口 — 组装完整链路:
#
#   SimulationRun (数据)
#     → ReplayCursor (时间导航)
#       → ReplayController (播放控制)
#         → BattleReplayAdapter (Event Sourcing → 虚拟状态)
#         → ReplayPresenter (事件 → UI 指令)
#           → ReplayRenderer (可视化 + 时间轴 + 事件列表)
#
# 双轨输出:
#   Track A — BattleReplayAdapter: 维护虚拟 HP/Qi/Block 状态
#   Track B — ReplayPresenter: 驱动 float text / shake / flash 动画
#   两者通过 ReplayRenderer 汇聚到 battle_view
#
# 使用方式:
#   1. new ReplayViewer → add_child(viewer)
#   2. viewer.setup_player(hp, max_hp, qi, qi_cap)
#   3. viewer.setup_enemies([{id, hp, max_hp}, ...])
#   4. viewer.load_replay(simulation_run)
#   5. viewer.bind_battle_view(battle_screen)
#   6. viewer.play()
# ============================================================
class_name ReplayViewer
extends Control


# ============================================================
# State
# ============================================================

## 回放数据
var run_data: SimulationRun = null

## 回放控制器
var controller: ReplayController = null

## 战斗状态适配器（Event Sourcing）
var adapter: BattleReplayAdapter = null

## 回放渲染器
var renderer: ReplayRenderer = null

## 状态差异检查器
var diff_inspector: StateDiffInspector = null


# ============================================================
# Public — Setup (必须在 load_replay 前调用)
# ============================================================

## 设置玩家初始状态
func setup_player(hp: int, max_hp: int, qi: int, qi_cap: int, qi_rate: int = 0, realm: int = 1) -> void:
	_get_adapter().set_player_initial(hp, max_hp, qi, qi_cap, qi_rate, realm)


## 注册敌人初始状态
func setup_enemy(enemy_id: String, hp: int, max_hp: int, qi: int = 0) -> void:
	_get_adapter().register_enemy(enemy_id, hp, max_hp, qi)


## 批量设置敌人（从数组）
func setup_enemies(enemy_list: Array[Dictionary]) -> void:
	for entry in enemy_list:
		var eid: String = entry.get("id", "")
		if eid.is_empty():
			continue
		_get_adapter().register_enemy(
			eid,
			entry.get("hp", 0),
			entry.get("max_hp", 0),
			entry.get("qi", 0)
		)


# ============================================================
# Public — Load
# ============================================================

## 加载 SimulationRun 并初始化全部子系统
func load_replay(run: SimulationRun) -> void:
	run_data = run

	# 1. 清理旧组件
	_cleanup()

	# 2. 创建控制器
	controller = ReplayController.new()
	controller.name = "ReplayController"
	add_child(controller)
	controller.bind(run)

	# 3. 绑定 adapter 到 run
	adapter.bind(run)

	# 4. 创建渲染器
	renderer = ReplayRenderer.new()
	renderer.name = "ReplayRenderer"
	renderer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	renderer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(renderer)
	renderer.bind_controller(controller)

	# 5. 创建差异检查器
	diff_inspector = StateDiffInspector.new()
	diff_inspector.name = "StateDiffInspector"
	add_child(diff_inspector)
	diff_inspector.bind_run(run)

	# 6. 连线: controller → adapter + diff
	if not controller.event_emitted.is_connected(_on_event_for_adapter):
		controller.event_emitted.connect(_on_event_for_adapter)
	if not controller.tick_changed.is_connected(_on_tick_for_diff):
		controller.tick_changed.connect(_on_tick_for_diff)

	# 7. 初始化战斗画面状态
	_push_state_to_view()


## 绑定的战斗画面引用（直接持有，供 render_tick 调用）
var battle_screen: Node = null

## 绑定战斗画面用于视觉同步
func bind_battle_view(view: Node) -> void:
	battle_screen = view
	if renderer:
		renderer.bind_battle_view(view)
	# 初次推状态
	_push_state_to_view()


## 绑定快照展示器
func bind_snapshot_presenter(sp) -> void:
	if renderer:
		renderer.bind_snapshot_presenter(sp)


# ============================================================
# Public — Playback (delegate to controller)
# ============================================================

func play() -> void:
	if controller:
		controller.play()


func pause() -> void:
	if controller:
		controller.pause()


func toggle_play() -> void:
	if controller:
		controller.toggle_play()


func stop() -> void:
	if controller:
		controller.stop()
	# 重置 adapter
	if adapter:
		adapter.seek(0)
	_push_state_to_view()


## Seek — 同时更新 cursor + adapter + battle_screen
func seek(tick: int) -> void:
	if controller:
		controller.seek(tick)
	# 从预建快照恢复 adapter 状态
	if adapter:
		adapter.seek(tick)
	# 推送完整状态到 battle_screen
	_render_to_battle_screen(tick)


func step() -> void:
	if controller:
		controller.step()


func step_back() -> void:
	if controller:
		controller.step_back()


# ============================================================
# Public — Query
# ============================================================

func get_current_tick() -> int:
	return controller.get_current_tick() if controller else 0


func get_total_ticks() -> int:
	return controller.get_tick_count() if controller else 0


func get_progress() -> float:
	return controller.get_progress() if controller else 0.0


func is_playing() -> bool:
	return controller.is_playing() if controller else false


func is_loaded() -> bool:
	return run_data != null


## 获取当前虚拟状态（供外部 Inspector 面板使用）
func get_player_vitals() -> Dictionary:
	return adapter.get_player_vitals() if adapter else {}


## 获取当前敌人虚拟状态
func get_enemy_vitals() -> Array[Dictionary]:
	return adapter.get_enemy_vitals() if adapter else []


# ============================================================
# Signals — Adapter → View
# ============================================================

## 状态已更新（供外部监听 — 例如 Inspector 面板）
signal state_updated(player_vitals: Dictionary, enemy_vitals: Array)


# ============================================================
# Internal
# ============================================================

func _get_adapter() -> BattleReplayAdapter:
	if adapter == null:
		adapter = BattleReplayAdapter.new()
	return adapter


func _cleanup() -> void:
	if controller:
		controller.queue_free()
		controller = null
	if renderer:
		renderer.queue_free()
		renderer = null
	if diff_inspector:
		diff_inspector.queue_free()
		diff_inspector = null
	# adapter 是 RefCounted，不需 queue_free


## 事件 → adapter 状态更新 → battle_screen 实时渲染
func _on_event_for_adapter(event: SimulationEvent) -> void:
	if adapter:
		adapter.process_event(event)

	# 用当前 live 状态构建快照并推送到 battle_screen
	if battle_screen and battle_screen.has_method("render_tick") and adapter:
		var live_snap: Dictionary = adapter.get_live_snapshot()
		if not live_snap.is_empty():
			battle_screen.render_tick(live_snap)
	else:
		_push_state_to_view()


## Tick 变化 → diff inspector
func _on_tick_for_diff(tick: int) -> void:
	if diff_inspector:
		diff_inspector.show_tick(tick)


## 推送当前虚拟状态到 battle_view
func _push_state_to_view() -> void:
	if adapter == null:
		return

	var player_vitals: Dictionary = adapter.get_player_vitals()
	var enemy_vitals: Array[Dictionary] = adapter.get_enemy_vitals()

	state_updated.emit(player_vitals, enemy_vitals)

	# 推送到 battle_view（轻量更新 — 仅 vitals）
	if renderer and renderer.battle_view:
		if renderer.battle_view.has_method("update_player_vitals"):
			renderer.battle_view.update_player_vitals(player_vitals)
		if renderer.battle_view.has_method("update_enemy_vitals"):
			renderer.battle_view.update_enemy_vitals(enemy_vitals)


## 推送完整 tick 快照到 battle_screen.render_tick()
func _render_to_battle_screen(tick: int) -> void:
	if adapter == null:
		return

	var snap: Dictionary = adapter.get_snapshot(tick)
	if snap.is_empty():
		return

	# 主路径: battle_screen.render_tick()
	if battle_screen and battle_screen.has_method("render_tick"):
		battle_screen.render_tick(snap)
		return

	# 降级: renderer.battle_view（旧接口）
	_push_state_to_view()
