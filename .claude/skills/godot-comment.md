# Godot GDScript 注释规范 — 大周天项目

为 Godot 4 项目的 `.gd` 资源定义文件强制执行详细的注释标准，使得在 `.tres` 文件中和 Godot 编辑器检查器中查看时，每个变量都清晰易懂。

## 触发条件

当用户执行以下操作时调用此技能：
- 编写或修改 `resources/` 目录下的任何 `.gd` 文件（Resource 定义）
- 请求「添加注释」「检查注释」「注释规范」或类似操作
- 创建新的 `@export var` 变量
- 要求审查代码的可读性

## 核心规则

### 规则 1：每个 `@export` 变量必须有前置 `##` 注释

```gdscript
## 卡牌唯一标识符，用于数据库索引和跨资源引用
@export var id: String = ""

## 卡牌显示名称，直接展示给玩家的文字
@export var display_name: String = ""
```

**为什么是 `##`（双井号）而不是 `#`？**
- `##` 是 Godot 的文档注释语法，会显示在编辑器检查器的工具提示中
- `.tres` 文件不显示注释，但编辑器中悬停时会显示 `##` 注释
- `#` 仅用于代码级旁注，不会出现在检查器中

### 规则 2：注释内容必须解释「是什么」而非重复名称

| 不好 | 好 |
|------|-----|
| `## 伤害` | `## 卡牌造成的基础伤害值，实际伤害由伤害计算系统处理` |
| `## ID` | `## 卡牌唯一标识符，用于数据库索引和跨资源引用` |
| `## 消耗` | `## 打出此卡牌消耗的灵气点数` |

### 规则 3：枚举型整数必须列出所有可选值

```gdscript
## 卡牌类型: 0=攻击 1=防御 2=技能 3=法宝牌 4=功法 5=蓄气 6=丹药
@export var card_type: CardType = CardType.ATTACK

## 目标类型: 0=无需目标 1=单个敌人 2=全体敌人 3=自身 4=随机敌人
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
```

### 规则 4：字符串格式的字段必须说明格式/语法

```gdscript
## 施加给自己的增益效果字符串，格式: "buff_name:value"，如 "strength:3"
@export var buff_self: String = ""

## 法宝触发时机: "on_turn_start" / "on_card_play" / "on_damage_taken" /
##   "on_qi_circulate" / "on_battle_start" / "always" /
##   "on_attack_played" / "on_defense_played"
@export var trigger: String = "always"
```

### 规则 5：引用其他资源的 ID 字段必须说明引用目标

```gdscript
## 关联的功法资源ID，对应 TechniqueData.id
@export var technique_id: String = ""

## 此经脉地图使用的穴位列表，索引对应 MeridianNodeData 的节点编号
@export var connections: Array = []
```

### 规则 6：浮点数因子必须说明范围和含义

```gdscript
## 攻击力倍率: 1.0=正常, >1=增幅, <1=衰减
@export var attack_multiplier: float = 1.0

## 灵气返回比例: 功法完成一个小周天后返回的灵气占比 (0.0~1.0)
@export var qi_return_rate: float = 0.8

## 经脉宽度: 0.3=极窄(流速快/承载少), 1.0=标准, 2.0=宽(流速慢/承载多)
@export var width: float = 1.0
```

### 规则 7：数组/Dictionary 字段必须说明元素含义

```gdscript
## 穴位特性列表，格式: ["特性名:参数"], 如 ["multi_target", "apply_burn:3", "life_steal:0.2"]
## 穴位解锁后且有灵气流过时在战斗中生效
@export var properties: Array[String] = []

## 功法-穴位反应映射, key=五行元素名 value=反应效果字符串
## 如 {"火": "attack_up:3", "水": "energy_down:1"}
@export var node_reactions: Dictionary = {}
```

### 规则 8：用 `# === 区块名 ===` 对相关字段分组

```gdscript
# === 基础信息 ===
@export var id: String = ""
@export var display_name: String = ""

# === 战斗属性 ===
@export var damage: int = 0
@export var block: int = 0

# === 升级加成 ===
@export var upgrade_damage_bonus: int = 3
@export var upgrade_block_bonus: int = 3
```

### 规则 9：公开方法需要注释说明用途、参数和返回值

```gdscript
## 将此卡牌升级，返回升级后的新卡牌实例（不修改原实例）
## @return: 升级后的 CardData 副本，伤害和格挡获得加成，费用减免
func apply_upgrade() -> CardData:
    ...

## 将元素字符串转为 Element 枚举整数值
## @param element_name: 元素中文名（火/水/木/金/土）
## @return: 对应的枚举值 (1-5)，未知返回 0
func get_element_int(element_name: String) -> int:
    ...
```

### 规则 10：注释使用中文

本项目是修仙题材中文项目，所有面向用户的注释一律使用中文。

## 注释模板速查

### 资源 ID 类
```gdscript
## [资源类型]唯一标识符，用于数据库索引和跨资源引用
@export var id: String = ""
```

### 显示名称类
```gdscript
## [资源类型]显示名称，直接展示给玩家
@export var display_name: String = ""
```

### 多行描述类
```gdscript
## [资源类型]详细描述，展示在卡牌/道具/事件等界面的描述区域
@export_multiline var description: String = ""
```

### 数值类（伤害/格挡/治疗）
```gdscript
## 卡牌造成的[伤害/格挡/治疗]基础值，实际数值经由伤害计算系统和增益修正
@export var damage: int = 0
```

### 计数类
```gdscript
## [动作/效果]数量，如抽牌张数、可选择目标数
@export var draw_count: int = 0
```

### 颜色类
```gdscript
## [用途]颜色，用于[场景/UI位置]显示
@export var texture_color: Color = Color(1, 1, 1)
```

### 权重/概率类
```gdscript
## [用途]权重，数值越大随机被选中的概率越高
@export var weight: int = 1
```

### 境界/等级限制类
```gdscript
## 最低境界要求，低于此境界不可[选择/使用]
@export var min_realm: int = 1
```

### 布尔标志类
```gdscript
## 是否已[状态描述]，true=已[状态] false=未[状态]
@export var unlocked: bool = true
```

## 执行流程

当用户要求为某个 `.gd` 文件添加注释时：

1. **读取文件** — 完整读取目标文件
2. **识别缺失注释** — 检查每个 `@export var` 前面是否有 `##` 注释
3. **按优先级分组**：
   - **P0（必须立即修复）**: 枚举型整数（如 `card_type: int`），在 `.tres` 中显示为数字，完全无法理解
   - **P1（高优先级）**: 缺少注释的 `@export var`（无任何 `#` 或 `##` 注释）
   - **P2（应修复）**: 有 `#` 注释但缺少 `##` 文档注释的变量（检查器工具提示不会显示）
   - **P3（建议修复）**: 注释过于简略，未说明取值范围/格式/引用目标
4. **添加注释** — 按优先级逐一添加 `##` 注释，保持现有代码逻辑不变
5. **检查区块分组** — 如相关字段超过 5 个且无分组注释，建议添加 `# === 区块名 ===`
6. **验证** — 确认所有 `@export var` 都有前置 `##` 注释

## 不做的

- 不修改注释以外的任何代码
- 不修改变量名、类型或默认值
- 不为引擎内置回调（`_ready`, `_process` 等）添加注释，除非行为不明确
- 不为显而易见的单行赋值添加注释（如 `var x := 0`）
- 不在 `@export` 变量行尾添加内联 `#` 注释 —— 始终使用前置 `##`
