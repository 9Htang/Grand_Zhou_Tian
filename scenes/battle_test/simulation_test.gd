# ============================================================
# 大周天 — Simulation Test Sandbox
# 启动后直接运行模拟战斗并打印报告
# ============================================================
extends Node


func _ready() -> void:
	_setup_test_data()
	# 延迟一帧确保所有 autoload 就绪
	await get_tree().process_frame
	_run_stress_test()
	_run_simulation()
	_run_replay_test()


## 长期回归压力测试 — 多 seed × N 次 replay 全 hash 一致性
func _run_stress_test() -> void:
	print("========================================")
	print("  Stress Test — Determinism Regression")
	print("========================================")

	const SEEDS: Array[int] = [1, 42, 999, 123456]
	const ITERATIONS: int = 20  # CI 快速: 20; 完整回归: 100
	const MAX_TICKS: int = 40  # 2s @ 0.05 tick

	var total_pass: int = 0
	var total_fail: int = 0

	for seed_val in SEEDS:
		var seed_failures: int = 0
		var first_hash_chain: Array[int] = []
		print("  Seed %d: running %d iterations..." % [seed_val, ITERATIONS])

		for iteration in range(ITERATIONS):
			# 1. 创建独立 PlayerActor（必须 add_child 才能让 BattleClock 信号工作）
			var player := PlayerActor.new()
			add_child(player)
			player.load_from_gm()
			player.reset_meridian_for_battle()

			# 2. 配置 input
			var input := SimulationInput.new()
			input.seed = seed_val
			input.tick_rate = 0.05
			input.max_ticks = MAX_TICKS
			input.auto_play_enabled = true
			input.execution_mode = SimulationInput.ExecutionMode.SIMULATION

			var config := SimulationConfig.new()
			config.encounter_id = "ch1_encounter_1"
			config.duration = float(MAX_TICKS) * 0.05
			config.seed = seed_val
			config.tick_rate = 0.05
			input.config = config

			# 3. Original run
			var kernel := SimulationKernel.new()
			kernel.set_player(player)
			var original_run: SimulationRun = kernel.run(input)

			# 4. Replay — 独立 player
			var replay_player := PlayerActor.new()
			add_child(replay_player)
			replay_player.load_from_gm()
			replay_player.reset_meridian_for_battle()

			var engine := ReplayEngine.new()
			var result: ReplayEngine.ReplayResult = engine.replay(original_run, replay_player)

			# 5. 校验
			if not result.hashes_match:
				seed_failures += 1
				if seed_failures == 1:
					print("    [FAIL] iter=%d divergence_tick=%d" % [iteration, result.divergence_tick])

			if iteration == 0:
				first_hash_chain = original_run.state_hashes.duplicate()
			elif first_hash_chain != original_run.state_hashes:
				seed_failures += 1
				if seed_failures <= 2:
					print("    [FAIL] iter=%d cross-run hash divergence" % iteration)

			# 6. 清理本轮节点，防止累积拖慢后续迭代
			remove_child(player)
			player.queue_free()
			remove_child(replay_player)
			replay_player.queue_free()

		# 汇总
		var passed: int = ITERATIONS - seed_failures
		total_pass += passed
		total_fail += seed_failures
		var status: String = "PASS" if seed_failures == 0 else "FAIL"
		print("  Seed %6d: %s (%d/%d)" % [seed_val, status, passed, ITERATIONS])

	print("\n  Total: %d/%d seeds passed, %d/%d iterations passed" % [
		SEEDS.size() - (1 if total_fail > 0 else 0), SEEDS.size(),
		total_pass, total_pass + total_fail])
	print("========================================")
	print("  Stress Test Complete")
	print("========================================")

	if total_fail > 0:
		print("\n  ❌ REGRESSION DETECTED — %d failures" % total_fail)
	else:
		print("\n  ✅ All deterministic — replay foundation is stable")


func _setup_test_data() -> void:
	# --- 玩家状态 ---
	GameManager.player_hp = 80
	GameManager.player_max_hp = 80
	GameManager.dantian_qi = 5
	GameManager.dantian_capacity = 10
	GameManager.qi_gather_rate = 3
	GameManager.realm = 1
	GameManager.talent = 2
	GameManager.speed = 1.0
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
	GameManager.elapsed_seconds = 0

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


func _run_simulation() -> void:
	print("========================================")
	print("  Simulation Test — Phase 1 First Run")
	print("========================================")

	# 1. 创建 PlayerActor (与 BattleScreen 相同流程)
	var player := PlayerActor.new()
	player.name = "PlayerActor"
	add_child(player)
	player.load_from_gm()
	player.reset_meridian_for_battle()

	print("\n[Player]")
	print("  HP: %d/%d" % [player.hp, player.max_hp])
	print("  Qi: %d/%d (gather: %d)" % [player.dantian_qi, player.dantian_capacity, player.qi_gather_rate])
	print("  Realm: %d  Talent: %d  Speed: %.1f" % [player.realm, player.talent, player.speed])
	print("  Deck Size: %d" % GameManager.master_deck.size())

	# 2. 配置模拟
	var config := SimulationConfig.new()
	config.encounter_id = "ch1_encounter_1"
	config.duration = 30.0  # 30秒快速测试
	config.seed = 42
	# tick_rate 使用 SimulationConfig 默认值 (0.025 = 40 TPS)
	# 如需覆盖: config.tick_rate = 0.05
	config.auto_play_enabled = true

	print("\n[Config]")
	print("  Encounter: %s" % config.encounter_id)
	print("  Duration: %.0fs  Tick: %.2fs  Seed: %d  Draw: %d/%.1fs" % [config.duration, config.tick_rate, config.seed, config.draw_count, config.draw_interval])

	# 3. 运行模拟
	print("\n[Running Simulation...]")
	var runner := SimulationRunner.new()
	var report := runner.run(player, config)

	# 4. 输出报告
	print("\n" + report.to_text())
	print("\n========================================")
	print("  Simulation Test Complete")
	print("========================================")

	# 5. 输出前5条事件作为样本
	print("\n[Sample Events (first 5)]")
	var count: int = min(5, report.raw_events.size())
	for i in count:
		var e: SimulationEvent = report.raw_events[i]
		print("  [%.2fs] %s | %s | %s" % [e.time, e.type, e.actor_id, e.payload])

	# 6. 回放验证
	_run_replay_test()

	# 7. 退出
	print("\n... exiting in 3s ...")
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()


## 回放验证: 用 SimulationKernel 跑一次 → ReplayEngine 重跑 → 比对一致性
func _run_replay_test() -> void:
	print("\n========================================")
	print("  Replay Test — Determinism Verification")
	print("========================================")

	# 1. 创建 PlayerActor
	var player := PlayerActor.new()
	player.name = "PlayerActor_Replay"
	add_child(player)
	player.load_from_gm()
	player.reset_meridian_for_battle()

	# 2. 配置 SimulationInput（模拟 Kernel 输入）
	var input := SimulationInput.new()
	input.seed = 42
	input.tick_rate = 0.05
	input.max_ticks = 600  # 30s @ 0.05 tick
	input.auto_play_enabled = true
	input.execution_mode = SimulationInput.ExecutionMode.SIMULATION

	# 设置 config 以指定 encounter
	var config := SimulationConfig.new()
	config.encounter_id = "ch1_encounter_1"
	config.duration = 30.0
	config.seed = 42
	config.tick_rate = 0.05
	input.config = config

	# 3. 第一次运行 — 产生原始 SimulationRun
	print("\n[Original Run]")
	var kernel := SimulationKernel.new()
	kernel.set_player(player)
	var original_run: SimulationRun = kernel.run(input)
	print("  Win: %s | Ticks: %d | Events: %d | RNG Calls: %d | Hashes: %d" % [
		original_run.win, original_run.total_ticks,
		original_run.events.size(), original_run.rng_call_count,
		original_run.state_hashes.size()
	])

	# 4. 检查 event 中有多少 INPUT 动作
	var input_events: int = 0
	for e in original_run.events.all():
		if e.payload.get("source_type", "") == "INPUT":
			input_events += 1
	print("  INPUT events (card_played): %d" % input_events)

	# 5. ReplayActionCompiler 反向编译
	var actions: Array[SimulationAction] = ReplayActionCompiler.compile(original_run.events.all())
	print("\n[ReplayActionCompiler]")
	print("  Compiled %d actions from %d events" % [actions.size(), original_run.events.size()])
	for i in min(3, actions.size()):
		var a: SimulationAction = actions[i]
		print("  [%d] PLAY_CARD idx=%d card=%s target=%d" % [a.id, a.card_index, a.card_id, a.target_index])

	# 6. ReplayEngine Full Replay — 需要新 PlayerActor（原始 player 已被修改）
	print("\n[ReplayEngine — Full Replay]")
	var replay_player := PlayerActor.new()
	replay_player.name = "PlayerActor_Replay_2"
	add_child(replay_player)
	replay_player.load_from_gm()
	replay_player.reset_meridian_for_battle()

	var engine := ReplayEngine.new()
	var result: ReplayEngine.ReplayResult = engine.replay(original_run, replay_player)
	print("  Actions replayed: %d" % result.total_actions)
	print("  Hashes match: %s" % result.hashes_match)
	print("  Divergence tick: %d" % result.divergence_tick)
	if not result.hashes_match:
		print("  Divergence reason: %s" % result.divergence_reason)

	# 7. ReplayVerifier — 独立验证模块
	print("\n[ReplayVerifier]")
	var vresult: ReplayVerifier.VerifyResult = ReplayVerifier.verify(original_run, result.replay_run)
	print(ReplayVerifier.to_text(vresult))
	print("  Compiler actions: %d | Original recorded: %d | Replay recorded: %d" % [
		actions.size(), original_run.actions.size(), result.replay_run.actions.size()])

	# 8. EventCursor 测试
	print("\n[EventCursor]")
	var cursor := EventCursor.new()
	cursor.load(original_run)
	var evt: SimulationEvent = cursor.step_forward()
	if evt:
		print("  step_forward: [%.2fs] %s (action_id=%d)" % [evt.time, evt.type, evt.action_id])
	evt = cursor.step_backward()
	if evt:
		print("  step_backward: [%.2fs] %s (action_id=%d)" % [evt.time, evt.type, evt.action_id])
	cursor.seek(0)
	print("  seek(0): index=%d" % cursor.current_index)

	print("\n========================================")
	print("  Replay Test Complete")
	print("========================================")
