# M3 — 地图流程系统 (Run Flow)

> **职责**: 主菜单→起始选择→章节地图→非战斗场景（商店/休息/奇遇）→奖励/突破→结束
> **依赖**: M0（数据）、M6（GameManager 全局状态）
> **被依赖**: 无（顶层模块，不向其他模块暴露接口）

## 文件清单 (12 files)

### scenes/ — 场景脚本 (11)
```
scenes/main/main.gd                        # 根场景
scenes/menu/main_menu.gd                   # 标题画面
scenes/run_start/run_start_screen.gd       # 起始功法3选1+起始牌组
scenes/chapter_map/chapter_map.gd          # 章节地图（网状6列×双Boss）
scenes/shop/shop_screen.gd                 # 商店（卡牌/丹药购买+治疗+移除卡牌）
scenes/rest/rest_screen.gd                 # 休息（回血30%+修复经脉+冥想+2起始灵气）
scenes/event/event_screen.gd               # 奇遇（3个内置事件+打字机叙事+多选项+条件检查）
scenes/reward/reward_screen.gd             # 3选1奖励
scenes/breakthrough/breakthrough_screen.gd # 突破抽卡（3选1）
scenes/story/story_screen.gd               # 剧情打字机
scenes/game_over/game_over_screen.gd       # 结束画面
```

### autoload/ — 场景管理器 (1)
```
autoload/scene_manager.gd                  # SceneManager: 场景过渡 (CanvasLayer)
```

## 流程架构

```
MainMenu (标题)
    │
    ▼
RunStartScreen (起始功法3选1)
    │
    ▼
ChapterMap (网状地图: 6列×3-4行×16节点)
    │
    ├─ 战斗节点 → BattleScreen (M2) [战斗结束自动返回地图]
    ├─ 商店节点 → ShopScreen
    ├─ 休息节点 → RestScreen
    ├─ 奇遇节点 → EventScreen
    ├─ Boss节点 → BattleScreen (M2)
    │
    ▼
RewardScreen (3选1奖励)
    │
    ▼
BreakthroughScreen (境界突破抽卡，修为满触发)
    │
    ▼
GameOverScreen (通关/死亡)
```

## 对外接口

```gdscript
# SceneManager (autoload)
SceneManager.change_scene(to: String)                    # 场景过渡
SceneManager.change_scene_with_data(to: String, data: Dictionary)

# 场景间通过 GameManager 属性通信：
GameManager.player_hp / gold / realm / cultivation
GameManager.current_chapter: ChapterData
GameManager.current_map_node: MapNodeData
```

## 地图节点类型

```
⚔ BATTLE / 💀 ELITE / 🔥 REST / 💰 SHOP / ? EVENT / ☠ BOSS
```

## 交互规则

- 亮色节点 = 可从当前节点到达
- 暗色节点 = 未解锁
- 灰色节点 = 已访问
- 金色连线 = 当前可选路径
- 战斗胜利后自动返回地图选择下一节点

## 关键设计决策

- **网状地图**: 6列×3-4行，16节点，2个可选Boss
- **商店按稀有度定价** — 卡牌/丹药价格基于 CardData.rarity
- **休息冥想** — +2起始灵气 buff
- **奇遇条件检查** — 支持属性/物品/buff 条件判断
- **突破抽卡制** — 修为满后触发，从卡池抽3选1
- **场景独立** — 每个场景自成一体，不引用其他场景的脚本

## 修改本模块的影响

- 各场景独立，修改一个不影响其他
- 添加新场景需在 SceneManager 注册 + ChapterMap 加节点类型
- 布局使用了 UIHelpers（M5），修改布局时注意视口百分比
