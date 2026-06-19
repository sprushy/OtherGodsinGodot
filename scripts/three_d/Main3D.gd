extends Node3D

const WindowsSelfUpdaterScript = preload("res://scripts/client/WindowsSelfUpdater.gd")
const GAME_SCENE_PATH := "res://scenes/mainfork.tscn"
const DEFAULT_VIEWPORT_SIZE := Vector2i(2560, 1440)
const SERVER_MODE_ARG := "server_mode"
const MATCH_CONFIG_ARG := "match_config"
const STEALTH_FOG_CURSOR_LEAD_SECONDS := 0.055
const STEALTH_FOG_CURSOR_MAX_LEAD_PIXELS := 86.0
const STEALTH_FOG_CURSOR_REFERENCE_SECONDS := 0.018
const STEALTH_FOG_CURSOR_MAX_WIND_PIXELS := 96.0
const STEALTH_FOG_SMOKE_TEXTURE_PATH := "res://images/ui/stealth_fog/lelu_smoke_b7.png"
const STEALTH_FOG_CLOUD_TEXTURE_PATH := "res://images/ui/stealth_fog/lelu_cloud_noise_tiled.png"
const STEALTH_FOG_DETAIL_TEXTURE_PATH := "res://images/ui/stealth_fog/seamless_noise_02.png"

@export var game_scene_path: String = GAME_SCENE_PATH
@export var game_viewport_size: Vector2i = DEFAULT_VIEWPORT_SIZE
@export var screen_size: Vector2 = Vector2(18.4, 10.35)
@export var screen_tilt_degrees: float = 0.0
@export var use_flat_match_view: bool = false
@export var show_stealth_fog_3d: bool = true

var _game_viewport: SubViewport = null
var _game_instance: Node = null
var _three_d_world: Node3D = null
var _flat_canvas_layer: CanvasLayer = null
var _screen_rig: Node3D = null
var _screen_mesh: MeshInstance3D = null
var _stealth_fog_root: Node3D = null
var _camera: Camera3D = null
var _last_game_mouse_position: Vector2 = Vector2.INF
var _is_flat_2d_mode: bool = false
var _stealth_fog_emitters: Dictionary = {}
var _stealth_fog_textures: Array[Texture2D] = []
var _stealth_fog_smoke_texture: Texture2D = null
var _stealth_fog_cloud_texture: Texture2D = null
var _stealth_fog_detail_texture: Texture2D = null
var _stealth_fog_control_rects: Dictionary = {}
var _stealth_fog_refresh_elapsed: float = 999.0
var _stealth_fog_motion_elapsed: float = 0.0
var _screen_world_height: float = 0.0
var _fog_cursor_actual_position: Vector2 = Vector2.INF
var _fog_cursor_position: Vector2 = Vector2.INF
var _fog_cursor_velocity: Vector2 = Vector2.ZERO
var _fog_cursor_wind: Vector2 = Vector2.ZERO

func _ready() -> void:
	var launch_args := _parse_user_args(OS.get_cmdline_user_args())
	if WindowsSelfUpdaterScript.is_update_launch(launch_args):
		var updater := WindowsSelfUpdaterScript.new()
		add_child(updater)
		updater.start(launch_args)
		return
	if _should_boot_server_runtime(launch_args):
		_load_original_scene_directly()
		return

	_build_3d_shell()
	_load_game_into_viewport()
	call_deferred("_refresh_display_mode")

func _build_3d_shell() -> void:
	_screen_world_height = screen_size.y
	_game_viewport = SubViewport.new()
	_game_viewport.name = "GameViewport"
	_game_viewport.size = game_viewport_size
	_game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_game_viewport)

	_three_d_world = Node3D.new()
	_three_d_world.name = "ThreeDWorld"
	add_child(_three_d_world)

	_build_environment()
	_build_game_screen()
	_build_camera()
	_build_lighting()
	_build_flat_canvas()
	_sync_3d_display_to_window()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.015, 0.018, 0.024)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.54, 0.62, 0.70)
	environment.ambient_light_energy = 0.45
	_configure_volumetric_fog_environment(environment)
	world_environment.environment = environment
	_three_d_world.add_child(world_environment)

func _configure_volumetric_fog_environment(environment: Environment) -> void:
	if environment == null:
		return
	environment.set("volumetric_fog_enabled", true)
	environment.set("volumetric_fog_density", 0.0008)
	environment.set("volumetric_fog_albedo", Color(0.10, 0.10, 0.12))
	environment.set("volumetric_fog_emission", Color(0.0, 0.0, 0.0))
	environment.set("volumetric_fog_length", 18.0)
	environment.set("volumetric_fog_detail_spread", 2.0)

func _build_table() -> void:
	var floor_mesh := _make_box(
		"StoneFloor",
		Vector3(26.0, 0.16, 18.0),
		Vector3(0.0, -3.05, -1.0),
		Color(0.09, 0.10, 0.115)
	)
	_three_d_world.add_child(floor_mesh)

	var table := _make_box(
		"GameTable",
		Vector3(20.2, 0.34, 6.8),
		Vector3(0.0, -2.86, 0.35),
		Color(0.18, 0.12, 0.075)
	)
	_three_d_world.add_child(table)

	var rear_rail := _make_box(
		"RearTableRail",
		Vector3(20.6, 0.44, 0.28),
		Vector3(0.0, -2.34, -2.78),
		Color(0.23, 0.16, 0.10)
	)
	_three_d_world.add_child(rear_rail)

func _build_game_screen() -> void:
	var rig := Node3D.new()
	rig.name = "GameScreenRig"
	rig.position = Vector3(0.0, 1.80, 0.0)
	rig.rotation_degrees.x = screen_tilt_degrees
	_three_d_world.add_child(rig)
	_screen_rig = rig

	var quad := QuadMesh.new()
	quad.size = screen_size

	_screen_mesh = MeshInstance3D.new()
	_screen_mesh.name = "InteractiveGameScreen"
	_screen_mesh.mesh = quad
	var screen_material := StandardMaterial3D.new()
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	screen_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	screen_material.albedo_texture = _game_viewport.get_texture()
	_screen_mesh.material_override = screen_material
	rig.add_child(_screen_mesh)

	_stealth_fog_root = Node3D.new()
	_stealth_fog_root.name = "StealthFog3DRoot"
	_screen_mesh.add_child(_stealth_fog_root)

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "MainCamera3D"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = screen_size.y
	_camera.position = Vector3(0.0, 1.80, 11.35)
	_three_d_world.add_child(_camera)
	_camera.look_at(Vector3(0.0, 1.80, 0.0), Vector3.UP)
	_camera.current = true

func _build_lighting() -> void:
	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.light_energy = 2.1
	key_light.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	_three_d_world.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.name = "ScreenFillLight"
	fill_light.position = Vector3(0.0, 2.5, 5.0)
	fill_light.light_energy = 1.2
	fill_light.omni_range = 10.0
	_three_d_world.add_child(fill_light)

func _build_flat_canvas() -> void:
	_flat_canvas_layer = CanvasLayer.new()
	_flat_canvas_layer.name = "Flat2DCanvas"
	_flat_canvas_layer.layer = 100
	_flat_canvas_layer.visible = false
	add_child(_flat_canvas_layer)

func _make_box(node_name: String, box_size: Vector3, box_position: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh_instance.mesh = mesh
	mesh_instance.position = box_position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh_instance.material_override = material
	return mesh_instance

func _load_game_into_viewport() -> void:
	var scene := load(game_scene_path)
	if not (scene is PackedScene):
		push_error("Main3D: could not load embedded game scene at %s" % game_scene_path)
		return
	_game_instance = (scene as PackedScene).instantiate()
	_flat_canvas_layer.add_child(_game_instance)

func _process(delta: float) -> void:
	_sync_3d_display_to_window()
	_refresh_display_mode()
	_refresh_stealth_fog_cursor_from_window(delta)
	_stealth_fog_motion_elapsed += delta
	_stealth_fog_refresh_elapsed += delta
	if _stealth_fog_refresh_elapsed >= 0.12:
		_stealth_fog_refresh_elapsed = 0.0
		_update_stealth_fog_emitters()
	else:
		_update_existing_stealth_fog_cursor_wind()
	_animate_stealth_fog_layers()
	_decay_stealth_fog_cursor_motion(delta)

func _sync_3d_display_to_window() -> void:
	if _game_viewport == null:
		return
	var visible_size := get_viewport().get_visible_rect().size
	if visible_size.x <= 0.0 or visible_size.y <= 0.0:
		return

	var target_viewport_size := Vector2i(
		maxi(16, int(round(visible_size.x))),
		maxi(16, int(round(visible_size.y)))
	)
	if _game_viewport.size != target_viewport_size:
		_game_viewport.size = target_viewport_size
		_fit_embedded_game_to_viewport()

	var aspect := visible_size.x / visible_size.y
	var target_screen_size := Vector2(_screen_world_height * aspect, _screen_world_height)
	if not screen_size.is_equal_approx(target_screen_size):
		screen_size = target_screen_size
		var quad: QuadMesh = null
		if _screen_mesh != null:
			quad = _screen_mesh.mesh as QuadMesh
		if quad != null:
			quad.size = screen_size
		if _camera != null:
			_camera.size = screen_size.y

func _refresh_display_mode() -> void:
	var wants_flat_2d := _should_show_flat_2d()
	if wants_flat_2d == _is_flat_2d_mode and _is_game_instance_in_correct_parent():
		return
	_is_flat_2d_mode = wants_flat_2d
	_reparent_game_instance_for_display_mode()
	if _flat_canvas_layer != null:
		_flat_canvas_layer.visible = _is_flat_2d_mode
	if _three_d_world != null:
		_three_d_world.visible = not _is_flat_2d_mode
	_last_game_mouse_position = Vector2.INF
	_fit_embedded_game_to_viewport()

func _is_game_instance_in_correct_parent() -> bool:
	if _game_instance == null or not is_instance_valid(_game_instance):
		return true
	var expected_parent: Node = _flat_canvas_layer
	if not _is_flat_2d_mode:
		expected_parent = _game_viewport
	return _game_instance.get_parent() == expected_parent

func _reparent_game_instance_for_display_mode() -> void:
	if _game_instance == null or not is_instance_valid(_game_instance):
		return
	var target_parent: Node = _flat_canvas_layer
	if not _is_flat_2d_mode:
		target_parent = _game_viewport
	if target_parent == null or _game_instance.get_parent() == target_parent:
		return
	_game_instance.reparent(target_parent)

func _fit_embedded_game_to_viewport() -> void:
	var menu := _get_embedded_menu_control()
	if menu != null and menu.has_method("_fit_to_viewport"):
		menu.call("_fit_to_viewport")

func _should_show_flat_2d() -> bool:
	var menu := _get_embedded_menu_control()
	if menu == null:
		return true
	if use_flat_match_view:
		return true
	var menu_container := menu.get_node_or_null("MenuContainer") as Control
	if menu_container != null and menu_container.visible:
		return true
	var deck_builder := menu.get_node_or_null("GameContainer/DeckBuilder") as Control
	if deck_builder != null and is_instance_valid(deck_builder) and deck_builder.visible:
		return true
	var rules_overlay := menu.get_node_or_null("RulesOverlay") as Control
	if rules_overlay != null and is_instance_valid(rules_overlay):
		return true
	return false

func _update_stealth_fog_emitters() -> void:
	if _stealth_fog_root == null or not is_instance_valid(_stealth_fog_root):
		return
	if not show_stealth_fog_3d:
		_stealth_fog_root.visible = false
		_stealth_fog_control_rects.clear()
		return
	if _is_flat_2d_mode:
		_stealth_fog_root.visible = false
		_stealth_fog_control_rects.clear()
		return
	_stealth_fog_root.visible = true

	var active_keys: Dictionary = {}
	for control in _get_visible_stealth_zone_controls():
		var key := str(control.get_instance_id())
		active_keys[key] = true
		var fog_cluster := _stealth_fog_emitters.get(key, null) as Node3D
		if fog_cluster == null or not is_instance_valid(fog_cluster):
			fog_cluster = _create_stealth_fog_cluster()
			_stealth_fog_emitters[key] = fog_cluster
			_stealth_fog_root.add_child(fog_cluster)
		_place_stealth_fog_cluster(fog_cluster, control)

	for key in _stealth_fog_emitters.keys():
		if active_keys.has(key):
			continue
		var stale := _stealth_fog_emitters.get(key, null) as Node
		if stale != null and is_instance_valid(stale):
			stale.queue_free()
		_stealth_fog_emitters.erase(key)
		_stealth_fog_control_rects.erase(key)

func _update_existing_stealth_fog_cursor_wind() -> void:
	for key in _stealth_fog_emitters.keys():
		var fog_cluster := _stealth_fog_emitters.get(key, null) as Node3D
		if fog_cluster == null or not is_instance_valid(fog_cluster):
			continue
		var rect_value = _stealth_fog_control_rects.get(key, null)
		if not (rect_value is Rect2):
			continue
		_update_stealth_fog_cursor_wind(fog_cluster, rect_value)

func _animate_stealth_fog_layers() -> void:
	if _stealth_fog_emitters.is_empty():
		return
	for key in _stealth_fog_emitters.keys():
		var fog_cluster := _stealth_fog_emitters.get(key, null) as Node3D
		if fog_cluster == null or not is_instance_valid(fog_cluster):
			continue
		var mist := fog_cluster.get_node_or_null("SteadyMist") as Node3D
		if mist == null:
			continue
		var cluster_phase := float(fog_cluster.get_instance_id() % 1000) * 0.017
		for i in range(mist.get_child_count()):
			var layer := mist.get_child(i) as MeshInstance3D
			if layer == null:
				continue
			var layer_phase := cluster_phase + float(i) * 1.73
			var speed_x := 0.36 + float(i) * 0.10
			var speed_y := 0.29 + float(i) * 0.08
			var sway_x := sin(_stealth_fog_motion_elapsed * speed_x + layer_phase) * (0.070 + float(i) * 0.030)
			var sway_y := cos(_stealth_fog_motion_elapsed * speed_y + layer_phase * 0.82) * (0.052 + float(i) * 0.022)
			layer.position = Vector3(sway_x, sway_y, -0.034 + float(i) * 0.014)
			layer.rotation.z = sin(_stealth_fog_motion_elapsed * 0.24 + layer_phase) * (0.025 + float(i) * 0.014)

func _refresh_stealth_fog_cursor_from_window(delta: float) -> void:
	if _game_viewport == null or _screen_mesh == null or _camera == null or _is_flat_2d_mode:
		_clear_stealth_fog_cursor_motion()
		return
	var mapped_position = _map_window_position_to_game_viewport(get_viewport().get_mouse_position())
	if not (mapped_position is Vector2):
		_clear_stealth_fog_cursor_motion()
		return
	var game_position: Vector2 = mapped_position
	var motion_delta := Vector2.ZERO
	if _fog_cursor_actual_position != Vector2.INF:
		motion_delta = game_position - _fog_cursor_actual_position
	_update_stealth_fog_cursor_motion(game_position, motion_delta, delta)

func _update_stealth_fog_cursor_motion(game_position: Vector2, motion_delta: Vector2, delta: float) -> void:
	_fog_cursor_actual_position = game_position
	if motion_delta.length_squared() > 0.01:
		_fog_cursor_velocity = motion_delta / maxf(delta, 0.001)
	_apply_stealth_fog_cursor_prediction()

func _apply_stealth_fog_cursor_prediction() -> void:
	if _fog_cursor_actual_position == Vector2.INF:
		_fog_cursor_position = Vector2.INF
		_fog_cursor_wind = Vector2.ZERO
		return
	var lead := _fog_cursor_velocity * STEALTH_FOG_CURSOR_LEAD_SECONDS
	if lead.length() > STEALTH_FOG_CURSOR_MAX_LEAD_PIXELS:
		lead = lead.normalized() * STEALTH_FOG_CURSOR_MAX_LEAD_PIXELS
	_fog_cursor_position = _fog_cursor_actual_position + lead

	var wind_delta := _fog_cursor_velocity * STEALTH_FOG_CURSOR_REFERENCE_SECONDS
	if wind_delta.length() > STEALTH_FOG_CURSOR_MAX_WIND_PIXELS:
		wind_delta = wind_delta.normalized() * STEALTH_FOG_CURSOR_MAX_WIND_PIXELS
	_fog_cursor_wind = wind_delta

func _decay_stealth_fog_cursor_motion(delta: float) -> void:
	if _fog_cursor_actual_position == Vector2.INF:
		return
	_fog_cursor_velocity = _fog_cursor_velocity.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	_apply_stealth_fog_cursor_prediction()

func _clear_stealth_fog_cursor_motion() -> void:
	_fog_cursor_actual_position = Vector2.INF
	_fog_cursor_position = Vector2.INF
	_fog_cursor_velocity = Vector2.ZERO
	_fog_cursor_wind = Vector2.ZERO

func _get_visible_stealth_zone_controls() -> Array[Control]:
	var result: Array[Control] = []
	var menu := _get_embedded_menu_control()
	if menu == null:
		return result

	var stack: Array[Node] = [menu]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if _control_has_visible_stealth_creature(control):
			result.append(control)
	return result

func _control_has_visible_stealth_creature(control: Control) -> bool:
	var zone := control.get("zone") as Zone
	if zone == null:
		return false
	if zone.cards.is_empty():
		return false
	var card := zone.cards[0] as Card
	if card == null:
		return false
	return card.is_stealth and card.card_type == Card.CardType.CREATURE

func _place_stealth_fog_cluster(fog_cluster: Node3D, control: Control) -> void:
	if _game_viewport == null:
		return
	var rect := control.get_global_rect()
	_stealth_fog_control_rects[str(control.get_instance_id())] = rect
	var center := rect.position + rect.size * 0.5
	var viewport_size := Vector2(_game_viewport.size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var uv := Vector2(center.x / viewport_size.x, center.y / viewport_size.y)
	fog_cluster.position = Vector3(
		(uv.x - 0.5) * screen_size.x,
		(0.5 - uv.y) * screen_size.y,
		0.24
	)

	var local_size := Vector2(
		rect.size.x / viewport_size.x * screen_size.x,
		rect.size.y / viewport_size.y * screen_size.y
	)
	_update_steady_stealth_mist(fog_cluster, local_size)
	_update_stealth_fog_cursor_wind(fog_cluster, rect)
	_update_native_stealth_fog_volume(fog_cluster, local_size)

func _create_stealth_fog_cluster() -> Node3D:
	var fog_cluster := Node3D.new()
	fog_cluster.name = "StealthFog3D"
	fog_cluster.add_child(_make_steady_stealth_mist())
	return fog_cluster

func _make_native_stealth_fog_volume() -> FogVolume:
	var volume := FogVolume.new()
	volume.name = "NativeFogVolume"
	volume.position.z = 0.18
	volume.size = Vector3(1.25, 0.92, 1.15)

	var material := FogMaterial.new()
	material.set("density", 0.42)
	material.set("albedo", Color(0.16, 0.16, 0.17, 1.0))
	material.set("emission", Color(0.0, 0.0, 0.0))
	material.set("height_falloff", 0.0)
	material.set("edge_fade", 0.34)
	volume.material = material
	return volume

func _update_native_stealth_fog_volume(fog_cluster: Node3D, local_size: Vector2) -> void:
	var volume := fog_cluster.get_node_or_null("NativeFogVolume") as FogVolume
	if volume == null:
		return
	volume.size = Vector3(
		maxf(0.86, local_size.x * 1.36),
		maxf(0.64, local_size.y * 1.28),
		0.86
	)

func _make_steady_stealth_mist() -> Node3D:
	var mist := Node3D.new()
	mist.name = "SteadyMist"
	for i in range(2):
		var layer := MeshInstance3D.new()
		layer.name = "CloudLayer%d" % i
		var mesh := QuadMesh.new()
		mesh.size = Vector2.ONE
		mesh.material = _make_steady_stealth_mist_material(i)
		layer.mesh = mesh
		layer.position.z = -0.034 + float(i) * 0.014
		mist.add_child(layer)
	return mist

func _update_steady_stealth_mist(fog_cluster: Node3D, local_size: Vector2) -> void:
	var mist := fog_cluster.get_node_or_null("SteadyMist") as Node3D
	if mist == null:
		return
	var base_scale := Vector2(maxf(0.64, local_size.x * 1.22), maxf(0.52, local_size.y * 1.18))
	for i in range(mist.get_child_count()):
		var layer := mist.get_child(i) as MeshInstance3D
		if layer == null:
			continue
		var layer_scale := 1.0 + float(i) * 0.070
		layer.scale = Vector3(base_scale.x * layer_scale, base_scale.y * layer_scale, 1.0)
		var material := layer.get_active_material(0) as ShaderMaterial
		if material != null and local_size.x > 0.0 and local_size.y > 0.0:
			material.set_shader_parameter("layer_card_scale", Vector2(
				layer.scale.x / local_size.x,
				layer.scale.y / local_size.y
			))

func _update_stealth_fog_cursor_wind(fog_cluster: Node3D, control_rect: Rect2) -> void:
	var cursor_uv := Vector2(-10.0, -10.0)
	var cursor_lead_uv := Vector2(-10.0, -10.0)
	var wind := Vector2.ZERO
	var influence_rect := control_rect.grow(maxf(control_rect.size.x, control_rect.size.y) * 0.72)
	if _fog_cursor_actual_position != Vector2.INF \
			and _fog_cursor_position != Vector2.INF \
			and control_rect.size.x > 0.0 \
			and control_rect.size.y > 0.0 \
			and (influence_rect.has_point(_fog_cursor_actual_position) or influence_rect.has_point(_fog_cursor_position)):
		cursor_uv = Vector2(
			(_fog_cursor_actual_position.x - control_rect.position.x) / control_rect.size.x,
			(_fog_cursor_actual_position.y - control_rect.position.y) / control_rect.size.y
		)
		cursor_lead_uv = Vector2(
			(_fog_cursor_position.x - control_rect.position.x) / control_rect.size.x,
			(_fog_cursor_position.y - control_rect.position.y) / control_rect.size.y
		)
		wind = _fog_cursor_wind / maxf(control_rect.size.x, control_rect.size.y)
	for child in fog_cluster.get_children():
		var mist := child as Node3D
		if mist == null or mist.name != "SteadyMist":
			continue
		for layer_child in mist.get_children():
			var layer := layer_child as MeshInstance3D
			if layer == null or layer.mesh == null:
				continue
			var material := layer.get_active_material(0) as ShaderMaterial
			if material == null:
				continue
			material.set_shader_parameter("cursor_uv", cursor_uv)
			material.set_shader_parameter("cursor_lead_uv", cursor_lead_uv)
			material.set_shader_parameter("cursor_wind", wind)

func _make_stealth_fog_particle_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.albedo_color = Color(0.07, 0.068, 0.078, 0.18)
	var texture := _get_next_stealth_fog_texture()
	if texture != null:
		material.albedo_texture = texture
	return material

func _make_steady_stealth_mist_material(layer_index: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 fog_color : source_color = vec4(0.80, 0.82, 0.84, 0.34);
uniform float fog_alpha = 0.42;
uniform float cloud_scale = 2.3;
uniform float drift_speed = 0.025;
uniform float phase = 0.0;
uniform sampler2D smoke_texture;
uniform sampler2D cloud_texture;
uniform sampler2D detail_texture;
uniform bool use_smoke_texture = false;
uniform bool use_cloud_texture = false;
uniform bool use_detail_texture = false;
uniform vec2 cursor_uv = vec2(-10.0, -10.0);
uniform vec2 cursor_lead_uv = vec2(-10.0, -10.0);
uniform vec2 cursor_wind = vec2(0.0, 0.0);
uniform vec2 layer_card_scale = vec2(1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 5; i++) {
		value += amplitude * noise(p);
		p = p * 2.02 + vec2(13.7, 8.9);
		amplitude *= 0.52;
	}
	return value;
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 segment = b - a;
	float segment_length = max(dot(segment, segment), 0.0001);
	float h = clamp(dot(p - a, segment) / segment_length, 0.0, 1.0);
	return length((p - a) - segment * h);
}

vec2 rotate_uv(vec2 p, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	vec2 centered = p - vec2(0.5);
	return vec2(centered.x * c - centered.y * s, centered.x * s + centered.y * c) + vec2(0.5);
}

void fragment() {
	vec2 uv = UV;
	vec2 remapped_cursor_uv = vec2(0.5) + (cursor_uv - vec2(0.5)) / max(layer_card_scale, vec2(0.001));
	vec2 remapped_cursor_lead_uv = vec2(0.5) + (cursor_lead_uv - vec2(0.5)) / max(layer_card_scale, vec2(0.001));
	vec2 to_cursor = uv - remapped_cursor_lead_uv;
	float lead_distance = length(to_cursor);
	float actual_distance = length(uv - remapped_cursor_uv);
	float path_distance = segment_distance(uv, remapped_cursor_uv, remapped_cursor_lead_uv);
	vec2 scaled_wind = cursor_wind / max(layer_card_scale, vec2(0.001));
	float speed_strength = clamp(length(scaled_wind) * 22.0, 0.0, 1.0);
	float cursor_distance = min(min(lead_distance, actual_distance), path_distance * mix(1.35, 1.0, speed_strength));
	float brush_radius = mix(0.25, 0.46, speed_strength);
	float brush_field = smoothstep(brush_radius, 0.0, cursor_distance);
	float pressure_radius = mix(0.42, 0.62, speed_strength);
	float pressure_field = smoothstep(pressure_radius, 0.0, cursor_distance) * speed_strength;
	float gust_field = max(brush_field * mix(0.62, 1.0, speed_strength), pressure_field * 0.55);
	vec2 radial_push = normalize(to_cursor + vec2(0.0001, 0.0001)) * gust_field * 0.32;
	vec2 stirred_uv = uv + radial_push;
	vec2 drift = vec2(TIME * drift_speed, -TIME * drift_speed * 0.55 + phase);
	float flow_time = TIME * (0.42 + drift_speed * 1.8) + phase;
	float broad = fbm(stirred_uv * cloud_scale + drift);
	float rolling = fbm(stirred_uv * cloud_scale * 1.72 - drift * 0.88 + phase);
	float fine = fbm(stirred_uv * cloud_scale * 3.1 + drift * 1.6 + phase);
	float ridge = smoothstep(0.060, 0.0, abs(cursor_distance - brush_radius)) * speed_strength * 0.06;
	float smoke_mask = 1.0;
	if (use_smoke_texture) {
		vec2 smoke_offset_a = vec2(sin(flow_time * 0.71), cos(flow_time * 0.53)) * 0.082;
		vec2 smoke_offset_b = vec2(cos(flow_time * 0.47 + 1.4), sin(flow_time * 0.61 - 0.8)) * 0.055;
		vec2 smoke_uv_a = clamp(rotate_uv(uv + smoke_offset_a, sin(flow_time * 0.33) * 0.105), vec2(0.0), vec2(1.0));
		vec2 smoke_uv_b = clamp(rotate_uv((uv - vec2(0.5)) * 1.08 + vec2(0.5) - smoke_offset_b, -sin(flow_time * 0.29 + 0.6) * 0.085), vec2(0.0), vec2(1.0));
		float smoke_a = texture(smoke_texture, smoke_uv_a).r;
		float smoke_b = texture(smoke_texture, smoke_uv_b).r;
		smoke_mask = smoothstep(0.02, 0.80, max(smoke_a, smoke_b * 0.82));
	}
	float density = 0.38 + broad * 0.31 + rolling * 0.20 + fine * 0.065;
	if (use_cloud_texture) {
		vec2 cloud_uv_a = fract(stirred_uv * (cloud_scale * 0.58) + drift * 1.35 + vec2(phase * 0.037, phase * 0.021));
		vec2 cloud_uv_b = fract(stirred_uv * (cloud_scale * 0.91) - drift * 1.05 + vec2(phase * 0.019, -phase * 0.031));
		float texture_cloud = texture(cloud_texture, cloud_uv_a).r * 0.62 + texture(cloud_texture, cloud_uv_b).r * 0.38;
		density = mix(density, texture_cloud, 0.46);
	}
	if (use_detail_texture) {
		vec2 detail_uv = fract(stirred_uv * (cloud_scale * 2.65) + drift * 2.20 + vec2(phase * 0.017, phase * 0.047));
		float detail_noise = texture(detail_texture, detail_uv).r;
		density += (detail_noise - 0.5) * 0.075 * (1.0 - gust_field * 0.45);
	}
	density *= 0.94 + sin(flow_time * 0.66) * 0.060;
	density = clamp(density * smoke_mask + ridge - gust_field * 1.34, 0.0, 1.0);
	float edge_x = smoothstep(0.0, 0.16, uv.x) * smoothstep(0.0, 0.16, 1.0 - uv.x);
	float edge_y = smoothstep(0.0, 0.16, uv.y) * smoothstep(0.0, 0.16, 1.0 - uv.y);
	float feather = edge_x * edge_y;
	ALBEDO = fog_color.rgb;
	ALPHA = fog_alpha * density * feather;
}
"""
	material.shader = shader
	material.set_shader_parameter("fog_alpha", 0.48 - float(layer_index) * 0.070)
	material.set_shader_parameter("cloud_scale", 1.12 + float(layer_index) * 0.26)
	material.set_shader_parameter("drift_speed", 0.090 + float(layer_index) * 0.034)
	material.set_shader_parameter("phase", float(layer_index) * 3.17)
	var smoke_texture := _get_stealth_fog_smoke_texture()
	if smoke_texture != null:
		material.set_shader_parameter("smoke_texture", smoke_texture)
		material.set_shader_parameter("use_smoke_texture", true)
	var cloud_texture := _get_stealth_fog_cloud_texture()
	if cloud_texture != null:
		material.set_shader_parameter("cloud_texture", cloud_texture)
		material.set_shader_parameter("use_cloud_texture", true)
	var detail_texture := _get_stealth_fog_detail_texture()
	if detail_texture != null:
		material.set_shader_parameter("detail_texture", detail_texture)
		material.set_shader_parameter("use_detail_texture", true)
	return material

func _get_next_stealth_fog_texture() -> Texture2D:
	var textures := _get_stealth_fog_textures()
	if textures.is_empty():
		return null
	var index := _stealth_fog_emitters.size() % textures.size()
	return textures[index]

func _get_stealth_fog_textures() -> Array[Texture2D]:
	if not _stealth_fog_textures.is_empty():
		return _stealth_fog_textures
	var paths := [
		"res://images/ui/stealth_fog/shadow_fog_03.png",
		"res://images/ui/stealth_fog/shadow_fog_05.png",
		"res://images/ui/stealth_fog/shadow_fog_08.png",
		"res://images/ui/stealth_fog/shadow_fog_09.png",
		"res://images/ui/stealth_fog/shadow_fog_10.png",
		"res://images/ui/stealth_fog/shadow_fog_15.png",
	]
	for path in paths:
		var texture := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
		if texture != null:
			_stealth_fog_textures.append(texture)
	return _stealth_fog_textures

func _get_stealth_fog_smoke_texture() -> Texture2D:
	if _stealth_fog_smoke_texture != null:
		return _stealth_fog_smoke_texture
	_stealth_fog_smoke_texture = ResourceLoader.load(
		STEALTH_FOG_SMOKE_TEXTURE_PATH,
		"Texture2D",
		ResourceLoader.CACHE_MODE_REUSE
	) as Texture2D
	return _stealth_fog_smoke_texture

func _get_stealth_fog_cloud_texture() -> Texture2D:
	if _stealth_fog_cloud_texture != null:
		return _stealth_fog_cloud_texture
	_stealth_fog_cloud_texture = ResourceLoader.load(
		STEALTH_FOG_CLOUD_TEXTURE_PATH,
		"Texture2D",
		ResourceLoader.CACHE_MODE_REUSE
	) as Texture2D
	return _stealth_fog_cloud_texture

func _get_stealth_fog_detail_texture() -> Texture2D:
	if _stealth_fog_detail_texture != null:
		return _stealth_fog_detail_texture
	_stealth_fog_detail_texture = ResourceLoader.load(
		STEALTH_FOG_DETAIL_TEXTURE_PATH,
		"Texture2D",
		ResourceLoader.CACHE_MODE_REUSE
	) as Texture2D
	return _stealth_fog_detail_texture

func _get_embedded_menu_control() -> Control:
	if _game_instance == null or not is_instance_valid(_game_instance):
		return null
	return _game_instance.get_node_or_null("Control") as Control

func _load_original_scene_directly() -> void:
	var scene := load(game_scene_path)
	if not (scene is PackedScene):
		push_error("Main3D: could not load server bootstrap scene at %s" % game_scene_path)
		get_tree().quit(1)
		return
	add_child((scene as PackedScene).instantiate())

func _input(event: InputEvent) -> void:
	if _game_viewport == null or _screen_mesh == null or _camera == null:
		return
	if _is_flat_2d_mode:
		return
	if event is InputEventMouseMotion:
		_forward_mouse_motion(event as InputEventMouseMotion)
		return
	if event is InputEventMouseButton:
		_forward_mouse_button(event as InputEventMouseButton)
		return
	if event is InputEventKey or event is InputEventShortcut:
		_game_viewport.push_input(event.duplicate(), true)
		get_viewport().set_input_as_handled()

func _forward_mouse_motion(event: InputEventMouseMotion) -> void:
	var mapped_position = _map_window_position_to_game_viewport(event.position)
	if not (mapped_position is Vector2):
		_last_game_mouse_position = Vector2.INF
		_clear_stealth_fog_cursor_motion()
		return
	var game_position: Vector2 = mapped_position
	var forwarded := event.duplicate() as InputEventMouseMotion
	if forwarded == null:
		return
	forwarded.position = game_position
	forwarded.global_position = game_position
	if _last_game_mouse_position == Vector2.INF:
		forwarded.relative = Vector2.ZERO
	else:
		forwarded.relative = game_position - _last_game_mouse_position
	_last_game_mouse_position = game_position
	if event.velocity.length_squared() > 0.01:
		_fog_cursor_actual_position = game_position
		_fog_cursor_velocity = event.velocity
		_apply_stealth_fog_cursor_prediction()
	else:
		_update_stealth_fog_cursor_motion(game_position, forwarded.relative, get_process_delta_time())
	_update_existing_stealth_fog_cursor_wind()
	_game_viewport.push_input(forwarded, true)
	get_viewport().set_input_as_handled()

func _forward_mouse_button(event: InputEventMouseButton) -> void:
	var mapped_position = _map_window_position_to_game_viewport(event.position)
	if not (mapped_position is Vector2):
		return
	var game_position: Vector2 = mapped_position
	var forwarded := event.duplicate() as InputEventMouseButton
	if forwarded == null:
		return
	forwarded.position = game_position
	forwarded.global_position = game_position
	_last_game_mouse_position = game_position
	_update_stealth_fog_cursor_motion(game_position, Vector2.ZERO, get_process_delta_time())
	_game_viewport.push_input(forwarded, true)
	get_viewport().set_input_as_handled()

func _map_window_position_to_game_viewport(window_position: Vector2):
	var ray_origin := _camera.project_ray_origin(window_position)
	var ray_direction := _camera.project_ray_normal(window_position)
	var local_origin := _screen_mesh.to_local(ray_origin)
	var local_ray_end := _screen_mesh.to_local(ray_origin + ray_direction)
	var local_direction := local_ray_end - local_origin
	if absf(local_direction.z) < 0.0001:
		return null
	var hit_distance := -local_origin.z / local_direction.z
	if hit_distance < 0.0:
		return null
	var local_hit := local_origin + local_direction * hit_distance
	var half_screen := screen_size * 0.5
	if local_hit.x < -half_screen.x or local_hit.x > half_screen.x:
		return null
	if local_hit.y < -half_screen.y or local_hit.y > half_screen.y:
		return null

	var uv := Vector2(
		(local_hit.x + half_screen.x) / screen_size.x,
		1.0 - ((local_hit.y + half_screen.y) / screen_size.y)
	)
	return Vector2(
		uv.x * float(_game_viewport.size.x),
		uv.y * float(_game_viewport.size.y)
	)

func _parse_user_args(args: PackedStringArray) -> Dictionary:
	var parsed: Dictionary = {}
	for arg in args:
		var parts := String(arg).split("=", false, 1)
		if parts.size() != 2:
			continue
		parsed[str(parts[0]).strip_edges()] = str(parts[1]).strip_edges()
	return parsed

func _should_boot_server_runtime(launch_args: Dictionary) -> bool:
	if str(launch_args.get(MATCH_CONFIG_ARG, "")).strip_edges() != "":
		return true
	var requested_mode := str(launch_args.get(SERVER_MODE_ARG, "")).strip_edges().to_lower()
	if requested_mode == "lobby":
		return true
	return OS.has_feature("dedicated_server")
