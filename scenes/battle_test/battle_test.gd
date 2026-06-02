# ============================================================
# 大周天 — Battle Test Sandbox
# 启动后直接进入战斗，自动注入测试数据
# ============================================================
extends Node


func _ready() -> void:
	_setup_test_data()
	_launch_battle()


func _setup_test_data() -> void:
	# --- 玩家状态 ---
	GameManager.player_hp = 80
	GameManager.player_max_hp = 80
	GameManager.dantian_qi = 5
	GameManager.dantian_capacity = 10
	GameManager.qi_gather_rate = 3
	GameManager.realm = 1
	GameManager.talent = 2
	GameManager.cultivation = 0
	GameManager.cultivation_to_next = 100
	GameManager.gold = 0
	GameManager.current_block = 0
	GameManager.active_techniques.clear()
	GameManager.active_buffs.clear()
	GameManager.artifacts.clear()
	GameManager.damaged_pathways.clear()
	GameManager.node_base_buffs.clear()
	GameManager.current_chapter = 1
	GameManager.current_encounter_index = 0
	GameManager.turn_count = 0

	# --- 测试牌组 ---
	GameManager.master_deck = [
		"attack_basic", "attack_basic", "attack_basic", "attack_basic",
		"defense_basic", "defense_basic",
		"technique_fire_heart", "technique_fire_heart",
		"qi_gathering",
		"healing_breeze",
	]

	# --- 默认经脉 ---
	GameManager.base_meridian = MeridianRegistry.get_meridian("small_circuit")

	# --- 穴位特性测试：给已解锁的节点分配特性 ---
	var mer: MeridianMapData = GameManager.base_meridian
	if mer:
		# 解锁全部节点以便测试特性
		for node in mer.nodes:
			if node:
				node.unlocked = true
				node.current_qi = node.capacity * 0.5  # 注入灵气触发特性
		# 命门(火) — apply_burn:3
		var n2: MeridianNodeData = mer.get_node(2)
		if n2: n2.properties = ["apply_burn:3"]
		# 百会(土) — multi_target
		var n5: MeridianNodeData = mer.get_node(5)
		if n5: n5.properties = ["multi_target"]
		# 气海(水) — life_steal:0.2
		var n3: MeridianNodeData = mer.get_node(3)
		if n3: n3.properties = ["life_steal:0.2"]
		# 膻中(金) — pierce:2
		var n4: MeridianNodeData = mer.get_node(4)
		if n4: n4.properties = ["pierce:2"]


func _launch_battle() -> void:
	var BattleScreenScript: GDScript = load("res://scenes/battle/battle_screen.gd") as GDScript
	var battle := CanvasLayer.new()
	battle.set_script(BattleScreenScript)
	battle.name = "BattleScreen"
	add_child(battle)
