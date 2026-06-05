# M0 — 核心数据层 (Core Data)

> **职责**: 所有 Resource 类型定义 + 数据库索引/查询 + 效果字节码类型定义
> **依赖**: 无（叶子模块，不依赖任何其他模块）
> **被依赖**: M1, M2, M3, M4, M5, M6

## 文件清单 (33 files)

### resources/ — Resource class 定义 (27)
```
resources/card_data.gd                   # CardData — 卡牌模板（名称/消耗/类型/效果图/稀有度/元素/生命周期行为/触发器效果）
resources/card_property_block.gd          # CardPropertyBlock — 卡牌属性块（工厂输入，含全部可生成字段）
resources/card_instance.gd               # CardInstance — 卡牌实例（升级/来源/标记 + 转化系统 grafted_effects/removed_effect_ids/element_override）
resources/card_forge_result.gd           # CardForgeResult — 锻造结果数据载体（success/extracted_trait/added_trait/removed_trait/message）
resources/technique_data.gd              # TechniqueData — 功法（元素/压力/穴位反应/buff基数/聚灵修正）
resources/meridian_map_data.gd           # MeridianMapData — 经脉图（节点+路径+穴位集合）
resources/meridian_node_data.gd          # MeridianNodeData — 穴位（名称/五行/属性列表/位置）
resources/meridian_pathway_data.gd       # MeridianPathwayData — 经脉路径（起止节点/宽度/元素/容量）
resources/map_node_data.gd               # MapNodeData — 地图节点（类型/坐标/连接/遭遇id）
resources/artifact_data.gd               # ArtifactData — 法宝（触发时机/效果/类型/灵气消耗/容器属性）
resources/equipment_data.gd              # EquipmentData — 装备（槽位/属性加成/特殊效果）
resources/curio_data.gd                  # CurioData — 奇物（被动效果/主动技能）
resources/breakthrough_option_data.gd    # BreakthroughOptionData — 突破选项
resources/enemy_data.gd                  # EnemyData — 敌人（HP/AI/意图池/对称战斗8字段）
resources/enemy_action_data.gd           # EnemyActionData — 敌人行动（类型/数值/条件）
resources/encounter_data.gd              # EncounterData — 遭遇配置（敌人+奖励）
resources/chapter_data.gd                # ChapterData — 章节（地图节点+连通性）
resources/event_data.gd                  # EventData — 奇遇事件（叙事+选项）
resources/event_choice_data.gd           # EventChoiceData — 事件选项（条件+结果）
resources/event_random_outcome.gd        # EventRandomOutcome — 随机结果
resources/shop_data.gd                   # ShopData — 商店配置（商品列表+定价）

# === v6 效果字节码系统 ===
resources/effect_opcode.gd               # EffectOpcode — 27个效果操作码枚举 + type→opcode映射表
resources/effect_node.gd                 # EffectNode — AST效果节点（id/type/opcode/value/meta/selector）
resources/effect_graph.gd                # EffectGraph — 效果节点有序集合（CRUD/查询/深拷贝）
resources/execution_plan.gd              # ExecutionPlan — 节点执行顺序（按优先级排序）
resources/effect_instruction.gd          # EffectInstruction — 单条字节码指令（opcode/value/meta/selector/jump）
resources/effect_program.gd              # EffectProgram — 不可变字节码序列（EffectCompiler输出→EffectVM输入）
```

### autoload/ — 数据库索引 (6)
```
autoload/card_database.gd                # 卡牌索引：get_card(id) → CardData, get_all_cards()
autoload/technique_database.gd           # 功法索引：get_technique(id) → TechniqueData
autoload/meridian_registry.gd            # 经脉图索引：get_map(id) → MeridianMapData
autoload/artifact_registry.gd            # 法宝索引：get_artifact(id) → ArtifactData
autoload/breakthrough_pool.gd            # 突破卡池：get_random_options(n) → Array[BreakthroughOptionData]
autoload/enemy_database.gd               # 敌人索引：get_enemy(id) → EnemyData
```

## 对外接口

所有数据库 autoload 在 Godot 运行时全局可访问。Resource 类通过 `.tres` 文件实例化。

```gdscript
# 典型用法（场景层）:
CardDatabase.get_card("attack_basic")          # → CardData
TechniqueDatabase.get_technique("fire_heart")  # → TechniqueData
MeridianRegistry.get_map("standard")           # → MeridianMapData
EnemyDatabase.get_enemy("yao_lang")            # → EnemyData
ArtifactRegistry.get_artifact("xxx")           # → ArtifactData
BreakthroughPool.get_random_options(3)         # → Array[BreakthroughOptionData]
```

## 卡牌数据三层架构

```
CardData (设计时模板 .tres)
    │
    ▼
CardInstance (运行时身份: 升级/来源/标记 + 转化修改)
    │
    ▼
CardRuntime (战斗工作副本: 可变EffectGraph + 执行状态)
```

- **CardData**: 静态模板，`@tool` Resource，字段含 base_effects（EffectNode数组）+ trigger_effects（触发器效果Dictionary）
  - CardBehavior 枚举: NORMAL(0)/TECHNIQUE(1)/PERSISTENT_SKILL(2)/MOUNT_ARTIFACT(3)/CHARGE_ARTIFACT(4)/CONTAINER(5)/**FORGE(6)**
- **CardInstance**: 玩家持有实例，记录 upgrade_level/branch/source，**新增转化字段**:
  - `grafted_effects: Array[EffectNode]` — 通过转化获得的效果
  - `grafted_tags: Array[String]` — 通过转化获得的标签
  - `removed_effect_ids: Array[String]` — 从模板中移除的效果节点id
  - `element_override: String` — 元素覆盖（空=使用模板元素）
  - `get_effective_effects()` / `get_effective_tags()` / `get_effective_element()` — 合并模板+嫁接
  - `get_conversion_count()` / `increment_conversion_count()` — 从 flags 读取转化次数
- **CardRuntime**: 战斗中的可变副本，`build_initial_graph()` 使用 `instance.get_effective_effects()` 合并实例修改

## CardForgeResult — 锻造结果数据载体

```
CardForgeResult (Domain → Controller → UI 数据流)
    success: bool
    forge_type: String          # "pass_torch" / "swap_li"
    extracted_trait: Dictionary # 提取的特性
    added_trait: Dictionary     # 添加的特性
    removed_trait: Dictionary   # 移除的特性（失败时）
    message: String             # 人类可读结果
```

工厂方法: `success_pass_torch()` / `failure_pass_torch()` / `success_swap_li()` / `failure_swap_li()` / `cancelled()`

## 效果字节码类型体系

```
EffectNode (AST 数据节点)
    │  type/opcode/value/meta/selector
    ▼
EffectGraph (节点有序集合)
    │  nodes + edges
    ▼
ExecutionPlan (执行顺序, 按优先级排序)
    │
    ▼
EffectCompiler.compile() → EffectInstruction (单条字节码)
    │  opcode/value/meta/selector/jump
    ▼
EffectProgram (不可变字节码序列)
    │
    ▼
EffectVM.execute() — 通过 EffectContext 路由到 Domain Services
```

### EffectOpcode 操作码 (27个)

| 分类 | Opcode | 说明 |
|------|--------|------|
| 战斗 | DAMAGE(0), BLOCK(1), HEAL(2) | 伤害/格挡/治疗 |
| 卡牌 | DRAW(3) | 抽牌 |
| 状态 | APPLY_STATUS(4) | 统一状态入口，meta["status_type"] 区分 |
| 灵气 | QI_GATHER(5), QI_RESTORE(6), SPEND_QI(7) | 聚气/恢复/消耗 |
| 经脉 | DANTIAN_UP(8), PATHWAY_UP(9) | 丹田容量/路径容量 |
| 角色 | MAX_HP_UP(10), GATHER_UP(11), TALENT_UP(12), SELF_DAMAGE(13) | 属性提升/自伤 |
| 经脉操作 | UNLOCK_NODE(14), REPAIR_PATH(15) | 解锁穴位/修复路径 |
| 物品 | GAIN_CARD(16)~GOLD(22) | 卡牌/法宝/金币操作 |
| 特殊 | CLEANSE_ALL(23) | 清除所有 buff |
| 控制流 | JUMP_IF(24) | 条件跳转，meta["condition"] 为真时跳转 |
| 敌人 | APPLY_STRENGTH(25), SET_ENEMY_HP(26) | 敌人力量/HP 操作 |

## 关键设计决策

- **每个 class_name 独立一个 .gd 文件** — Godot 4 不允许单文件多 class_name
- **数据库按依赖顺序注册 autoload** — card_database → technique_database → ... → enemy_database（在 project.godot 中按此顺序）
- **Resource 字段用 `Array` 不用 `Array[int]`** — Godot 4 类型擦除导致不兼容
- **.tres 文件位于 `resources/card_data/*.tres`** — 备份在 `_tres_backup/`
- **EnemyData 含对称战斗 8 字段** — 支持 CombatActor 抽象层
- **v6 字节码系统**: 效果从字符串协议迁移到整数 opcode + 编译器管道，EffectNode 降级为纯 AST 数据节点
- **三层卡牌架构**: CardData(模板) → CardInstance(身份+转化) → CardRuntime(战斗副本)，分离关注点
- **FORGE 卡牌行为**: CardBehavior.FORGE=6，锻造型技能卡（薪火相传/离火易象），通过 CardForgeService 修改 CardInstance
- **CardInstance 转化系统**: grafted_effects/grafted_tags/removed_effect_ids/element_override 支持运行时特性增删改
- **CardForgeResult 数据载體**: Domain 不操作 UI，返回结构化结果给 Controller→Screen
- **EffectGraph.from_array() 强制深拷贝**: EffectNode extends Resource 是全局共享的（.tres 加载），必须 duplicate_node() 后才能被 EffectOperator 修改，否则 modifier 污染原始 CardData（多次战斗累积/归零 bug）
- **ExecutionPlan.from_node_ids()**: compile_with_mods 后 modifier 可能添加/删除节点，需用编译后的节点 ID 重建计划确保 plan.order.size() == program.size()

## 修改本模块的影响

- 修改 Resource 字段 → 需同步更新所有引用该字段的 system/scene 脚本
- 修改数据库 autoload → 影响所有模块（但接口稳定，很少改）
- 添加新 .tres → 无需改代码，只需确保脚本引用正确
- **CardDatabase.reload()**: 清空缓存并重新扫描 `card_data/` 目录，支持热加载新增/修改的卡牌 `.tres` 文件，无需重启 Godot
- **technique_duan_zhen_jue.tres**: 煅真诀功法卡牌，`card_type=TECHNIQUE` / `behavior=TECHNIQUE`，关联 `technique_id="duan_zhen_jue"`，选择起始功法后自动加入牌库
- 添加新 opcode → 需同步更新 EffectOpcode.TYPE_TO_OPCODE + EffectVM + 对应 Domain Service
