extends RefCounted
## Shared audio volume settings helper.
## Master/Music/SFX bus volumes are stored as floats 0..1 in the "audio"
## section of the user settings file and applied straight to the AudioServer,
## so the main menu and the in-match pause settings stay in sync.

const SETTINGS_SECTION := "audio"
const MASTER_VOLUME_KEY := "master_volume"
const MUSIC_VOLUME_KEY := "music_volume"
const EFFECTS_VOLUME_KEY := "effects_volume"
const MASTER_BUS_NAME := "Master"
const MUSIC_BUS_NAME := "Music"
const SFX_BUS_NAME := "SFX"
const DEFAULT_SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_VOLUME := 1.0

const VOLUME_KEYS: Array[String] = [MASTER_VOLUME_KEY, MUSIC_VOLUME_KEY, EFFECTS_VOLUME_KEY]

static func is_volume_key(key: String) -> bool:
	return key in VOLUME_KEYS

static func get_volume(key: String, settings_path: String = DEFAULT_SETTINGS_PATH) -> float:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return DEFAULT_VOLUME
	return clampf(float(config.get_value(SETTINGS_SECTION, key, DEFAULT_VOLUME)), 0.0, 1.0)

static func set_volume(key: String, value: float, settings_path: String = DEFAULT_SETTINGS_PATH) -> void:
	var clamped_volume := clampf(value, 0.0, 1.0)
	_apply_bus_volume(key, clamped_volume)
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value(SETTINGS_SECTION, key, clamped_volume)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Could not save audio volume setting %s: %s" % [key, str(error)])

static func apply_saved_volumes(settings_path: String = DEFAULT_SETTINGS_PATH) -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	for key in VOLUME_KEYS:
		_apply_bus_volume(key, clampf(float(config.get_value(SETTINGS_SECTION, key, DEFAULT_VOLUME)), 0.0, 1.0))

static func _apply_bus_volume(key: String, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(_bus_name_for_key(key))
	if bus_index < 0:
		return
	# Volume only: never touch bus mute flags, the mute toggles own those.
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear_volume, 0.0001)))

static func _bus_name_for_key(key: String) -> String:
	if key == MUSIC_VOLUME_KEY:
		return MUSIC_BUS_NAME
	if key == EFFECTS_VOLUME_KEY:
		return SFX_BUS_NAME
	return MASTER_BUS_NAME
