# ============================================================
# 大周天 — SimulationRun (模拟运行结果)
# ============================================================
# 工具层: tools/simulation/kernel/ — 不属于四层运行时架构
#
# SimulationKernel.run() 的输出。
# 包含事件流、状态哈希链、轨迹、指标、最终状态。
# 所有派生视图（Report/Replay/AI Dataset）从此构建。
# ============================================================
class_name SimulationRun
extends RefCounted


## 输入配置
const REPLAY_VERSION: int = 1

## 录像格式版本 — 序列化时写入，未来 v1/v2/v3 迁移用
var replay_version: int = REPLAY_VERSION

var config: SimulationConfig = null

## 使用的种子
var seed: int = 0

## 事件流（唯一真相源）
var events: EventStream = null

## 动作序列（Dictionary 格式 — 数据化存储，与代码版本解耦）
var actions: Array[Dictionary] = []

## 每 tick 的状态哈希序列
var state_hashes: Array[int] = []

## 轨迹记录（AI 训练数据）
var trajectory: TrajectoryRecorder = null

## 最终指标
var metrics: Dictionary = {}

## RNG 总调用次数
var rng_call_count: int = 0

## 胜负
var win: bool = false

## 总 tick 数
var total_ticks: int = 0

## 最终玩家状态 {hp, max_hp, qi, capacity, block}
var final_player_state: Dictionary = {}

## 最终敌人状态 [{hp, max_hp, qi}, ...]
var final_enemy_states: Array[Dictionary] = []

## 分歧报告（DeterminismGuard 检测到 divergence 时填充）
var divergence_report: Dictionary = {}


## 工厂方法
static func create(
	p_input: SimulationInput,
	p_events: EventStream,
	p_hashes: Array[int],
	p_trajectory: TrajectoryRecorder,
	p_metrics: Dictionary,
	p_rng_call_count: int,
	p_player,
	p_enemies: Array,
	p_actions: Array[Dictionary] = [],
) -> SimulationRun:
	var r := SimulationRun.new()
	r.config = p_input.config
	r.seed = p_input.seed
	r.events = p_events
	r.actions = p_actions
	r.state_hashes = p_hashes
	r.trajectory = p_trajectory
	r.metrics = p_metrics
	r.rng_call_count = p_rng_call_count
	r.total_ticks = p_hashes.size()

	# 最终状态快照
	r.final_player_state = {
		"hp": p_player.hp, "max_hp": p_player.max_hp,
		"qi": p_player.dantian_qi, "capacity": p_player.dantian_capacity,
		"block": p_player.current_block,
	}
	for e in p_enemies:
		r.final_enemy_states.append({
			"hp": e.hp, "max_hp": e.max_hp, "qi": e.dantian_qi,
		})

	# 胜负判定
	r.win = p_player.hp > 0
	if r.win:
		for e in p_enemies:
			if e.hp > 0:
				r.win = false
				break

	return r


## 创建分歧结果
static func diverged(p_input: SimulationInput, report: Dictionary) -> SimulationRun:
	var r := SimulationRun.new()
	r.config = p_input.config
	r.seed = p_input.seed
	r.divergence_report = report
	r.win = false
	return r
