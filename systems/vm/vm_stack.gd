# ============================================================
# 大周天 — VMStack (VM 执行栈)
# ============================================================
# L2 定位: systems/vm/ — VM 内部组件
#
# 指令间数据传递的核心机制。
# SelectTarget → push(目标列表) → Damage → pop(目标列表)
#
# 工业级 VM 的关键组件:
#   - 支持 target selection buffer
#   - 支持 conditional effects
#   - 支持 multi-step resolution
#   - 未来可扩展: interrupt system (enemy reaction)
# ============================================================
class_name VMStack
extends RefCounted


# ============================================================
# State
# ============================================================

var _stack: Array = []


# ============================================================
# Public API
# ============================================================

## 压入栈顶
func push(value) -> void:
	_stack.append(value)


## 弹出栈顶，栈空返回 null
func pop():
	if _stack.is_empty():
		return null
	return _stack.pop_back()


## 查看栈顶（不弹出），栈空返回 null
func peek():
	if _stack.is_empty():
		return null
	return _stack.back()


## 清空栈
func clear() -> void:
	_stack.clear()


## 栈大小
func size() -> int:
	return _stack.size()


## 栈是否为空
func is_empty() -> bool:
	return _stack.is_empty()


## 获取栈的浅拷贝（供 VMTrace 记录用）
func snapshot() -> Array:
	return _stack.duplicate()
