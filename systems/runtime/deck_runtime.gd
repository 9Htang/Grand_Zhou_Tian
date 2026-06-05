# ============================================================
# 大周天 — DeckRuntime
# 牌库状态纯容器 — 不包含任何业务逻辑
# ============================================================
class_name DeckRuntime
extends RefCounted


## 抽牌堆
var draw_pile: Array = []

## 手牌
var hand: Array = []

## 弃牌堆
var discard_pile: Array = []

## 耗尽堆（本场战斗移除）
var exhaust_pile: Array = []

## 待抽牌惩罚
var pending_draw_penalty: int = 0


func clone() -> DeckRuntime:
	var rt: DeckRuntime = DeckRuntime.new()
	rt.draw_pile = draw_pile.duplicate()
	rt.hand = hand.duplicate()
	rt.discard_pile = discard_pile.duplicate()
	rt.exhaust_pile = exhaust_pile.duplicate()
	rt.pending_draw_penalty = pending_draw_penalty
	return rt
