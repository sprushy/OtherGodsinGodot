extends AudioStreamPlayer
class_name AttackSoundPlayer

const QUICK_SOUND: AudioStream = preload("res://audio/attack_quick.ogg")
const STRONG_SOUND: AudioStream = preload("res://audio/attack_strong.ogg")

static func play_sound(strong: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var player := AttackSoundPlayer.new()
	tree.root.add_child(player)
	player.stream = STRONG_SOUND if strong else QUICK_SOUND
	player.play()

func _ready() -> void:
	bus = "SFX"
	finished.connect(queue_free)
