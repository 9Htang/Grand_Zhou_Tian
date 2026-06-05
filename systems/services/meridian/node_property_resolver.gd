# ============================================================
# 大周天 — Node Property Resolver (穴位特性解析器)
# ============================================================
# 扫描所有已解锁且有灵气的穴位，收集活跃的穴位特性
# 特性在穴位解锁 + current_qi > 0 时生效
# 多个穴位有同名特性时数值叠加
# ============================================================
class_name NodePropertyResolver
extends RefCounted


## 收集所有活跃穴位特性
## 返回: {"multi_target": ["multi_target"], "apply_burn": ["apply_burn:3", "apply_burn:2"]}
static func collect_active_properties(gm: Node) -> Dictionary:
	var result: Dictionary = {}
	var meridian: MeridianMapData = gm.base_meridian
	if meridian == null:
		return result

	for node: MeridianNodeData in meridian.nodes:
		if node == null or not node.unlocked or node.blocked:
			continue
		if node.current_qi <= 0.0:
			continue
		for prop: String in node.properties:
			var parts: PackedStringArray = prop.split(":")
			var name: String = parts[0]
			if not result.has(name):
				result[name] = []
			result[name].append(prop)

	return result


## 检查某布尔特性是否激活 (如 multi_target, double_strike)
static func has_active_property(gm: Node, property_name: String) -> bool:
	var props: Dictionary = collect_active_properties(gm)
	return props.has(property_name)


## 获取某特性的数值总和 (如 apply_burn, life_steal, pierce)
## 布尔类型无参数时返回 1.0（表示激活）
static func get_active_property_total(gm: Node, property_name: String) -> float:
	var props: Dictionary = collect_active_properties(gm)
	if not props.has(property_name):
		return 0.0
	var total: float = 0.0
	for entry: String in props[property_name]:
		var parts: PackedStringArray = entry.split(":")
		if parts.size() >= 2:
			total += float(parts[1])
		else:
			total += 1.0
	return total
