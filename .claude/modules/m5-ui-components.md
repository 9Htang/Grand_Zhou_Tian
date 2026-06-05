# M5 — UI 组件与工具 (UI Components & Utils)

> **职责**: 可复用 UI 控件 + 常量定义 + 工具函数 + 水黑风格主题 + 调试面板
> **依赖**: M0（数据类型显示）、M6（GameManager 属性读取）
> **被依赖**: M1, M2, M3（场景脚本使用这些组件）

## 文件清单 (16 files: 11 ui_components + 5 utils)

### ui_components/ — UI 控件 (11)
```
ui_components/health_bar.gd            # HealthBar — 雕纹HP条（朱砂渐变+低血量脉冲+受伤闪白）
ui_components/qi_bar.gd                # QiBar — 灵气水晶条（天青填充+微光呼吸+流动光泽）
ui_components/buff_icon.gd             # BuffIcon — emoji图标+数值+回合+正负极性颜色
ui_components/meridian_view.gd         # MeridianView — 经脉图可视化（三层粒子叠加+流体动画+双击冲刷）
ui_components/sandbox_panel.gd         # SandboxPanel — 调试面板（` 键呼出, 三Tab: 经脉/卡牌/敌人）
ui_components/node_info_popup.gd       # NodeInfoPopup — 穴位信息弹窗（单击穴位+特性中文解释）
ui_components/styled_button.gd         # StyledButton — 古风按钮（5种变体/hover金边/press弹性）
ui_components/background_ambiance.gd   # BackgroundAmbiance — 背景氛围（飘浮灵气粒子+四角暗角）
ui_components/screen_transition.gd     # ScreenTransition — 墨迹场景过渡 (INK_WASH/FADE_BLACK/INK_DROP)
ui_components/forge_popup.gd           # ForgePopup — 锻造结果弹窗（接收CardForgeResult，成功金边/失败朱砂边，3秒自关）
ui_components/trait_selector.gd        # TraitSelector — 特性选择弹窗（特性列表+点击选择+取消，通过trait_selected信号传出）
```

### utils/ — 工具 (5)
```
utils/constants.gd                     # Constants — 所有枚举+五行生克表
utils/helpers.gd                       # Helpers — 通用工具函数
utils/ui_helpers.gd                    # UIHelpers — 自适应屏幕方案（pt()视口百分比）
utils/game_colors.gd                   # GameColors — 统一色板（底色/五行/文字/功能/卡牌5组常量）
utils/theme_builder.gd                 # ThemeBuilder — StyleBox工厂+字体自动探测
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

# MeridianView — 经脉图
# 三层粒子叠加（独立色+融合色+生克效果）
# 双击穴位 → 标记冲刷目标
# 单击穴位 → NodeInfoPopup

# SandboxPanel (调试面板)
SandboxPanel.toggle()                                # ` 键切换显示
SandboxPanel.set_player_data(actor: PlayerActor)
SandboxPanel.set_enemy_data(actor: EnemyActor)

# StyledButton — 古风按钮
# 5种变体: DEFAULT/PRIMARY/DANGER/SUCCESS/GHOST
# hover金边发光, press缩小弹性

# BackgroundAmbiance — 背景氛围
# 30个飘浮灵气粒子 + 四角暗角

# ScreenTransition — 场景过渡
# INK_WASH / FADE_BLACK / INK_DROP

# UIHelpers (static func)
UIHelpers.pt(percent: float) → float                 # 视口百分比转像素

# GameColors — 统一色板
GameColors.BG_DARK / BG_PARCHMENT                    # 底色
GameColors.FIRE / EARTH / METAL / WATER / WOOD       # 五行色
GameColors.TEXT_PRIMARY / TEXT_SECONDARY             # 文字色
GameColors.HP_BAR / QI_BAR / BLOCK_BAR              # 功能色
GameColors.RARITY_BASIC / COMMON / UNCOMMON / RARE  # 稀有度色

# ThemeBuilder (static func)
ThemeBuilder.build_stylebox(...)                      # StyleBox工厂
ThemeBuilder.detect_font() → Font                     # 字体自动探测(楷体>宋体>黑体)

# Constants
Constants.ELEMENT_GENERATES: Dictionary              # 五行相生表
Constants.ELEMENT_OVERCOMES: Dictionary              # 五行相克表
```

## 五行生克表

```gdscript
# 相生: 火→土→金→水→木→火
# 相克: 火→金→木→土→水→火
```

## 关键设计决策

- **自适应屏幕**: stretch_aspect=keep, UIHelpers.pt() 将视口百分比转为像素
- **修仙水墨主题**: GameColors 统一色板 + ThemeBuilder 主题工厂 + 古风 StyledButton
- **背景氛围**: 飘浮灵气粒子 + 四角暗角营造沉浸感
- **墨迹过渡**: 场景切换走墨迹动画 (INK_WASH/FADE_BLACK/INK_DROP)
- **Sandbox 由 ProjectSettings 控制**: ProjectSettingsRegister (@tool autoload) 注册 `game/debug/sandbox_enabled`，编辑器 Project Settings → Game → Debug 中切换
- **Sandbox 赋值时序**: 类级变量初始化为 false，_ready() 中读 ProjectSettings（必须在 autoload _ready 之后）
- **TraitSelector GDScript 兼容**: 信号参数和 _init 参数不用类型标注（Godot 4.6 解析器限制），_init 所有参数需有默认值
- **Sandbox 默认 false** (调试阶段在 ProjectSettingsRegister 设 true)
- **禁止 Color.RED/GREEN 等**: 统一用 `Color(r, g, b)`
- **ForgePopup/TraitSelector 纯表现层**: 接收数据→展示→自管理生命周期，不包含业务逻辑
- **锻造 UI 数据流**: CardForgeResult (Domain) → BattleController → BattleScreen → ForgePopup

## 卡牌交互模式

- **打出**: 仅拖拽 — 拖拽卡牌至打出区域（PlayZone 叠加面板），区域随视口自适应（PLAY_ZONE_WIDTH_PCT/Y_PCT/HEIGHT_PCT）
- **点击**: 仅在 TargetManager 卡牌选择模式时有效（锻淬流程中选择祭品/受体卡牌），验证合法目标后提交
- **功法挂载**: 拖拽功法卡至功法区域
- **弃牌**: 拖拽卡牌至手牌下方 50px

## 打出区域（PlayZone）

- 视口相对定位：宽度 70%、Y 起始 3.3%（顶栏下方）、高度 47.3%（覆盖敌人+经脉区）
- 仅在拖拽时可见，悬停时金色高亮（边框变亮 + 背景变亮 + 文字变 GOLD_BRIGHT）
- `_update_play_zone_rect()` 每帧更新以适配窗口大小变化
- 卡牌拖入松手 → `_try_play_card()` 尝试打出；失败则弹回

## 沙盒面板卡牌热加载

- 切换至卡牌标签页时自动调用 `CardDatabase.reload()` 重新扫描目录
- 新增"🔄 刷新卡牌列表"按钮手动触发
- 手牌卡牌在目标选择模式中始终可点击（不受灵气消耗限制）

## Godot 4 注意事项

- `Color(r, g, b)` 值域 0-1
- `SIZE_EXPAND_FILL` 不自动按比例 → 手动按 ratio 计算宽度
- CanvasLayer 用于跨场景 UI（SandboxPanel）
