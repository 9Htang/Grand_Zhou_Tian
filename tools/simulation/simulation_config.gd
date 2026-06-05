# ============================================================
# 大周天 — SimulationConfig (模拟配置 Resource)
# ============================================================
# 工具层: tools/simulation/ — 不属于四层运行时架构
#
# Godot Inspector 可直接编辑的模拟参数。
# ============================================================
@tool
class_name SimulationConfig
extends Resource


## 遭遇战 ID，对应 resources/encounter_data/<id>.tres
@export var encounter_id: String = "ch1_encounter_1"

## 模拟战斗时长 (秒)
@export var duration: float = 120.0

## 随机种子
@export var seed: int = 12345

## Tick 步长 (秒)，0.025 = 40 TPS, 0.05 = 20 TPS
@export var tick_rate: float = 0.025

## 是否启用自动出牌 AI
@export var auto_play_enabled: bool = true

## 自动抽牌间隔 override (秒)，正值覆盖速度计算值，0 或负值走 CardPacingSystem
@export var draw_interval: float = 1.0

## 每次自动抽牌数量
@export var draw_count: int = 2
