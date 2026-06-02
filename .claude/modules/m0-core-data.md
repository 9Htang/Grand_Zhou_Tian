# M0 — 核心数据层 (Core Data)

> **职责**: 所有 Resource 类型定义 + 数据库索引/查询
> **依赖**: 无（叶子模块，不依赖任何其他模块）
> **被依赖**: M1, M2, M3, M4, M5, M6

## 文件清单 (27 files)

### resources/ — Resource class 定义 (21)
```
resources/card_data.gd                   # CardData — 卡牌（名称/消耗/类型/效果/稀有度/元素/生命周期行为/聚灵修正）
resources/card_property_block.gd          # CardPropertyBlock — 卡牌属性块（工厂输入，含全部可生成字段）
resources/technique_data.gd              # TechniqueData — 功法（元素/压力/穴位反应/buff基数/聚灵修正）
resources/meridian_map_data.gd           # MeridianMapData — 经脉图（节点+路径集合）
resources/meridian_node_data.gd          # MeridianNodeData — 穴位（名称/五行/属性列表/位置）
resources/meridian_pathway_data.gd       # MeridianPathwayData — 经脉路径（起止节点/宽度/元素）
resources/map_node_data.gd               # MapNodeData — 地图节点（类型/坐标/连接）
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

## 关键设计决策

- **每个 class_name 独立一个 .gd 文件** — Godot 4 不允许单文件多 class_name
- **数据库按依赖顺序注册 autoload** — card_database → technique_database → ... → enemy_database（在 project.godot 中按此顺序）
- **Resource 字段用 `Array` 不用 `Array[int]`** — Godot 4 类型擦除导致不兼容
- **.tres 文件位于 `resources/<type>/*.tres`** — 备份在 `_tres_backup/`
- **EnemyData 含对称战斗 8 字段** — 支持 CombatActor 抽象层

## 修改本模块的影响

- 修改 Resource 字段 → 需同步更新所有引用该字段的 system/scene 脚本
- 修改数据库 autoload → 影响所有模块（但接口稳定，很少改）
- 添加新 .tres → 无需改代码，只需确保脚本引用正确
