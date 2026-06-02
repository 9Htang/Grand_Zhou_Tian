# ============================================================
# 大周天 — Technique Database (功法资源索引)
# ============================================================
extends Node

var _cache: Dictionary = {}
var _all_ids: Array[String] = []


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	var dir: String = "res://resources/technique_data/"
	var dir_access: DirAccess = DirAccess.open(dir)
	if dir_access == null:
		return
	dir_access.list_dir_begin()
	var file_name: String = dir_access.get_next()
	while file_name != "":
		if not dir_access.current_is_dir() and file_name.ends_with(".tres"):
			var tech: TechniqueData = load(dir + file_name)
			if tech and not tech.id.is_empty():
				_cache[tech.id] = tech
				_all_ids.append(tech.id)
		file_name = dir_access.get_next()
	dir_access.list_dir_end()


func get_technique(id: String) -> TechniqueData:
	return _cache.get(id)


func get_all_techniques() -> Array[TechniqueData]:
	return _cache.values()


func get_all_ids() -> Array[String]:
	return _all_ids.duplicate()


func get_starting_techniques() -> Array[TechniqueData]:
	# Return techniques suitable for starting choice
	var result: Array[TechniqueData] = []
	for id in _all_ids:
		result.append(_cache[id])
	return result
