extends AudioStreamPlayer
class_name CreatureDeathSoundPlayer

const SOUND: AudioStream = preload("res://audio/creature_death.ogg")

static func play_sound(was_aerial: bool = false) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var player := CreatureDeathSoundPlayer.new()
	tree.root.add_child(player)
	player.stream = SOUND
	player.play()
	if not was_aerial:
		var cutoff := player.create_tween()
		cutoff.tween_interval(1.0)
		cutoff.tween_callback(player.stop)
		cutoff.tween_callback(player.queue_free)

func _ready() -> void:
	bus = "SFX"
	finished.connect(queue_free)
