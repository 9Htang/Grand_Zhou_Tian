# ============================================================
# 大周天 — CardPlayService (卡牌效果执行域 — L2, 即时制)
# ============================================================
# 四层定位: L2 Domain Layer
#
# 即时制改造:
#   - 移除递归 _resolve_loop 和自状态机
#   - delegate 到 EffectQueue (tick-by-tick 执行)
#   - 路由 (discard/exhaust) 在 EffectQueue.effect_finished 回调中执行
#
# 职责:
#   - CardRuntime 创建 (查找或新建)
#   - Resolver.begin 初始化
#   - 入队到 EffectQueue
#   - 效果完成后路由卡牌
#
# 红线: 不做 UI, 不访问 autoload
# ============================================================
class_name CardPlayService
extends RefCounted


## 效果执行完成时发射
signal execution_done(result: Dictionary)


# === Injected References ===
var player: PlayerActor = null
var deck_manager: DeckManager = null
var card_repo: CardRepository = null
var target_manager: TargetManager = null
var context_factory: BattleContextFactory = null

## EffectQueue 引用 (由 Bootstrapper 注入)
var effect_queue: EffectQueue = null


## 执行卡牌效果流水线
## card_data: 待执行的卡牌
## destination: "discard" | "exhaust"
## ctx: 预构建的 BattleContext
func execute(card_data: CardData, destination: String, ctx: BattleContext) -> Dictionary:
	# 1. 查找或创建 CardRuntime
	var inst: CardInstance = card_repo.find_by_clone(card_data)
	if inst == null:
		inst = card_repo.find_one(card_data.id)

	var runtime: CardRuntime
	if inst != null and (not inst.grafted_effects.is_empty() or not inst.removed_effect_ids.is_empty() or not inst.grafted_tags.is_empty() or not inst.element_override.is_empty()):
		runtime = CardFactory.create_runtime(inst)
	else:
		runtime = CardFactory.create_runtime_direct(card_data.id)

	# 2. 无效果图 → 直接路由
	if runtime.effect_graph.is_empty():
		_route_card(card_data, destination)
		return {"played": true}

	# 3. 初始化 Resolver
	var init_result: BattleResult = Resolver.begin(runtime, ctx)
	if not init_result.executed:
		return {"played": false, "reason": init_result.failure_reason}

	# 4. 入队到 EffectQueue (异步 tick-by-tick 执行)
	if effect_queue == null:
		push_warning("CardPlayService: effect_queue not set, executing synchronously")
		return {"played": false, "reason": "no effect queue"}

	effect_queue.enqueue(runtime, ctx, {
		"card_data": card_data,
		"destination": destination,
	})

	return {"played": true, "enqueued": true}


## 外部回调: EffectQueue 完成效果执行后, 路由卡牌
func on_effect_finished(_card_key: String, _result: Dictionary, user_data: Dictionary) -> void:
	var card_data: CardData = user_data.get("card_data")
	var destination: String = user_data.get("destination", "discard")
	if card_data:
		_route_card(card_data, destination)
	execution_done.emit(_result)


func cancel_pending() -> void:
	if effect_queue:
		effect_queue.cancel_all()


# === 内部 ===

func _route_card(card_data: CardData, destination: String) -> void:
	match destination:
		"discard":
			deck_manager.play_card(card_data)
		"exhaust":
			deck_manager.exhaust_card(card_data)
