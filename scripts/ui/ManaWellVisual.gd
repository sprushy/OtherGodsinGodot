@tool
extends TextureRect
class_name ManaWellVisual

enum WellState { CLOSED, OPEN, ACTIVATED }

const CLOSED_TEXTURE := preload("res://images/ui/zones/mana_well_story_snow_hatch_closed_v2.png")
const OPEN_TEXTURE := preload("res://images/ui/zones/mana_well_story_snow_hatch_open_v2.png")
const ACTIVE_TEXTURE := preload("res://images/ui/zones/mana_well_story_snow_activated_hatch.png")
const NORMAL_CLOSED_TEXTURE := preload("res://images/ui/zones/mana_well_ancient_high_angle_closed.png")
const NORMAL_OPEN_TEXTURE := preload("res://images/ui/zones/mana_well_ancient_high_angle.png")
const WELL_SHADER := preload("res://shaders/ui/mana_well.gdshader")

@export var snow_style: bool = true:
	set(value):
		if snow_style == value:
			return
		snow_style = value
		if is_node_ready():
			_apply_state()

@export var state: WellState = WellState.ACTIVATED:
	set(value):
		state = value
		if is_node_ready():
			_apply_state()

@export_range(0.0, 4.0, 0.05) var animation_speed: float = 1.0

@export_range(-2.0, 2.0, 0.05) var swirl_speed: float = 0.55:
	set(value):
		swirl_speed = value
		if _well_material != null:
			_well_material.set_shader_parameter("swirl_speed", swirl_speed)

@export_range(0.0, 1.0, 0.01) var steam_strength: float = 0.36:
	set(value):
		steam_strength = value
		if _well_material != null:
			_well_material.set_shader_parameter("steam_strength", steam_strength)

var _well_material: ShaderMaterial
var _effect_time: float = 0.0


func _ready() -> void:
	# Each instance has its own clock and activation state.
	_well_material = ShaderMaterial.new()
	_well_material.shader = WELL_SHADER
	_well_material.set_shader_parameter("swirl_speed", swirl_speed)
	_well_material.set_shader_parameter("steam_strength", steam_strength)
	material = _well_material
	_apply_state()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_effect_time += delta * animation_speed
	_well_material.set_shader_parameter("effect_time", _effect_time)


func set_activated(enabled: bool) -> void:
	state = WellState.ACTIVATED if enabled else WellState.OPEN


func _apply_state() -> void:
	match state:
		WellState.CLOSED:
			texture = CLOSED_TEXTURE if snow_style else NORMAL_CLOSED_TEXTURE
		WellState.OPEN:
			# Uncovered means the hatch is still attached and folded fully back.
			texture = OPEN_TEXTURE if snow_style else NORMAL_OPEN_TEXTURE
		WellState.ACTIVATED:
			texture = ACTIVE_TEXTURE if snow_style else NORMAL_OPEN_TEXTURE
	# The normal well animates its own pool rather than using the snowy pool's UVs.
	_well_material.set_shader_parameter("pool_center", Vector2(0.503, 0.630) if snow_style else Vector2(0.48, 0.47))
	_well_material.set_shader_parameter("pool_radius", Vector2(0.188, 0.148) if snow_style else Vector2(0.25, 0.24))
	var activated := state == WellState.ACTIVATED
	_well_material.set_shader_parameter("activity", 1.0 if activated else 0.0)
	_well_material.set_shader_parameter("effect_time", _effect_time)
	set_process(activated)
