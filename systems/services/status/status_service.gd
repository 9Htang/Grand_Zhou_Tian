# ============================================================
# 大周天 — StatusService (状态域)
# 职责: buff/debuff/燃烧/易伤/虚弱/眩晕/净化/pending
# ============================================================
class_name StatusService
extends RefCounted


var _ctx: EffectContext = null


## 施加战斗状态 (burn/vulnerable/weak/stun) — 写入 BattleResult
func apply_battle_status(status_type: String, value: int, turns: int) -> void:
	if _ctx.result:
		_ctx.result.status_applied.append({"type": status_type, "value": value, "turns": turns})
	_ctx.trace("APPLY_STATUS %s x%d (%d turns)" % [status_type, value, turns])


## 施加增益 buff — 写入 BattleResult
func apply_buff(buff_name: String, value: int, turns: int) -> void:
	if _ctx.result and not buff_name.is_empty():
		_ctx.result.status_applied.append({"type": "buff", "name": buff_name, "value": value, "turns": turns})
	_ctx.trace("APPLY_STATUS buff:%s +%d" % [buff_name, value])


## 施加减益 — 写入 BattleResult
func apply_debuff(debuff_name: String, value: int, turns: int) -> void:
	if _ctx.result and not debuff_name.is_empty():
		_ctx.result.status_applied.append({"type": "debuff", "name": debuff_name, "value": value, "turns": turns})
	_ctx.trace("APPLY_STATUS debuff:%s +%d" % [debuff_name, value])


## 净化 — 写入 BattleResult
func apply_cleanse(count: int) -> void:
	if _ctx.result:
		_ctx.result.status_applied.append({"type": "cleanse", "count": count})
	_ctx.trace("APPLY_STATUS cleanse x%d" % count)


## 地图模式: 添加永久 buff 到 active_buffs
func add_permanent_buff(buff_name: String, value: int, turns: int = 0) -> void:
	var target: Node = _ctx.actor
	if target == null:
		return
	var rb := TechniqueResolver.ResolvedBuff.new()
	rb.name = buff_name
	rb.value = value
	rb.source = "effect"
	rb.turns_remaining = turns
	target.active_buffs.append(rb)
	if target.has_signal("buffs_updated"):
		target.buffs_updated.emit(target.active_buffs)


## 地图模式: 暂存 pending 效果
func add_pending(effect_type: String, subtype: String, value: int) -> void:
	var target: Node = _ctx.actor
	if target == null:
		return
	if not target.has_meta("pending_effects"):
		target.set_meta("pending_effects", [])
	var pe: Array = target.get_meta("pending_effects")
	pe.append({"type": effect_type, "subtype": subtype, "value": value})


## 清除所有 buff
func cleanse_all() -> void:
	var target: Node = _ctx.actor
	if target == null:
		return
	target.active_buffs = []
	if target.has_signal("buffs_updated"):
		target.buffs_updated.emit(target.active_buffs)
