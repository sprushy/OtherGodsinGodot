extends AudioStreamPlayer
class_name CreatureDeathSoundPlayer

const SOUND: AudioStream = preload("res://audio/creature_death.ogg")

static func play_sound() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var player := CreatureDeathSoundPlayer.new()
	tree.root.add_child(player)
	player.stream = SOUND
	player.play()

func _ready() -> void:
	bus = "SFX"
	finished.connect(queue_free)
