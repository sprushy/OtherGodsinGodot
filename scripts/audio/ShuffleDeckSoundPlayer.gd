extends AudioStreamPlayer
class_name ShuffleDeckSoundPlayer

# User-provided sound effects for shuffling the deck. One is chosen at random each play.
const SHUFFLE_1_PATH := "res://audio/shuffle_1.ogg"
const SHUFFLE_2_PATH := "res://audio/shuffle_2.ogg"

static var _sound_1: AudioStream
static var _sound_2: AudioStream

static func play_sound() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _sound_1 == null:
		_sound_1 = load(SHUFFLE_1_PATH) as AudioStream
	if _sound_2 == null:
		_sound_2 = load(SHUFFLE_2_PATH) as AudioStream
	var sound := _sound_1 if randf() < 0.5 else _sound_2
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var player := ShuffleDeckSoundPlayer.new()
	tree.root.add_child(player)
	player.stream = sound
	player.play()

func _ready() -> void:
	bus = "SFX"
	finished.connect(queue_free)
