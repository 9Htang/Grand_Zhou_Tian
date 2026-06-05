# ============================================================
# 大周天 — CombatActor (战斗角色抽象层)
# 统一玩家与敌人的战斗状态接口，所有战斗相关逻辑的基类
# ============================================================
class_name CombatActor
extends Node


# === Signals ===
signal hp_changed(new_hp: int, max_hp: int)
signal qi_changed(new_qi: int, max_qi: int)
signal technique_activated(technique: TechniqueData)
signal technique_deactivated(technique: TechniqueData)
signal node_unlocked(node_name: String)
signal pathway_damaged(from_node: int, to_node: int)
signal pathway_repaired()
signal buffs_updated(buffs: Array)
signal circuit_formed(circuit: Dictionary)
signal erosion_targets_changed()


# === Life & Qi ===
var hp: int = 0
var max_hp: int = 0
var dantian_qi: int = 0
var dantian_capacity: int = 0
var dantian_pressure: float = 0.0
var qi_gather_rate: int = 0
## 灵气回复小数累加器 (避免 per-tick int 截断导致低 rate 永远不回复)
var _qi_accumulator: float = 0.0
var current_block: int = 0

# === Techniques & Buffs ===
var active_techniques: Array[TechniqueData] = []
var active_buffs: Array = []              # Array[TechniqueResolver.ResolvedBuff]
var artifacts: Array[ArtifactData] = []
var realm: int = 1
var talent: int = 1
## 气运值，影响转化成功率等随机事件的概率
var luck: int = 0
## 神识值，影响特性提取精准度等
var divine_sense: int = 0
## 速度值，影响自动抽牌频率（仅玩家使用）
signal speed_changed(value: float)
var speed: float = 1.0:
	set(value):
		speed = value
		speed_changed.emit(value)
## 功法→路径绑定: {technique_id: {"from": int, "to": int}}
var technique_pathways: Dictionary = {}

# === Meridian State ===
var base_meridian: MeridianMapData = null
var active_circuits: Array[Dictionary] = []
var erosion_targets: Array[int] = []
var is_flow_dry: bool = true
var node_base_buffs: Dictionary = {}       # {"node_name": "buff_string"}
var damaged_pathways: Dictionary = {}      # Dictionary{turns, original_width, original_capacity} managed by MeridianDamageSystem

# === Bonus Systems ===
var erosion_bonuses: Dictionary = {}       # {source_id: amount}
var qi_gather_bonuses: Dictionary = {}     # {source_id: amount}


# ============================================================
# Lifecycle
# ============================================================

func _ready() -> void:
	if base_meridian == null:
		base_meridian = MeridianRegistry.get_meridian("small_circuit")


# ============================================================
# HP
# ============================================================

func heal(amount: int) -> void:
	hp = min(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)


func take_damage(amount: int) -> void:
	var remaining: int = amount
	if current_block > 0:
		var blocked: int = min(remaining, current_block)
		current_block -= blocked
		remaining -= blocked
	hp = max(0, hp - remaining)
	hp_changed.emit(hp, max_hp)
	ArtifactManager.on_damage_taken(self, amount)


func increase_max_hp(amount: int) -> void:
	max_hp += amount
	hp += amount
	hp_changed.emit(hp, max_hp)


# ============================================================
# Qi
# ============================================================

func add_qi(amount: int) -> void:
	dantian_qi = min(dantian_capacity, dantian_qi + amount)
	qi_changed.emit(dantian_qi, dantian_capacity)


func spend_qi(amount: int) -> bool:
	if dantian_qi < amount:
		return false
	dantian_qi -= amount
	qi_changed.emit(dantian_qi, dantian_capacity)
	return true


func emit_qi_changed() -> void:
	qi_changed.emit(dantian_qi, dantian_capacity)


# ============================================================
# Technique
# ============================================================

func activate_technique(tech: TechniqueData) -> void:
	if active_techniques.has(tech):
		return
	if active_techniques.size() >= talent:
		return  # Would need to replace (handled by UI)
	active_techniques.append(tech)
	technique_activated.emit(tech)


func deactivate_technique(tech: TechniqueData) -> void:
	active_techniques.erase(tech)
	technique_deactivated.emit(tech)


func replace_technique(old: TechniqueData, new: TechniqueData) -> void:
	var idx: int = active_techniques.find(old)
	if idx >= 0:
		active_techniques[idx] = new
		technique_deactivated.emit(old)
		technique_activated.emit(new)


# ============================================================
# Meridian
# ============================================================

## 重置经脉为战斗初始状态（仅丹田解锁，清除所有灵气/侵蚀/阻塞）
func reset_meridian_for_battle() -> void:
	if base_meridian == null:
		return
	var dantian_idx: int = base_meridian.dantian_node_index
	for i: int in base_meridian.nodes.size():
		var node: MeridianNodeData = base_meridian.nodes[i]
		if node:
			node.unlocked = (i == dantian_idx)
			node.current_qi = 0.0
			node.erosion_progress = 0.0
			node.technique_qi = {}
			node.properties.clear()
			node.blocked = false
	for pw in base_meridian.pathways:
		if pw:
			pw.current_qi = 0.0
			pw.technique_qi = {}
			pw.damaged = false
			pw.blocked = false


func unlock_meridian_node(node_name: String) -> void:
	if base_meridian == null:
		return
	if node_name == "random":
		var locked: Array[int] = []
		for i in base_meridian.nodes.size():
			if not base_meridian.nodes[i].unlocked:
				locked.append(i)
		if locked.is_empty():
			return
		var idx := locked[randi() % locked.size()]
		base_meridian.nodes[idx].unlocked = true
		node_unlocked.emit(base_meridian.nodes[idx].name)
	else:
		for node in base_meridian.nodes:
			if node.name == node_name and not node.unlocked:
				node.unlocked = true
				node_unlocked.emit(node_name)
				return


## Bug 5 fix: delegate to MeridianDamageSystem for consistent data format
func damage_pathway(from_idx: int, to_idx: int, turns: int = 3) -> void:
	MeridianDamageSystem.damage_pathway(self, from_idx, to_idx, turns)


func repair_pathway(path_key: String) -> void:
	damaged_pathways.erase(path_key)
	pathway_repaired.emit()


func repair_random_pathway() -> void:
	if damaged_pathways.is_empty():
		return
	var keys: Array = damaged_pathways.keys()
	damaged_pathways.erase(keys[randi() % keys.size()])
	pathway_repaired.emit()


func repair_all_pathways() -> void:
	damaged_pathways.clear()
	pathway_repaired.emit()


func get_node_base_buff(node_name: String) -> String:
	return node_base_buffs.get(node_name, "")


func set_node_base_buff(node_name: String, buff: String) -> void:
	node_base_buffs[node_name] = buff


# ============================================================
# Erosion Targets (冲刷目标)
# ============================================================

## 获取当前最大同时冲刷数量（天资 + 法宝 + 丹药 + buff 加成）
func get_max_erosion_targets() -> int:
	var total: int = talent
	for bonus in erosion_bonuses.values():
		total += int(bonus)
	return max(0, total)


## 添加冲刷上限加成（source_id 用于去重: "artifact:xxx", "elixir:yyy", "buff:zzz"）
func add_erosion_bonus(source_id: String, amount: int) -> void:
	erosion_bonuses[source_id] = amount


## 移除冲刷上限加成
func remove_erosion_bonus(source_id: String) -> void:
	erosion_bonuses.erase(source_id)


# ============================================================
# Qi Gather Bonus (聚气加成)
# ============================================================

## 获取当前聚气总加成
func get_qi_gather_bonuses() -> int:
	var total: int = 0
	for v in qi_gather_bonuses.values():
		total += int(v)
	return total


## 添加聚气加成（source_id 用于去重: "artifact:xxx", "elixir:yyy", "effect"）
func add_qi_gather_bonus(source_id: String, amount: int) -> void:
	qi_gather_bonuses[source_id] = amount


## 移除聚气加成
func remove_qi_gather_bonus(source_id: String) -> void:
	qi_gather_bonuses.erase(source_id)


## 检查指定穴位是否可以切换冲刷目标
## 条件: 未解锁 + 邻接至少一个已解锁穴位
func can_toggle_erosion(node_idx: int) -> bool:
	if base_meridian == null:
		return false
	var node: MeridianNodeData = base_meridian.get_node(node_idx)
	if node == null or node.unlocked:
		return false
	for conn in node.connections:
		var cn: MeridianNodeData = base_meridian.get_node(conn)
		if cn and cn.unlocked:
			return true
	return false


func toggle_erosion_target(node_idx: int) -> bool:
	var existing: int = erosion_targets.find(node_idx)
	if existing >= 0:
		erosion_targets.remove_at(existing)
		erosion_targets_changed.emit()
		return false  # 已移除
	if erosion_targets.size() >= get_max_erosion_targets():
		return false  # 已达上限
	erosion_targets.append(node_idx)
	erosion_targets_changed.emit()
	return true  # 已添加


func clear_erosion_targets() -> void:
	erosion_targets.clear()
	erosion_targets_changed.emit()


# ============================================================
# Artifacts
# ============================================================

func gain_artifact(artifact_id: String) -> void:
	var art: ArtifactData = ArtifactRegistry.get_artifact(artifact_id)
	if art:
		artifacts.append(art)


func gain_random_artifact() -> void:
	var pool: Array[ArtifactData] = ArtifactRegistry.get_all_artifacts()
	if pool.is_empty():
		return
	artifacts.append(pool[randi() % pool.size()])


# ============================================================
# Buffs
# ============================================================

## 解析并添加增益效果
## 格式: "name:value" (永久/手动清除) 或 "name:value:turns" (多回合)
## 例: "energy_up:1:3" → 每回合恢复1点灵气，持续3回合
func add_buff(buff_str: String) -> void:
	var parts: PackedStringArray = buff_str.split(":")
	if parts.size() < 2:
		return
	var buff := TechniqueResolver.ResolvedBuff.new()
	buff.name = parts[0]
	buff.value = int(parts[1])
	buff.source = "card"
	if parts.size() >= 3:
		buff.turns_remaining = int(parts[2])
	active_buffs.append(buff)
	buffs_updated.emit(active_buffs)


func clear_technique_buffs() -> void:
	# 清除冲穴生成的 buff（source="technique"），保留卡牌 buff
	var kept: Array = []
	for buff in active_buffs:
		if buff.source != "technique":
			kept.append(buff)
	active_buffs = kept
	buffs_updated.emit(active_buffs)


## 回合结束时处理卡牌增益: 递减 turns_remaining, 归零则移除
## turns_remaining=0 表示无回合限制，保持到手动清除
func clear_card_buffs() -> void:
	var kept: Array = []
	for buff in active_buffs:
		if buff.source != "card":
			kept.append(buff)
			continue
		# 卡牌来源的 buff: 检查回合数
		if buff.turns_remaining > 1:
			buff.turns_remaining -= 1
			kept.append(buff)
		elif buff.turns_remaining == 0:
			# 无回合限制，保留（兼容旧数据）
			kept.append(buff)
		# turns_remaining == 1 → 最后一回合，移除
	active_buffs = kept
	buffs_updated.emit(active_buffs)


# ============================================================
# Technique Pathway Binding (功法→经脉路径挂载)
# ============================================================

## 获取功法绑定的路径，返回 {"from": int, "to": int} 或空字典
func get_bound_pathway(tech_id: String) -> Dictionary:
	return technique_pathways.get(tech_id, {})


## 绑定功法到经脉路径 (from_idx=起点穴位, to_idx=终点穴位)
func bind_technique_to_pathway(tech_id: String, from_idx: int, to_idx: int) -> void:
	technique_pathways[tech_id] = {"from": from_idx, "to": to_idx}


## 解除功法的路径绑定
func unbind_technique_pathway(tech_id: String) -> void:
	technique_pathways.erase(tech_id)


## 获取挂载在指定路径上的所有功法 ID 列表
func get_pathway_techniques(from_idx: int, to_idx: int) -> Array[String]:
	var result: Array[String] = []
	for tech_id in technique_pathways:
		var binding: Dictionary = technique_pathways[tech_id]
		if binding.get("from", -1) == from_idx and binding.get("to", -1) == to_idx:
			result.append(tech_id)
	return result


## 获取所有丹田邻接的已解锁未阻塞穴位（= 可用起点）
func get_dantian_adjacent_nodes() -> Array[int]:
	var result: Array[int] = []
	if base_meridian == null:
		return result
	var dantian_idx: int = base_meridian.dantian_node_index
	for pw in base_meridian.pathways:
		var pw_data: MeridianPathwayData = pw as MeridianPathwayData
		if pw_data == null or pw_data.blocked:
			continue
		var neighbor: int = -1
		if pw_data.from_node == dantian_idx:
			neighbor = pw_data.to_node
		elif pw_data.to_node == dantian_idx:
			neighbor = pw_data.from_node
		if neighbor >= 0:
			var node: MeridianNodeData = base_meridian.get_node(neighbor)
			if node and node.unlocked and not node.blocked:
				if not result.has(neighbor):
					result.append(neighbor)
	return result
