# ============================================================
# 大周天 — ProjectSettings 调试开关注册
# @tool 脚本在编辑器启动时运行，注册自定义项目设置
# ============================================================
@tool
extends Node


func _ready() -> void:
	# Sandbox 开关 — 默认 true（调试阶段），发布前改 false
	if not ProjectSettings.has_setting("game/debug/sandbox_enabled"):
		ProjectSettings.set_setting("game/debug/sandbox_enabled", true)
	ProjectSettings.set_as_basic("game/debug/sandbox_enabled", true)
	ProjectSettings.set_initial_value("game/debug/sandbox_enabled", true)
	# 注册后可在编辑器 Project Settings → Game → Debug 中切换

	# 日志等级 — 0=DEBUG 1=INFO 2=WARN 3=ERROR。调试阶段默认 DEBUG
	if not ProjectSettings.has_setting("game/log/level"):
		ProjectSettings.set_setting("game/log/level", 0)
	ProjectSettings.set_as_basic("game/log/level", true)
	ProjectSettings.set_initial_value("game/log/level", 0)

	# 日志是否同步输出到控制台
	if not ProjectSettings.has_setting("game/log/console"):
		ProjectSettings.set_setting("game/log/console", true)
	ProjectSettings.set_as_basic("game/log/console", true)
	ProjectSettings.set_initial_value("game/log/console", true)
