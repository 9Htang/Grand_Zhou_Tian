# ============================================================
# 大周天 — EffectNode
# 卡牌效果图中的最小效果节点
# 所有效果（伤害/格挡/治疗/灼烧/眩晕...）统一为此结构
# ============================================================
@tool
class_name EffectNode
extends Resource


## 节点唯一标识，如 "n1", "n2"
@export var id: String = ""

## 效果类型: "damage" / "block" / "heal" / "burn" / "stun" / "vulnerable" /
##   "weak" / "draw" / "qi_gather" / "buff" / "debuff" / "cleanse" / ...
@export var type: String = "damage"

## 效果基础数值，具体含义由 type 决定:
##   damage → 伤害量, block → 格挡量, burn → 灼烧伤害/回合
##   draw → 抽牌数, heal → 治疗量
@export var value: int = 0

## 额外参数（如 burn 的持续回合: {"turns": 3}）
@export var meta: Dictionary = {}


func duplicate_node() -> EffectNode:
	var n: EffectNode = EffectNode.new()
	n.id = id
	n.type = type
	n.value = value
	n.meta = meta.duplicate()
	return n


func description() -> String:
	match type:
		"damage": return "造成 %d 点伤害" % value
		"block": return "获得 %d 点格挡" % value
		"heal": return "恢复 %d 点生命" % value
		"burn": return "施加 %d 层灼烧" % value
		"stun": return "眩晕 %d 回合" % value
		"vulnerable": return "施加 %d 层易伤" % value
		"weak": return "施加 %d 层虚弱" % value
		"draw": return "抽取 %d 张牌" % value
		"qi_gather": return "聚集 %d 点灵气" % value
		"buff": return "获得增益: %s" % meta.get("name", "?")
		"debuff": return "施加减益: %s" % meta.get("name", "?")
		"cleanse": return "清除负面效果" if value <= 0 else "清除 %d 个负面效果" % value
		_: return "%s: %d" % [type, value]
