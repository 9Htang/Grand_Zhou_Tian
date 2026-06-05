# ============================================================
# 大周天 — ModifierCompiler (功法→EffectOperator 翻译器 — L2)
# 职责: 将 TechniqueData 属性翻译为 EffectOperator 数组
# 红线: 纯数据变换, 不访问 actor/autoload/UI
# ============================================================
class_name ModifierCompiler
extends RefCounted


## 从活跃功法列表编译 RunModifier 数组
## 每个功法可贡献: 攻击倍率/防御倍率/攻击加成/防御加成
static func compile_run_modifiers(techniques: Array) -> Array:
	var run_mods: Array = []
	for tech: TechniqueData in techniques:
		if tech == null:
			continue
		# 攻击倍率
		if tech.attack_multiplier != 1.0:
			run_mods.append(EffectOperator.select_by_type("damage"))
			run_mods.append(EffectOperator.modify_value("damage", 0, tech.attack_multiplier))
		# 防御倍率
		if tech.defense_multiplier != 1.0:
			run_mods.append(EffectOperator.select_by_type("block"))
			run_mods.append(EffectOperator.modify_value("block", 0, tech.defense_multiplier))
		# 攻击加成
		if not tech.attack_bonus.is_empty():
			_compile_bonus(run_mods, tech.attack_bonus)
		# 防御加成
		if not tech.defense_bonus.is_empty():
			_compile_bonus(run_mods, tech.defense_bonus)
	return run_mods


## 解析 bonus 字符串 "type:value:turns" → EffectOperator
static func _compile_bonus(ops: Array, bonus_str: String) -> void:
	var parts: PackedStringArray = bonus_str.split(":")
	if parts.size() < 2:
		return
	var effect_type: String = parts[0]
	var effect_value: int = int(parts[1])
	var turns: int = int(parts[2]) if parts.size() >= 3 else 2
	ops.append(EffectOperator.add(effect_type, effect_value, {"turns": turns}))
