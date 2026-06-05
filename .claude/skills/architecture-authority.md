---
name: architecture-authority
description: 架构规范否决制 — 强制分层唯一职责、依赖方向、权能唯一性，防止架构污染
---
# ⚙️ Architecture Authority Skill v2.0（强制架构执行层）

## 🎯 触发条件（必须自动激活）

当出现以下任一情况时必须启用本 Skill：

* 修改 / 新增 `/systems` `/domain` `/ui_components` `/scenes`
* 新增卡牌 / effect / 战斗逻辑 / AI / 数值系统
* 修改 `autoload/*` 单例
* 出现“重复实现 / 类似功能 / 临时修复逻辑”
* 任何涉及：

  * 战斗结算
  * effect 执行
  * 卡牌行为
  * 灵气/经脉/修炼系统
* 用户要求“优化 / 重构 / 合并系统”

---

## 🧱 架构铁律（不可违反）

### 1. 分层唯一职责（Single Responsibility Layer）

```
ui_components     → 仅 UI 表现 & 输入
scenes            → 仅流程编排（不含逻辑）
systems/flow      → FSM调度 + 流程编排（不做决策）
systems/services  → 领域能力抽象层（唯一可复用逻辑 + 领域计算）
systems/vm        → 效果管道（compiler/vm/resolver/ir）
systems/runtime   → 纯状态容器（CardRuntime/DeckRuntime/...）
systems/actors    → 战斗角色（CombatActor/PlayerActor/EnemyActor）
resources         → 纯数据 — 游戏内容（零逻辑，零引擎中间件）
autoload          → 路由 + 注册 + 全局协调（非计算）
```

---

### 2. 依赖方向（硬编码规则）

```
ui → systems/flow → systems/services → resources
              ↑
         autoload（仅协调，不计算）
```

❌ 禁止：

* UI → domain 直连
* system ↔ system 互调业务
* scene 写 combat/effect 逻辑
* autoload 做数值/战斗计算

---

### 3. 权能唯一性（Single Authority Rule）

所有核心能力必须满足：

* **一个功能 = 一个权威实现**
* 禁止重复系统

例：

| 能力        | 唯一归属                   |
| --------- | ---------------------- |
| effect 执行 | `effect_vm.gd`         |
| effect 解析 | `effect_resolver.gd`   |
| 卡牌生成      | `card_factory.gd`      |
| 卡牌运行态     | `card_runtime.gd`      |
| 战斗流程      | `battle_controller.gd` |
| 目标选择      | `target_manager.gd`    |

❌ 禁止：

* 在 card / enemy / ui 中实现 effect
* 重写一套“临时战斗逻辑”

---

## ⚔️ Effect 系统强约束

### 唯一链路：

```
effect_graph
   ↓
effect_compiler
   ↓
effect_vm（唯一执行）
   ↓
effect_resolver（唯一解析）
```

❌ 禁止：

* UI 触发 effect 逻辑
* card 直接计算伤害
* enemy 自己改数值

---

## 🃏 Card 系统规则

```
card_factory   → 生成
card_runtime   → 状态
battle_flow_orchestrator → 行为路由 (play_card 唯一入口)
```

❌ 禁止：

* card_instance 写逻辑
* scene 操作 card 内部状态
* effect 逻辑写进 card

---

## 🧠 Autoload 限制（极重要）

允许：

* registry（注册表）
* routing（转发）
* global state coordination（状态协调）

禁止：

* 战斗计算
* effect 执行
* 数值逻辑
* AI 决策

---

## 🧬 Domain Layer 规则

systems/services/ = **唯一可复用业务能力层**

必须满足：

* 无 UI 依赖
* 无 scene 依赖
* 只能被 systems 调用

---

## 🚨 冲突处理机制（强制流程）

当出现设计冲突：

### ❌ 禁止行为

* 临时 patch
* duplication system
* UI 直接补逻辑

### ✅ 必须执行

1. 定位权能归属
2. 提取到 `domain/service`
3. 删除重复实现
4. 统一引用入口
5. 更新依赖链

---

## 🧯 防止“双系统污染”

如果出现以下情况：

* 同一功能在 2 个 system 中存在
* 新写 system 替代旧 system
* UI 开始“顺手实现逻辑”

👉 立即判定为：

> ❌ 架构污染（Architecture Drift）

必须回滚并重构归一权能。

---

## 🧪 修改前强制检查（Checklist）

每次修改必须通过：

* [ ] 是否已有唯一 system/service？
* [ ] 是否在重复实现能力？
* [ ] 是否违反依赖方向？
* [ ] 是否 UI/scene 写了逻辑？
* [ ] 是否 autoload 被当成业务层？
* [ ] 是否 effect 绕过 VM？

---

## 🧠 最终铁律（Override Level 最高）

> **任何新代码必须归入已有权能体系，否则禁止创建。**

如果无法归类：

➡ 必须先重构 domain 层，而不是新增 system

---

## 🔥 一句话执行原则

> **不允许“新增功能”，只允许“归位能力”。**