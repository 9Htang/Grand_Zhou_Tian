# ============================================================
# 大周天 — SimulationEvent (模拟事件数据)
# ============================================================
# 工具层: tools/simulation/ — 不属于四层运行时架构
#
# 模拟战斗中的单条事件记录。所有分析器 (MonteCarlo/QiAnalyzer/BuildAnalyzer)
# 共享同一套事件流，避免各自统计。
#
# 事件语义以施加者为中心:
#   actor_id  = 谁做了这件事 (player | enemy_0 | ...)
#   target_id = 这件事作用于谁 (player | enemy_0 | ...)
# ============================================================
class_name SimulationEvent
extends RefCounted


## 战斗内时间戳 (秒)
var time: float = 0.0

## 事件类型 (以施加者为中心):
##   hp: "damage_dealt" | "heal_received"
##   qi: "qi_generated" | "qi_consumed" | "qi_wasted_estimated"
##   card: "card_played"
##   tech: "technique_activated" | "technique_deactivated"
##   buff: "buffs_updated"
##   state: "qi_state"
var type: String = ""

## 事件施加者: "player" | "enemy_0" | "enemy_1" | ...
var actor_id: String = ""

## 事件承受者: "player" | "enemy_0" | "enemy_1" | ...
var target_id: String = ""

## 事件来源: card_id 或系统名 (如 "qi_regen", "qi_circulation")
var source: String = ""

## 事件数据: 因 type 而异, 例 {amount: 35, new_hp: 65}
var payload: Dictionary = {}


# === v3.0 确定性字段 ===

## 事件前的游戏状态哈希
var state_hash_before: int = 0

## 事件后的游戏状态哈希
var state_hash_after: int = 0

## 事件发生时的 RNG 调用计数
var rng_call_index: int = 0


# === v3.1 因果链字段 ===

## 本事件唯一 ID (UUID)
var event_id: String = ""

## 触发本事件的上级事件 ID
var parent_event_id: String = ""

## 产生本事件的 VM 指令索引
var instruction_index: int = -1

## 产生本事件的 opcode 名称
var opcode: String = ""

## 来源卡牌 ID
var source_card_id: String = ""

## 事件来源类型: "INPUT"=玩家输入 "SYSTEM"=系统事件 "TRIGGER"=触发连锁
var source_type: String = ""

## 触发此事件的 Action ID（双向绑定: Action ↔ Event）
var action_id: int = -1


## 事件指纹 — 全字段走 StableSerializer，防分隔符碰撞 + 防字段遗漏
func fingerprint() -> String:
	return StableSerializer.serialize({
		"type": type,
		"actor_id": actor_id,
		"target_id": target_id,
		"source_card_id": source_card_id,
		"action_id": action_id,
		"payload": payload,
	})


func _init(p_time: float = 0.0, p_type: String = "", p_actor_id: String = "", p_target_id: String = "", p_source: String = "", p_payload: Dictionary = {}) -> void:
	time = p_time
	type = p_type
	actor_id = p_actor_id
	target_id = p_target_id
	source = p_source
	payload = p_payload
