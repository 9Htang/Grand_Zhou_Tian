# ============================================================
# 大周天 — ShopData Resource
# ============================================================
@tool
class_name ShopData
extends Resource

# === 基础信息 ===

## 商店唯一标识符
@export var id: String = ""

## 商店显示名称，展示在地图节点和商店界面标题栏
@export var display_name: String = "流浪商人"

# === 商品池 ===

## 可出售的卡牌 ID 池，从池中随机抽取 card_count 张
@export var card_pool: Array[String] = []

## 可出售的丹药 ID 池，从池中随机抽取 elixir_count 个
@export var elixir_pool: Array[String] = []

## 可出售的法宝 ID 池，从池中随机抽取
@export var artifact_pool: Array[String] = []

# === 商品数量 ===

## 商店每次刷新出售的卡牌数量
@export var card_count: int = 3

## 商店每次刷新出售的丹药数量
@export var elixir_count: int = 2

# === 服务价格 ===

## 恢复服务价格（灵石），购买后恢复 30% 最大生命值
@export var heal_cost: int = 30

## 移除卡牌服务价格（灵石），从牌库中永久删除一张卡牌
@export var remove_card_cost: int = 50
