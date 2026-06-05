# ============================================================
# 大周天 — EventDatabase (事件数据库)
# ============================================================
# L2 Domain Service — 静态工具
# 从 resources/events/ 目录加载 EventData .tres 资源
# 如果目录为空则使用内置默认事件
# ============================================================
class_name EventDatabase
extends RefCounted


static var _events: Array[EventData] = []
static var _loaded: bool = false


## 获取随机事件
static func get_random_event() -> EventData:
	_ensure_loaded()
	if _events.is_empty():
		return _get_fallback_event()
	var idx: int = randi() % _events.size()
	return _events[idx]


## 根据 ID 获取事件，找不到返回 null
static func get_event(event_id: String) -> EventData:
	_ensure_loaded()
	for ev in _events:
		if ev.id == event_id:
			return ev
	return null


## 获取所有已加载事件的数量
static func get_event_count() -> int:
	_ensure_loaded()
	return _events.size()


## 强制重新加载事件数据库
static func reload() -> void:
	_loaded = false
	_events.clear()
	_ensure_loaded()


# ============================================================
# Internal — Loading
# ============================================================

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	# 尝试从 resources/events/ 目录加载 .tres 文件
	var dir: DirAccess = DirAccess.open("res://resources/events")
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while not file_name.is_empty():
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var path: String = "res://resources/events/" + file_name
				var res: Resource = load(path)
				if res is EventData:
					_events.append(res as EventData)
			file_name = dir.get_next()
		dir.list_dir_end()

	# 回退：如果没有 .tres 文件，使用内置默认事件
	if _events.is_empty():
		_load_builtin_defaults()


static func _load_builtin_defaults() -> void:
	for d in _get_default_dicts():
		var ev: EventData = _build_event_from_dict(d)
		if ev:
			_events.append(ev)


# ============================================================
# Internal — Dictionary → EventData 转换（内置回退用）
# ============================================================

static func _build_event_from_dict(d: Dictionary) -> EventData:
	var event := EventData.new()
	event.id = str(d.get("id", ""))
	event.display_name = str(d.get("display_name", ""))
	event.description = str(d.get("description", ""))

	for choice_dict in d.get("choices", []):
		var choice := EventChoiceData.new()
		choice.text = str(choice_dict.get("text", ""))
		choice.requirements = str(choice_dict.get("requirements", ""))
		choice.cost = str(choice_dict.get("cost", ""))
		choice.result_text = str(choice_dict.get("result_text", ""))

		# 固定效果
		var effects_arr: Array = choice_dict.get("effects", [])
		for e in effects_arr:
			choice.effects.append(str(e))

		# 随机结果
		var ro_arr: Array = choice_dict.get("random_outcomes", [])
		for ro_dict in ro_arr:
			var ro := EventRandomOutcome.new()
			ro.weight = int(ro_dict.get("weight", 1))
			ro.text = str(ro_dict.get("text", ""))
			var ro_effects: Array = ro_dict.get("effects", [])
			for e in ro_effects:
				ro.effects.append(str(e))
			choice.random_outcomes.append(ro)

		event.choices.append(choice)

	return event


static func _get_fallback_event() -> EventData:
	var d := {
		"id": "xiu_xi",
		"display_name": "休憩",
		"description": "你找到了一处安静的地方，稍作休息。",
		"choices": [
			{
				"text": "继续前进",
				"effects": [],
				"result_text": "你恢复了精神，继续前行。"
			}
		]
	}
	return _build_event_from_dict(d)


# ============================================================
# Internal — 内置默认事件数据（当 resources/events/ 为空时使用）
# ============================================================

static func _get_default_dicts() -> Array:
	return [
		{
			"id": "gu_dong_qi_yu",
			"display_name": "古洞奇遇",
			"description": "你发现了一个古老的洞府，洞口闪烁着微光，似乎隐藏着某种机缘。洞府深处隐约传来阵阵灵气波动，但空气中弥漫着一丝危险的气息……",
			"choices": [
				{
					"text": "进入探索",
					"cost": "hp:-5",
					"random_outcomes": [
						{"weight": 3, "text": "你在洞府深处发现了一柄古剑，剑身泛着寒光！", "effects": ["gain_artifact:random"]},
						{"weight": 1, "text": "洞府中弥漫着毒瘴，你急忙退出，却已中毒……", "effects": ["damage:10"]},
						{"weight": 2, "text": "你找到了一些散落的灵石，收获颇丰。", "effects": ["gold:15"]}
					]
				},
				{
					"text": "谨慎绕行",
					"effects": ["gold:10"],
					"result_text": "你选择谨慎地绕过洞府，在路边捡到了一些散落的灵石。"
				}
			]
		},
		{
			"id": "xian_ren_yi_fu",
			"display_name": "仙人遗府",
			"description": "一座废弃的仙人洞府矗立在前方，石门半掩。石壁上刻着残缺的功法文字，虽然年代久远，仍能感受到其中的玄奥气息。府内似乎还藏着不少宝物……",
			"choices": [
				{
					"text": "研习功法",
					"requirements": "realm>=2",
					"random_outcomes": [
						{"weight": 1, "text": "你领悟了一式残招，心有所悟！", "effects": ["gain_card:attack_basic"]},
						{"weight": 1, "text": "石壁上的功法让你对修炼有了新的理解。", "effects": ["gain_card:qi_gathering"]},
						{"weight": 1, "text": "你从残谱中习得了一式防御之术。", "effects": ["gain_card:defense_basic"]}
					]
				},
				{
					"text": "搜寻宝物",
					"effects": ["gold:20"],
					"result_text": "你在洞府中翻找，发现了一些前人遗留的金币。"
				},
				{
					"text": "强行破禁",
					"cost": "hp:-15",
					"effects": ["talent_up:1"],
					"result_text": "你强行冲破禁制，虽然受了些伤，但似乎激发了自身的潜力！"
				}
			]
		},
		{
			"id": "ling_yao_yuan",
			"display_name": "灵药园",
			"description": "一片隐秘的灵药园出现在你面前，药香扑鼻。园中各类灵草郁郁葱葱，一看便知是上品。若能善加利用，必大有裨益。",
			"choices": [
				{
					"text": "采集灵药",
					"effects": ["heal:20"],
					"result_text": "你小心翼翼地采集了数株灵药，药力入体，伤势恢复了不少。"
				},
				{
					"text": "炼制丹药",
					"requirements": "talent>=3",
					"effects": ["gain_card:attack_basic", "gain_card:defense_basic"],
					"result_text": "你以灵药为材，就地炼制丹药。丹成之时，药香四溢！"
				}
			]
		}
	]
