# ============================================================
# 大周天 — CardPacingSystem (抽牌节奏调度引擎 — L2)
# ============================================================
# 四层定位: L2 Domain Layer — 速度→抽牌间隔计算
#
# 职责:
#   - 根据玩家速度计算自动抽牌间隔
#   - 提供软上限 (log(1+x) 衰减) 避免极端速度失衡
#   - 上下限保护: min_interval 防爆发, max_interval 防卡手
#
# 架构原则:
#   - 纯函数 — 无状态、无副作用
#   - AutoDrawSystem 不知道 speed 语义 — 只通过本系统获取 interval
#   - 不操作任何其他系统/服务
#
# 优先级规则:
#   1. Config override (draw_interval > 0) — 最高
#   2. speed 计算 (compute_interval) — 生产环境唯一来源
#   3. AutoDrawSystem 默认值 (3.0) — 兜底
# ============================================================
class_name CardPacingSystem
extends RefCounted


## 基础抽牌间隔 (speed=1.0 时的间隔)
var base_draw_interval: float = 2.0

## 最小抽牌间隔 (防 burst 底线)
var min_interval: float = 0.6

## 最大抽牌间隔 (防 stall 天花板)
var max_interval: float = 3.0

## 软上限阈值 (超过此值后 log(1+x) 衰减)
var soft_cap_speed: float = 20.0


## 统一入口：override > 0 直接使用，否则从 speed 计算
func get_interval(speed: float, override: float = 0.0) -> float:
	if override > 0.0:
		return override
	return compute_interval(speed)


## 从 speed 计算 interval，含 log(1+x) 软上限
func compute_interval(speed: float) -> float:
	if speed <= 0.0:
		return max_interval
	var effective: float = soft_cap(speed)
	return clamp(base_draw_interval / effective, min_interval, max_interval)


## log(1+x) 软上限曲线，比 sqrt 更稳
## speed <= soft_cap_speed -> 线性；超出后 log 衰减
func soft_cap(speed: float) -> float:
	if speed <= soft_cap_speed:
		return speed
	return soft_cap_speed + log(1.0 + (speed - soft_cap_speed))