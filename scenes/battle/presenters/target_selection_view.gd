# ============================================================
# 大周天 — TargetSelectionView (目标选择 UI — L0)
# 职责: 响应 TargetManager 信号，高亮合法目标/显示选择提示
# 红线: 不调 controller, 不 import services/
# ============================================================
class_name TargetSelectionView
extends RefCounted

## 回合提示标签
var turn_label: Label
## 经脉 Presenter (用于节点/路径高亮)
var meridian_presenter: MeridianPresenter
## 锻造 Presenter (用于特性选择弹窗)
var forge_presenter: ForgePresenter
## 敌人 Presenter (用于敌人选择高亮)
var enemy_presenter: EnemyPresenter


## 注入依赖
func setup(p_turn_label: Label, p_meridian: MeridianPresenter, p_forge: ForgePresenter, p_enemy: EnemyPresenter) -> void:
	turn_label = p_turn_label
	meridian_presenter = p_meridian
	forge_presenter = p_forge
	enemy_presenter = p_enemy


## TargetManager 发起选择 → 高亮合法目标
func on_selection_started(selector: Dictionary, valid_targets: Array) -> void:
	var stype: String = selector.get("type", "")
	match stype:
		"node":
			var indices: Array[int] = []
			for t in valid_targets:
				var idx: int = t.get("idx", -1)
				if idx >= 0:
					indices.append(idx)
			if meridian_presenter.meridian_panel and meridian_presenter.meridian_panel.has_method("set_pathway_highlights"):
				meridian_presenter.meridian_panel.set_pathway_highlights(indices, [])
			turn_label.text = "选择目标穴位 (%d个可选)" % indices.size()
		"path":
			var from_nodes: Array[int] = []
			var to_nodes: Array[int] = []
			for t in valid_targets:
				from_nodes.append(t.get("from", -1))
				to_nodes.append(t.get("to", -1))
			if meridian_presenter.meridian_panel and meridian_presenter.meridian_panel.has_method("set_pathway_highlights"):
				meridian_presenter.meridian_panel.set_pathway_highlights(from_nodes, to_nodes)
			turn_label.text = "选择目标经脉路径 (%d条可选)" % valid_targets.size()
		"card":
			var card_names: Array[String] = []
			for t in valid_targets:
				card_names.append(t.get("display_name", "?"))
			if not card_names.is_empty():
				turn_label.text = "选择卡牌: " + ", ".join(card_names)
			else:
				turn_label.text = "手牌无可选卡牌"
		"feature":
			forge_presenter._show_feature_selection_popup(valid_targets)
			turn_label.text = "选择要操作的特性"
		"enemy":
			var enemy_names: Array[String] = []
			for t in valid_targets:
				var actor: Node = t.get("actor")
				if actor and actor.get("display_name") != null:
					enemy_names.append(actor.display_name)
			if enemy_names.is_empty():
				turn_label.text = "无可选敌人"
			else:
				turn_label.text = "选择目标敌人: " + ", ".join(enemy_names)
			if enemy_presenter:
				enemy_presenter.highlight_valid(valid_targets)
		_:
			turn_label.text = "选择目标 (%s)" % stype


## TargetManager 选择完成 → 清理 UI
func on_selection_completed() -> void:
	meridian_presenter.clear_pathway_highlights()
	forge_presenter._close_feature_popup()
	if enemy_presenter:
		enemy_presenter.clear_highlight()
	turn_label.text = ""


## TargetManager 取消 → 清理 UI
func on_selection_cancelled() -> void:
	meridian_presenter.clear_pathway_highlights()
	forge_presenter._close_feature_popup()
	forge_presenter.remove_forge_hint()
	if enemy_presenter:
		enemy_presenter.clear_highlight()
	turn_label.text = ""
