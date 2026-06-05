# ============================================================
# 大周天 — DamageCalculation
# 通用伤害计算工具
# ============================================================
class_name DamageCalculation
extends RefCounted


## 敌方伤害计算 — 境界压制修正
## base_damage: 原始伤害值
## player_realm: 玩家境界
## enemy_realm: 敌人境界
## 返回: 修正后伤害（敌境界 > 玩境界时120%）
static func enemy_damage(base_damage: int, player_realm: int, enemy_realm: int) -> int:
	var dmg: int = base_damage
	if enemy_realm > player_realm:
		dmg = int(float(dmg) * 1.2)
	return max(0, dmg)
