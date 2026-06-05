# ============================================================
# 大周天 — MockScreen (模拟用空 Screen)
# ============================================================
# 工具层: tools/simulation/ — 不属于四层运行时架构
#
# 满足 BattleBootstrapper.bootstrap(screen, ...) 的 screen 接口。
# 所有 UI 方法为空实现 — 模拟器无 UI/动画/Node 树。
#
# 重要: 不重写 has_method()。
#   - Node.has_method() 检查真实方法列表
#   - 未来新增 screen 方法时，编译器的 "方法未找到" 错误会暴露漏实现
#   - 如果用 `has_method() → true` 会隐藏此错误
# ============================================================
class_name MockScreen
extends Node


# === BattleBootstrapper 需要的方法 ===

## 锻造结果显示 (模拟器: 无 UI, 忽略)
func show_forge_result(_data: Dictionary) -> void:
	pass


## 锻造提示更新 (模拟器: 忽略)
func show_forge_hint(_data: Dictionary) -> void:
	pass


## 效果执行完成通知 (模拟器: 忽略)
func notify_effect_execution_done(_data: Dictionary) -> void:
	pass


## 锻造 UI 清除 (模拟器: 忽略)
func clear_forge_ui() -> void:
	pass


# === QiCirculationService 需要的方法 ===

## 穴位解锁通知 (模拟器: 忽略)
func notify_node_unlocked(_node_name: String) -> void:
	pass


# === BattleFlowOrchestrator 需要的方法 ===

## 功法溢出处理 (模拟器: 功法不溢出, 忽略)
func _handle_technique_overflow(_tech: TechniqueData) -> void:
	pass
