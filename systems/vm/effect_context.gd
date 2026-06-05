# ============================================================
# 大周天 — EffectContext
# VM 唯一窗口 — EffectVM 通过此对象访问游戏世界
# EffectVM 永远不直接访问 actor/gm/系统
#
# v3.0 升级: 新增 Stack + RNG + EventStream + VMTrace
#   - stack: 指令间数据传递 (SelectTarget → push, Damage → pop)
#   - rng: 确定性随机数生成器 (注入)
#   - events: 事件流写入 (唯一 emit 入口)
#   - vm_trace: VM 执行轨迹记录
# ============================================================
class_name EffectContext
extends RefCounted


# === 世界引用 ===

## 行动方（CombatActor 或 GameManager）
var actor: Node = null

## 主目标（UI 选择 / 默认目标），地图模式为 null
var primary_target: Node = null

## 当前 effect 作用的所有目标集合（支持 AoE / 多目标）
var targets: Array[Node] = []

## 战斗上下文（地图模式为 null）
var battle_ctx: BattleContext = null

## 结算结果
var result: BattleResult = null


# === 领域服务 ===

var combat: CombatService = null
var qi: QiService = null
var meridian: MeridianService = null
var deck: DeckService = null
var status: StatusService = null
var artifact: ArtifactService = null
var enemy: EnemyService = null
var query: AIQueryService = null
var progression: ProgressionService = null


# === 运行时状态 ===

var meridian_rt: MeridianRuntime = null
var deck_rt: DeckRuntime = null
var artifact_rt: ArtifactRuntime = null


# === v3.0 新增 — VM 内核字段 ===

## VM 执行栈 — 指令间传递数据
var stack: VMStack = null

## 确定性 RNG — 由 Kernel 注入，所有随机操作必须通过此实例
var rng: DeterministicRNG = null

## 事件流 — VM 指令 emit event 的唯一出口
var events: EventStream = null

## VM 执行轨迹记录器（可选，仅开发/CI 模式启用）
var vm_trace: VMTrace = null

## 当前 tick（由外部设置）
var current_tick: int = 0

## 当前指令指针（在 VMProgram 中的索引）
var current_ip: int = 0

## 当前执行的卡牌 ID（由外部设置）
var current_card_id: String = ""


# ============================================================
# 初始化
# ============================================================


## 战斗模式初始化
func init_battle(p_actor: Node, p_primary_target: Node, p_targets: Array, p_battle_ctx: BattleContext, p_result: BattleResult) -> void:
	actor = p_actor
	primary_target = p_primary_target
	targets = p_targets
	battle_ctx = p_battle_ctx
	result = p_result
	_init_services()


## 地图模式初始化
func init_map(gm: Node) -> void:
	actor = gm
	primary_target = null
	targets = []
	battle_ctx = null
	result = null
	_init_services()


func _init() -> void:
	stack = VMStack.new()


func _init_services() -> void:
	combat = CombatService.new()
	combat._ctx = self
	qi = QiService.new()
	qi._ctx = self
	meridian = MeridianService.new()
	meridian._ctx = self
	deck = DeckService.new()
	deck._ctx = self
	status = StatusService.new()
	status._ctx = self
	artifact = ArtifactService.new()
	artifact._ctx = self
	enemy = EnemyService.new()
	enemy._ctx = self
	query = AIQueryService.new()
	query._ctx = self
	progression = ProgressionService.new()
	progression._ctx = self


# ============================================================
# 便捷方法
# ============================================================


func is_battle() -> bool:
	return battle_ctx != null


func trace(msg: String) -> void:
	if result:
		result.add_trace(msg)
