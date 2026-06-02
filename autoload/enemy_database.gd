extends Node

var _cache: Dictionary = {}
var _all_ids: Array[String] = []


func _ready() -> void:
	_create_defaults()
	_load_all()


func _create_defaults() -> void:
	# Wild Wolf
	var wolf := EnemyData.new()
	wolf.id = "wild_wolf"
	wolf.display_name = "妖狼"
	wolf.max_hp = 20
	wolf.realm = 1
	wolf.element = "木"
	wolf.reward_gold = 8
	wolf.reward_cultivation = 15
	wolf.texture_color = Color(0.3, 0.5, 0.3)

	var a1 := EnemyActionData.new()
	a1.intent = 0; a1.damage = 6; a1.weight = 3
	var a2 := EnemyActionData.new()
	a2.intent = 2; a2.block = 5; a2.weight = 2
	var a3 := EnemyActionData.new()
	a3.intent = 3; a3.buff_self = "strength:2"; a3.weight = 1
	wolf.actions = [a1, a2, a3]
	_cache["wild_wolf"] = wolf
	_all_ids.append("wild_wolf")

	# Rogue Cultivator
	var rogue := EnemyData.new()
	rogue.id = "rogue_cultivator"
	rogue.display_name = "散修"
	rogue.max_hp = 26
	rogue.realm = 1
	rogue.element = "水"
	rogue.reward_gold = 12
	rogue.reward_cultivation = 22
	rogue.texture_color = Color(0.2, 0.3, 0.7)

	var ra1 := EnemyActionData.new()
	ra1.intent = 0; ra1.damage = 8; ra1.weight = 2
	var ra2 := EnemyActionData.new()
	ra2.intent = 7; ra2.damage = 3; ra2.debuff_player = "energy_down:1"; ra2.weight = 2
	var ra3 := EnemyActionData.new()
	ra3.intent = 2; ra3.block = 6; ra3.weight = 1
	rogue.actions = [ra1, ra2, ra3]
	_cache["rogue_cultivator"] = rogue
	_all_ids.append("rogue_cultivator")

	# Boss Elder
	var boss := EnemyData.new()
	boss.id = "boss_elder"
	boss.display_name = "执事长老"
	boss.max_hp = 55
	boss.realm = 2
	boss.element = "火"
	boss.reward_gold = 30
	boss.reward_cultivation = 60
	boss.texture_color = Color(0.8, 0.2, 0.2)

	var ba1 := EnemyActionData.new()
	ba1.intent = 0; ba1.damage = 14; ba1.weight = 2
	var ba2 := EnemyActionData.new()
	ba2.intent = 1; ba2.damage = 5; ba2.weight = 2
	var ba3 := EnemyActionData.new()
	ba3.intent = 5; ba3.target_node = "random"; ba3.weight = 2
	var ba4 := EnemyActionData.new()
	ba4.intent = 3; ba4.buff_self = "strength:3"; ba4.weight = 1
	boss.actions = [ba1, ba2, ba3, ba4]
	_cache["boss_elder"] = boss
	_all_ids.append("boss_elder")


func _load_all() -> void:
	var dir: String = "res://resources/enemy_data/"
	var dir_access: DirAccess = DirAccess.open(dir)
	if dir_access == null:
		return
	dir_access.list_dir_begin()
	var file_name: String = dir_access.get_next()
	while file_name != "":
		if not dir_access.current_is_dir() and file_name.ends_with(".tres"):
			# Skip if already created by _create_defaults()
			var base_id: String = file_name.replace(".tres", "")
			if not _cache.has(base_id):
				var enemy: EnemyData = load(dir + file_name)
				if enemy and not enemy.id.is_empty():
					_cache[enemy.id] = enemy
					_all_ids.append(enemy.id)
		file_name = dir_access.get_next()
	dir_access.list_dir_end()


func get_enemy(id: String) -> EnemyData:
	return _cache.get(id)


func get_all_enemies() -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	for v in _cache.values():
		result.append(v)
	return result


func get_enemies_by_ids(ids: Array[String]) -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	for id: String in ids:
		var e: EnemyData = get_enemy(id)
		if e:
			result.append(e)
	return result
