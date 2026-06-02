# ============================================================
# 大周天 — EventChoiceData Resource（事件选项定义）
# ============================================================
@tool
class_name EventChoiceData
extends Resource

# === 选项内容 ===

## 选项按钮上显示的文字，如 "上前查看"
@export var text: String = ""

## 选择此选项的前置条件表达式，空字符串表示无条件可选
@export var requirements: String = ""

## 选择此选项的代价表达式，如 "gold:50" 或 "hp:30%"
@export var cost: String = ""

# === 结果定义 ===

## 固定触发的效果列表，格式: ["效果名:参数"]
@export var effects: Array[String] = []

## 随机结果池，从 EventRandomOutcome 列表中按权重随机抽取一个触发
@export var random_outcomes: Array = []  # Array[EventRandomOutcome]

## 随机结果的基础成功概率 (0.0~1.0)，1.0=必定成功
@export var success_chance: float = 1.0
