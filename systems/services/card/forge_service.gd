# ============================================================
# 大周天 — ForgeService (锻淬领域 — L2)
# 职责: 锻真诀多步状态机 — 薪火相传(pass_torch) + 离火易象(swap_li)
# 红线: 不做 UI, 不访问 autoload, 不直接修改 actor 状态
# UI 通知通过 signal 发射, 由 L1/BattleScreen 连接
# ============================================================
class_name ForgeService
extends RefCounted


## 锻造结果就绪 (替代 screen.show_forge_result)
signal forge_result_ready(result: CardForgeResult)

## 锻造提示更新 (替代 screen.show_forge_hint)
signal forge_hint_changed(hint: String)

## 锻造完成 (替代 screen.notify_effect_execution_done)
signal forge_finished()

## 锻造取消 (替代 screen.clear_forge_ui)
signal forge_cancelled()


# === Injected References (set by BattleController) ===
var player: PlayerActor = null
var deck_manager: DeckManager = null
var card_repo: CardRepository = null
var target_manager: TargetManager = null
var context_factory: BattleContextFactory = null


# === Forge State Machine ===
## 锻造步骤: 0=未激活 1-5=进行中
var forge_step: int = 0
## 锻造类型: "pass_torch" | "swap_li"
var forge_type: String = ""
## 锻造卡自身 (触发锻造的卡牌)
var forge_card_data: CardData = null
## 祭品卡 A (薪火相传) / 卡牌 A (离火易象)
var forge_card_a: CardData = null
## 受体卡 B (薪火相传) / 卡牌 B (离火易象)
var forge_card_b: CardData = null
## A 被选中的特性
var forge_feature_a: Dictionary = {}
## B 被选中的特性
var forge_feature_b: Dictionary = {}


# ============================================================
# Public API
# ============================================================


## 启动锻造流程 — 由 BattleController.play_card 在检测到 FORGE 行为时调用
func start_forge(card_data: CardData, p_forge_type: String) -> void:
	forge_card_data = card_data
	forge_type = p_forge_type
	forge_card_a = null
	forge_card_b = null
	forge_feature_a = {}
	forge_feature_b = {}

	forge_step = 1
	_request_card_selection("hand", card_data.id, "选择祭品卡牌")


## SelectionDispatcher 消费者接口: 选择完成
## 返回 true = 已消费事件
func on_selection_completed(_selector: Dictionary, selected: Array) -> bool:
	if not is_active():
		return false
	advance_step(_selector, selected)
	return true


## SelectionDispatcher 消费者接口: 选择取消
func on_selection_cancelled() -> void:
	if is_active():
		cancel()


## 是否处于锻造流程中
func is_active() -> bool:
	return forge_step > 0


## 取消锻造流程 (Esc / 外部中断) → 发射 forge_cancelled 信号
## 幂等: 重复调用不重复发射信号
func cancel() -> void:
	if not is_active():
		return
	_reset_state()
	forge_cancelled.emit()


## 锻造流程完成 → 发射 forge_finished 信号
func finish() -> void:
	_reset_state()
	forge_finished.emit()


# ============================================================
# Internal — Step Dispatch
# ============================================================


## 锻造选择完成 → 分发到对应步骤机
func advance_step(_selector: Dictionary, selected: Array) -> void:
	if forge_step <= 0:
		return

	match forge_type:
		"pass_torch":
			_advance_pass_torch(selected)
		"swap_li":
			_advance_swap_li(selected)
		_:
			cancel()


# ============================================================
# Pass Torch (薪火相传) Step Machine
# ============================================================


func _advance_pass_torch(selected: Array) -> void:
	match forge_step:
		1:  # 选择了祭品 A
			if selected.is_empty():
				cancel(); return
			forge_card_a = selected[0].get("card")
			forge_step = 2
			_request_card_selection("hand", forge_card_a.id, "选择受体卡牌")
		2:  # 选择了受体 B → 执行
			if selected.is_empty():
				cancel(); return
			forge_card_b = selected[0].get("card")
			forge_step = 5
			_execute_pass_torch()
		_:
			cancel()


# ============================================================
# Swap Li (离火易象) Step Machine
# ============================================================


func _advance_swap_li(selected: Array) -> void:
	match forge_step:
		1:  # 选择了卡牌 A
			if selected.is_empty():
				cancel(); return
			forge_card_a = selected[0].get("card")
			forge_step = 2
			_request_card_selection("hand", forge_card_a.id, "选择卡牌 B")
		2:  # 选择了卡牌 B
			if selected.is_empty():
				cancel(); return
			forge_card_b = selected[0].get("card")
			forge_step = 3
			_request_feature_selection(forge_card_a.id, "选择 A 的特性 (将被移到 B)")
		3:  # 选择了 A 的特性
			if selected.is_empty():
				cancel(); return
			forge_feature_a = selected[0]
			forge_step = 4
			_request_feature_selection(forge_card_b.id, "选择 B 的特性 (将被移到 A)")
		4:  # 选择了 B 的特性 → 执行
			if selected.is_empty():
				cancel(); return
			forge_feature_b = selected[0]
			forge_step = 5
			_execute_swap_li()
		_:
			cancel()


# ============================================================
# Execute — Pass Torch
# ============================================================


func _execute_pass_torch() -> void:
	if forge_card_a == null or forge_card_b == null:
		cancel(); return

	var shenshi: int = player.get("divine_sense") if player.get("divine_sense") != null else 0
	var luck: int = player.get("luck") if player.get("luck") != null else 0

	# 通过 CardRepository 获取/创建 B 的实例
	var inst_b: CardInstance = card_repo.bind_clone(forge_card_b)
	var b_conv: int = inst_b.get_conversion_count()

	# 从 A 随机提取特性
	var inst_a: CardInstance = CardFactory.create_instance(forge_card_a.id)
	forge_feature_a = DeckService.extract_random_feature(inst_a, shenshi)

	# 成功率判定
	var success: bool = DeckService.roll_success(60, luck, b_conv, 5, 95)

	# 构建结果
	var result: CardForgeResult
	if success:
		if not forge_feature_a.is_empty():
			DeckService.apply_feature(inst_b, forge_feature_a)
			result = CardForgeResult.success_pass_torch(forge_feature_a, forge_feature_a, forge_card_a.display_name, forge_card_b.display_name)
		else:
			result = CardForgeResult.failure_pass_torch({}, forge_card_b.display_name)
	else:
		var lost: Dictionary = DeckService.remove_random_feature(inst_b)
		result = CardForgeResult.failure_pass_torch(lost, forge_card_b.display_name)

	inst_b.increment_conversion_count()
	card_repo.add(inst_b)

	# A 移除
	deck_manager.exhaust_card(forge_card_a)
	if player.has_method("remove_card"):
		player.remove_card(forge_card_a.id)

	forge_result_ready.emit(result)
	finish()


# ============================================================
# Execute — Swap Li
# ============================================================


func _execute_swap_li() -> void:
	if forge_card_a == null or forge_card_b == null:
		cancel(); return
	if forge_feature_a.is_empty() or forge_feature_b.is_empty():
		cancel(); return

	var luck: int = player.get("luck") if player.get("luck") != null else 0

	var inst_a: CardInstance = card_repo.bind_clone(forge_card_a)
	var inst_b: CardInstance = card_repo.bind_clone(forge_card_b)

	var max_conv: int = maxi(inst_a.get_conversion_count(), inst_b.get_conversion_count())
	var success: bool = DeckService.roll_success(50, luck, max_conv, 5, 90)

	var result: CardForgeResult
	if success:
		var swapped: bool = DeckService.swap_features(inst_a, forge_feature_a, inst_b, forge_feature_b)
		if swapped:
			result = CardForgeResult.success_swap_li(forge_feature_a, forge_feature_b, forge_card_a.display_name, forge_card_b.display_name)
		else:
			result = CardForgeResult.failure_swap_li(forge_feature_a, forge_feature_b)
	else:
		DeckService.remove_specific_feature(inst_a, forge_feature_a)
		DeckService.remove_specific_feature(inst_b, forge_feature_b)
		result = CardForgeResult.failure_swap_li(forge_feature_a, forge_feature_b)

	inst_a.increment_conversion_count()
	inst_b.increment_conversion_count()
	card_repo.add(inst_a)
	card_repo.add(inst_b)

	forge_result_ready.emit(result)
	finish()


# ============================================================
# Internal — Selection Requests
# ============================================================


## 请求锻造卡牌选择
func _request_card_selection(pool: String, exclude_id: String, hint: String) -> void:
	var exclude_ids: Array[String] = []
	if not exclude_id.is_empty():
		exclude_ids.append(exclude_id)
	# 始终排除锻造卡自身
	if forge_card_data and forge_card_data.id not in exclude_ids:
		exclude_ids.append(forge_card_data.id)
	var selector: Dictionary = {"type": "card", "pool": pool, "count": 1, "exclude_ids": exclude_ids}
	target_manager.request(selector, context_factory.build_minimal())
	forge_hint_changed.emit(hint)


## 请求锻造特性选择
func _request_feature_selection(card_id: String, hint: String) -> void:
	var shenshi: int = player.get("divine_sense") if player.get("divine_sense") != null else 0
	var selector: Dictionary = {"type": "feature", "card_id": card_id, "count": 1, "shenshi": shenshi}
	target_manager.request(selector, context_factory.build_minimal())
	forge_hint_changed.emit(hint)


## 重置锻造状态
func _reset_state() -> void:
	forge_step = 0
	forge_type = ""
	forge_card_data = null
	forge_card_a = null
	forge_card_b = null
	forge_feature_a = {}
	forge_feature_b = {}
