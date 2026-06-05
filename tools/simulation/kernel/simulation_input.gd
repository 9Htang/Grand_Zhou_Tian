# ============================================================
# 大周天 — SimulationInput (模拟输入)
# ============================================================
# 工具层: tools/simulation/kernel/ — 不属于四层运行时架构
#
# SimulationKernel 的唯一输入。
# 冻结所有模拟参数：seed、policy、tick 配置、冻结牌序。
# 同 SimulationInput → 同 SimulationRun — 确定性保证。
# ============================================================
class_name SimulationInput
extends RefCounted


## 执行模式: LIVE=真人对局 SIMULATION=AI模拟 REPLAY=录像回放
enum ExecutionMode { LIVE = 0, SIMULATION = 1, REPLAY = 2 }


## 基础模拟配置 (encounter_id, duration 等)
var config: SimulationConfig = null

## 随机种子 — 确定性模拟的核心
var seed: int = 0

## 决策策略（null = 使用内置 EnemyAI）
var policy: Policy = null

## 最大 tick 数（默认 2400 = 120s @ 0.05 tick）
var max_ticks: int = 2400

## Tick 步长（秒），默认 0.05 = 20 TPS
var tick_rate: float = 0.05

## 是否启用自动出牌（无 Policy 时）
var auto_play_enabled: bool = true

## 自动抽牌间隔 (秒)
var draw_interval: float = 1.0

## 每次抽牌数量
var draw_count: int = 2

## 是否记录轨迹（AI 训练用）
var record_trajectory: bool = true

## 冻结的抽牌堆顺序（空 = 使用 Bootstrapper 默认 shuffle）
var frozen_deck_order: Array[String] = []

## 期望的 state_hashes（CI 模式 — DeterminismGuard 比对用）
var expected_hashes: Array[int] = []

## 执行模式: LIVE / SIMULATION / REPLAY
var execution_mode: int = ExecutionMode.LIVE


## 从 SimulationConfig 同步字段到本对象顶层
## 调用后 config 中的 seed/tick_rate/duration/auto_play 会覆盖顶层默认值
func apply_config(p_config: SimulationConfig) -> void:
	config = p_config
	if config == null:
		return
	seed = config.seed
	tick_rate = config.tick_rate if config.tick_rate > 0.0 else tick_rate
	# duration(秒) → max_ticks
	if config.duration > 0.0:
		max_ticks = int(config.duration / tick_rate)
	auto_play_enabled = config.auto_play_enabled
	draw_interval = config.draw_interval if config.draw_interval > 0.0 else draw_interval
	draw_count = config.draw_count if config.draw_count > 0 else draw_count
