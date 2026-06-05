# ============================================================
# 大周天 — BattleSnapshotPresenter (快照分发编排 — L0)
# 职责: 将 BattleSnapshot 分发到所有子 Presenter + 玩家状态栏
# 红线: 不调 controller, 不 import services/, 只做纯数据分发
# ============================================================
class_name BattleSnapshotPresenter
extends RefCounted

# === 子 Presenter ===
var buff_presenter: BuffPresenter
var technique_presenter: TechniquePresenter
var enemy_presenter: EnemyPresenter
var meridian_presenter: MeridianPresenter
var hand_presenter: HandPresenter

# === 玩家状态栏 ===
var player_hp_bar: Control
var player_qi_bar: Control
var realm_label: Label
var deck_info: Label


## 注入全部子 Presenter 和 UI 节点引用
func setup(
	p_buff: BuffPresenter,
	p_technique: TechniquePresenter,
	p_enemy: EnemyPresenter,
	p_meridian: MeridianPresenter,
	p_hand: HandPresenter,
	p_hp_bar: Control,
	p_qi_bar: Control,
	p_realm: Label,
	p_deck: Label,
) -> void:
	buff_presenter = p_buff
	technique_presenter = p_technique
	enemy_presenter = p_enemy
	meridian_presenter = p_meridian
	hand_presenter = p_hand
	player_hp_bar = p_hp_bar
	player_qi_bar = p_qi_bar
	realm_label = p_realm
	deck_info = p_deck


## 应用战斗快照 → 所有 UI 刷新的唯一入口
func apply_snapshot(snap: BattleSnapshot) -> void:
	_apply_player_vitals(snap)
	_apply_deck_info(snap)
	buff_presenter.apply(snap)
	technique_presenter.apply(snap)
	meridian_presenter.apply(snap)
	enemy_presenter.apply(snap)


## 刷新全部（手牌 + 其余）→ 常用组合
func refresh_all(snap: BattleSnapshot, deck_manager: DeckManager, playability_map: Dictionary) -> void:
	hand_presenter.refresh_hand(snap, deck_manager, playability_map)
	apply_snapshot(snap)


# === Player Vitals ===

func _apply_player_vitals(snap: BattleSnapshot) -> void:
	if player_hp_bar:
		player_hp_bar.set_values(snap.hp, snap.max_hp)
	if player_qi_bar:
		player_qi_bar.set_values(snap.dantian_qi, snap.dantian_capacity, snap.qi_gather_rate)
	realm_label.text = "境界: " + str(snap.realm)


# === Deck Info ===

func _apply_deck_info(snap: BattleSnapshot) -> void:
	deck_info.text = "牌库:" + str(snap.draw_pile_count) + " 弃牌:" + str(snap.discard_count)
