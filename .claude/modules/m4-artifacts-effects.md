# M4 — 法宝效果系统 (Artifacts & Effects)

> **职责**: 法宝被动触发调度 + 统一效果协议解析执行
> **依赖**: M0（ArtifactData / 效果字符串操作 GameManager 属性）
> **被依赖**: M2（战斗系统触发法宝时机）、M3（场景通过 EffectResolver 应用效果）

## 文件清单 (2 files)

```
systems/artifact_manager.gd       # 法宝触发调度：7个触发时机 + 便利wrapper
systems/effect_resolver.gd        # 统一效果协议：apply(gm, effect_string) / apply_all(gm, effects[])
```

## 对外接口

```gdscript
# ArtifactManager — 7个触发时机 (static func, 参数 gm: Node)
ArtifactManager.on_battle_start(gm: Node)
ArtifactManager.on_turn_start(gm: Node, turn_count: int)
ArtifactManager.on_card_play(gm: Node, card: CardData)
ArtifactManager.on_damage_taken(gm: Node, amount: int)
ArtifactManager.on_damage_dealt(gm: Node, amount: int)
ArtifactManager.on_qi_circulate(gm: Node)
ArtifactManager.on_kill(gm: Node)

# EffectResolver — 统一效果协议 (static func)
EffectResolver.apply(gm: Node, effect: String) → void
EffectResolver.apply_all(gm: Node, effects: Array[String]) → void
```

## 效果协议（所有系统共用）

```
heal:<amount>              damage:<amount>
max_hp_up:<amount>         dantian_up:<amount>
gather_up:<amount>         qi_restore:<amount>
unlock_node:<name>         repair_path:<id>
repair_all                 gain_artifact:<id>
talent_up:<amount>         gold:<amount>
gain_card:<id>             remove_card:<id>
upgrade_card:<id>          transform_card
duplicate_card             buff:<type>:<value>
```

所有系统（奇遇/丹药/奖励/商店/法宝）走同一协议，`EffectResolver.apply(gm, effect)` 统一解析执行。

## 内部架构

```
触发时机 (M2/M3 调用)
    │
    ▼
ArtifactManager.on_xxx(gm)
    ├─ 遍历 gm.artifacts[]
    ├─ 筛选匹配 trigger_timing 的法宝
    └─ 对每个匹配法宝:
        EffectResolver.apply_all(gm, artifact.effects)
            │
            └─ 解析效果字符串 → 直接操作 GameManager 属性
```

## 关键设计决策

- **被动触发** — 法宝是 run 间差异化的核心，不占手牌/灵气
- **7 个触发时机覆盖战斗全流程**
- **统一协议** — 所有"造成效果"的地方（法宝/丹药/奇遇/奖励/商店）都用同一个效果字符串格式
- **EffectResolver 直接操作 GameManager** — 不通过中间层

## 修改本模块的影响

- 添加新效果类型 → 修改 EffectResolver（需了解 GameManager 所有属性）
- 添加新触发时机 → 修改 ArtifactManager + 在 M2 battle_screen 对应位置插入调用点
