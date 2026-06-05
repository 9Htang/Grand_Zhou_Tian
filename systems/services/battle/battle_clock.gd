# ============================================================
# 大周天 — BattleClock (即时战斗主时钟 — L2)
# ============================================================
# 四层定位: L2 Domain Layer — 时间驱动基础设施
#
# 职责:
#   - _process 驱动 tick 循环 (0.25s = 4 ticks/s)
#   - 发射 tick 信号供所有子系统同步
#   - 发射 battle_second 信号 (每 1s) 供慢速检测 (胜负/自动抽牌/法宝轮询)
#   - 支持暂停/恢复
#
# 红线:
#   ❌ 不做领域计算 (仅发射时间信号)
#   ❌ 不持有业务状态
#   ❌ 不访问 actor/deck/系统
#
# 使用:
#   var clock := BattleClock.new()
#   screen.add_child(clock)  # 必须是 Node 才能 _process
#   clock.tick.connect(_on_tick)
#   clock.battle_second.connect(_on_second)
# ============================================================
class_name BattleClock
extends Node


## 每次 tick 的时间间隔 (秒)
const TICK_RATE: float = 0.25

## 每秒 battle_second 信号对应的 tick 数
const TICKS_PER_SECOND: int = 4


## 发射: delta_tick(delta: float) — 每帧原始 delta, 供实时系统驱动
signal delta_tick(delta: float)

## 发射: tick(tick_number: int, delta: float)
signal tick(tick_number: int, delta: float)

## 发射: battle_second(tick_number: int)
signal battle_second(tick_number: int)

## 发射: 时钟被暂停
signal clock_paused()

## 发射: 时钟被恢复
signal clock_resumed()


## 当前 tick 计数 (从 1 开始)
var tick_count: int = 0

## 累计已过时间 (秒)
var elapsed: float = 0.0

## 是否暂停
var paused: bool = false:
	set(v):
		if v == paused:
			return
		paused = v
		if v:
			clock_paused.emit()
		else:
			clock_resumed.emit()


## 驱动时钟前进 delta 秒。正式战斗由 _process 调用，模拟器可直接调用。
## 这是唯一的业务入口 — _process 仅做引擎回调转发。
func advance(delta: float) -> void:
	if paused:
		return
	delta_tick.emit(delta)
	elapsed += delta
	while elapsed >= TICK_RATE:
		elapsed -= TICK_RATE
		tick_count += 1
		tick.emit(tick_count, TICK_RATE)
		if tick_count % TICKS_PER_SECOND == 0:
			battle_second.emit(tick_count)


func _process(delta: float) -> void:
	advance(delta)


## 重置时钟到初始状态
func reset() -> void:
	tick_count = 0
	elapsed = 0.0
	paused = false
