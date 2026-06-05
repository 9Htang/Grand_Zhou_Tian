# ============================================================
# 大周天 — BattleLayoutBuilder (UI 布局构建 — L0)
# 职责: 一次性构建战斗界面全部 UI 节点，设置 screen 的节点引用
# 红线: 纯 UI 创建，不调 controller，不 import services/
# ============================================================
class_name BattleLayoutBuilder
extends RefCounted


## 构建完整 UI 布局，设置 screen 上所有节点变量
func build(screen: CanvasLayer) -> void:
	var top_h: int = UIHelpers.pct_h(UIHelpers.TOP_BAR_PCT, screen)
	var enemy_h: int = UIHelpers.pct_h(UIHelpers.ENEMY_AREA_PCT, screen)
	var meridian_h: int = UIHelpers.pct_h(UIHelpers.MERIDIAN_AREA_PCT, screen)
	var tech_h: int = UIHelpers.pct_h(UIHelpers.TECH_AREA_PCT, screen)
	var buffs_h: int = UIHelpers.pct_h(UIHelpers.BUFFS_PCT, screen)
	var player_h: int = UIHelpers.pct_h(UIHelpers.PLAYER_AREA_PCT, screen)
	var hand_h: int = UIHelpers.pct_h(UIHelpers.HAND_AREA_PCT, screen)
	var btn_h: int = max(28, int(float(hand_h) * 0.15))
	var hp_bar_w: int = UIHelpers.pct_w(0.11, screen)
	var hp_bar_h: int = max(16, int(float(player_h) * 0.7))
	var meridian_panel_w: int = UIHelpers.pct_w(0.55, screen)
	var meridian_panel_h: int = max(140, meridian_h - 20)
	var sandbox_btn_sz: Vector2 = Vector2(float(max(24, int(float(top_h) * 0.8))), float(top_h))

	# Root control fills the screen
	var root := Control.new()
	root.name = "Layout"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background ambiance
	var ambiance_sc: GDScript = load("res://ui_components/background_ambiance.gd") as GDScript
	var ambiance := Control.new()
	ambiance.set_script(ambiance_sc)
	ambiance.name = "BackgroundAmbiance"
	root.add_child(ambiance)

	# Main VBox layout
	var vbox := VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(vbox)
	screen.add_child(root)

	# === Top Bar ===
	var top := HBoxContainer.new()
	top.name = "TopBar"
	top.custom_minimum_size.y = top_h

	screen.turn_label = Label.new()
	screen.turn_label.name = "TurnLabel"
	screen.turn_label.text = "战斗开始"
	screen.turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.turn_label.add_theme_color_override("font_color", GameColors.TEXT_TITLE)
	screen.turn_label.add_theme_font_size_override("font_size", UIHelpers.scale_font(16, screen))
	top.add_child(screen.turn_label)

	var wrench_btn := Button.new()
	wrench_btn.name = "SandboxBtn"
	wrench_btn.text = "🔧"
	wrench_btn.flat = true
	wrench_btn.custom_minimum_size = sandbox_btn_sz
	wrench_btn.pressed.connect(screen._toggle_sandbox)
	wrench_btn.visible = screen._sandbox_enabled
	top.add_child(wrench_btn)

	vbox.add_child(top)

	# === Enemy Area ===
	var enemy_area := MarginContainer.new()
	enemy_area.name = "EnemyArea"
	enemy_area.custom_minimum_size.y = enemy_h
	screen.enemy_container = HBoxContainer.new()
	screen.enemy_container.name = "EnemyContainer"
	screen.enemy_container.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_area.add_child(screen.enemy_container)
	vbox.add_child(enemy_area)

	# === Meridian Area ===
	var meridian_area := MarginContainer.new()
	meridian_area.name = "MeridianArea"
	meridian_area.custom_minimum_size.y = meridian_h
	screen.meridian_panel = Panel.new()
	screen.meridian_panel.name = "MeridianPanel"
	screen.meridian_panel.custom_minimum_size = Vector2(float(meridian_panel_w), float(meridian_panel_h))
	var mv_sc: GDScript = load("res://ui_components/meridian_view.gd") as GDScript
	screen.meridian_panel.set_script(mv_sc)
	meridian_area.add_child(screen.meridian_panel)
	vbox.add_child(meridian_area)

	# === Technique Area ===
	var tech_area := MarginContainer.new()
	tech_area.name = "TechniqueArea"
	tech_area.custom_minimum_size.y = tech_h
	tech_area.add_theme_constant_override("margin_left", UIHelpers.pad_h(screen))
	tech_area.add_theme_constant_override("margin_right", UIHelpers.pad_h(screen))
	var tech_label := Label.new()
	tech_label.text = "⚡ 活跃功法"
	tech_label.add_theme_color_override("font_color", GameColors.ACCENT_GOLD_DIM)
	tech_label.add_theme_font_size_override("font_size", UIHelpers.scale_font(12, screen))
	tech_area.add_child(tech_label)
	screen.technique_area = HBoxContainer.new()
	screen.technique_area.name = "TechniqueContainer"
	screen.technique_area.add_theme_constant_override("separation", UIHelpers.gap_small(screen))
	tech_area.add_child(screen.technique_area)
	vbox.add_child(tech_area)

	# === Buffs Bar ===
	var buffs := MarginContainer.new()
	buffs.name = "BuffsBar"
	buffs.custom_minimum_size.y = buffs_h
	buffs.add_theme_constant_override("margin_left", UIHelpers.pad_h(screen))
	buffs.add_theme_constant_override("margin_right", UIHelpers.pad_h(screen))
	screen.buffs_bar = HBoxContainer.new()
	screen.buffs_bar.name = "BuffsContainer"
	screen.buffs_bar.add_theme_constant_override("separation", UIHelpers.gap_small(screen))
	buffs.add_child(screen.buffs_bar)
	vbox.add_child(buffs)

	# === Player Area ===
	var player_area := HBoxContainer.new()
	player_area.name = "PlayerArea"
	player_area.custom_minimum_size.y = player_h
	player_area.add_theme_constant_override("separation", UIHelpers.gap_small(screen))
	player_area.add_theme_constant_override("margin_left", UIHelpers.pad_h(screen))
	player_area.add_theme_constant_override("margin_right", UIHelpers.pad_h(screen))
	screen.player_hp_bar = _create_health_bar(hp_bar_w, hp_bar_h, screen.player_actor.max_hp, screen.player_actor.hp, screen)
	screen.player_qi_bar = _create_qi_bar(hp_bar_w, hp_bar_h, screen)
	screen.realm_label = Label.new()
	screen.realm_label.name = "RealmLabel"
	screen.realm_label.add_theme_color_override("font_color", GameColors.TEXT_TITLE)
	screen.realm_label.add_theme_font_size_override("font_size", UIHelpers.scale_font(14, screen))
	screen.deck_info = Label.new()
	screen.deck_info.name = "DeckInfo"
	screen.deck_info.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	screen.deck_info.add_theme_font_size_override("font_size", UIHelpers.scale_font(12, screen))
	player_area.add_child(screen.player_hp_bar)
	player_area.add_child(screen.player_qi_bar)
	player_area.add_child(screen.realm_label)
	player_area.add_child(screen.deck_info)
	vbox.add_child(player_area)

	# === Hand Area ===
	var hand_area_container := MarginContainer.new()
	hand_area_container.name = "HandArea"
	hand_area_container.custom_minimum_size.y = hand_h
	hand_area_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_area_container.add_theme_constant_override("margin_left", UIHelpers.pad_h(screen))
	hand_area_container.add_theme_constant_override("margin_right", UIHelpers.pad_h(screen))
	var hand_vbox := VBoxContainer.new()
	screen.hand_area = HBoxContainer.new()
	screen.hand_area.name = "HandContainer"
	screen.hand_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.hand_area.add_theme_constant_override("separation", UIHelpers.gap_small(screen))
	hand_vbox.add_child(screen.hand_area)
	screen.end_turn_btn = Button.new()
	screen.end_turn_btn.name = "PauseButton"
	screen.end_turn_btn.text = "⏸ 暂停"
	screen.end_turn_btn.custom_minimum_size.y = btn_h
	screen.end_turn_btn.flat = true
	var et_sb := StyleBoxFlat.new()
	et_sb.bg_color = GameColors.BG_PANEL
	et_sb.border_width_left = 1; et_sb.border_width_right = 1
	et_sb.border_width_top = 1; et_sb.border_width_bottom = 1
	et_sb.border_color = GameColors.BORDER_GOLD
	et_sb.corner_radius_top_left = 6; et_sb.corner_radius_top_right = 6
	et_sb.corner_radius_bottom_left = 6; et_sb.corner_radius_bottom_right = 6
	screen.end_turn_btn.add_theme_stylebox_override("normal", et_sb)
	screen.end_turn_btn.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	screen.end_turn_btn.add_theme_font_size_override("font_size", UIHelpers.scale_font(15, screen))
	hand_vbox.add_child(screen.end_turn_btn)
	hand_area_container.add_child(hand_vbox)
	vbox.add_child(hand_area_container)

	# === Play Zone (卡牌打出区域 — 仅在拖拽时可见) ===
	screen.play_zone = Panel.new()
	screen.play_zone.name = "PlayZone"
	screen.play_zone.visible = false
	screen.play_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_play_zone_rect(screen)
	var pz_style := StyleBoxFlat.new()
	pz_style.bg_color = Color(0.063, 0.071, 0.102, 0.55)
	pz_style.border_width_left = 2; pz_style.border_width_right = 2
	pz_style.border_width_top = 2; pz_style.border_width_bottom = 2
	pz_style.border_color = GameColors.BORDER_GOLD
	pz_style.corner_radius_top_left = 12; pz_style.corner_radius_top_right = 12
	pz_style.corner_radius_bottom_left = 12; pz_style.corner_radius_bottom_right = 12
	pz_style.shadow_size = 20
	pz_style.shadow_color = Color(GameColors.ACCENT_GOLD.r, GameColors.ACCENT_GOLD.g, GameColors.ACCENT_GOLD.b, 0.3)
	screen.play_zone.add_theme_stylebox_override("panel", pz_style)
	var pz_label := Label.new()
	pz_label.name = "PlayZoneLabel"
	pz_label.text = "⚔ 打出卡牌 ⚔"
	pz_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pz_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pz_label.add_theme_color_override("font_color", GameColors.ACCENT_GOLD_DIM)
	pz_label.add_theme_font_size_override("font_size", UIHelpers.scale_font(22, screen))
	pz_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.play_zone.add_child(pz_label)
	root.add_child(screen.play_zone)

	# === FSM ===
	screen.fsm = BattleStateMachine.new()
	screen.fsm.name = "BattleStateMachine"
	screen.add_child(screen.fsm)


# === Helpers ===

func _create_health_bar(w: int, h: int, max_hp: int, current_hp: int, _screen: Node) -> Control:
	var bar := PanelContainer.new()
	bar.name = "HPBar"
	bar.custom_minimum_size = Vector2(float(w), float(h))
	var sc: GDScript = load("res://ui_components/health_bar.gd") as GDScript
	bar.set_script(sc)
	bar.max_value = max_hp
	bar.current_value = current_hp
	return bar


func _create_qi_bar(w: int, h: int, _screen: Node) -> Control:
	var bar := PanelContainer.new()
	bar.name = "QiBar"
	bar.custom_minimum_size = Vector2(float(w), float(h))
	var sc: GDScript = load("res://ui_components/qi_bar.gd") as GDScript
	bar.set_script(sc)
	return bar


## 更新打出区域的位置和尺寸
func _update_play_zone_rect(screen: Node) -> void:
	if screen.play_zone == null:
		return
	var pw: int = UIHelpers.pct_w(UIHelpers.PLAY_ZONE_WIDTH_PCT, screen)
	var ph: int = UIHelpers.pct_h(UIHelpers.PLAY_ZONE_HEIGHT_PCT, screen)
	var vp_w: float = UIHelpers.vp_w(screen)
	var x: float = (vp_w - float(pw)) / 2.0
	var y: float = UIHelpers.pct_h(UIHelpers.PLAY_ZONE_Y_PCT, screen)
	screen.play_zone.position = Vector2(x, y)
	screen.play_zone.size = Vector2(float(pw), float(ph))
