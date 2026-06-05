# ============================================================
# 大周天 — DeterministicRNG (确定性随机数生成器)
# ============================================================
# 工具层: tools/simulation/determinism/ — 不属于四层运行时架构
#
# 基于 SplitMix64 的完全确定性随机数流。
# 不依赖 Godot RandomNumberGenerator（Godot 4.6.3 存在跨实例非确定性 bug）。
#
# 核心能力:
#   - 种子确定性: 同 seed → 同序列
#   - 调用计数: call_count 单调递增，用于 divergence detection
#   - 状态保存: save_state() 用于轨迹记录
#   - RNG 日志: 可选 enable_logging() 记录每次调用上下文
# ============================================================
class_name DeterministicRNG
extends RefCounted


# ============================================================
# Constants（SplitMix32 — 全部在 int64 范围内）
# ============================================================

const SPLITMIX32_MAGIC: int = 0x9e3779b9
const MURMUR3_32_C1: int = 0x85ebca6b
const MURMUR3_32_C2: int = 0xc2b2ae35
const U32_MASK: int = 0xffffffff


# ============================================================
# State
# ============================================================

## 内部状态（32-bit SplitMix）
var _state: int = 0

## 初始种子
var _seed: int = 0

## 全局调用计数 — 每次 randi/randf/shuffle 递增
## 用于检测两次运行是否产生了完全一致的 RNG 调用序列
var call_count: int = 0

## 当前 tick（由外部设置，供日志使用）
var current_tick: int = 0

## 当前调用上下文（由外部设置，供日志使用）
var current_context: String = ""

## RNG 日志（可选启用）
var _log: RNGEventLog = null


# ============================================================
# Init
# ============================================================

func _init(seed_val: int) -> void:
	_seed = seed_val
	# 避免 seed=0 导致全零序列
	_state = (seed_val & U32_MASK) if seed_val != 0 else 1


# ============================================================
# Internal — SplitMix32 next
# ============================================================

## SplitMix32 核心: 返回下一个 32-bit 伪随机数
func _next() -> int:
	_state = (_state + SPLITMIX32_MAGIC) & U32_MASK
	var z: int = _state
	z = ((z ^ (z >> 16)) * MURMUR3_32_C1) & U32_MASK
	z = ((z ^ (z >> 13)) * MURMUR3_32_C2) & U32_MASK
	return z ^ (z >> 16)


# ============================================================
# Public — Random Generation
# ============================================================

func randi() -> int:
	call_count += 1
	var result: int = _next() & 0x7fffffff  # 取低 31 位为正数
	if _log:
		_log.record(call_count, current_tick, current_context, "randi", {}, result)
	return result


func randf() -> float:
	call_count += 1
	# 用 53 位精度生成 [0, 1) 浮点数
	var result: float = float(_next() & 0x1fffffffffffff) / float(0x1fffffffffffff + 1)
	if _log:
		_log.record(call_count, current_tick, current_context, "randf", {}, result)
	return result


func randi_range(min_val: int, max_val: int) -> int:
	call_count += 1
	var span: int = max_val - min_val + 1
	var result: int = min_val + int(abs(_next()) % span)
	if _log:
		_log.record(call_count, current_tick, current_context, "randi_range", {"min": min_val, "max": max_val}, result)
	return result


# ============================================================
# Public — Shuffle / Pick
# ============================================================

## Fisher-Yates 洗牌 — 使用自身的确定性 RNG，不依赖 Godot Array.shuffle()
func shuffle(arr: Array) -> void:
	call_count += 1
	var n: int = arr.size()
	while n > 1:
		n -= 1
		var k: int = int(abs(_next()) % (n + 1))
		var tmp = arr[n]
		arr[n] = arr[k]
		arr[k] = tmp


## 从数组中随机抽取一个元素
func pick_random(arr: Array):
	if arr.is_empty():
		return null
	return arr[int(abs(_next()) % arr.size())]


## 加权随机抽取
## items: 包含 weight_key 字段的数组
func pick_weighted(items: Array, weight_key: String = "weight") -> Dictionary:
	if items.is_empty():
		return {}
	var total: int = 0
	for item in items:
		total += int(item.get(weight_key) if item is Dictionary else item[weight_key])
	if total <= 0:
		return items[0] if items[0] is Dictionary else {}
	var roll: int = int(abs(_next()) % total)
	var acc: int = 0
	for item in items:
		var w: int = int(item.get(weight_key) if item is Dictionary else item[weight_key])
		acc += w
		if roll < acc:
			return item if item is Dictionary else {}
	return items[0] if items[0] is Dictionary else {}


## 从数组中随机抽取 count 个不重复元素
func sample(arr: Array, count: int) -> Array:
	if count <= 0 or arr.is_empty():
		return []
	var pool: Array = arr.duplicate()
	shuffle(pool)
	return pool.slice(0, min(count, pool.size()))


# ============================================================
# Public — State Save / Log
# ============================================================

## 从保存的状态恢复
func restore_state(d: Dictionary) -> void:
	if d.has("state"):
		_state = d.get("state", _state)
	if d.has("call_count"):
		call_count = d.get("call_count", call_count)


func save_state() -> Dictionary:
	return {
		"seed": _seed,
		"state": _state,
		"call_count": call_count,
	}


## 启用 RNG 调用日志（内存开销大，仅开发/CI 模式使用）
func enable_logging(log: RNGEventLog) -> void:
	_log = log


## 禁用 RNG 调用日志
func disable_logging() -> void:
	_log = null
