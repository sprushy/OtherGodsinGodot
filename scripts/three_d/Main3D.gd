extends Node3D

const WindowsSelfUpdaterScript = preload("res://scripts/client/WindowsSelfUpdater.gd")
const GAME_SCENE_PATH := "res://scenes/mainfork.tscn"
const DEFAULT_VIEWPORT_SIZE := Vector2i(1920, 1080)
const SERVER_MODE_ARG := "server_mode"
const MATCH_CONFIG_ARG := "match_config"

@export var game_scene_path: String = GAME_SCENE_PATH
@export var game_viewport_size: Vector2i = DEFAULT_VIEWPORT_SIZE
@export var screen_size: Vector2 = Vector2(18.4, 10.35)
@export var screen_tilt_degrees: float = -2.0
@export var use_flat_match_view: bool = true

var _game_viewport: SubViewport = null
var _game_instance: Node = null
var _three_d_world: Node3D = null
var _flat_canvas_layer: CanvasLayer = null
var _screen_mesh: MeshInstance3D = null
var _camera: Camera3D = null
var _last_game_mouse_position: Vector2 = Vector2.INF
var _is_flat_2d_mode: bool = false

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
	_game_viewport = SubViewport.new()
	_game_viewport.name = "GameViewport"
	_game_viewport.size = game_viewport_size
	_game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_game_viewport)

	_three_d_world = Node3D.new()
	_three_d_world.name = "ThreeDWorld"
	add_child(_three_d_world)

	_build_environment()
	_build_table()
	_build_game_screen()
	_build_camera()
	_build_lighting()
	_build_flat_canvas()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.015, 0.018, 0.024)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.54, 0.62, 0.70)
	environment.ambient_light_energy = 0.45
	world_environment.environment = environment
	_three_d_world.add_child(world_environment)

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

	var quad := QuadMesh.new()
	quad.size = screen_size

	_screen_mesh = MeshInstance3D.new()
	_screen_mesh.name = "InteractiveGameScreen"
	_screen_mesh.mesh = quad
	var screen_material := StandardMaterial3D.new()
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	screen_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	screen_material.albedo_texture = _game_viewport.get_texture()
	_screen_mesh.material_override = screen_material
	rig.add_child(_screen_mesh)

	var half_width := screen_size.x * 0.5
	var half_height := screen_size.y * 0.5
	var frame_color := Color(0.16, 0.10, 0.065)
	var frame_depth := 0.18
	var frame_thickness := 0.09

	var top := _make_box(
		"TopFrame",
		Vector3(screen_size.x + frame_thickness * 2.0, frame_thickness, frame_depth),
		Vector3(0.0, half_height + frame_thickness * 0.5, 0.04),
		frame_color
	)
	rig.add_child(top)

	var bottom := _make_box(
		"BottomFrame",
		Vector3(screen_size.x + frame_thickness * 2.0, frame_thickness, frame_depth),
		Vector3(0.0, -half_height - frame_thickness * 0.5, 0.04),
		frame_color
	)
	rig.add_child(bottom)

	var left := _make_box(
		"LeftFrame",
		Vector3(frame_thickness, screen_size.y, frame_depth),
		Vector3(-half_width - frame_thickness * 0.5, 0.0, 0.04),
		frame_color
	)
	rig.add_child(left)

	var right := _make_box(
		"RightFrame",
		Vector3(frame_thickness, screen_size.y, frame_depth),
		Vector3(half_width + frame_thickness * 0.5, 0.0, 0.04),
		frame_color
	)
	rig.add_child(right)

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "MainCamera3D"
	_camera.position = Vector3(0.0, 1.94, 11.35)
	_camera.fov = 47.0
	_three_d_world.add_child(_camera)
	_camera.look_at(Vector3(0.0, 1.79, 0.0), Vector3.UP)
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

func _process(_delta: float) -> void:
	_refresh_display_mode()

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
