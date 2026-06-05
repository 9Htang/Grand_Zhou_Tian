# ============================================================
# 大周天 — CardRepository
# 卡牌实例唯一仓储 — 集中管理所有 CardInstance
#
# 职责:
#   1. 按 uid 管理 CardInstance 的增删查
#   2. 保证同牌型多个副本各有独立 uid
#   3. 提供 base_id → [uid, ...] 反向索引
#   4. 持久化: 与 PlayerActor.card_instance_registry 同步
#
# 不负责:
#   ❌ 卡牌效果结算 (Domain Service)
#   ❌ UI 展示 (BattleScreen)
#   ❌ 卡牌模板加载 (CardDatabase)
# ============================================================
class_name CardRepository
extends RefCounted


## 主存储: uid → CardInstance
var _by_uid: Dictionary = {}

## 反向索引: base_id → Array[uid]
var _uids_by_base: Dictionary = {}


# ============================================================
# CRUD
# ============================================================


## 按 uid 获取实例，不存在返回 null
func get_instance(uid: String) -> CardInstance:
	return _by_uid.get(uid)


## 按 base_id 获取所有实例 uid（返回 Array 避免与 Array[String] 类型冲突）
func find_uids(base_id: String) -> Array:
	return _uids_by_base.get(base_id, [])


## 按 base_id 获取所有实例
func find_all(base_id: String) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for uid: String in find_uids(base_id):
		var inst: CardInstance = _by_uid.get(uid)
		if inst:
			result.append(inst)
	return result


## 按 base_id 获取最新一个实例（常见场景：每牌型一个实例）
func find_one(base_id: String) -> CardInstance:
	var uids: Array = find_uids(base_id)
	if uids.is_empty():
		return null
	return _by_uid.get(uids[0])


## 存入实例（自动维护反向索引）
func add(inst: CardInstance) -> void:
	if inst.instance_id.is_empty():
		inst.ensure_instance_id()
	var uid: String = inst.instance_id
	_by_uid[uid] = inst
	if not _uids_by_base.has(inst.base_id):
		_uids_by_base[inst.base_id] = []
	var arr: Array = _uids_by_base[inst.base_id]
	if uid not in arr:
		arr.append(uid)


## 移除实例
func remove(uid: String) -> bool:
	var inst: CardInstance = _by_uid.get(uid)
	if inst == null:
		return false
	_by_uid.erase(uid)
	var arr: Array = _uids_by_base.get(inst.base_id, [])
	var idx: int = arr.find(uid)
	if idx >= 0:
		arr.remove_at(idx)
	if arr.is_empty():
		_uids_by_base.erase(inst.base_id)
	return true


## 实例数量
func size() -> int:
	return _by_uid.size()


## 清空全部
func clear() -> void:
	_by_uid.clear()
	_uids_by_base.clear()


# ============================================================
# CardData Clone Tracking
# ============================================================


## 为 CardData 克隆体绑定实例（通过 meta 打标）
## 返回关联的 CardInstance
func bind_clone(clone: CardData) -> CardInstance:
	# 已绑定 → 直接返回
	if clone.has_meta("instance_uid"):
		var existing_uid: String = clone.get_meta("instance_uid")
		var existing: CardInstance = _by_uid.get(existing_uid)
		if existing:
			return existing

	# 创建新实例
	var inst: CardInstance = CardFactory.create_instance(clone.id)
	clone.set_meta("instance_uid", inst.instance_id)
	add(inst)
	return inst


## 通过 CardData 克隆体查找关联实例
func find_by_clone(clone: CardData) -> CardInstance:
	if not clone.has_meta("instance_uid"):
		return null
	var uid: String = clone.get_meta("instance_uid")
	return _by_uid.get(uid)


# ============================================================
# Persistent Sync
# ============================================================


## 从持久化字典加载（PlayerActor.card_instance_registry）
func load_from_dict(dict: Dictionary) -> void:
	for key: String in dict:
		var inst: CardInstance = dict[key]
		if inst:
			add(inst)


## 导出为持久化字典
func save_to_dict() -> Dictionary:
	var result: Dictionary = {}
	for uid: String in _by_uid:
		result[uid] = _by_uid[uid]
	return result
