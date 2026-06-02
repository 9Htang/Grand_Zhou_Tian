# ============================================================
# 大周天 — EventData Resource（事件定义）
# ============================================================
@tool
class_name EventData
extends Resource

# === 基础信息 ===

## 事件唯一标识符，用于数据库索引和地图节点引用
@export var id: String = ""

## 事件标题，展示在事件界面的顶部标题栏
@export var display_name: String = ""

## 事件描述正文，展示在事件界面的描述区域
@export_multiline var description: String = ""

## 事件插图的精灵资源标识符，空字符串表示无插图
@export var sprite_id: String = ""

# === 选项 ===

## 玩家可选的事件选项列表，每个选项包含文字、条件、代价和结果
@export var choices: Array[EventChoiceData] = []
