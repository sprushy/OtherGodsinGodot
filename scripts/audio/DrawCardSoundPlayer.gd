extends AudioStreamPlayer
class_name DrawCardSoundPlayer

# User-provided sound effect for drawing a card from the deck.
const SOUND_PATH := "res://audio/draw.ogg"

static var _sound: AudioStream

static func play_sound() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _sound == null:
		_sound = load(SOUND_PATH) as AudioStream
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var player := DrawCardSoundPlayer.new()
	tree.root.add_child(player)
	player.stream = _sound
	player.play()

func _ready() -> void:
	bus = "SFX"
	finished.connect(queue_free)
