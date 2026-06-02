@tool
class_name MeridianNodeData
extends Resource

# === 基础信息 ===

## 穴位名称，如 "丹田" / "百会" / "涌泉"
@export var name: String = ""

## 穴位五行元素: "火"/"水"/"木"/"金"/"土"，空字符串表示无属性
@export var element: String = ""

## 穴位在地图上的显示位置 (像素坐标)
@export var position: Vector2 = Vector2.ZERO

## 与当前穴位相连的其他穴位索引列表，指向 nodes 数组的下标
@export var connections: Array = []

## 穴位是否已解锁，true=已解锁可流通灵气 false=未解锁需冲刷开启
@export var unlocked: bool = true

# === 灵气参数 ===

## 穴位灵气容量上限，灌满此穴位所需的总灵气量
@export var capacity: float = 10.0
## 传播阈值（0-1，灵气占比到此就开始往下一级泄漏）
@export var spread_threshold: float = 0.3
## 穴位当前灵气量
@export var current_qi: float = 0.0
## 按功法ID归属的灵气量 {technique_id: qi_amount}
@export var technique_qi: Dictionary = {}
## 是否被丹药阻塞（预留接口）
@export var blocked: bool = false
## 灵气冲刷阈值（累积到此值自动解锁）
@export var erosion_threshold: float = 50.0
## 当前冲刷累积值
@export var erosion_progress: float = 0.0
## 穴位特性列表: ["multi_target", "apply_burn:3", "life_steal:0.2"]
## 穴位解锁后，有灵气流过时这些特性在战斗中生效
@export var properties: Array[String] = []


## 返回已解析的特性列表 [{name, param?}]
func get_parsed_properties() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for prop: String in properties:
		var parts: PackedStringArray = prop.split(":")
		var entry: Dictionary = {"name": parts[0]}
		if parts.size() >= 2:
			entry["param"] = parts[1]
		result.append(entry)
	return result
