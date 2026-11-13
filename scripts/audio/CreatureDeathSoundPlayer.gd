extends AudioStreamPlayer
class_name CreatureDeathSoundPlayer

const SOUND_PATH := "res://audio/creature_death.ogg"

static var _sound: AudioStream

static func play_sound(was_aerial: bool = false) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _sound == null:
		_sound = load(SOUND_PATH) as AudioStream
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var player := CreatureDeathSoundPlayer.new()
	tree.root.add_child(player)
	player.stream = _sound
	player.play()
	if not was_aerial:
		var cutoff := player.create_tween()
		cutoff.tween_interval(1.0)
		cutoff.tween_callback(player.stop)
		cutoff.tween_callback(player.queue_free)

func _ready() -> void:
	bus = "SFX"
	finished.connect(queue_free)
