# ============================================================
# 大周天 — AutoDrawSystem (定时自动抽牌 — L2)
# ============================================================
# 四层定位: L2 Domain Layer — 代替回合开始统一抽牌
#
# 职责:
#   - 定时自动从牌库抽牌到手牌
#   - 支持加速/减速 (buff 影响抽牌间隔)
#
# 红线:
#   ❌ 不操作 UI
#   ❌ 不持有牌库引用 (通过 DeckManager 操作)
# ============================================================
class_name AutoDrawSystem
extends RefCounted


## 发射: 抽牌发生
signal card_drawn()

## 发射: 抽牌间隔到达但牌库为空
signal draw_failed_empty()


## 基础抽牌间隔 (秒)
var draw_interval: float = 3.0

## 每次抽牌数量
var draw_count: int = 1

## 内部计时器
var _timer: float = 0.0

## 牌库管理引用 (由 Bootstrapper 注入)
var deck_manager: DeckManager = null

## 冷却管理引用, 用于跳过冷却中的卡牌
var cooldown_manager: CooldownManager = null

## 抽牌节奏系统引用 (由 Bootstrapper 注入)
var pacing_system: CardPacingSystem = null


## 唯一刷新入口——设置 draw_interval（生产/仿真/restore 统一走此方法）
func apply_pacing(speed: float, override: float = 0.0) -> void:
	if pacing_system:
		draw_interval = pacing_system.get_interval(speed, override)


## 信号中间层——speed 变更时调用，未来可插 buff delay / animation sync / UI preview
func request_pacing_update(speed: float) -> void:
	apply_pacing(speed, 0.0)


## 重置计时器 (战斗开始时调用)
func reset() -> void:
	_timer = draw_interval * 0.5  # 首次抽牌加快


## 每 tick 递减计时器
func tick(delta: float) -> void:
	if deck_manager == null:
		return

	_timer -= delta
	if _timer <= 0.0:
		_timer += draw_interval
		_draw_cards()


func _draw_cards() -> void:
	if deck_manager.draw_pile.is_empty() and deck_manager.discard_pile.is_empty():
		draw_failed_empty.emit()
		return

	var drawn: Array = deck_manager.draw_cards(draw_count)
	if drawn.is_empty():
		draw_failed_empty.emit()
	else:
		card_drawn.emit()
