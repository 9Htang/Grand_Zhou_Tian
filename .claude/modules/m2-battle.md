# M2 — 战斗系统 + 效果引擎 (Battle & Effect Engine)

> **职责**: 战斗主编排、FSM 状态机、对称战斗 Actor、敌人 AI、卡牌效果结算、牌库管理、**EffectVM 字节码执行**、**EffectContext 领域门面**、**Domain Services**
> **依赖**: M0（数据）、M1（经脉灵气引擎）
> **被依赖**: M3（地图流程通过 GameManager 启动战斗）；M4（法宝在战斗时机触发）

## 文件清单 (56 files)

### systems/ — 战斗流程 (10)
```
systems/battle_controller.gd          # BattleController — 纯编排器：FSM驱动/回合流转/路径选择/卡牌打出/锻造流程（FORGE 6步状态机）
systems/battle_state_machine.gd       # BattleStateMachine — FSM 10状态转换
systems/combat_actor.gd               # CombatActor — 抽象基类（+luck/divine_sense 气运/神识）
systems/player_actor.gd               # PlayerActor extends CombatActor（金币/修为/牌库/天资 + card_instance_registry）
systems/enemy_actor.gd                # EnemyActor extends CombatActor（状态效果/AI策略/意图）
systems/enemy_ai.gd                   # EnemyAI — 三层AI：Layer1权重 + Layer2条件触发 + Layer3经脉自主选冲刷
systems/enemy_intents.gd              # EnemyIntents — 敌人意图引擎（通过 EffectContext → Domain Service 执行）
systems/enemy_status_system.gd        # EnemyStatusSystem — 敌人状态管理（burn/vulnerable/weak 施加与tick）
systems/card_effects.gd               # CardEffects — 卡牌特殊行为协调层（功法/丹药/法宝/容器/锻造 + play_condition 检查）
systems/damage_calculation.gd         # DamageCalculation — 伤害公式（境界/功法/buff修正）
```

### systems/ — 卡牌运行时 (6)
```
systems/card_factory.gd               # CardFactory — 三层构建工厂 + clone_instance 深拷贝转化字段 + _deep_copy_effects
systems/card_runtime.gd               # CardRuntime — build_initial_graph() 使用 instance.get_effective_effects()
systems/card_trigger_router.gd        # CardTriggerRouter — 卡牌生命周期触发器（6种事件）
systems/card_repository.gd            # CardRepository — 卡牌实例唯一仓储（uid→CardInstance + base_id反向索引 + clone绑定）
systems/deck_manager.gd               # DeckManager — clone CardData 确保每卡独立对象，支持锻造追踪
systems/target_manager.gd             # TargetManager — 目标选择调度器（request→合法目标→submit→恢复执行）
```

### systems/ — 效果字节码引擎 (7)
```
systems/effect_compiler.gd            # EffectCompiler — EffectNode(AST) → EffectProgram(Bytecode) + compile_with_mods()
systems/effect_vm.gd                  # EffectVM — 确定性执行内核（只执行 opcode，只通过 EffectContext 访问世界）
systems/effect_operator.gd            # EffectOperator — 效果图变换语言 (SCOPE→CREATE→MODIFY→DESTROY)
systems/resolver.gd                   # Resolver — 纯调度器（validate→compile→step→result）
systems/effect_resolver.gd            # EffectResolver — 旧字符串DSL兼容层（→EffectOpcode→EffectVM）
systems/battle_context.gd             # BattleContext — 执行上下文（actor/opponent/turn/modifiers）
systems/battle_result.gd              # BattleResult — 结算输出（damage/block/heal/status/trace）
```

### systems/ — EffectContext + Domain Services (11)
```
systems/effect_context.gd             # EffectContext — VM 唯一窗口（actor/opponent/battle_ctx/result + 全 Service 实例）
systems/domain/combat_service.gd      # CombatService — 伤害/治疗/格挡/抽牌/最大HP/胜负判定
systems/domain/qi_service.gd          # QiService — 灵气聚集/消耗/恢复/速率修正
systems/domain/meridian_service.gd    # MeridianService — 丹田容量/路径容量/穴位解锁/修复/封穴/断脉/吸灵
systems/domain/deck_service.gd        # DeckService — 卡牌域（实例方法:增删改查 + 静态方法:特性提取/应用/移除/交换/成功率）
systems/domain/status_service.gd      # StatusService — 战斗状态/永久buff/pending效果/净化
systems/domain/artifact_service.gd    # ArtifactService — 获得法宝
systems/domain/enemy_service.gd       # EnemyService — 敌人攻击/防御/强化/封穴/断脉/吸灵
systems/domain/ai_query_service.gd    # AIQueryService — AI只读查询（境界/buff/穴位属性）
systems/domain/progression_service.gd # ProgressionService — 修炼/境界/天赋/金币
systems/domain/qi_circulation_service.gd # QiCirculationService — 灵气循环 + buff生成 + buff消费（从 BattleController 提取）
```

### systems/ — 辅助 (3)
```
systems/providers.gd                  # Providers — 目标提供者体系 (PathProvider/NodeProvider/CardProvider/EnemyProvider/FeatureProvider等)
systems/provider_registry.gd          # ProviderRegistry — 选择器类型注册表（含 feature/effect_node/card）
systems/intent_compiler.gd            # IntentCompiler — EnemyActionData → EffectProgram 编译器
```

### systems/ — 运行时状态 (4)
```
systems/meridian_runtime.gd           # MeridianRuntime — 经脉状态纯容器
systems/deck_runtime.gd               # DeckRuntime — 牌库状态纯容器
systems/artifact_runtime.gd           # ArtifactRuntime — 法宝状态纯容器
systems/runtime_sync_service.gd       # RuntimeSyncService — GameManager ↔ RuntimeState ↔ CombatActor 双向同步
```

### scenes/ — 场景脚本 (12)
```
scenes/battle/battle_screen.gd              # BattleScreen — 战斗 UI 薄壳 (~209行, L0)
scenes/battle_test/battle_test.gd           # BattleTest — 战斗测试沙盒
scenes/card/card_ui.gd                       # CardUI — 卡牌UI交互
# BattleScreen 拆出的子系统 (L0, extends RefCounted):
scenes/battle/builders/battle_layout_builder.gd  # 一次性构建全部 UI 节点
scenes/battle/flow/battle_flow_view.gd            # FSM 信号 → UI 适配器
scenes/battle/input/drag_input_handler.gd         # 拖拽输入 + 打出路由
scenes/battle/presenters/snapshot_presenter.gd    # 快照分发编排
scenes/battle/presenters/hand_presenter.gd        # 手牌展示
scenes/battle/presenters/enemy_presenter.gd       # 敌人展示
scenes/battle/presenters/meridian_presenter.gd    # 经脉展示 + 交互
scenes/battle/presenters/technique_presenter.gd   # 功法展示
scenes/battle/presenters/buff_presenter.gd        # Buff 图标
scenes/battle/presenters/forge_presenter.gd       # 锻造 UI
scenes/battle/presenters/target_selection_view.gd # 目标选择 UI
```

## 终局架构：效果执行管道

```
                       设计时                          运行时
              ┌─────────────────────┐    ┌──────────────────────────────┐
              │ EffectNode (AST)    │    │  CardFactory.create_runtime()│
              │   .tres 中定义      │    │         │                    │
              │   type/value/meta   │    │         ▼                    │
              └─────────┬───────────┘    │  CardRuntime                 │
                        │                │   ├─ effect_graph (可变副本) │
                        ▼                │   ├─ execution_plan          │
              EffectGraph.from_array()   │   └─ effect_program          │
                        │                │         │                    │
                        ▼                │         ▼                    │
              卡牌打出 (BattleController)│  Resolver (纯调度器)          │
                        │                │   begin(): compile           │
                        ▼                │   step(): VM execute         │
              Resolver.begin()           │         │                    │
              ┌─────────────────────┐    │         ▼                    │
              │ EffectOperator      │    │  EffectCompiler              │
              │  图变换 (SCOPE→     │    │   compile_with_mods()        │
              │   CREATE→MODIFY→   │    │   应用全部Operator后编译      │
              │   DESTROY)          │    │         │                    │
              └─────────────────────┘    │         ▼                    │
                                         │  EffectVM.execute()          │
                                         │   只执行 opcode              │
                                         │   只通过 EffectContext       │
                                         │         │                    │
                                         │         ▼                    │
                                         │  EffectContext (VM唯一窗口)  │
                                         │   ├─ combat.damage_target()  │
                                         │   ├─ qi.add_qi()             │
                                         │   ├─ meridian.unlock_node()  │
                                         │   ├─ progression.add_gold()  │
                                         │   └─ ... (9 Services)        │
                                         │         │                    │
                                         │         ▼                    │
                                         │  Domain Services → Actors    │
                                         │         │                    │
                                         │         ▼                    │
                                         │  BattleResult (输出)         │
                                         └──────────────────────────────┘
```

### EffectContext → Domain Services 架构

```
EffectVM (确定性执行内核)
    │ 禁止访问 actor/opponent/gm/任何系统
    │ 只执行 opcode
    ▼
EffectContext (VM 唯一窗口)
    │ actor, opponent, battle_ctx, result
    │ combat, qi, meridian, deck, status, artifact
    │ enemy, query, progression
    │ meridian_rt, deck_rt, artifact_rt
    ▼
Domain Services (9个，实例方法通过 _ctx 访问世界)
    ├─ CombatService      — 伤害/治疗/格挡/抽牌/最大HP/胜负判定
    ├─ QiService          — 灵气聚集/消耗/恢复/速率
    ├─ MeridianService    — 丹田/路径/穴位/修复/封穴/断脉/吸灵
    ├─ DeckService        — 获得/移除/升级/变换/复制卡牌
    ├─ StatusService      — 状态效果/buff/pending/净化
    ├─ ArtifactService    — 获得法宝
    ├─ EnemyService       — 敌人攻击/防御/强化
    ├─ AIQueryService     — AI只读查询
    └─ ProgressionService — 修炼/境界/天赋/金币
    │
    ▼
Runtime State (纯数据容器)
    CombatActor / PlayerActor / EnemyActor
    MeridianRuntime / DeckRuntime / ArtifactRuntime
```

## 卡牌生命周期触发器

```
DeckManager 区域转换
    │
    ├─ draw_pile → hand      触发: on_draw + on_hand_enter
    ├─ hand → discard_pile   触发: on_discard + on_hand_leave
    ├─ hand → exhaust_pile   触发: on_exhaust + on_hand_leave
    ├─ (任意) → hand         触发: on_hand_enter
    └─ 回合结束保留在手牌    触发: on_retain
```

## TargetManager 两阶段执行

```
Resolver.step() 遇到 selector ≠ {}
    │
    ▼
BattleResult.waiting = true → BattleController 挂起
    │
    ▼
TargetManager.request(selector, battle_context)
    ├─ ProviderRegistry.get_targets() → 合法目标列表
    └─ selection_started signal → UI 高亮
    │
    ▼
玩家选择 → TargetManager.submit_target()
    │
    ▼
selection_completed signal → BattleController 恢复执行
```

## 对外接口

```gdscript
# EffectContext (VM 唯一入口)
var ctx: EffectContext = EffectContext.new()
ctx.init_battle(actor, opponent, battle_ctx, result)  # 战斗模式
ctx.init_map(gm)                                        # 地图模式

# Resolver (static func)
Resolver.resolve(card: CardRuntime, context: BattleContext) → BattleResult
Resolver.begin(card: CardRuntime, context: BattleContext) → BattleResult
Resolver.step(card: CardRuntime, context: BattleContext) → BattleResult

# EffectCompiler (static func)
EffectCompiler.compile(nodes: Array[EffectNode]) → EffectProgram
EffectCompiler.compile_with_mods(nodes, instance_mods, run_mods, battle_mods, temp_mods) → EffectProgram

# EffectVM (static func)
EffectVM.execute(program: EffectProgram, ctx: EffectContext) → void
EffectVM.execute_instruction(ins: EffectInstruction, ctx: EffectContext) → void

# CardFactory (static func)
CardFactory.create_instance(card_id: String) → CardInstance
CardFactory.create_runtime(inst: CardInstance) → CardRuntime

# IntentCompiler (static func)
IntentCompiler.compile(action: EnemyActionData) → EffectProgram

# CardRepository (实例方法)
var repo: CardRepository = CardRepository.new()
repo.bind_clone(card_clone) → CardInstance
repo.find_by_clone(card_clone) → CardInstance
repo.find_one(base_id) → CardInstance
repo.load_from_dict(dict) / repo.save_to_dict() → Dictionary

# DeckService 静态方法 (锻造)
DeckService.extract_random_feature(inst, shenshi) → Dictionary
DeckService.apply_feature(inst, feature) → bool
DeckService.remove_random_feature(inst) → Dictionary
DeckService.swap_features(inst_a, fa, inst_b, fb) → bool
DeckService.roll_success(base, luck, conv, min, max) → bool
```

## 敌人意图类型

```
ATTACK / ATTACK_MULTI / DEFEND / BUFF_SELF / DEBUFF_PLAYER / SEAL_MERIDIAN / DAMAGE_PATHWAY / DRAIN_QI
```

## 锻造流程 (FORGE CardBehavior)

```
BattleController.play_card(FORGE卡)
    │
    ▼
CardEffects.apply() → {awaiting_forge: true, forge_type: "pass_torch"|"swap_li"}
    │
    ▼
BattleController._start_forge_flow()
    │
    ├─【薪火相传】Step1 选祭品A → Step2 选受体B → 执行
    └─【离火易象】Step1 选卡A → Step2 选卡B → Step3 选A特性 → Step4 选B特性 → 执行
    │
    ▼
DeckService (静态方法)
    ├─ extract_random_feature(inst, shenshi)
    ├─ apply_feature(inst, feature) / remove_random_feature(inst)
    ├─ swap_features(inst_a, fa, inst_b, fb)
    └─ roll_success(base_rate, luck, conv_count, min, max) → bool
    │
    ▼
CardForgeResult {success, extracted_trait, added_trait, removed_trait, message}
    │
    ▼
BattleScreen._show_forge_result(result) → ForgePopup 组件
```

## CardRepository 实例管理

```
CardRepository
    _by_uid: Dictionary          # uid → CardInstance（主存储）
    _uids_by_base: Dictionary    # base_id → [uid, ...]（反向索引）

核心方法:
    get_instance(uid) → CardInstance
    find_one(base_id) → CardInstance      # 最常见场景
    find_all(base_id) → Array[CardInstance]  # 多副本
    bind_clone(clone) → CardInstance      # clone 打标 + 绑定实例
    find_by_clone(clone) → CardInstance   # 通过 meta("instance_uid") 查找
    load_from_dict(dict) / save_to_dict()  # 持久化同步
```

查找链:
```
CardData 克隆体 meta("instance_uid")
    → card_repo.find_by_clone(clone)
        ↓ 未找到
    → card_repo.find_one(card.id)
        ↓ 未找到
    → 无修改，用模板 CardData
```

## DeckService 卡牌域（归并后）

```
DeckService
├── 实例方法 (EffectContext 模式 — EffectVM 调用)
│   ├── gain_card / remove_card
│   ├── upgrade_card
│   └── transform_random / duplicate_random
│
└── 静态方法 (锻造流程 — BattleController / Provider 调用)
    ├── get_extractable_features(inst, shenshi)
    ├── extract_random_feature(inst, shenshi)
    ├── apply_feature(inst, feature)
    ├── remove_random_feature(inst) / remove_specific_feature(inst, feature)
    ├── swap_features(inst_a, fa, inst_b, fb)
    ├── calculate_success_rate(base, luck, conv, min, max)
    └── roll_success(base, luck, conv, min, max) → bool
```

## 关键设计决策

- **EffectVM 红线**: 永久禁止访问 actor/opponent/gm/任何系统，只执行 opcode + 调 EffectContext
- **EffectContext 唯一窗口**: VM 通过 EffectContext 访问世界，所有 Domain Service 通过 `_ctx` 回引用访问
- **Domain Service 实例方法**: 不再传 `state: GameState` 参数，通过 `_ctx` 访问 actor/opponent/result
- **BattleController 纯编排器**: 357行（从627行削减43%），不做任何游戏规则计算，不直接修改状态
- **QiCirculationService**: 灵气循环 + buff生成 + buff消费，从 BattleController 提取
- **IntentCompiler**: 统一敌人意图和玩家卡牌走同一条 EffectVM 管道
- **Resolver 纯调度器**: 删除 Steps 2-5 修正应用（移到 EffectCompiler.compile_with_mods），只做 compile + step + result
- **对称战斗**: 玩家/敌人共享 CombatActor 基类，敌人复用全部经脉/灵气/功法逻辑
- **Runtime State 分离**: MeridianRuntime/DeckRuntime/ArtifactRuntime 纯数据容器，RuntimeSyncService 负责双向同步
- **Sandbox 总开关**: `_sandbox_enabled` 默认 false
- **CardForgeService 归并入 DeckService**: 卡牌增删改 + 特性转化锻造统一在同一个域服务中
- **CardRepository 集中管理实例**: 替换散落在 DeckManager/BattleController/GameManager 的 registry 逻辑，uid 唯一标识
- **CardForgeResult 数据载体**: Domain→Controller→UI 数据流，Domain 不直接操作 UI
- **FORGE 6步状态机**: BattleController 内 forge_step 驱动 sequential target selection，复用 TargetManager
- **DeckManager clone**: initialize() 时 duplicate CardData，确保每张卡独立可追踪
- **play_condition 生效**: CardEffects._check_play_condition() 检查 has_technique/realm/talent 前置条件
- **Resolver plan sync**: begin() 中 compile_with_mods 后重建 execution_plan，避免 modifier 添加节点导致 step() OOB
- **compile_with_mods out_node_order**: 输出参数返回编译后最终节点 ID 列表
- **step() 双守卫**: 同时检查 program.size() 和 plan.order.size()
- **_on_target_selection_completed 越界保护**: 检查 step_pc 范围
- **CardRepository.find_uids 返回 Array**: Godot 4 拒绝 Array→Array[String] 隐式转换
- **卡牌仅拖拽打出**: 点击不再打出卡牌，必须拖拽至打出区域（PlayZone）。点击仅用于锻淬目标选择（_on_card_tapped → TargetManager.submit_target）
- **FORGE 锻造卡立即消耗**: play_card() 中 _start_forge_flow 后立即 _route_card(exhaust)，避免锻造卡残留在手牌
- **_finish_forge 不再调用 _cancel_forge**: 提取 _reset_forge_state() 纯状态重置，_finish_forge 成功后不发"已取消锻造"，改走 _on_effect_execution_done 正常刷新

## 测试入口

```
# 战斗测试（跳过菜单→功法→地图）:
project.godot: run/main_scene="res://scenes/battle_test/battle_test.tscn"

# 完整流程:
project.godot: run/main_scene="res://scenes/main/main.tscn"
```
