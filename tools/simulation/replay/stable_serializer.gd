# ============================================================
# 大周天 — StableSerializer (确定性序列化)
# ============================================================
# 工具层: tools/simulation/replay/ — 不属于四层运行时架构
#
# 生成值的确定性字符串表示，保证同内容=同输出。
# 解决 Dictionary key 遍历顺序不稳定 + 嵌套结构序列化问题。
#
# 递归策略:
#   Dictionary → key 排序后递归
#   Array      → 顺序遍历每项递归
#   int/float/String → str()
#   Object     → to_dict() 后递归（若不存在则 fallback str()）
# ============================================================
class_name StableSerializer
extends RefCounted


## 将任意值序列化为确定性字符串
static func serialize(value) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			return _serialize_dict(value)
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			return _serialize_array(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return "\"" + str(value) + "\""
		TYPE_INT, TYPE_FLOAT, TYPE_BOOL:
			return str(value)
		TYPE_NIL:
			return "null"
		TYPE_OBJECT:
			if value.has_method("to_dict"):
				var d: Dictionary = value.to_dict()
				return _serialize_dict(d)
			return "\"<obj:" + value.get_class() + ">\""
		_:
			return "\"" + str(value) + "\""


static func _serialize_dict(d: Dictionary) -> String:
	var keys: Array = d.keys()
	keys.sort()
	var parts: PackedStringArray = []
	parts.append("{")
	for i in range(keys.size()):
		var k = keys[i]
		parts.append(serialize(k))
		parts.append(":")
		parts.append(serialize(d[k]))
		if i < keys.size() - 1:
			parts.append(",")
	parts.append("}")
	return "".join(parts)


static func _serialize_array(arr: Array) -> String:
	var parts: PackedStringArray = []
	parts.append("[")
	for i in range(arr.size()):
		parts.append(serialize(arr[i]))
		if i < arr.size() - 1:
			parts.append(",")
	parts.append("]")
	return "".join(parts)
