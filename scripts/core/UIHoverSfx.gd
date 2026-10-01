extends Node
## Global UI sound effects (autoload: UIHoverSfx).
## Plays a short hover tick when the mouse enters any BaseButton anywhere in
## the UI, and a click effect when a BaseButton is pressed inside the click
## zone (the main menu screens).
## Screens opt out per button ancestor:
##   SUPPRESS_ALL_GROUP   - no hover tick and no click (deck builder)
##   SUPPRESS_CLICK_GROUP - click only; hover tick still plays (match UI)
## Both players route to the "SFX" bus and saved Master/Music/SFX volumes are
## applied on startup via AudioSettings.

const AudioSettingsScript := preload("res://scripts/core/AudioSettings.gd")

const HOVER_SFX_STREAM := preload("res://audio/ui_hover.mp3")
const CLICK_SFX_STREAM := preload("res://audio/ui_click.mp3")
const HOVER_VOLUME_DB := -12.0
const CLICK_VOLUME_DB := -3.0
const SFX_BUS_NAME := "SFX"
const SUPPRESS_ALL_GROUP := "ui_hover_sfx_suppress_all"
const SUPPRESS_CLICK_GROUP := "ui_hover_sfx_suppress_click"
const CLICK_ZONE_GROUP := "ui_hover_sfx_click_zone"

var _player: AudioStreamPlayer
var _click_player: AudioStreamPlayer

func _ready() -> void:
	AudioSettingsScript.apply_saved_volumes()
	_player = AudioStreamPlayer.new()
	_player.stream = HOVER_SFX_STREAM
	_player.volume_db = HOVER_VOLUME_DB
	_player.bus = SFX_BUS_NAME
	add_child(_player)
	_click_player = AudioStreamPlayer.new()
	_click_player.stream = CLICK_SFX_STREAM
	_click_player.volume_db = CLICK_VOLUME_DB
	_click_player.bus = SFX_BUS_NAME
	add_child(_click_player)
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		if not node.mouse_entered.is_connected(_on_button_hovered):
			node.mouse_entered.connect(_on_button_hovered.bind(node))
		if not node.pressed.is_connected(_on_button_pressed):
			node.pressed.connect(_on_button_pressed.bind(node))

func _on_button_hovered(button: BaseButton) -> void:
	if button.disabled or _has_grouped_ancestor(button, SUPPRESS_ALL_GROUP):
		return
	_play_hover()

func _on_button_pressed(button: BaseButton) -> void:
	if _has_grouped_ancestor(button, SUPPRESS_ALL_GROUP):
		return
	if _has_grouped_ancestor(button, SUPPRESS_CLICK_GROUP):
		return
	if _has_grouped_ancestor(button, CLICK_ZONE_GROUP):
		_play_click()

func _has_grouped_ancestor(node: Node, group: String) -> bool:
	var current := node
	while current != null:
		if current.is_in_group(group):
			return true
		current = current.get_parent()
	return false

func _play_hover() -> void:
	_player.play()

func _play_click() -> void:
	_click_player.play()
