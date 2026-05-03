extends AudioStreamPlayer
class_name PowerUnlockSoundPlayer

const UNLOCK_SOUNDS: Array[AudioStream] = [
	preload("res://audio/power_unlock_01.wav"),
]

var _sound_index := 0

static func play_sequence() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var player := PowerUnlockSoundPlayer.new()
	tree.root.add_child(player)
	player._play_next()

func _ready() -> void:
	finished.connect(_on_finished)

func _play_next() -> void:
	if _sound_index >= UNLOCK_SOUNDS.size():
		queue_free()
		return
	stream = UNLOCK_SOUNDS[_sound_index]
	_sound_index += 1
	play()

func _on_finished() -> void:
	_play_next()
