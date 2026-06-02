extends Node

var _cache: Dictionary = {}
var _all_ids: Array[String] = []


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	var dir: String = "res://resources/card_data/"
	var files: Array[String] = _get_tres_files(dir)
	for file: String in files:
		var card: CardData = load(dir + file) as CardData
		if card and not card.id.is_empty():
			_cache[card.id] = card
			_all_ids.append(card.id)


func get_card(id: String) -> CardData:
	if id.ends_with("+"):
		var base: CardData = _cache.get(id.trim_suffix("+"))
		if base:
			return base.apply_upgrade()
	return _cache.get(id)


func get_all_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	for v in _cache.values():
		result.append(v)
	return result


func get_all_card_ids() -> Array[String]:
	return _all_ids.duplicate()


func get_cards_by_pool(pool_ids: Array[String]) -> Array[CardData]:
	var result: Array[CardData] = []
	for id: String in pool_ids:
		var card: CardData = get_card(id)
		if card:
			result.append(card)
	return result


func get_random_cards(count: int, exclude_ids: Array[String] = []) -> Array[CardData]:
	var pool: Array[CardData] = []
	for id: String in _all_ids:
		if id not in exclude_ids:
			var card: CardData = _cache.get(id)
			if card:
				pool.append(card)
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))


func _get_tres_files(dir_path: String) -> Array[String]:
	var files: Array[String] = []
	var da: DirAccess = DirAccess.open(dir_path)
	if da == null:
		return files
	da.list_dir_begin()
	var file_name: String = da.get_next()
	while file_name != "":
		if not da.current_is_dir() and file_name.ends_with(".tres"):
			files.append(file_name)
		file_name = da.get_next()
	da.list_dir_end()
	return files
