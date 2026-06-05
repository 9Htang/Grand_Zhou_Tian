# ============================================================
# 大周天 — WinLossMonitor (连续胜负检测 — L2)
# ============================================================
# 四层定位: L2 Domain Layer — 代替 BattleTurnService 的回合末胜负检测
#
# 职责:
#   - 每 battle_second 检测玩家和敌人 HP
#   - 返回战斗结果
#
# 红线:
#   ❌ 不触发状态转换 (由 L1 BattleController 处理)
#   ❌ 不操作 UI
# ============================================================
class_name WinLossMonitor
extends RefCounted


## 战斗结果枚举
enum BattleOutcome {
	CONTINUE = 0,
	WON = 1,
	LOST = 2,
}


## 发射: 战斗结束
signal battle_ended(outcome: int)


## 玩家引用
var player: PlayerActor = null

## 敌人列表引用
var enemies: Array[EnemyActor] = []


## 检测战斗是否结束
## 返回 BattleOutcome
func check() -> int:
	if player == null:
		return BattleOutcome.CONTINUE

	# 玩家死亡
	if player.hp <= 0:
		battle_ended.emit(BattleOutcome.LOST)
		return BattleOutcome.LOST

	# 所有敌人死亡
	if enemies.is_empty():
		return BattleOutcome.CONTINUE

	var all_dead: bool = true
	for enemy in enemies:
		if enemy and enemy.hp > 0:
			all_dead = false
			break

	if all_dead:
		battle_ended.emit(BattleOutcome.WON)
		return BattleOutcome.WON

	return BattleOutcome.CONTINUE


## 设置敌人列表
func set_enemies(p_enemies: Array[EnemyActor]) -> void:
	enemies = p_enemies
