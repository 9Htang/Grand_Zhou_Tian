# ============================================================
# 大周天 — EventRandomOutcome Resource（事件随机结果定义）
# ============================================================
@tool
class_name EventRandomOutcome
extends Resource

## 此结果被随机选中的权重，数值越大被选中的概率越高
@export var weight: int = 1

## 结果描述文字，如 "你成功打开了宝箱，获得 50 灵石"
@export var text: String = ""

## 触发此结果时执行的效果列表，格式: ["效果名:参数"]
@export var effects: Array[String] = []
