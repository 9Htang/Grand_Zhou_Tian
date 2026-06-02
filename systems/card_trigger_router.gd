# ============================================================
# 大周天 — CardTriggerRouter
# 卡牌生命周期触发器路由器
#
# 接收 DeckManager 的区域转换通知，检查卡牌的 trigger_effects，
# 构建临时 EffectGraph 并通过 Resolver 执行效果
#
# 用法:
#   1. BattleController 在 start_battle() 中创建实例
#   2. deck_manager.trigger_router = card_trigger_router
#   3. Router 自动接收并处理 DeckManager 发来的事件
# ============================================================
class_name CardTriggerRouter
extends RefCounted


# ============================================================
# Trigger Key 常量
# ============================================================

const ON_DRAW: StringName = &"on_draw"
const ON_DISCARD: StringName = &"on_discard"
const ON_EXHAUST: StringName = &"on_exhaust"
const ON_HAND_ENTER: StringName = &"on_hand_enter"
const ON_HAND_LEAVE: StringName = &"on_hand_leave"
const ON_RETAIN: StringName = &"on_retain"


# ============================================================
# 状态
# ============================================================

## 战斗上下文 — 包含 actor, opponent, turn_count 等
## 由 BattleController 在创建时注入，每次触发时传入 Resolver
var context: BattleContext


# ============================================================
# 初始化
# ============================================================

func _init(ctx: BattleContext) -> void:
	context = ctx


# ============================================================
# DeckManager 事件入口
# ============================================================


## 抽牌: draw_pile → hand
## 触发: on_draw + on_hand_enter
func on_card_drawn(card: CardData) -> void:
	_fire(card, ON_DRAW)
	_fire(card, ON_HAND_ENTER)


## 弃牌: hand → discard_pile
func on_card_discarded(card: CardData) -> void:
	_fire(card, ON_DISCARD)


## 耗尽: hand → exhaust_pile
func on_card_exhausted(card: CardData) -> void:
	_fire(card, ON_EXHAUST)


## 离开手牌: hand → (任意目标)
func on_hand_leave(card: CardData) -> void:
	_fire(card, ON_HAND_LEAVE)


## 进入手牌（外部调用，如容器展开 / 效果返还）
func on_hand_enter(card: CardData) -> void:
	_fire(card, ON_HAND_ENTER)


## 回合结束时保留在手牌
func on_retain(card: CardData) -> void:
	_fire(card, ON_RETAIN)


# ============================================================
# Internal — 触发执行
# ============================================================


## 检查并执行指定触发器
func _fire(card: CardData, trigger_key: StringName) -> void:
	if context == null:
		return

	# 快速失败: 卡牌无此触发器
	if not card.trigger_effects.has(trigger_key):
		return

	var effects: Array = card.trigger_effects[trigger_key]
	if effects.is_empty():
		return

	# 从 trigger_effects 的值构建 EffectGraph
	var graph: EffectGraph = EffectGraph.from_array(effects)
	if graph.is_empty():
		return

	# 创建临时 CardRuntime 供 Resolver 使用
	# 仅设置必要字段，不应用升级/修正
	var runtime: CardRuntime = CardRuntime.new()
	runtime.base_data = card
	runtime.instance = null  # 触发器不参与升级修正
	runtime.effect_graph = graph
	runtime.rebuild_plan()
	runtime.delay_remaining = 0  # 触发器立即生效

	# 通过 Resolver 执行 8 步管线
	# Resolver._dispatch() 已直接将 block/heal/damage 写到 context.actor/context.opponent
	var result: BattleResult = Resolver.resolve(runtime, context)

	# Debug 日志
	if OS.is_debug_build() and result.executed:
		print("CardTrigger[%s] '%s': dmg=%d block=%d heal=%d draw=%d" % [
			trigger_key, card.display_name,
			result.damage_dealt, result.block_gained,
			result.heal_done, result.cards_drawn
		])
