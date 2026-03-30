extends SceneTree

const MAIN_MENU_SCRIPT = preload("res://scripts/Other/MainMenu.gd")
const MAIN_SCENE = preload("res://scenes/mainfork.tscn")

func _initialize() -> void:
	var scene = MAIN_SCENE
	if scene == null:
		push_error("multiplayer_menu_probe: could not load mainfork.tscn")
		quit(1)
		return
	var instance = scene.instantiate()
	if instance == null:
		push_error("multiplayer_menu_probe: could not instantiate main scene")
		quit(1)
		return
	get_root().add_child(instance)
	process_frame.connect(_finish_probe, CONNECT_ONE_SHOT)

func _finish_probe() -> void:
	print("multiplayer_menu_probe: PASS")
	quit()
