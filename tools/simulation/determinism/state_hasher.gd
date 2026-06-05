# ============================================================
# 大周天 — StateHasher (确定性状态哈希)
# ============================================================
# 工具层: tools/simulation/determinism/ — 不属于四层运行时架构
#
# 纯函数 — 不读取 RNG 内部状态，不读取系统时间。
# 只对游戏状态（hp, qi, deck 计数）做确定性哈希。
#
# 用途:
#   - Desync detection: 两次运行同 tick hash 不同 → 非确定性 bug
#   - CI 回归: 提交前后同 seed hash 序列必须一致
#   - AI training consistency: 确保训练数据可复现
# ============================================================
class_name StateHasher
extends RefCounted


# ============================================================
# Public Static
# ============================================================

## 对当前战斗状态做确定性哈希
## player: CombatActor (或任何有 hp/max_hp/dantian_qi/dantian_capacity/current_block 的对象)
## enemies: Array[CombatActor]
## deck: 任何有 draw_pile/hand/discard_pile/exhaust_pile 的对象
## rng: DeterministicRNG（只读取 call_count，不读取内部状态）
static func hash_tick(player, enemies: Array, deck, rng: DeterministicRNG) -> int:
	var s: String = ""

	# 玩家状态
	s += "%d|%d|%d|%d|" % [player.hp, player.max_hp, player.dantian_qi, player.dantian_capacity]
	s += "%d|" % player.current_block

	# 敌人状态
	for e in enemies:
		if e == null:
			s += "0|0|0|"
		else:
			s += "%d|%d|%d|" % [e.hp, e.max_hp, e.dantian_qi]

	# 牌库计数（只记录数量，不记录具体卡牌 ID — 具体顺序由 RNG seed 保证）
	if deck:
		s += "%d|%d|%d|%d|" % [deck.draw_pile.size(), deck.hand.size(), deck.discard_pile.size(), deck.exhaust_pile.size()]

	# RNG 调用计数（不读取 RNG state — 只验证调用次数一致）
	s += "%d" % rng.call_count

	return s.hash()


## 对单个 actor 做轻量哈希（用于 event 前后的 hash_before/after）
## 从 CanonicalState 取预计算 hash — O(1)
static func hash_canonical(cs: CanonicalState) -> int:
	return cs.canonical_hash


static func hash_dict(d: Dictionary) -> int:
	return hash_canonical(StateCanonical.from_dict(d))


static func hash_state(state: KernelState) -> int:
	return hash_canonical(StateCanonical.from_state(state))


static func hash_actor(actor) -> int:
	var s: String = "%d|%d|%d|%d|%d" % [actor.hp, actor.max_hp, actor.dantian_qi, actor.dantian_capacity, actor.current_block]
	return s.hash()
