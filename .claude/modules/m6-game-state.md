# M6 — 游戏状态中枢 (Game State)

> **职责**: GameManager 全局单例 + EffectContext 管道容器 + RuntimeState 纯数据容器 + RuntimeSyncService 状态同步
> **依赖**: M0（所有数据库 autoload）
> **被依赖**: M1, M2, M3, M4, M5（几乎所有模块都通过 gm 参数或 actor 引用访问状态）

## 文件清单 (7 files)

```
autoload/game_manager.gd              # GameManager — autoload 全局单例，run 级别持久状态
autoload/logger.gd                    # Logger — 全局日志系统（文件+控制台，四级日志，自动刷盘）
systems/effect_context.gd             # EffectContext — VM 唯一窗口，持有 actor/opponent/result + 全 Service 实例
systems/meridian_runtime.gd           # MeridianRuntime — 经脉状态纯容器（无业务逻辑）
systems/deck_runtime.gd               # DeckRuntime — 牌库状态纯容器
systems/artifact_runtime.gd           # ArtifactRuntime — 法宝/装备/奇物状态纯容器
systems/runtime_sync_service.gd       # RuntimeSyncService — GameManager ↔ RuntimeState ↔ CombatActor 双向同步
```

## 状态模型架构

```
GameManager (autoload 单例, run 级别)
  │  持久字段: gold, cultivation, realm, talent, master_deck, artifacts
  │  章节字段: current_chapter, current_map_node
  │
  ▼ RuntimeSyncService.load_player(gm, player)
CombatActor (战斗局部, Node)
  │  hp, max_hp, dantian_qi, block, active_techniques, active_buffs
  │  base_meridian, erosion_targets, damaged_pathways, ...
  │
  ▼ RuntimeSyncService.save_player(player, gm)
GameManager (回写持久字段)
```

```
EffectContext (管道内共享容器, RefCounted)
  │  actor: Node           # 行动方
  │  opponent: Node        # 目标方
  │  battle_ctx: BattleContext
  │  result: BattleResult
  │  combat, qi, meridian, deck, status, artifact, enemy, query, progression
  │  meridian_rt, deck_rt, artifact_rt
  │
  ├─ init_battle(actor, opponent, battle_ctx, result)  # 战斗模式
  └─ init_map(gm)                                        # 地图模式
```

## Runtime State 纯数据容器

```gdscript
# MeridianRuntime — 经脉状态
var base_meridian: MeridianMapData
var active_circuits: Array[Dictionary]
var erosion_targets: Array[int]
var damaged_pathways: Dictionary
var node_base_buffs: Dictionary
var is_flow_dry: bool
var dantian_pressure: float
func copy_from(gm: Node)     # 从 GameManager 复制
func sync_to(actor: CombatActor)   # 同步到 CombatActor
func sync_from(actor: CombatActor) # 从 CombatActor 回读

# DeckRuntime — 牌库状态
var draw_pile: Array
var hand: Array
var discard_pile: Array
var exhaust_pile: Array
var pending_draw_penalty: int

# ArtifactRuntime — 法宝状态
var artifacts: Array[ArtifactData]
var equipment: Dictionary
var curios: Array[CurioData]
```

## EffectContext 接口

```gdscript
class_name EffectContext extends RefCounted

# 世界引用
var actor: Node
var opponent: Node
var battle_ctx: BattleContext
var result: BattleResult

# Domain Services (实例)
var combat: CombatService
var qi: QiService
var meridian: MeridianService
var deck: DeckService
var status: StatusService
var artifact: ArtifactService
var enemy: EnemyService
var query: AIQueryService
var progression: ProgressionService

# Runtime State
var meridian_rt: MeridianRuntime
var deck_rt: DeckRuntime
var artifact_rt: ArtifactRuntime

func init_battle(p_actor, p_opponent, p_battle_ctx, p_result)  # 战斗初始化
func init_map(gm: Node)                                          # 地图初始化
func is_battle() → bool
func trace(msg: String)
```

## GameManager 核心状态（仅 run 级别持久字段）

```gdscript
# 玩家持久状态
var player_hp: int = 80
var player_max_hp: int = 80
var realm: int = 1
var talent: int = 2
var luck: int = 0              # 气运 — 影响转化成功率
var divine_sense: int = 0      # 神识 — 影响特性提取精度
var cultivation: int = 0
var cultivation_to_next: int = 100
var gold: int = 0

# 牌库/法宝（持久）
var master_deck: Array[String] = []
var artifacts: Array[ArtifactData] = []
var card_instance_registry: Dictionary = {}  # uid→CardInstance（锻造持久化）

# 经脉持久状态
var base_meridian: MeridianMapData
var unlocked_nodes: Array[String] = []
var damaged_pathways: Dictionary = {}
var node_base_buffs: Dictionary = {}

# 地图/章节
var current_chapter: ChapterData
var current_map_node: MapNodeData
var turn_count: int = 0
```

## autoload 加载顺序

```
project.godot [autoload] 顺序（依赖在前）:
① project_settings_register → ② logger              → ③ card_database
④ technique_database        → ⑤ meridian_registry   → ⑥ artifact_registry
⑦ breakthrough_pool         → ⑧ enemy_database       → ⑨ scene_manager
⑩ game_manager
```

## 架构约束

- **systems/ 不能全局引用 GameManager** — 必须通过 `gm: Node` 或 `actor: CombatActor` 参数传入
- **scenes/ 可以直接引用 GameManager** — autoload 在运行时可用
- **EffectVM 不访问 GameManager** — 只通过 EffectContext → Domain Services 间接访问
- **Domain Service 不访问 GameManager** — 只通过 `_ctx: EffectContext` 访问 actor/opponent/result
- **Runtime State 不含业务逻辑** — 纯数据字段 + copy_from/sync_to/sync_from
- **修改 project.godot autoload 顺序时** — 必须先关闭 Godot（否则被覆盖）
- **CardRepository ↔ PlayerActor 同步**: 战斗结束时 `card_repo.save_to_dict()` → `player.card_instance_registry` → `save_to_gm()`
- **PlayerActor 新增字段**: `luck`(气运)、`divine_sense`(神识)、`card_instance_registry`(实例持久化)
- **ProjectSettingsRegister autoload**: 第一位加载的 @tool autoload，注册自定义项目设置（game/debug/sandbox_enabled、game/log/level、game/log/console 等），使 Project Settings 编辑器中可见

## Logger — 全局日志系统

```gdscript
# 用法（任意脚本中直接调用，autoload 全局可访问）
Logger.info("Battle", "卡牌打出: %s" % card.display_name)
Logger.warn("QiFlow", "灵气碰撞: 路径阻塞")
Logger.error("Forge", "锻造失败: 祭品为空")
Logger.debug("CardDB", "加载卡牌: %d 张" % count)
```

| 特性 | 说明 |
|------|------|
| **四级日志** | `Level.DEBUG(0)` / `INFO(1)` / `WARN(2)` / `ERROR(3)` |
| **文件输出** | `user://logs/YYYYMMDD_HHMMSS.log`，每条日志立即 `flush()` 防崩溃丢失 |
| **控制台输出** | INFO/DEBUG → `print()`，WARN → `push_warning()`，ERROR → `printerr()` |
| **格式** | `HH:MM:SS [DBG\|INF\|WRN\|ERR] [分类] 消息` |
| **等级过滤** | `min_level` 低于阈值的日志直接丢弃（发布时调高等级清静输出） |

### ProjectSettings 配置

| 设置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `game/log/level` | int | 0 (DEBUG) | 最低输出等级 |
| `game/log/console` | bool | true | 是否同步输出到 Godot 控制台 |

在编辑器 **Project Settings → Game → Log** 中可切换。
