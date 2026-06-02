# ============================================================
# 大周天 — ProviderRegistry
# 统一 Provider 注册表，管理所有目标选择器类型
# ============================================================
class_name ProviderRegistry
extends RefCounted


var _Providers = preload("res://systems/providers.gd")

var _provider_cache: Dictionary = {}


func _init() -> void:
	_provider_cache["path"] = _Providers.PathProvider.new()
	_provider_cache["node"] = _Providers.NodeProvider.new()
	_provider_cache["card"] = _Providers.CardProvider.new()
	_provider_cache["enemy"] = _Providers.EnemyProvider.new()
	_provider_cache["field"] = _Providers.FieldProvider.new()
	_provider_cache["effect_node"] = _Providers.EffectNodeProvider.new()
	_provider_cache["technique"] = _Providers.TechniqueProvider.new()


func get_provider(type: String):
	return _provider_cache.get(type)


func get_targets(selector: Dictionary, battle: BattleContext) -> Array:
	var stype: String = selector.get("type", "")
	var provider = _provider_cache.get(stype)
	if provider == null:
		return []
	return provider.get_targets(selector, battle)
