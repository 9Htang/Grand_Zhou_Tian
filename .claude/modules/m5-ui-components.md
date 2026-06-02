# M5 — UI 组件与工具 (UI Components & Utils)

> **职责**: 可复用 UI 控件 + 常量定义 + 工具函数 + 调试面板
> **依赖**: M0（数据类型显示）、M6（GameManager 属性读取）
> **被依赖**: M1, M2, M3（场景脚本使用这些组件）

## 文件清单 (7 files)

### ui_components/ — UI 控件 (4)
```
ui_components/health_bar.gd       # HP 条：按比例缩放、颜色渐变
ui_components/qi_bar.gd           # 灵气条：类似 HealthBar 但显示灵气
ui_components/buff_icon.gd        # Buff 图标：显示 buff 类型+数值
ui_components/sandbox_panel.gd    # 调试面板：` 键呼出，三Tab(经脉/卡牌/敌人)
```

### utils/ — 工具 (3)
```
utils/constants.gd                # class_name Constants — 所有枚举+五行表
utils/helpers.gd                  # class_name Helpers — 通用工具函数
utils/ui_helpers.gd               # class_name UIHelpers — 自适应屏幕宽高方案
```

## 对外接口

```gdscript
# HealthBar
HealthBar.set_health(current: int, maximum: int)
HealthBar.set_animated(enabled: bool)

# QiBar
QiBar.set_qi(current: int, maximum: int)

# BuffIcon
BuffIcon.set_buff(buff_type: String, value: int, duration: int)
# 颜色通过 _pending_color 设置（不能用 Color.GREEN）

# SandboxPanel (调试面板)
# 默认禁用：_sandbox_enabled = false
SandboxPanel.toggle()                                # 切换显示
SandboxPanel.set_player_data(actor: PlayerActor)
SandboxPanel.set_enemy_data(actor: EnemyActor)

# UIHelpers (static func)
UIHelpers.pt(percent: float) → float                 # 视口百分比转像素

# Constants
Constants.ELEMENT_GENERATES: Dictionary              # 五行相生表
Constants.ELEMENT_OVERCOMES: Dictionary              # 五行相克表
# 其他枚举：CardType / TechniqueElement / NodeProperty / BattleState 等

# Helpers (static func)
# 通用工具函数集合
```

## 五行生克表

```gdscript
# 相生: 火→土→金→水→木→火
# 相克: 火→金→木→土→水→火
```

## 关键设计决策

- **自适应屏幕**: stretch_aspect=keep, UIHelpers.pt() 将视口百分比转为像素
- **HealthBar 尺寸保护**: `_build_ui()` 不覆盖外部设置的尺寸
- **Sandbox 默认禁用**: `_sandbox_enabled` 默认 false
- **禁止 Color.RED/GREEN 等**: 统一用 `Color(r, g, b)`

## Godot 4 注意事项

- `Color(r, g, b)` 值域 0-1
- `SIZE_EXPAND_FILL` 不自动按比例 → 手动按 ratio 计算宽度
- CanvasLayer 用于跨场景 UI（SandboxPanel）
