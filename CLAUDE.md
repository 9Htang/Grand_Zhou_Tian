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
| **M0** 核心数据 | Resource定义 + 数据库索引 | `.claude/modules/m0-core-data.md` | 22 |
| **M1** 经脉灵气 | 灵气流动/碰撞/冲穴/回路/功法buff/穴位特性 | `.claude/modules/m1-meridian-qi.md` | 9 |
| **M2** 战斗系统 | FSM/Actor/AI/卡牌结算/牌库 | `.claude/modules/m2-battle.md` | 12 |
| **M3** 地图流程 | 菜单→地图→商店/休息/奇遇→奖励/突破 | `.claude/modules/m3-run-flow.md` | 12 |
| **M4** 法宝效果 | 法宝触发 + 统一效果协议 | `.claude/modules/m4-artifacts-effects.md` | 2 |
| **M5** UI组件 | 可复用控件 + 常量/工具函数 | `.claude/modules/m5-ui-components.md` | 7 |
| **M6** 状态中枢 | GameManager 全局状态 | `.claude/modules/m6-game-state.md` | 1 |

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

## 架构规则

- **systems/** — `RefCounted` + `static func`，通过 `gm: Node` 参数接收 GameManager，**禁止全局引用**
- **scenes/** — 可以直接引用 `GameManager.xxx`（autoload 运行时可用）
- **autoload** — 按依赖顺序注册：数据库在前 → GameManager → SceneManager 最后
- **resources/** — `@tool class_name extends Resource`，每个 class_name 独立文件
- **.tres** — 备份在 `_tres_backup/`

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
