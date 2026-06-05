# ============================================================
# 大周天 — TargetSpec
# 统一目标规格 — 替代 Dictionary selector
# CardData/EffectNode/EffectInstruction → TargetResolver → EffectVM
# ============================================================
class_name TargetSpec
extends RefCounted


## 目标类型枚举
enum Type {
	NONE = 0,
	SELF = 1,
	SINGLE_ENEMY = 2,
	ALL_ENEMIES = 3,
	RANDOM_ENEMY = 4,
}


## 目标类型
var type: int = Type.NONE

## 需求数量（SINGLE_ENEMY 时 >1 = 选多个）
var count: int = 1

## 是否允许选择已死亡目标
var allow_dead: bool = false


# ============================================================
# 查询
# ============================================================


## 无需目标（self-buff / no-target）
func is_empty() -> bool:
	return type == Type.NONE


## 是否需要 UI 选择（SINGLE_ENEMY 需玩家交互）
func needs_selection() -> bool:
	return type == Type.SINGLE_ENEMY


# ============================================================
# 工厂
# ============================================================


## 从 CardData.target_type (int) 构建 TargetSpec
static func from_card_type(target_type: int, p_count: int = 1) -> TargetSpec:
	var spec := TargetSpec.new()
	match target_type:
		1:  # SINGLE_ENEMY
			spec.type = Type.SINGLE_ENEMY
			spec.count = p_count
		2:  # ALL_ENEMIES
			spec.type = Type.ALL_ENEMIES
		3:  # SELF
			spec.type = Type.SELF
		4:  # RANDOM_ENEMY
			spec.type = Type.RANDOM_ENEMY
		_:  # NONE (0)
			spec.type = Type.NONE
	return spec


## 深拷贝
func duplicate_spec() -> TargetSpec:
	var spec := TargetSpec.new()
	spec.type = type
	spec.count = count
	spec.allow_dead = allow_dead
	return spec
