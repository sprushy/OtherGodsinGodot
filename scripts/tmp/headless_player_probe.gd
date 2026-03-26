extends SceneTree

const PlayerScript = preload("res://scripts/Other/player.gd")

func _init() -> void:
	var player = PlayerScript.new()
	player._initialize_zones()
	print("headless_player_probe: PASS %d %d" % [player.frontline_zones.size(), player.reserve_zones.size()])
	quit()
