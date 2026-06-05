# ============================================================
# 大周天 — DecisionTrace (AI 决策追踪)
# ============================================================
class_name DecisionTrace
extends RefCounted


## 决策时刻
var tick: int = 0

## 决策者
var actor_id: String = ""

## 选择的动作
var chosen_action: SimulationAction = null

## 可选动作数
var legal_actions_count: int = 0

## AI 概率分布（可选，供 NeuralPolicy 记录）
var action_probs: Dictionary = {}

## AI 价值估计（可选，供 MCTS 记录）
var value_estimate: float = 0.0
