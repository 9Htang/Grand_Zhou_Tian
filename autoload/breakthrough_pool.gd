extends Node

var _cache: Dictionary = {}
var _all_ids: Array[String] = []


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	var dir: String = "res://resources/breakthrough_options/"
	var dir_access: DirAccess = DirAccess.open(dir)
	if dir_access == null:
		return
	dir_access.list_dir_begin()
	var file_name: String = dir_access.get_next()
	while file_name != "":
		if not dir_access.current_is_dir() and file_name.ends_with(".tres"):
			var opt: BreakthroughOptionData = load(dir + file_name) as BreakthroughOptionData
			if opt and not opt.id.is_empty():
				_cache[opt.id] = opt
				_all_ids.append(opt.id)
		file_name = dir_access.get_next()
	dir_access.list_dir_end()


func get_option(id: String) -> BreakthroughOptionData:
	return _cache.get(id)


func draw_options(count: int = 3, current_realm: int = 1) -> Array[BreakthroughOptionData]:
	var pool: Array[BreakthroughOptionData] = []
	for opt in _cache.values():
		if current_realm >= opt.min_realm and current_realm <= opt.max_realm:
			var w: int = opt.weight
			for _j in range(w):
				pool.append(opt)

	pool.shuffle()
	var result: Array[BreakthroughOptionData] = []
	var seen: Dictionary = {}
	for opt in pool:
		if result.size() >= count:
			break
		if not seen.has(opt.id):
			seen[opt.id] = true
			result.append(opt)
	return result
