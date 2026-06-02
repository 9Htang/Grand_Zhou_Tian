# ============================================================
# 大周天 — BreakthroughOptionData Resource
# ============================================================
@tool
class_name BreakthroughOptionData
extends Resource

# === 基础信息 ===

## 突破选项唯一标识符
@export var id: String = ""

## 突破选项显示名称，如 "天雷淬体"
@export var display_name: String = ""

## 突破选项详细描述，展示在突破界面的描述区域
@export_multiline var description: String = ""

# === 出现条件 ===

## 随机抽中此突破选项的权重，数值越大越容易出现
@export var weight: int = 1

## 最低境界要求，低于此境界不会出现此选项
@export var min_realm: int = 1

## 最高境界限制，高于此境界不再出现此选项
@export var max_realm: int = 99

## 前置条件表达式，空字符串表示无条件可选
@export var requirements: String = ""

# === 效果与风险 ===

## 正面效果列表，格式: ["效果名:参数"]
@export var effects: Array[String] = []

## 风险/代价列表，格式: ["风险名:参数"]
@export var risks: Array[String] = []
