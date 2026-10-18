extends AudioStreamPlayer
class_name MatchStartSoundPlayer

# User-provided rlxmusic24-relaxing-music-original-viking-attacking-battle-horn-116623.mp3.
const SOUND: AudioStream = preload("res://audio/match_start_horn.mp3")
const PLAYBACK_DURATION_SECONDS := 4.2

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
	var cutoff := Timer.new()
	cutoff.one_shot = true
	cutoff.wait_time = PLAYBACK_DURATION_SECONDS
	cutoff.ignore_time_scale = true
	cutoff.process_mode = Node.PROCESS_MODE_ALWAYS
	cutoff.timeout.connect(player.stop)
	cutoff.timeout.connect(player.queue_free)
	player.add_child(cutoff)
	cutoff.start()
