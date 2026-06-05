# ============================================================
# 大周天 — MeridianPresenter (经脉展示 — L0)
# 职责: 经脉面板数据刷新、穴位交互、路径高亮
# 红线: 不调 controller, 业务判断由 BattleScreen/FlowView 传入
# ============================================================
class_name MeridianPresenter
extends RefCounted

## 经脉面板 (meridian_view.gd 脚本)
var meridian_panel: Panel


## 注入依赖
func setup(p_meridian_panel: Panel) -> void:
	meridian_panel = p_meridian_panel


## 根据快照刷新经脉面板全部数据
func apply(snap: BattleSnapshot) -> void:
	if meridian_panel == null:
		return

	meridian_panel.set_meridian(snap.base_meridian)
	meridian_panel.set_erosion_targets(snap.erosion_targets)
	meridian_panel.set_max_targets(snap.max_erosion_targets)
	meridian_panel.set_circuit_pathways(snap.circuit_pathway_keys)
	meridian_panel.set_dry(snap.is_flow_dry)
	meridian_panel.set_technique_colors(snap.technique_colors)

	# 构建 pathway_data {from->to: [tech_id, ...]}
	var pathway_data: Dictionary = {}
	for tech_id in snap.technique_pathways:
		var binding: Dictionary = snap.technique_pathways[tech_id]
		var key: String = str(binding.get("from", -1)) + "->" + str(binding.get("to", -1))
		if not pathway_data.has(key):
			pathway_data[key] = []
		pathway_data[key].append(tech_id)
	meridian_panel.set_technique_pathways(pathway_data)

	if snap.collision_data != null:
		meridian_panel.set_collision_data(snap.collision_data)


# ============================================================
# 路径选择高亮
# ============================================================

## 高亮所有可用起点穴位（丹田邻接、已解锁、未阻塞）
func highlight_available_start_nodes(player_actor: PlayerActor) -> void:
	if not meridian_panel or not meridian_panel.has_method("set_pathway_highlights"):
		return
	var nodes: Array[int] = player_actor.get_dantian_adjacent_nodes()
	meridian_panel.set_pathway_highlights(nodes, [])


## 高亮所有可用终点穴位（除起点外的任意已解锁穴位）
func highlight_available_end_nodes(from_idx: int, player_actor: PlayerActor) -> void:
	if not meridian_panel or not meridian_panel.has_method("set_pathway_highlights"):
		return
	if from_idx < 0:
		return
	var mer: MeridianMapData = player_actor.base_meridian
	if mer == null:
		return
	var end_nodes: Array[int] = []
	for i: int in mer.nodes.size():
		var node: MeridianNodeData = mer.nodes[i]
		if node and node.unlocked and not node.blocked and i != from_idx:
			end_nodes.append(i)
	meridian_panel.set_pathway_highlights([from_idx], end_nodes)


## 清除所有路径选择高亮
func clear_pathway_highlights() -> void:
	if meridian_panel and meridian_panel.has_method("clear_pathway_highlights"):
		meridian_panel.clear_pathway_highlights()


## 通知穴位解锁动画
func notify_node_unlocked(idx: int) -> void:
	if meridian_panel and meridian_panel.has_method("notify_node_unlocked"):
		meridian_panel.notify_node_unlocked(idx)


# ============================================================
# 穴位信息弹窗
# ============================================================

## 显示穴位信息弹窗 → 自管理生命周期
func show_node_info_popup(idx: int, node: MeridianNodeData, parent_node: Node) -> void:
	# 清理已有弹窗
	for child in parent_node.get_children():
		if child is CanvasLayer and child.name.begins_with("NodeInfo_"):
			child.queue_free()
	var popup := CanvasLayer.new()
	var sc: GDScript = load("res://ui_components/node_info_popup.gd") as GDScript
	popup.set_script(sc)
	popup.name = "NodeInfo_" + str(idx)
	parent_node.add_child(popup)
	popup.show_info(idx, node)
