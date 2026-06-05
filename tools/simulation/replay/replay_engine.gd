# ============================================================
# 大周天 — ReplayEngine (确定性回放引擎)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 从原始 SimulationRun 重建完全相同的模拟运行。
# 优先使用 run.actions（直接录制的输入），降级使用 ReplayActionCompiler 从 Event 反向编译。
#
# 核心约束:
#   - 完全 HEADLESS: 零 Node/UI 依赖
#   - 确定性: 回放运行的 state_hashes 必须与原始完全一致
#   - 纯 RefCounted — 无场景树参与
# ============================================================
class_name ReplayEngine
extends RefCounted


## 回放结果
class ReplayResult:
	var original_run: SimulationRun = null
	var replay_run: SimulationRun = null
	var hashes_match: bool = false
	var divergence_tick: int = -1
	var divergence_reason: String = ""
	var total_actions: int = 0


## 回放一次完整的运行
## 优先使用 run.actions（直接录制），降级为 ReplayActionCompiler（兼容旧录像）
## player: 用于初始化 replay kernel 的玩家角色（必须注入）
func replay(run: SimulationRun, player: PlayerActor = null) -> ReplayResult:
	var input := _build_replay_input(run)

	# 优先使用直接录制的 Action，降级为 Event 反向编译
	var actions: Array[SimulationAction] = _get_actions(run)

	var policy := ScriptedPolicy.new()
	policy.set_actions(actions)
	input.policy = policy

	return _execute(input, run, actions, player)


## 获取可回放的 Action 序列
func _get_actions(run: SimulationRun) -> Array[SimulationAction]:
	# 优先: 直接录制的 Action（Dictionary → SimulationAction）
	if not run.actions.is_empty():
		var converted: Array[SimulationAction] = []
		for d in run.actions:
			converted.append(SimulationAction.from_dict(d))
		return converted

	# 降级: 从 Event 反向编译（兼容旧录像）
	var events: Array[SimulationEvent] = run.events.all()
	return ReplayActionCompiler.compile(events)

func _build_replay_input(run: SimulationRun) -> SimulationInput:
	var input := SimulationInput.new()
	input.seed = run.seed
	input.config = run.config
	input.max_ticks = run.total_ticks
	input.execution_mode = SimulationInput.ExecutionMode.REPLAY
	input.record_trajectory = false
	return input


## 执行 replay 并验证确定性
func _execute(input: SimulationInput, original: SimulationRun, actions: Array[SimulationAction], player: PlayerActor = null) -> ReplayResult:
	var kernel := SimulationKernel.new()
	if player:
		kernel.set_player(player)
	var replay_run: SimulationRun = kernel.run(input)

	if replay_run == null:
		var result := ReplayResult.new()
		result.original_run = original
		result.replay_run = null
		result.total_actions = actions.size()
		result.hashes_match = false
		result.divergence_reason = "kernel returned null — player not set?"
		return result

	var v: Dictionary = SimulationVerifier.verify(original, replay_run)

	var result := ReplayResult.new()
	result.original_run = original
	result.replay_run = replay_run
	result.total_actions = actions.size()
	result.hashes_match = v.get("match", false)
	result.divergence_tick = v.get("first_divergence_tick", -1)
	result.divergence_reason = v.get("reason", "")
	return result
