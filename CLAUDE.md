# Grand Zhou Tian (大周天) — 项目上下文

## 环境

- **Engine**: Godot 4.6.3 portable: `C:\Users\Cwb\Downloads\Godot_463.exe`
- **Project**: `D:\Grand_Zhou_Tian`
- **Lang**: GDScript, 2D 1280×720
- **Obsidian**: `D:\Obsidian\30-项目\大周天\`

## 模块地图

> 用户说"开发 Mx"时，只读对应模块文件 + 涉及的 .gd 源码。不加载 Obsidian 其他文档。

| 模块 | 内容 | 上下文文件 | 文件数 |
|------|------|-----------|--------|
| **M0** 核心数据 | Resource定义 + 数据库索引 + 效果字节码类型 + CardForgeResult | `.claude/modules/m0-core-data.md` | 34 |
| **M1** 经脉灵气 | 灵气流动/碰撞/冲穴/回路/功法buff/穴位特性 | `.claude/modules/m1-meridian-qi.md` | 9 |
| **M2** 战斗系统 | FSM/Actor/AI/卡牌结算/牌库/EffectVM/Domain Services/锻淬系统 | `.claude/modules/m2-battle.md` | 45 |
| **M3** 地图流程 | 菜单→地图→商店/休息/奇遇→奖励/突破 | `.claude/modules/m3-run-flow.md` | 12 |
| **M4** 法宝效果 | 法宝触发 + 统一效果协议 + 物品工厂 | `.claude/modules/m4-artifacts-effects.md` | 5 |
| **M5** UI组件 | 可复用控件 + 常量/工具函数 + 水墨主题 + ForgePopup/TraitSelector | `.claude/modules/m5-ui-components.md` | 16 |
| **M6** 状态中枢 | GameManager全局状态 + EffectContext + CardRepository + Logger日志系统 | `.claude/modules/m6-game-state.md` | 7 |

**跨模块任务**: 如"开发 M2+M6"，同时加载两个模块文件。

## Godot 4 规则（严格）

- `@tool` 必须在第1行（注释可在上方）
- 每个 .gd 文件只能有一个 `class_name`
- 禁止 `Color.RED` / `Color.GREEN` → 用 `Color(r, g, b)`
- `var x := dict.get(key)` → 必须显式类型: `var x: Type = dict.get(key)`
- `var x := min(a, b)` / `max(a, b)` → `var x: int = min(a, b)`
- `var x := load(path)` → `var x: Type = load(path) as Type`
- `DirAccess.open()` 返回 nullable — 检查 null
- `Array[int]` 不接受无类型 Array → 资源字段用 `Array`

## 架构规则 — Architecture Authority v2.0 四层模型

> **铁律**: 任何新代码必须归入已有权能体系，否则禁止创建。
> 详细规范见 `.claude/skills/architecture-authority.md`

### 四层执行模型

```
L0  UI Layer         scenes/  ui_components/     — 只做: show + input + animation
    ↑ signal (L2→L0 通过 signal 转发, L1 纯接线)
L1  Systems Layer    systems/flow/               — 只做: FSM调度 + 服务调用 + 查询委托
    ↑ 委托 (L1 不做决策, 不做 DI, 不调 UI)
L2  Domain Layer     systems/services/           — 只做: 规则执行 + 路由决策 + 数据映射
    ↑ 读取
L3  Resources        resources/                  — 纯数据 (游戏内容), 零逻辑
L4  Autoload         autoload/                   — 全局协调 (GameManager/SceneManager), 禁止计算
```

### 目录结构

```
systems/
├── providers.gd / provider_registry.gd  — 跨层基础设施
├── flow/           L1 FSM调度: battle_controller, battle_state_machine, battle_flow_orchestrator
├── services/       L2 领域服务 — 按领域分子目录:
│   ├── battle/     战斗生命周期/引导/时钟/胜负/伤害/快照/进阶
│   ├── card/       卡牌全生命周期(play/factory/repo/trigger/cooldown/cost/req/forge/tech/modifier/intent)
│   ├── qi/         灵气流体(service/pool/regen/collision/circulation/flow)
│   ├── meridian/   经脉穴位回路(service/damage/circuit/node_property/pathway)
│   ├── enemy/      敌人AI/意图/定时器/状态
│   ├── artifact/   法宝装备奇遇工厂(service/factory/manager/equipment/curio)
│   ├── deck/       牌库管理(service/manager/auto_draw)
│   ├── target/     目标选择(manager/resolver/dispatcher)
│   └── status/     Buff/Debuff(service/realtime_buff/effect_queue)
├── actors/         combat_actor, player_actor, enemy_actor
├── runtime/        card_runtime, deck_runtime, artifact_runtime, meridian_runtime, runtime_sync_service
└── vm/             效果管道: compiler, vm, resolver, context, operator, ir/
    └── ir/         VM中间表示: effect_node, effect_graph, effect_instruction, effect_program, execution_plan, effect_opcode
```

### 依赖方向 (硬编码)

```
L0 → L1 → L2 → L3
         ↑
    L4 (仅协调, 不计算)
```

❌ 禁止: L0→L2 直连 / system↔system 互调 / scene 写逻辑 / autoload 做计算

### L1 — BattleController (systems/flow/, 纯FSM运行时)

```
职责: FSM状态推进 / 服务调用 / 查询委托 / 取消调度
红线: 不做DI(服务创建) / 不做信号接线 / 不做决策 / 不调UI方法 / 不构建Context

play_card(card) → flow_orchestrator.play_card().to_dict()  // 一行委托
其余方法 → 纯 delegate 到 L2 Service
```

### L2 — Domain Services (systems/services/, 20+个)

| 服务 | 职责 | 模式 |
|------|------|------|
| **BattleFlowOrchestrator** | 卡牌行为分类 + 卡牌路由决策(功法/丹药/法宝/容器/锻造/通用) — play_card() 唯一入口 | 实例, 注入 |
| **BattleBootstrapper** | 一次性: new全部服务 + 注入依赖 + 接线signal | 静态 |
| **BattleContextFactory** | 组装BattleContext + ModifierCompiler(Tech→EffectOperator翻译) | 实例, 注入 |
| **SnapshotService** | 从Actor/Deck构建BattleSnapshot的domain数据部分 | 实例, 注入 |
| **SelectionDispatcher** | 盲转发TargetManager信号→注册的消费者(不知业务状态) | 实例, 注册 |
| **CardPlayService** | CardRuntime创建→Resolver流水线→显式状态机(IDLE/EXECUTING/WAITING_SELECTION) | 实例, 注入 |
| **ForgeService** | 锻造多步状态机(薪火相传/离火易象), 结果通过signal发射 | 实例, 注入 |
| **PathwayService** | 功法卡经脉路径绑定(起点→终点选择) | 实例, 注入 |
| **BattleTurnService** | 回合结算(胜负判定/pending效果/状态tick/弃牌) | 纯静态 |
| **EnemyTurnService** | 敌方回合(AI决策+Intent执行+灵气循环), 数据封装 | 实例, 注入 |
| **QiCirculationService** | 灵气流体循环 + buff生成 + buff消费 | 实例, 注入 |
| **CombatService** | 伤害/治疗/格挡/抽牌/最大HP / 战斗结束判定 / Boss遭遇判定 | 实例(ctx)+静态 |
| **DeckService** | 卡牌增删改 + 转化锻造 + 特性提取/交换 + 成功率 | 实例(ctx)+静态 |
| **StatusService** | buff/debuff/燃烧/易伤/虚弱/眩晕/净化/pending | 实例(ctx) |
| **EnemyService** | 敌人攻击/防御/强化/削弱时的状态修改 | 实例(ctx) |

### 信号通信 (L2→L0 零UI耦合)

```
ForgeService → forge_result_ready / forge_hint_changed / forge_finished / forge_cancelled
CardPlayService → execution_done
SelectionDispatcher → effect_execution_done
```
L1 在 Bootstrapper 中做纯接线: `forge.forge_result_ready.connect(screen.show_forge_result)`
L1/L2 代码中不出现 UI 方法名。

### 服务创建模式

```
BattleBootstrapper.bootstrap(screen, player, fsm, turn_count) → BootResult
    BootResult 包含全部已接线服务
    ↓
controller.inject_boot_result(br)  // L1 接收, 不创建
```

- **systems/services/** — Domain Service，实例通过注入引用操作，封装单一领域业务逻辑
- **systems/flow/** — FSM控制器 + 流程编排器，纯调度不决策
- **systems/vm/** — 效果管道：compiler → vm → resolver → context，禁止访问 actor/opponent/gm/系统
- **systems/runtime/** — 纯状态容器 (CardRuntime/DeckRuntime/ArtifactRuntime/MeridianRuntime)
- **systems/actors/** — 战斗角色基类 + 玩家/敌人
- **scenes/** — 可以直接引用 `GameManager.xxx`（autoload 运行时可用）
- **autoload** — 按依赖顺序注册：ProjectSettingsRegister → Logger → 数据库 → SceneManager → GameManager 最后
- **resources/** — `@tool class_name extends Resource`，每个 class_name 独立文件
- **.tres** — 备份在 `_tres_backup/`

### 权能唯一性

| 能力 | 唯一归属 (目录) |
|------|---------|
| effect 执行 | `systems/vm/effect_vm.gd` |
| effect 解析 | `systems/vm/effect_resolver.gd` |
| 卡牌生成 | `systems/services/card/card_factory.gd` |
| 卡牌运行态 | `systems/runtime/card_runtime.gd` |
| 战斗流程 | `systems/flow/battle_controller.gd` (FSM) + `systems/flow/battle_flow_orchestrator.gd` (路由) |
| 目标选择 | `systems/services/target/target_manager.gd` + `systems/services/target/selection_dispatcher.gd` |
| 卡牌路由决策 | `systems/flow/battle_flow_orchestrator.gd` |
| Context构建 | `systems/services/battle/battle_context_factory.gd` |
| 快照映射 | `systems/services/battle/snapshot_service.gd` |
| Modifier编译 | `systems/services/card/modifier_compiler.gd` |

### 修改前强制检查

- [ ] 是否已有唯一 system/service？
- [ ] 是否在重复实现能力？
- [ ] 是否违反依赖方向？
- [ ] 是否 UI/scene 写了逻辑？
- [ ] 是否 autoload 被当成业务层？
- [ ] 是否 effect 绕过 VM？
- [ ] L1 是否在做决策(if/elif 业务分支)？
- [ ] L2 是否依赖 UI(Node/Screen)？

## GDScript 注释规范

> **强制**：每个 `@export var` 必须有前置 `##` 文档注释（展示在 Godot 检查器工具提示中）。
> 详细规范见 `/godot-comment` 技能或 `.claude/skills/godot-comment.md`。

- `##` 注释解释变量含义、取值范围、引用目标（中文）
- 枚举型整数必须列出: `## 卡牌类型: 0=攻击 1=防御 ...`
- 字符串格式字段必须说明语法: `## 增益效果，格式: "buff_name:value"`
- 浮点因子必须说明范围: `## 倍率: 1.0=正常, >1=增幅, <1=衰减`
- 数组/Dictionary 必须说明元素格式和含义
- 用 `# === 区块名 ===` 对相关字段分组（超过5个字段时）
- **禁止**在 `@export var` 前无注释，**禁止**仅用行尾 `#` 内联注释代替 `##`

## 编译修复流程

1. 先修 `resources/*.gd`
2. 再修 `systems/*.gd`
3. 再修 `autoload/*.gd`
4. 最后修 `scenes/*.gd`
5. **关 Godot 再改 project.godot**（Godot 退出时覆盖）

## 上下文整理规则（Obsidian 自动归档）

> 防止上下文溢出导致项目文档缺失关键信息。

### 自动触发（PostCompact hook）

当上下文达到 ~80% 自动压缩时，hook 会将压缩摘要保存到
`D:\Obsidian\30-项目\大周天\08-开发日志\收件箱\context-inbox-*.md`
并通过 `additionalContext` 注入整理指令。

**收到注入指令后，你必须：**
1. 读取收件箱中最新的 `context-inbox-*.md` 文件
2. 分析对话涉及哪些模块（参考上方模块地图 M0-M6）
3. 将关键决策、设计变更、Bug 修复、代码改动整理到对应的 Obsidian 文档：

| 模块 | Obsidian 目录 | 典型内容 |
|------|-------------|---------|
| M0 核心数据 | `01-架构设计/` | Resource 定义、数据结构变更、opcode/字节码类型 |
| M2 战斗+效果 | `02-卡牌系统/` `03-战斗系统/` | 卡牌逻辑、Buff/触发器、FSM、AI、EffectVM/EffectContext/Domain Services |
| M1 经脉灵气 | `04-经脉系统/` | 灵气流、冲穴、回路、功法buff |
| M3 功法/地图 | `05-功法系统/` | 功法机制、转化、章节地图 |
| M4 法宝/丹药 | `06-丹药系统/` | 法宝、丹药、奇遇、效果协议 |
| M5 UI | `07-UI系统/` | UI 组件、样式、交互 |
| M6 状态中枢 | `01-架构设计/` | GameManager、EffectContext、RuntimeState、RuntimeSyncService |
| 通用 | `08-开发日志/` | Bug 修复、开发记录 |

4. **追加**到现有文档末尾（用 `---` 分隔），不要覆盖原有内容
5. 整理完成后删除收件箱中的该文件（标记已处理）

### 手动触发

- 任何时候输入 `/compact` 也会触发同样的保存+整理流程
- 对话中感觉信息量大了，可以直接说"整理到 Obsidian"
