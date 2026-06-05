# ============================================================
# 大周天 — SimulationAction (AI 输出动作)
# ============================================================
class_name SimulationAction
extends RefCounted


enum Type { PLAY_CARD, SKIP }

## 动作类型
var type: int = Type.SKIP

## 手牌索引（PLAY_CARD 时）
var card_index: int = -1

## 卡牌 ID
var card_id: String = ""

## 目标敌人索引（-1 = 默认/随机）
var target_index: int = -1

## 唯一 Action ID（双向绑定: Action ↔ Event）
var id: int = -1


static func play_card(idx: int, card_id: String, target: int = -1) -> SimulationAction:
	var a := SimulationAction.new()
	a.type = Type.PLAY_CARD
	a.card_index = idx
	a.card_id = card_id
	a.target_index = target
	return a


static func skip() -> SimulationAction:
	var a := SimulationAction.new()
	a.type = Type.SKIP
	return a


## 深拷贝 — 用于录制时防止引用污染
func to_dict() -> Dictionary:
	return {"type": type, "card_index": card_index, "card_id": card_id, "target_index": target_index, "id": id}


static func from_dict(d: Dictionary) -> SimulationAction:
	var a := SimulationAction.new()
	a.type = d.get("type", Type.SKIP)
	a.card_index = d.get("card_index", -1)
	a.card_id = d.get("card_id", "")
	a.target_index = d.get("target_index", -1)
	a.id = d.get("id", -1)
	return a


func duplicate() -> SimulationAction:
	var a := SimulationAction.new()
	a.type = type
	a.card_index = card_index
	a.card_id = card_id
	a.target_index = target_index
	a.id = id
	return a
