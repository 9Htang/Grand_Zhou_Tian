# ============================================================
# 大周天 — ArtifactService (法宝域)
# 职责: 获得法宝/获得金币
# ============================================================
class_name ArtifactService
extends RefCounted


var _ctx: EffectContext = null


func gain_artifact(artifact_id: String) -> void:
	var target: Node = _ctx.actor
	if target == null:
		return
	if artifact_id == "random" and target.has_method("gain_random_artifact"):
		target.gain_random_artifact()
	elif target.has_method("gain_artifact"):
		target.gain_artifact(artifact_id)
