extends AudioStreamPlayer
class_name LocustSwarmSoundPlayer

const SOUND: AudioStream = preload("res://audio/locust_swarm.wav")

static func play_sound() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var player := LocustSwarmSoundPlayer.new()
	tree.root.add_child(player)
	player.play_once()

func _ready() -> void:
	finished.connect(queue_free)

func play_once() -> void:
	stream = SOUND
	play()
