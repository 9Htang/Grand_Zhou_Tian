# ============================================================
# 大周天 — BattleSnapshot (战斗快照)
# ============================================================
# 纯数据传输对象 — UI 消费此结构，禁止直接读 Actor 内部字段
# 由 BattleController.build_snapshot() 构建，每帧重建
# ============================================================
class_name BattleSnapshot
extends RefCounted


# === Player Vitals ===
var hp: int = 0
var max_hp: int = 0
var dantian_qi: int = 0
var dantian_capacity: int = 0
var qi_gather_rate: int = 0
var realm: int = 1

# === Deck Info ===
var draw_pile_count: int = 0
var discard_count: int = 0

# === Techniques ===
## 活跃功法列表（引用，非拷贝 — TechniqueData 不可变）
var techniques: Array[TechniqueData] = []
## 天资上限
var talent: int = 1
## 功法→路径绑定: {tech_id: {from: int, to: int}}
var technique_pathways: Dictionary = {}

# === Meridian ===
var base_meridian: MeridianMapData = null
var erosion_targets: Array[int] = []
var max_erosion_targets: int = 0
## 回路高亮键: ["from->to", ...]
var circuit_pathway_keys: Array[String] = []
var is_flow_dry: bool = true
## 功法颜色: {tech_id: Color}
var technique_colors: Dictionary = {}
## 灵气碰撞数据（可空）
var collision_data = null

# === Buffs ===
var buffs: Array = []

# === Enemies ===
## 敌人快照: [{actor: EnemyActor, hp: int, current_block: int, statuses: Dictionary}]
var enemy_snapshots: Array[Dictionary] = []

# === State Flags ===
## 是否处于卡牌选择模式（锻淬选牌）
var is_selecting_cards: bool = false
## 是否阻止玩家输入（FSM 切换 / 动画中）
var is_input_blocked: bool = false


# === Display Constants ===
## 减益名称列表（用于区分 buff/debuff 图标颜色）
const DEBUFF_NAMES: Array[String] = ["burn", "vulnerable", "weak", "self_damage", "energy_down", "poison"]
