# M1 — 经脉灵气引擎 (Meridian & Qi Engine)

> **职责**: 灵气流动模拟、五行碰撞结算、冲穴、回路检测、经脉损伤、功法buff、穴位特性、经脉图可视化
> **依赖**: M0（Resource 类、数据库）
> **被依赖**: M2（战斗系统调用本模块进行冲穴/聚气/碰撞）

## 文件清单 (9 files)

### systems/ — 纯逻辑 (7)
```
systems/qi_pool_manager.gd            # QiPoolManager — 丹田灵气池：gather/spend/can_afford/distribute
systems/qi_flow_system.gd             # QiFlowSystem — 灵气流体蔓延引擎：tick() 注入→传播→冲穴→回路返回，含 init_pathway_capacities / clear_flow_state
systems/qi_collision_resolver.gd      # QiCollisionResolver — 五行碰撞结算：相生×1.5/相克损伤/相同叠加
systems/circuit_detector.gd           # CircuitDetector — 图论回路检测：DFS 简单环检测
systems/meridian_damage_system.gd     # MeridianDamageSystem — 经脉损伤/修复/宽度管理/tick_damage_timers
systems/technique_resolver.gd         # TechniqueResolver — 功法-穴位反应→buff 生成（流量驱动）
systems/node_property_resolver.gd     # NodePropertyResolver — 穴位特性收集解析（12种特性查询）
```

### ui_components/ — 经脉图可视化 (2)
```
ui_components/meridian_view.gd        # MeridianView — 经脉图绘制：穴位/路径/流体动画/双击冲刷/功法色粒子
ui_components/node_info_popup.gd      # NodeInfoPopup — 穴位信息弹窗：单击弹出/特性中文解释
```

## 内部架构（数据流）

```
CombatActor (对称战斗状态载体)
    │  dantian_qi, base_meridian
    │  unlocked_nodes, erosion_targets
    │  active_techniques, active_buffs
    │
    ▼
QiPoolManager.gather_passive(actor)     ← 回合开始聚气
    │
    ▼
QiFlowSystem.init_pathway_capacities(actor)  ← 战斗开始时初始化路径容量
QiFlowSystem.tick(actor, flow_tracker)
    │
    ├─ inject_from_dantian()       # 从丹田抽取灵气注入经脉
    ├─ propagate()                 # 沿经脉图 BFS 传播（锁穴阻断）
    ├─ deliver_to_nodes()          # 灵气到达穴位（记录流经量）
    ├─ erosion()                   # 冲穴消耗→解锁穴位（目标权重×4, 冲刷×3.0）
    ├─ detect_circuits() → CircuitDetector  # 检测闭环回路
    └─ return_to_dantian()         # 回路灵气返回丹田（守恒）
    │
    ▼
QiCollisionResolver.resolve_all()    ← 多功法灵气流相遇→五行生克
    │
    ▼
TechniqueResolver.resolve_network_buffs()  ← 流经量×基础值×碰撞修正→buff
    │
    ▼
NodePropertyResolver.collect_active_properties(actor)  ← 解锁+有灵气→特性激活
NodePropertyResolver.get_active_property_total(actor, "extra_draw")  ← 单特性查询
```

## 对外接口（M2 战斗系统调用）

```gdscript
# QiPoolManager (static func, 参数 gm: Node / actor: CombatActor)
QiPoolManager.gather_passive(gm: Node)                   # 回合开始聚气
QiPoolManager.gather_active(gm: Node, amount: int)        # 主动蓄气卡
QiPoolManager.spend(gm: Node, cost: int) → bool           # 出牌消耗灵气
QiPoolManager.can_afford(gm: Node, cost: int) → bool
QiPoolManager.get_remaining(actor: CombatActor) → int
QiPoolManager.distribute(remaining: int, technique_count: int) → Array[int]

# QiFlowSystem (static func, 参数 actor: CombatActor)
QiFlowSystem.init_pathway_capacities(actor: CombatActor)  # 战斗开始：根据丹田容量初始化路径容量
QiFlowSystem.tick(actor: CombatActor, flow_tracker: Dictionary) → Dictionary
# 返回: {flow_moved: bool, is_dry: bool, nodes_unlocked: Array, circuits_formed: Array}
QiFlowSystem.clear_flow_state(actor: CombatActor)         # 清理断流时的微量残留
# flow_tracker 结构: {node_id: {technique_id: flow_amount, ...}, ...}

# QiCollisionResolver (static func)
QiCollisionResolver.resolve_all(techniques: Array, active_nodes: Array[int], meridian: MeridianMapData) → CollisionResult
# CollisionResult: {damaged_pathways: Array, descriptions: Array}

# TechniqueResolver (static func)
TechniqueResolver.resolve_network_buffs(techniques: Array, meridian: MeridianMapData, node_base_buffs: Dictionary, collision, flow_tracker: Dictionary) → Array[ResolvedBuff]
# ResolvedBuff: {name: String, value: int, source_node: String, technique_id: String}
# 优先使用流经量计算buff

# CircuitDetector (static func)
CircuitDetector.detect_circuits(meridian: MeridianMapData, unlocked_nodes: Array) → Array
# 返回: [[node_id, ...], ...] 闭环路径列表

# MeridianDamageSystem (static func)
MeridianDamageSystem.damage_pathway(actor: CombatActor, from_idx: int, to_idx: int, turns: int)
MeridianDamageSystem.tick_damage_timers(actor: CombatActor)  # 每回合递减损伤计时器

# NodePropertyResolver (static func)
NodePropertyResolver.collect_active_properties(actor: CombatActor) → Dictionary
# 返回: {property_type: {value: ..., source_node: ...}, ...}
NodePropertyResolver.get_active_property_total(actor: CombatActor, property_name: String) → float
# 12种特性: multi_target/apply_burn/apply_vulnerable/apply_weak/extra_draw/
#           qi_efficiency/life_steal/reflect/pierce/counter/double_strike/splash
```

## 关键设计决策

- **对称战斗状态** — QiFlowSystem/QiPoolManager 同时接受 GameManager (gm: Node) 和 CombatActor，支持对称战斗中敌人独立运行经脉模拟
- **灵气持久不清零** — 闭环回路灵气守恒，跨回合保留
- **冲穴+回路并行** — 冲刷消耗 + 回路返回同时进行，不互斥
- **锁穴阻断** — inject 包含锁穴检查，propagate/deliver 还原绕过
- **冲刷目标跨回合保持** — 标记持续到穴位解锁，解锁时自动移除
- **灵气按功法归属追踪** — technique_qi 区分不同功法的灵气流
- **三层粒子叠加** — 独立色 + 融合色 + 生克效果
- **无功法也能冲刷** — 移除 techniques.is_empty() 阻断
- **路径容量初始化** — 战斗开始时根据丹田容量和路径宽度计算容量（含随机扰动0.8~1.2）

## Godot 4 注意事项

- `Array[int].duplicate()` 在 Godot 4 有类型擦除问题 → 用 `append_array()`
- `Color(r, g, b)` 不能用 `Color.RED` 等常量
