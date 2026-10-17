extends AudioStreamPlayer
class_name MatchStartSoundPlayer

# User-provided rlxmusic24-relaxing-music-original-viking-attacking-battle-horn-116623.mp3.
const SOUND: AudioStream = preload("res://audio/match_start_horn.mp3")

static func play_sound() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.finished.connect(player.queue_free)
	tree.root.add_child(player)
	player.stream = SOUND
	player.play()
