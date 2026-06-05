# ============================================================
# 大周天 — BuffPresenter (Buff 展示 — L0)
# 职责: buffs_bar 的差分刷新，纯 UI 表现
# 红线: 不调 controller, 不 import services/
# ============================================================
class_name BuffPresenter
extends RefCounted

## Buff 图标容器
var buffs_bar: HBoxContainer


## 注入依赖
func setup(p_buffs_bar: HBoxContainer) -> void:
	buffs_bar = p_buffs_bar


## 根据快照差分刷新 buff 图标
func apply(snap: BattleSnapshot) -> void:
	var old_count: int = buffs_bar.get_child_count()
	var new_buffs: Array = snap.buffs

	# 移除多余节点
	while buffs_bar.get_child_count() > new_buffs.size():
		var child := buffs_bar.get_child(buffs_bar.get_child_count() - 1)
		buffs_bar.remove_child(child)
		child.queue_free()

	# 更新或创建
	for i: int in new_buffs.size():
		var buff = new_buffs[i]
		var is_pos: bool = not (buff.name in BattleSnapshot.DEBUFF_NAMES)
		if i < old_count:
			var icon := buffs_bar.get_child(i)
			if icon.has_method("setup"):
				icon.setup(buff.name, buff.value, is_pos)
		else:
			var icon := PanelContainer.new()
			icon.name = "BuffIcon"
			var sc: GDScript = load("res://ui_components/buff_icon.gd") as GDScript
			icon.set_script(sc)
			icon.setup(buff.name, buff.value, is_pos)
			buffs_bar.add_child(icon)
