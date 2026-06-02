extends Node

var _cache: Dictionary = {}
var _all_ids: Array[String] = []


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	var dir: String = "res://resources/artifact_data/"
	var dir_access: DirAccess = DirAccess.open(dir)
	if dir_access == null:
		return
	dir_access.list_dir_begin()
	var file_name: String = dir_access.get_next()
	while file_name != "":
		if not dir_access.current_is_dir() and file_name.ends_with(".tres"):
			var art: ArtifactData = load(dir + file_name) as ArtifactData
			if art and not art.id.is_empty():
				_cache[art.id] = art
				_all_ids.append(art.id)
		file_name = dir_access.get_next()
	dir_access.list_dir_end()


func get_artifact(id: String) -> ArtifactData:
	return _cache.get(id)


func get_all_artifacts() -> Array[ArtifactData]:
	var result: Array[ArtifactData] = []
	for v in _cache.values():
		result.append(v)
	return result


func get_all_ids() -> Array[String]:
	return _all_ids.duplicate()
