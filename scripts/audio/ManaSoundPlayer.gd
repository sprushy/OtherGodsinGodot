extends AudioStreamPlayer
class_name ManaSoundPlayer

const GAIN_SOUND_PATH := "res://audio/mana_gain.ogg"
const SPEND_SOUND_PATH := "res://audio/mana_spend.ogg"

static func play_gain(amount: int) -> void:
	if amount <= 0:
		return
	var intensity := clampf(log(float(amount)) / log(8.0), 0.0, 1.0)
	_play_sound(GAIN_SOUND_PATH, lerpf(-6.0, -2.0, intensity))

static func play_spend() -> void:
	_play_sound(SPEND_SOUND_PATH, -4.0)

static func _play_sound(sound_path: String, volume: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var player := ManaSoundPlayer.new()
	tree.root.add_child(player)
	player.stream = load(sound_path) as AudioStream
	player.volume_db = volume
	player.play()

func _ready() -> void:
	bus = "SFX"
	finished.connect(queue_free)
