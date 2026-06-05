# ============================================================
# 大周天 — SelectionDispatcher (选择事件分发器 — L2)
# 职责: 盲转发 TargetManager 信号 → 注册的消费者
# 红线: 不知道消费者内部状态, 不做业务判断, 纯迭代转发
# ============================================================
class_name SelectionDispatcher
extends RefCounted


## 效果执行完成时发射 (替代 screen.notify_effect_execution_done)
signal effect_execution_done(result: Dictionary)

## 锻造 UI 清理时发射 (替代 screen.clear_forge_ui)
signal forge_cancelled()


# === Consumer Registry ===
## 每个 consumer: { "obj": Object, "completed": String, "cancelled": String }
var _consumers: Array[Dictionary] = []


# ============================================================
# Registration
# ============================================================


## 注册选择事件消费者
## obj: 服务对象
## completed_method: 方法名 — func(selector: Dictionary, selected: Array) -> bool
## cancelled_method: 方法名 (optional) — func() -> void
func register(obj: Object, completed_method: String, cancelled_method: String = "") -> void:
	_consumers.append({
		"obj": obj,
		"completed": completed_method,
		"cancelled": cancelled_method,
	})


# ============================================================
# Blind Dispatch — L2 纯转发, 不做 if/elif 业务判断
# ============================================================


## 选择完成 → 逐个尝试消费者, 第一个返回 true 即消费
func dispatch_completed(selector: Dictionary, selected: Array) -> void:
	print("[SelectionDispatcher] consumers=%d selected=%s" % [_consumers.size(), selected])
	for entry in _consumers:
		var obj: Object = entry["obj"]
		var consumed: bool = obj.call(entry["completed"], selector, selected)
		if consumed:
			return


## 选择取消 → 逐个通知所有注册了 cancelled 方法的消费者
func dispatch_cancelled() -> void:
	for entry in _consumers:
		if entry["cancelled"].is_empty():
			continue
		var obj: Object = entry["obj"]
		obj.call(entry["cancelled"])
