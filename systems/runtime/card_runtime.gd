# ============================================================
# 大周天 — CardRuntime
# Layer2 战斗工作副本
# 所有 swap/remove/reorder/transform 操作此对象
# CardData 和 CardInstance 在此层之上保持不变
# ============================================================
class_name CardRuntime
extends RefCounted


enum Zone {
	HAND = 0,          # 手牌
	TECHNIQUE = 1,     # 功法区
	DISCARD = 2,       # 弃牌堆
	PENDING = 3,       # 待生效区 (延迟生效)
	EXHAUST = 4,       # 耗尽区 (本场移除)
}

# === 引用 ===

## 模板引用 (只读)
var base_data: CardData

## 身份引用 (只读)
var instance: CardInstance

# === 可变效果 ===

## 效果图 — 所有 Operator 的操作目标
var effect_graph: EffectGraph

## 执行计划 — Resolver Step 6 构建
var execution_plan: ExecutionPlan

## 编译后的字节码程序 — Resolver Step 6 编译，Step 7 由 EffectVM 执行
var effect_program: EffectProgram

## 触发器效果图 — Dictionary{String: EffectGraph}
## key = 触发器名 ("on_draw"/"on_discard"/etc.)
## 由 build_initial_graph() 预构建，CardTriggerRouter 在事件触发时查询
var trigger_graphs: Dictionary = {}

## 临时修正 — EffectOperator 数组
var temp_modifiers: Array = []

# === 执行上下文 (Resolver.step 两阶段) ===

## 当前执行到的 EffectNode 索引 (0=第一个节点)
var step_pc: int = 0

## 已选择的目标 — {"path": [{from, to}, ...], "node": [{idx, name}, ...]}
var selected_targets: Dictionary = {}

## 效果执行变量 — 用于跨节点传递值 {"damage_bonus": 3, "previous_result": ...}
var variables: Dictionary = {}

# === 战斗状态 ===

## 延迟剩余回合数, 0=立即生效
var delay_remaining: int = 0

## 当前所在区域
var zone: int = Zone.HAND


# ============================================================
# 初始化
# ============================================================


## 从 CardData.base_effects + CardInstance 修改构建 EffectGraph
func build_initial_graph() -> void:
	if base_data == null:
		effect_graph = EffectGraph.new()
		return

	# 使用 CardInstance 的 get_effective_effects() 合并嫁接/移除
	var effects: Array
	if instance:
		effects = instance.get_effective_effects()
	else:
		effects = base_data.get_or_build_effects()

	effect_graph = EffectGraph.from_array(effects)

	# 构建触发器效果图
	trigger_graphs.clear()
	if base_data and not base_data.trigger_effects.is_empty():
		for trigger_key: String in base_data.trigger_effects:
			var trigger_arr: Array = base_data.trigger_effects[trigger_key]
			if not trigger_arr.is_empty():
				trigger_graphs[trigger_key] = EffectGraph.from_array(trigger_arr)


## 重建执行计划
func rebuild_plan() -> void:
	execution_plan = ExecutionPlan.build_from(effect_graph)


# ============================================================
# 查询
# ============================================================


## 获取有效灵气消耗 (base.cost - 修正)
func get_effective_cost() -> int:
	var c: int = base_data.cost
	# 升级修正
	if instance:
		c = maxi(0, c - base_data.cost_reduce_per_upgrade * instance.upgrade_level)
	# temp_modifiers 中可能有 MODIFY_VALUE 影响 cost
	# (后续由 Resolver 统一处理)
	return c


## 获取指定触发器的预构建 EffectGraph（如果存在）
func get_trigger_graph(trigger_key: String) -> EffectGraph:
	return trigger_graphs.get(trigger_key, null)


## 获取卡牌类型
func get_card_type() -> int:
	return base_data.card_type


## 获取显示名称
func get_display_name() -> String:
	if instance:
		return instance.get_full_name()
	return base_data.display_name if base_data else "?"


## 是否为延迟生效卡牌
func is_pending() -> bool:
	return delay_remaining > 0


## 递减延迟计数器，返回是否到 0（该触发了）
func tick_delay() -> bool:
	if delay_remaining <= 0:
		return false
	delay_remaining -= 1
	return delay_remaining <= 0
