# ============================================================
# 大周天 — Scene Manager (场景过渡)
# ============================================================
extends CanvasLayer

var _current_scene_path: String = ""


func _ready() -> void:
	# 初始场景由主场景自行处理（battle_test 直接进战斗，main 跳到菜单）
	pass


func switch_to_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		printerr("SceneManager: scene not found: ", path)
		return

	_current_scene_path = path
	get_tree().change_scene_to_file(path)


func go_to_battle(encounter_id: String) -> void:
	# Store encounter data for battle scene to read
	switch_to_scene("res://scenes/battle/battle_screen.tscn")


func go_to_reward() -> void:
	switch_to_scene("res://scenes/reward/reward_screen.tscn")


func go_to_map() -> void:
	switch_to_scene("res://scenes/chapter_map/chapter_map.tscn")


func go_to_main_menu() -> void:
	switch_to_scene("res://scenes/menu/main_menu.tscn")


func go_to_breakthrough() -> void:
	switch_to_scene("res://scenes/breakthrough/breakthrough_screen.tscn")


func go_to_game_over(won: bool) -> void:
	switch_to_scene("res://scenes/game_over/game_over_screen.tscn")
