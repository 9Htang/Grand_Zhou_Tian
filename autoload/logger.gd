# ============================================================
# 大周天 — Logger (全局日志系统)
# ============================================================
# 用法（任意脚本中直接调用）:
#   Logger.info("Battle", "卡牌打出: %s" % card.display_name)
#   Logger.warn("QiFlow", "灵气碰撞: 路径阻塞")
#   Logger.error("Forge", "锻造失败: 祭品为空")
#   Logger.debug("CardDB", "加载卡牌: %d 张" % count)
# ============================================================
extends Node


enum Level { DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3 }


var _log_file: FileAccess = null
## 最低输出等级，低于此等级的日志被丢弃
var min_level: Level = Level.DEBUG
## 是否同步输出到 Godot 控制台
var log_to_console: bool = true


func _ready() -> void:
	min_level = ProjectSettings.get_setting("game/log/level", Level.DEBUG) as Level
	log_to_console = ProjectSettings.get_setting("game/log/console", true)

	var dir: DirAccess = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("logs"):
			dir.make_dir("logs")
	else:
		push_warning("Logger: 无法访问 user:// 目录")

	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var filename: String = "%04d%02d%02d_%02d%02d%02d.log" % [
		dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second
	]
	_log_file = FileAccess.open("user://logs/" + filename, FileAccess.WRITE)
	if _log_file:
		_store("Logger", Level.INFO, "日志系统已启动 — %s" % filename)
	else:
		push_warning("Logger: 无法创建日志文件 user://logs/" + filename)


func _exit_tree() -> void:
	if _log_file:
		_log_file.close()
		_log_file = null


# ============================================================
# 公共接口
# ============================================================


## 写入一条日志
func write(level: Level, category: String, message: String) -> void:
	if level < min_level:
		return
	_store(category, level, message)


## 调试日志（仅开发阶段可见）
func debug(category: String, message: String) -> void:
	write(Level.DEBUG, category, message)


## 信息日志
func info(category: String, message: String) -> void:
	write(Level.INFO, category, message)


## 警告日志
func warn(category: String, message: String) -> void:
	write(Level.WARN, category, message)


## 错误日志
func error(category: String, message: String) -> void:
	write(Level.ERROR, category, message)


# ============================================================
# Internal
# ============================================================


func _store(category: String, level: Level, message: String) -> void:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var ts: String = "%02d:%02d:%02d" % [dt.hour, dt.minute, dt.second]
	var line: String = "%s [%s] [%s] %s" % [ts, _level_tag(level), category, message]

	if log_to_console:
		match level:
			Level.ERROR:
				printerr(line)
			Level.WARN:
				push_warning(line)
			_:
				print(line)

	if _log_file:
		_log_file.store_line(line)
		# 每条日志立即刷盘，避免崩溃时丢失
		_log_file.flush()


func _level_tag(lv: Level) -> String:
	match lv:
		Level.DEBUG: return "DBG"
		Level.INFO:  return "INF"
		Level.WARN:  return "WRN"
		Level.ERROR: return "ERR"
	return "???"
