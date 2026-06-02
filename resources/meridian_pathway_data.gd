@tool
class_name MeridianPathwayData
extends Resource

# === 连接信息 ===

## 路径起点穴位索引，指向 nodes 数组中的穴位编号
@export var from_node: int = 0

## 路径终点穴位索引，指向 nodes 数组中的穴位编号
@export var to_node: int = 0

## 此经脉路径是否受损，true=受损(需丹药修复) false=正常
@export var damaged: bool = false

# === 经脉参数 ===

## 经脉宽度: 0.3=极窄(流速快/承载少), 1.0=标准, 2.0=宽(流速慢/承载多)
@export var width: float = 1.0
## 经脉基础承载上限，由丹田容量 × 宽度权重 + 随机扰动自动生成
@export var base_capacity: float = 5.0
## 经脉运行时承载上限 = base_capacity × 损伤因子 + 卡牌加权
@export var max_capacity: float = 5.0
## 当前经脉中流动的灵气量
@export var current_qi: float = 0.0
## 按功法ID归属的灵气量 {technique_id: qi_amount}
@export var technique_qi: Dictionary = {}
## 是否被丹药阻塞（预留接口）
@export var blocked: bool = false

## 卡牌/功法临时加权容量（运行时动态变化），战斗开始时清零
## 实际承载上限 = max_capacity + capacity_bonus
@export var capacity_bonus: float = 0.0
