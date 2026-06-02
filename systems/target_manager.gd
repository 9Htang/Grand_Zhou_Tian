# ============================================================
# 大周天 — TargetManager
# 卡牌效果目标选择调度器
#
# 职责: 发起选择 → 提供合法目标 → 验证提交 → 恢复执行
# 不负责: 目标是否合法的业务逻辑 (由 Provider 负责)
# ============================================================
class_name TargetManager
extends RefCounted


# ============================================================
# Signals
# ============================================================

signal selection_started(selector: Dictionary, valid_targets: Array)
signal selection_completed(selector: Dictionary, selected: Array)
signal selection_cancelled()


# ============================================================
# State
# ============================================================

var registry: ProviderRegistry = null
var pending_selector: Dictionary = {}
var pending_targets: Array = []  # 合法目标列表
var selected: Array = []          # 已选目标
var count: int = 1                # 需要选择的数量
var battle_context: BattleContext = null


# ============================================================
# Init
# ============================================================

func _init() -> void:
	registry = ProviderRegistry.new()


# ============================================================
# Request / Submit / Cancel
# ============================================================


## 发起目标选择
## selector: EffectNode.selector — {"type": "path", "count": 1}
## battle: BattleContext
func request(selector: Dictionary, battle: BattleContext) -> void:
	pending_selector = selector
	battle_context = battle
	count = selector.get("count", 1)
	selected.clear()

	pending_targets = registry.get_targets(selector, battle)

	selection_started.emit(selector, pending_targets.duplicate())


## 尝试提交一个目标
## 返回: true=接受 (还需选 count-selected 个), null=完成, false=非法
func submit_target(target: Dictionary) -> bool:
	# 去重
	for s in selected:
		if _target_eq(s, target):
			return true  # 已选，忽略

	selected.append(target)

	if selected.size() >= count:
		selection_completed.emit(pending_selector, selected.duplicate())
		return false  # 最后返回 false 表示"不再等待"
	return true


## 取消选择
func cancel() -> void:
	pending_selector = {}
	pending_targets.clear()
	selected.clear()
	count = 1
	selection_cancelled.emit()


## 是否处于选择模式
func is_selecting() -> bool:
	return not pending_selector.is_empty()


# ============================================================
# Internal
# ============================================================

func _target_eq(a: Dictionary, b: Dictionary) -> bool:
	# 路径: from+to 唯一
	if a.has("from") and b.has("from") and a.has("to") and b.has("to"):
		return a["from"] == b["from"] and a["to"] == b["to"]
	# 穴位: idx 唯一
	if a.has("idx") and b.has("idx"):
		return a["idx"] == b["idx"]
	# 卡牌: card.id 唯一
	if a.has("card") and b.has("card"):
		var ca: CardData = a["card"]
		var cb: CardData = b["card"]
		if ca and cb:
			return ca.id == cb.id
	# 降级: 全字段比较
	return a.hash() == b.hash()
