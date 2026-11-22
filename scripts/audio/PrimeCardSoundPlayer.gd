extends AudioStreamPlayer
class_name PrimeCardSoundPlayer

# User-provided sound effect for priming a card (setting it as the known top of the deck).
const SOUND_PATH := "res://audio/prime.ogg"

static var _sound: AudioStream

static func play_sound() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _sound == null:
		_sound = load(SOUND_PATH) as AudioStream
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var player := PrimeCardSoundPlayer.new()
	tree.root.add_child(player)
	player.stream = _sound
	player.play()

func _ready() -> void:
	bus = "SFX"
	finished.connect(queue_free)
