# ============================================================
# 大周天 — PathwayService (经脉路径绑定域)
# 职责: 功法卡经脉路径选择 — 起点/终点选择 + 功法绑定 + 取消
# 红线: 不做 UI 高亮, 不修改 technique 内部状态(委托给 PlayerActor)
# ============================================================
class_name PathwayService
extends RefCounted


# === Injected References (set by BattleController) ===
var player: PlayerActor = null
var deck_manager: DeckManager = null


# === State ===
var pending_technique_card: CardData = null
## 路径选择起点穴位索引: -1=未选择, >=0=已选起点
var pathway_selection_from: int = -1


# ============================================================
# Public API
# ============================================================


## 启动路径选择 — 由 BattleController 在检测到功法卡等待路径时调用
func start_selection(card_data: CardData) -> void:
	pending_technique_card = card_data
	pathway_selection_from = -1


## 选择穴位节点 — 两步: 先选起点, 再选终点
## 返回: -1=无效选择, 0=已选起点等待终点, 1=完成绑定
func select_node(node_idx: int) -> int:
	if pending_technique_card == null:
		return -1

	# 第一步: 选起点 (必须邻接丹田)
	if pathway_selection_from < 0:
		var adjacent: Array = player.get_dantian_adjacent_nodes()
		if not adjacent.has(node_idx):
			return -1
		pathway_selection_from = node_idx
		return 0

	# 第二步: 选终点 (不能是起点)
	if node_idx == pathway_selection_from:
		return -1

	var card: CardData = pending_technique_card
	bind_technique_to_pathway(card, pathway_selection_from, node_idx)
	pending_technique_card = null
	pathway_selection_from = -1
	return 1


## 取消路径选择 — 归还卡牌
func cancel() -> void:
	if pending_technique_card == null:
		return
	deck_manager.cancel_technique(pending_technique_card)
	pending_technique_card = null
	pathway_selection_from = -1


## 是否处于路径选择模式
func is_active() -> bool:
	return pending_technique_card != null


## 获取当前选择的起点穴位索引
func get_selection_from() -> int:
	return pathway_selection_from


## 将功法绑定到经脉路径 (from → to)
func bind_technique_to_pathway(card: CardData, from_idx: int, to_idx: int) -> void:
	var tech: TechniqueData = TechniqueDatabase.get_technique(card.technique_id)
	if tech == null:
		return
	player.bind_technique_to_pathway(tech.id, from_idx, to_idx)
	player.activate_technique(tech)
	deck_manager.exhaust_card(card)
