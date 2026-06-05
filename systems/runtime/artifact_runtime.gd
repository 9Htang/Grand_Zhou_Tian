# ============================================================
# 大周天 — ArtifactRuntime
# 法宝/装备/奇物状态纯容器 — 不包含任何业务逻辑
# ============================================================
class_name ArtifactRuntime
extends RefCounted


## 法宝列表
var artifacts: Array[ArtifactData] = []

## 装备 {slot: EquipmentData}
var equipment: Dictionary = {}

## 奇物列表
var curios: Array[CurioData] = []


## 从 GameManager 复制
func copy_from(gm: Node) -> void:
	var arts = gm.get("artifacts")
	artifacts = (arts if arts != null else []).duplicate()


func clone() -> ArtifactRuntime:
	var rt: ArtifactRuntime = ArtifactRuntime.new()
	rt.artifacts = artifacts.duplicate()
	rt.equipment = equipment.duplicate()
	rt.curios = curios.duplicate()
	return rt
