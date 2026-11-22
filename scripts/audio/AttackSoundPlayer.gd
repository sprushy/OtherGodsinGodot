extends AudioStreamPlayer
class_name AttackSoundPlayer

const QUICK_SOUND_PATH := "res://audio/attack_quick.ogg"
const STRONG_SOUND_PATH := "res://audio/attack_strong.ogg"

static var _quick_sound: AudioStream
static var _strong_sound: AudioStream

static func play_sound(strong: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if strong and _strong_sound == null:
		_strong_sound = load(STRONG_SOUND_PATH) as AudioStream
	elif not strong and _quick_sound == null:
		_quick_sound = load(QUICK_SOUND_PATH) as AudioStream
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var player := AttackSoundPlayer.new()
	tree.root.add_child(player)
	player.stream = _strong_sound if strong else _quick_sound
	player.play()

func _ready() -> void:
	bus = "SFX"
	finished.connect(queue_free)
