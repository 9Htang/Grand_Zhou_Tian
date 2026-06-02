# ============================================================
# 大周天 — ChapterData Resource
# ============================================================
@tool
class_name ChapterData
extends Resource

# === 基础信息 ===

## 章节唯一标识符
@export var id: String = ""

## 章节显示名称，如 "第一章·山林试炼"
@export var display_name: String = ""

## 章节序号 (1-based)，控制章节顺序
@export var chapter_index: int = 1

## 章节开场剧情文本，进入章节时展示
@export_multiline var story_intro: String = ""

## 章节结束剧情文本，通过章节后展示
@export_multiline var story_outro: String = ""

# === 地图数据 ===

## 网状地图节点列表，所有 MapNodeData 节点
@export var map_nodes: Array = []

## 入口节点在 map_nodes 中的索引位置
@export var entry_node_index: int = 0

## Boss 节点在 map_nodes 中的索引列表（可多个Boss节点）
@export var boss_node_indices: Array = []

# === Legacy 字段（线性流程，向后兼容） ===

## 顺次遭遇战 ID 列表（线性流程模式）
@export var encounter_ids: Array[String] = []

## Boss 遭遇战 ID（线性流程模式）
@export var boss_encounter_id: String = ""
