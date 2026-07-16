class_name SnowV2WeatherController
extends CanvasLayer

const CONTROL_GROUP := "other_gods_snowstorm_control"
const CARD_WEATHER_GROUP := "snow_v2_card_weather"
const SCREEN_OVERLAY_SCRIPT := preload("res://scripts/fx/SnowV2ScreenOverlay.gd")
const SNOWFLAKE_TEXTURE_PATH := "res://images/fx/snow_v2/snowflake.png"
const PAINTBRUSH_TEXTURE_PATH := "res://images/fx/snow_v2/snow_paintbrush.png"
const FLAKE_ATLAS_TEXTURE_PATH := "res://images/fx/snow_v2/flake_particle_atlas.png"
const WIND_WISP_TEXTURE_PATH := "res://images/fx/snow_v2/wind_wisps_overlay.png"
const SCREEN_WEATHER_LAYER := 150

var strength_variation: float = 0.0
var accumulation: float = 0.0
var wind_direction: Vector2 = Vector2(-1.0, 0.18)
var wind_force: float = 1.0

var _base_strength: float = 0.0
var _active: bool = false
var _screen_overlay: Control = null
var _world_root: Node3D = null
var _world_particles: GPUParticles3D = null
var _card_sync_elapsed: float = 999.0
var _variation_time: float = 0.0
var _snowflake_texture: Texture2D = null
var _paintbrush_texture: Texture2D = null
var _flake_atlas_texture: Texture2D = null
var _wind_wisp_texture: Texture2D = null

func _ready() -> void:
	layer = SCREEN_WEATHER_LAYER
	visible = false
	add_to_group(CONTROL_GROUP)
	_snowflake_texture = load(SNOWFLAKE_TEXTURE_PATH) as Texture2D
	_paintbrush_texture = load(PAINTBRUSH_TEXTURE_PATH) as Texture2D
	_flake_atlas_texture = load(FLAKE_ATLAS_TEXTURE_PATH) as Texture2D
	_wind_wisp_texture = load(WIND_WISP_TEXTURE_PATH) as Texture2D
	_build_screen_overlay()
	set_process(false)

func attach_3d_world(world_root: Node3D) -> void:
	if world_root == null:
		return
	_build_world_snow(world_root)
	_apply_weather()

func set_snowstorm_profile(
	base_strength: float,
	variation: float = 0.0,
	snow_accumulation: float = 0.0,
	new_wind_direction: Vector2 = Vector2(-1.0, 0.18),
	new_wind_force: float = 1.0
) -> void:
	_base_strength = clampf(base_strength, 0.0, 1.0)
	strength_variation = clampf(variation, 0.0, 0.45)
	accumulation = clampf(snow_accumulation, 0.0, 1.0)
	if new_wind_direction.length_squared() > 0.001:
		wind_direction = new_wind_direction.normalized()
	wind_force = clampf(new_wind_force, 0.0, 4.0)
	set_snowstorm_active(_base_strength > 0.01)

func set_snowstorm_active(active: bool) -> void:
	_active = active
	visible = _active
	set_process(_active)
	if _world_root != null and is_instance_valid(_world_root):
		_world_root.visible = _active
	if _world_particles != null and is_instance_valid(_world_particles):
		_world_particles.emitting = _active
	_apply_weather()
	if _active:
		_sync_card_overlays(_current_strength())
	else:
		_sync_card_overlays(0.0)

func _process(delta: float) -> void:
	_variation_time += delta
	_card_sync_elapsed += delta
	_apply_weather()
	if _card_sync_elapsed >= 0.45:
		_card_sync_elapsed = 0.0
		_sync_card_overlays(_current_strength())

func _build_screen_overlay() -> void:
	_screen_overlay = SCREEN_OVERLAY_SCRIPT.new()
	_screen_overlay.name = "SnowV2ScreenOverlay"
	_screen_overlay.snowflake_texture = _snowflake_texture
	_screen_overlay.paintbrush_texture = _paintbrush_texture
	_screen_overlay.flake_atlas_texture = _flake_atlas_texture
	_screen_overlay.wind_wisp_texture = _wind_wisp_texture
	add_child(_screen_overlay)

func _build_world_snow(world_root: Node3D) -> void:
	if _world_root != null and is_instance_valid(_world_root):
		return
	_world_root = Node3D.new()
	_world_root.name = "SnowV2WorldFX"
	_world_root.visible = false
	world_root.add_child(_world_root)

	_world_particles = GPUParticles3D.new()
	_world_particles.name = "SnowV2Air"
	_world_particles.amount = 120
	_world_particles.lifetime = 5.5
	_world_particles.emitting = false
	_world_particles.position = Vector3(0.0, 3.1, 5.7)
	_world_particles.visibility_aabb = AABB(Vector3(-16.0, -8.0, -8.0), Vector3(32.0, 16.0, 18.0))

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(10.5, 2.6, 2.0)
	process_material.direction = Vector3(0.0, -1.0, 0.0)
	process_material.spread = 7.0
	process_material.initial_velocity_min = 0.35
	process_material.initial_velocity_max = 1.15
	process_material.gravity = Vector3(wind_direction.x * 0.7, -1.45, wind_direction.y * 0.2)
	process_material.scale_min = 0.018
	process_material.scale_max = 0.055
	process_material.angular_velocity_min = -90.0
	process_material.angular_velocity_max = 90.0
	process_material.color = Color(0.90, 0.96, 1.0, 0.72)
	_world_particles.process_material = process_material

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = _snowflake_texture
	material.albedo_color = Color(0.90, 0.96, 1.0, 0.72)
	quad.material = material
	_world_particles.draw_pass_1 = quad
	_world_root.add_child(_world_particles)
	_add_world_snow_piles()

func _add_world_snow_piles() -> void:
	if _world_root == null or _paintbrush_texture == null:
		return
	for i in range(7):
		var pile := MeshInstance3D.new()
		pile.name = "SnowV2Pile%d" % i
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(1.7 + float(i % 3) * 0.35, 0.42 + float(i % 2) * 0.16)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_texture = _paintbrush_texture
		material.albedo_color = Color(0.92, 0.97, 1.0, 0.10)
		mesh.material = material
		pile.mesh = mesh
		pile.position = Vector3(-5.5 + float(i) * 1.85, -2.66, -2.42 + float(i % 2) * 0.25)
		pile.rotation_degrees.x = -90.0
		_world_root.add_child(pile)

func _apply_weather() -> void:
	var current_strength := _current_strength()
	if _screen_overlay != null and is_instance_valid(_screen_overlay):
		_screen_overlay.call("set_weather", _active, current_strength, wind_direction, wind_force)
	if _world_particles != null and is_instance_valid(_world_particles):
		_world_particles.amount = int(round(lerpf(120.0, 480.0, current_strength)))
		var process_material := _world_particles.process_material as ParticleProcessMaterial
		if process_material != null:
			process_material.gravity = Vector3(wind_direction.x * wind_force * 0.65, -1.45, wind_direction.y * wind_force * 0.18)
			process_material.initial_velocity_min = 0.25 + current_strength * 0.18
			process_material.initial_velocity_max = 0.75 + current_strength * 0.85
			process_material.color = Color(0.90, 0.96, 1.0, 0.38 + current_strength * 0.42)

func _current_strength() -> float:
	if not _active:
		return 0.0
	var wave := 0.0
	if strength_variation > 0.001:
		wave = sin(_variation_time * 0.75) * strength_variation
	return clampf(_base_strength + wave, 0.0, 1.0)

func _sync_card_overlays(current_strength: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.call_group(CARD_WEATHER_GROUP, "set_snow_v2_weather", _active, current_strength, wind_direction, wind_force)
