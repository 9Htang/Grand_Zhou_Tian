# M2 — 战斗系统 (Battle System)

> **职责**: 战斗主编排、FSM 状态机、对称战斗 Actor、敌人 AI、卡牌效果结算、牌库管理
> **依赖**: M0（数据）、M1（经脉灵气引擎）
> **被依赖**: M3（地图流程通过 GameManager 启动战斗）

## 文件清单 (12 files)

### systems/ — 纯逻辑 (9)
```
systems/battle_state_machine.gd      # FSM: TURN_START→PLAYER_TURN→QI_CIRCULATION→ENEMY_TURN→ENEMY_QI_CIRCULATION→TURN_END
systems/combat_actor.gd              # CombatActor 抽象基类（20+方法+10信号，玩家/敌人共享）
systems/player_actor.gd              # PlayerActor extends CombatActor（金币/修为/牌库/天资）
systems/enemy_actor.gd               # EnemyActor extends CombatActor（状态效果/AI策略/意图）
systems/enemy_ai.gd                  # 三层AI：Layer1权重 + Layer2条件触发 + Layer3经脉自主选冲刷
systems/enemy_intents.gd             # 敌人意图选择引擎
systems/card_effects.gd              # 卡牌效果结算（含穴位特性查询）
systems/damage_calculation.gd        # 伤害公式（境界/功法/buff修正）
systems/deck_manager.gd              # 牌库/手牌/弃牌堆/抽牌
```

### scenes/ — 场景脚本 (3)
```
scenes/battle/battle_screen.gd       # 战斗主编排：UI事件→系统调用→CombatActor更新
scenes/battle_test/battle_test.gd    # 战斗测试沙盒：跳过菜单直接进战斗
scenes/card/card_ui.gd              # 卡牌UI：拖拽+点击+三区域检测(功法区/弃牌区/无效)
```

## 内部架构（数据流）

```
BattleScreen (主编排)
    │
    ├─ BattleStateMachine (FSM)
    │   └─ 驱动回合流转: TURN_START → PLAYER_TURN → PLAYER_ACTION
    │                     → QI_CIRCULATION → ENEMY_TURN → ENEMY_ACTION
    │                     → ENEMY_QI_CIRCULATION → TURN_END
    │
    ├─ PlayerActor / EnemyActor (CombatActor 子类)
    │   ├─ hp, max_hp, block, qi
    │   ├─ active_techniques, active_buffs
    │   ├─ erosion_targets, unlocked_nodes
    │   └─ statuses (enemy only: burn/vulnerable/weak)
    │
    ├─ CardUI → 卡牌交互
    │   ├─ 拖拽到功法区 → 激活功法
    │   ├─ 拖拽到弃牌区 → 弃牌
    │   └─ 点击 → 出牌
    │
    ├─ CardEffects.apply(gm, card, battle_context)
    │   └─ 查询 NodePropertyResolver 获取穴位特性加成
    │
    ├─ EnemyAI → 三层决策
    │   ├─ Layer1: 权重选择意图类型
    │   ├─ Layer2: HP/状态/策略条件覆盖
    │   └─ Layer3: 经脉自主选择冲刷目标
    │
    └─ 调用 M1 接口:
        ├─ QiPoolManager.gather_passive/spend/can_afford
        ├─ QiFlowSystem.tick()
        ├─ TechniqueResolver.resolve_network_buffs()
        ├─ QiCollisionResolver.resolve_collisions()
        └─ MeridianDamageSystem.damage/repair
```

## 对外接口

```gdscript
# CombatActor (基类 — 属性访问)
actor.hp / actor.max_hp / actor.block / actor.qi
actor.active_techniques: Array[TechniqueData]
actor.active_buffs: Array[Dictionary]
actor.erosion_targets: Array[String]
actor.unlocked_nodes: Array[String]

# PlayerActor 额外属性
player.gold: int
player.cultivation: int
player.master_deck: Array[String]

# EnemyActor 额外属性
enemy.enemy_data: EnemyData
enemy.statuses: Dictionary  # {burn: {damage, turns}, vulnerable: {turns}, weak: {amount, turns}}

# CardEffects (static func)
CardEffects.apply(gm: Node, card: CardData, battle_context: Node) → bool

# DamageCalculation (static func)
DamageCalculation.calculate(base_damage: int, player_realm: int, buffs: Array, attacker_realm: int = 1) → int

# DeckManager (static func)
DeckManager.draw_cards(gm: Node, count: int)
DeckManager.shuffle_deck(gm: Node)
```

## 敌人意图类型

```
ATTACK / DEFEND / BUFF_SELF / DEBUFF_PLAYER / SEAL_MERIDIAN / DAMAGE_PATHWAY / DRAIN_QI
```

## 关键设计决策

- **对称战斗**: 玩家/敌人共享 CombatActor 基类，敌人复用全部经脉/灵气/功法逻辑
- **对称 FSM**: ENEMY_QI_CIRCULATION 阶段让敌人独立冲穴
- **Buff 生命周期区分**: `clear_technique_buffs()`（冲穴buff跨回合）/ `clear_card_buffs()`（卡牌buff当回合清理）
- **Sandbox 总开关**: `_sandbox_enabled` 默认 false
- **敌人状态自动结算**: 回合结束时 tick 灼烧/递减易伤/虚弱

## 测试入口

```
# 战斗测试（跳过菜单→功法→地图）:
project.godot: run/main_scene="res://scenes/battle_test/battle_test.tscn"

# 完整流程:
project.godot: run/main_scene="res://scenes/main/main.tscn"
```
