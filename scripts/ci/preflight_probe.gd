extends SceneTree

const PreflightProbeScript = preload("res://scripts/ci/PreflightProbe.gd")

func _init() -> void:
	var probe = PreflightProbeScript.new()
	var success := probe.run()
	quit(0 if success else 1)

func _initialize() -> void:
	pass
