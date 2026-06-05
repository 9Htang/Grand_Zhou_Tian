# M4 — 法宝效果与物品工厂 (Artifacts, Effects & Item Factories)

> **职责**: 法宝被动触发调度 + 统一效果协议解析 + 法宝/装备/奇物工厂
> **依赖**: M0（ArtifactData / EquipmentData / CurioData + EffectOpcode）、M2（EffectContext / EffectVM 用于效果执行）、M6（GameManager 属性）
> **被依赖**: M2（战斗系统触发法宝时机）、M3（场景通过 EffectResolver 应用效果）

## 文件清单 (5 files)

```
systems/artifact_manager.gd       # ArtifactManager — 法宝触发调度：7个触发时机 + 充能 + 便利wrapper
systems/effect_resolver.gd        # EffectResolver — 旧字符串DSL兼容层："cmd:arg" → EffectOpcode → EffectVM
systems/artifact_factory.gd       # ArtifactFactory — 法宝工厂（passive/active_mount/active_charge/active_container）
systems/equipment_factory.gd      # EquipmentFactory — 装备工厂（头/身/裤/脚/武器）
systems/curio_factory.gd          # CurioFactory — 奇物工厂（被动/主动技能）
```

## 效果协议双轨制

项目同时存在两套效果执行路径：

### 新路径 (v6 字节码 VM, 推荐)
```
CardData.base_effects (EffectNode[] AST)
    → CardRuntime.effect_graph
    → Resolver (8步管线)
    → EffectCompiler.compile()
    → EffectVM.execute(EffectProgram, EffectContext)
    → Domain Services → GameState
```
用于：所有新卡牌的 base_effects 和 trigger_effects。

### 旧路径 (字符串 DSL, 兼容层)
```
EffectResolver.apply(gm, "heal:5")
    → 解析字符串 "heal:5"
    → EffectOpcode.from_string_cmd("heal") → HEAL
    → EffectVM.execute_instruction()
```
用于：旧 .tres 中的 effect 字符串字段（法宝/丹药/奇遇），以及 EffectResolver.apply_all()。

两套路径共享 EffectVM 和 EffectOpcode，EffectResolver 已重构为 EffectOpcode 的薄兼容层。

## 对外接口

```gdscript
# ArtifactManager — 7个触发时机 + 扩展 (static func, 参数 actor: CombatActor)
ArtifactManager.on_battle_start(actor: CombatActor)
ArtifactManager.on_turn_start(actor: CombatActor, turn_count: int)
ArtifactManager.on_card_play(actor: CombatActor, card: CardData)
ArtifactManager.on_damage_taken(actor: CombatActor, amount: int)
ArtifactManager.on_damage_dealt(actor: CombatActor, amount: int)
ArtifactManager.on_qi_circulate(actor: CombatActor)
ArtifactManager.on_kill(actor: CombatActor)
ArtifactManager.poll_passive(actor: CombatActor, turn_count: int)    # 被动法宝轮询
ArtifactManager.charge_artifacts(actor: CombatActor, qi_income: int)  # 充能法宝蓄能

# EffectResolver — 兼容层 (static func)
EffectResolver.apply(gm: Node, effect: String) → void
EffectResolver.apply_all(gm: Node, effects: Array[String]) → void
```

## 效果字符串协议（旧 DSL）

```
heal:<amount>              damage:<amount>
max_hp_up:<amount>         dantian_up:<amount>
gather_up:<amount>         qi_restore:<amount>
unlock_node:<name>         repair_path:<id>
repair_all                 gain_artifact:<id>
talent_up:<amount>         gold:<amount>
gain_card:<id>             remove_card:<id>
upgrade_card:<id>          transform_card
duplicate_card             buff:<type>:<value>[:turns]
debuff:<type>:<value>[:turns]    cleanse_all
block:<amount>             draw_card:<count>
```

注意：这些字符串已映射到 EffectOpcode.STRING_CMD_TO_OPCODE，执行统一走 EffectVM。

## 法宝类型

| 类型 | ArtifactData.artifact_type | 说明 |
|------|---------------------------|------|
| 被动 | `passive` | 类似遗物，满足条件自动触发，每回合消耗灵气 |
| 挂载 | `active_mount` | 打出后挂载到遗物栏，每回合消耗灵气 |
| 充能 | `active_charge` | 日常积蓄灵气，打出时免费，后需重新充能 |
| 容器 | `active_container` | 储物戒指类，存储物品 |

## 内部架构

```
触发时机 (M2 BattleController 调用)
    │
    ▼
ArtifactManager.on_xxx(actor)
    ├─ 遍历 actor.artifacts[]
    ├─ 筛选匹配 trigger 的法宝
    ├─ 检查 condition（如果非空）
    ├─ 检查灵气是否充足（被动型每回合消耗）
    └─ 对每个匹配法宝:
        EffectResolver.apply(gm, artifact.effect)  ← 旧路径
            │
            └─ 解析字符串 → EffectOpcode → EffectVM → EffectContext
```

## 工厂类

三个工厂类用于程序化生成物品数据（设计时工具/测试/动态生成）：

```gdscript
# ArtifactFactory
ArtifactFactory.create_passive(id, name, desc, trigger, qi_per_turn, effect, condition) → ArtifactData
ArtifactFactory.create_mount(id, name, desc, trigger, qi_per_turn, effect, condition) → ArtifactData
ArtifactFactory.create_charge(id, name, desc, charge_cost, effect) → ArtifactData
ArtifactFactory.create_container(id, name, desc, slots, types, contents) → ArtifactData
ArtifactFactory.create_from_dict(data: Dictionary) → ArtifactData

# EquipmentFactory
EquipmentFactory.create(id, name, desc, slot, stats, effect, condition) → EquipmentData

# CurioFactory
CurioFactory.create_passive(id, name, desc, effect, condition) → CurioData
CurioFactory.create_active(id, name, desc, cooldown, effect, condition) → CurioData
```

## 关键设计决策

- **被动触发** — 法宝是 run 间差异化的核心，不占手牌/灵气（被动型除外）
- **7 个触发时机覆盖战斗全流程**
- **双轨效果协议** — 新卡牌用 EffectNode AST，旧系统用字符串 DSL，共享 EffectVM 执行
- **EffectResolver 已降级为兼容层** — 核心逻辑在 EffectOpcode + EffectVM（M2）
- **工厂类独立** — 每种物品类型有独立工厂，避免 Godot 4 单 class_name 限制

## 修改本模块的影响

- 添加新效果类型 → 先在 M0 的 EffectOpcode 加枚举 + 映射，再修改 EffectVM + Domain Service
- 添加新触发时机 → 修改 ArtifactManager + 在 M2 BattleController 对应位置插入调用点
- 添加新法宝类型 → 修改 ArtifactFactory + ArtifactData
