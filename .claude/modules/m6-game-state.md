# M6 — 游戏状态中枢 (Game State)

> **职责**: GameManager 全局单例 — 所有运行时游戏状态的中枢
> **依赖**: M0（所有数据库 autoload）
> **被依赖**: M1, M2, M3, M4, M5（几乎所有模块都通过 gm 参数访问状态）

## 文件清单 (1 file)

```
autoload/game_manager.gd           # GameManager — autoload，最后加载
```

## 核心状态属性

```gdscript
# 灵气
dantian_qi: int = 5                    # 丹田当前灵气
dantian_capacity: int = 10             # 丹田上限
qi_gather_rate: int = 3                # 被动聚灵速率
qi_gather_bonuses: Dictionary = {}     # 可扩展聚气加成 {source_id: amount}

# 玩家
player_hp: int = 80
player_max_hp: int = 80
realm: int = 1                         # 境界
talent: int = 2                        # 天资 → 功法并行上限
cultivation: int = 0                   # 修为值
cultivation_to_next: int = 100         # 突破所需修为
gold: int = 0
current_block: int = 0                 # 当前格挡

# 功法/卡牌
active_techniques: Array[TechniqueData] = []
master_deck: Array[String] = []
hand: Array[CardData] = []
draw_pile: Array[CardData] = []
discard_pile: Array[CardData] = []

# Buff
active_buffs: Array[Dictionary] = []
technique_buffs: Array[Dictionary] = []   # 冲穴buff（跨回合保留）
card_buffs: Array[Dictionary] = []        # 卡牌buff（当回合清理）

# 经脉
base_meridian: MeridianMapData
unlocked_nodes: Array[String] = []        # 已解锁穴位
erosion_targets: Array[String] = []       # 冲刷目标（跨回合保持）
erosion_bonuses: Dictionary = {}          # 冲刷上限加成 {source_id: amount}
damaged_pathways: Dictionary = {}         # 受损经脉 {pathway_id: remaining_turns}
node_base_buffs: Dictionary = {}          # 穴位永久基底buff

# 法宝
artifacts: Array[ArtifactData] = []

# 地图/章节
current_chapter: ChapterData
current_map_node: MapNodeData
```

## 关键方法

```gdscript
# 冲刷上限（可扩展）
get_max_erosion_targets() → int
# = talent + erosion_bonuses 总和
add_erosion_bonus(source_id: String, amount: int)
remove_erosion_bonus(source_id: String)

# Buff 生命周期管理
clear_technique_buffs()                  # 清理冲穴buff（跨回合，调用时机不同）
clear_card_buffs()                       # 清理卡牌buff（每回合结束时）

# 经脉状态
is_node_unlocked(node_id: String) → bool
unlock_node(node_id: String)
add_erosion_target(node_id: String)
remove_erosion_target(node_id: String)

# 初始化
start_new_run()                          # 重置所有状态开始新 run
```

## autoload 加载顺序

```
project.godot [autoload] 顺序（依赖在前）:
① card_database        → ② technique_database  → ③ meridian_registry
④ artifact_registry    → ⑤ breakthrough_pool   → ⑥ enemy_database
⑦ game_manager         → ⑧ scene_manager
```

GameManager 最后加载，其 `_ready()` 可安全引用所有数据库。

## 架构约束

- **systems/ 不能全局引用 GameManager** — 必须通过 `gm: Node` 参数传入
- **scenes/ 可以直接引用 GameManager** — autoload 在运行时可用
- **修改 project.godot autoload 顺序时** — 必须先关闭 Godot（否则被覆盖）

## 修改本模块的影响

- 添加新属性 → 可能影响所有模块（评估范围）
- 修改方法签名 → 影响所有调用方（systems/ + scenes/）
- **GameManager 是最危险的模块** — 修改前务必确认影响范围
