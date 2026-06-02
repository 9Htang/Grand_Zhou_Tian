class_name EffectResolver
extends RefCounted


static func apply(gm: Node, effect: String) -> void:
	if effect.is_empty():
		return
	var parts: PackedStringArray = effect.split(":")
	if parts.is_empty():
		return
	var cmd: String = parts[0]
	var args: PackedStringArray = []
	for i in range(1, parts.size()):
		args.append(parts[i])
	_execute(gm, cmd, args)


static func apply_all(gm: Node, effects: Array[String]) -> void:
	for e in effects:
		apply(gm, e)


static func _execute(gm: Node, cmd: String, args: PackedStringArray) -> void:
	match cmd:
		"heal":
			gm.heal(_arg_int(args, 0, 0))
		"damage":
			gm.take_damage(_arg_int(args, 0, 0))
		"max_hp_up":
			gm.increase_max_hp(_arg_int(args, 0, 0))
		"dantian_up":
			gm.dantian_capacity += _arg_int(args, 0, 0)
		"gather_up":
			if gm.has_method("add_qi_gather_bonus"):
				gm.add_qi_gather_bonus("effect", _arg_int(args, 0, 0))
		"qi_restore":
			gm.add_qi(_arg_int(args, 0, 0))
		"talent_up":
			gm.talent += _arg_int(args, 0, 0)
		"unlock_node":
			gm.unlock_meridian_node(args[0] if args.size() > 0 else "random")
		"repair_path":
			if args.size() > 0 and args[0] == "random":
				gm.repair_random_pathway()
			elif args.size() > 0:
				gm.repair_pathway(args[0])
		"repair_all":
			gm.repair_all_pathways()
		"gain_card":
			if args.size() > 0:
				gm.add_card_to_deck(args[0])
		"remove_card":
			gm.remove_card(args[0] if args.size() > 0 else "random")
		"upgrade_card":
			gm.upgrade_card(args[0] if args.size() > 0 else "random")
		"transform_card":
			gm.transform_random_card()
		"duplicate_card":
			gm.duplicate_random_card()
		"gain_elixir":
			if args.size() > 0:
				gm.add_card_to_deck(args[0])
		"gain_artifact":
			if args.size() > 0 and args[0] == "random":
				gm.gain_random_artifact()
			elif args.size() > 0:
				gm.gain_artifact(args[0])
		"gold":
			gm.gold += _arg_int(args, 0, 0)
		"energy_up":
			gm.add_qi(_arg_int(args, 0, 0))
		"energy_down":
			gm.spend_qi(_arg_int(args, 0, 0))
		"self_damage":
			gm.take_damage(_arg_int(args, 0, 0))
		"buff":
			# "buff:attack_up:3" → 添加 ResolvedBuff 到 active_buffs
			if args.size() >= 2:
				_add_buff_to_gm(gm, args[0], int(args[1]))
		"debuff":
			_pending(gm, "debuff", args[0] if args.size() > 0 else "", _arg_int(args, 1, 1))
		"attack_up":
			_add_buff_to_gm(gm, "attack_up", _arg_int(args, 0, 1))
		"defense_up":
			_add_buff_to_gm(gm, "defense_up", _arg_int(args, 0, 1))
		"burn":
			_pending(gm, "burn", "", _arg_int(args, 0, 1))
		"draw_card":
			_pending(gm, "draw_card", "", _arg_int(args, 0, 1))
		"block":
			gm.current_block += _arg_int(args, 0, 1)
		"cleanse_all":
			gm.active_buffs = []
			if gm.has_signal("buffs_updated"):
				gm.buffs_updated.emit(gm.active_buffs)
		_:
			printerr("EffectResolver: unknown command '", cmd, "'")


static func _arg_int(args: PackedStringArray, index: int, default: int) -> int:
	if index < args.size():
		return int(args[index])
	return default


## 添加 ResolvedBuff 到 GameManager.active_buffs
static func _add_buff_to_gm(gm: Node, name: String, value: int) -> void:
	var rb := TechniqueResolver.ResolvedBuff.new()
	rb.name = name
	rb.value = value
	rb.source = "effect"
	gm.active_buffs.append(rb)
	if gm.has_signal("buffs_updated"):
		gm.buffs_updated.emit(gm.active_buffs)


## 暂存需要 BattleScreen 上下文消费的效果（如 burn 需要敌人面板、draw_card 需要 deck）
static func _pending(gm: Node, type_str: String, subtype: String, value: int) -> void:
	if not gm.has_meta("pending_effects"):
		gm.set_meta("pending_effects", [])
	var pe: Array = gm.get_meta("pending_effects")
	pe.append({"type": type_str, "subtype": subtype, "value": value})
