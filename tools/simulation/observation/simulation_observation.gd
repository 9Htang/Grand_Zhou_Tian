# ============================================================
# 大周天 — SimulationObservation (AI 观察状态)
# ============================================================
class_name SimulationObservation
extends RefCounted


## 当前 tick
var tick: int = 0

## 玩家状态
var player_hp: int = 0
var player_max_hp: int = 0
var player_qi: int = 0
var player_capacity: int = 0
var player_block: int = 0
var player_realm: int = 0

## 手牌信息 [{id, cost, type, damage_estimate, ...}]
var hand_cards: Array[Dictionary] = []

## 敌人状态 [{hp, max_hp, block, qi, realm, buffs, ...}]
var enemy_states: Array[Dictionary] = []

## 牌库计数 {draw, hand, discard, exhaust}
var deck_counts: Dictionary = {}


## 从当前战斗状态构建观察
static func from_battle(player, enemies: Array, deck, tick: int) -> SimulationObservation:
	var obs := SimulationObservation.new()
	obs.tick = tick
	obs.player_hp = player.hp
	obs.player_max_hp = player.max_hp
	obs.player_qi = player.dantian_qi
	obs.player_capacity = player.dantian_capacity
	obs.player_block = player.current_block
	obs.player_realm = player.realm

	for c in deck.hand:
		if c:
			obs.hand_cards.append({
				"id": c.id if c.get("id") != null else "",
				"cost": c.cost if c.get("cost") != null else 0,
				"type": c.type if c.get("type") != null else "",
			})

	for e in enemies:
		obs.enemy_states.append({
			"hp": e.hp, "max_hp": e.max_hp,
			"block": e.current_block,
			"qi": e.dantian_qi,
			"realm": e.realm,
		})

	obs.deck_counts = {
		"draw": deck.draw_pile.size(),
		"hand": deck.hand.size(),
		"discard": deck.discard_pile.size(),
		"exhaust": deck.exhaust_pile.size(),
	}

	return obs
