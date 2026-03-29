extends SceneTree

func _initialize() -> void:
	var script_paths := [
		"res://scripts/server/PromptRouter.gd",
		"res://scripts/server/HeadlessMatchHost.gd",
		"res://scripts/client/MatchClient.gd",
		"res://scripts/Other/GameEventBroadcaster.gd",
		"res://scripts/Other/CombatMockGame.gd",
	]

	for path in script_paths:
		var script := load(path)
		if script == null:
			push_error("phase1_architecture_probe: failed to load %s" % path)
			quit(1)
			return

	print("phase1_architecture_probe: PASS")
	quit()
