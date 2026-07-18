extends Node3D

const WindowsSelfUpdaterScript = preload("res://scripts/client/WindowsSelfUpdater.gd")
const GameCursorScript = preload("res://scripts/ui/GameCursor.gd")
const SnowV2WeatherControllerScript = preload("res://scripts/fx/SnowV2WeatherController.gd")
const GAME_SCENE_PATH := "res://scenes/mainfork.tscn"
const DEFAULT_VIEWPORT_SIZE := Vector2i(2560, 1440)
const SERVER_MODE_ARG := "server_mode"
const MATCH_CONFIG_ARG := "match_config"
const LEGACY_3D_ARG := "legacy_3d"
const STEALTH_FOG_SMOKE_TEXTURE_PATH := "res://images/ui/stealth_fog/lelu_smoke_b7.png"
const STEALTH_FOG_CLOUD_TEXTURE_PATH := "res://images/ui/stealth_fog/lelu_cloud_noise_tiled.png"
const STEALTH_FOG_DETAIL_TEXTURE_PATH := "res://images/ui/stealth_fog/seamless_noise_02.png"
const LOCKED_POWER_CURSOR_TEXTURE_PATH := "res://images/NorseLockedPowerCursor.png"
const STEALTH_FOG_CLEAR_UI_GROUP := "stealth_fog_clear_ui"
const STEALTH_FOG_TOP_UI_GROUP := "stealth_fog_top_ui"
const CUSTOM_CURSOR_ACTIVE_META := &"other_gods_custom_cursor_active"
const LOCKED_POWER_CURSOR_ACTIVE_META := &"other_gods_locked_power_cursor_active"
const SOFTWARE_CURSOR_LAYER := 20000
const LOCKED_POWER_CURSOR_TARGET_HEIGHT := 72
const LOCKED_POWER_CURSOR_HOTSPOT_RATIO := Vector2(0.50, 0.28)
const STEALTH_FOG_PLANE_Z := 0.001
const STEALTH_FOG_LAYER_Z_BASE := 0.0002
const STEALTH_FOG_LAYER_Z_STEP := 0.0003
const STEALTH_FOG_CURSOR_EFFECT_RADIUS_PIXELS := 52.0
const STEALTH_FOG_CURSOR_CENTER_OFFSET := Vector2(18.0, 20.0)
const STEALTH_FOG_CURSOR_TRAIL_LIFETIME := 1.4
const STEALTH_FOG_CURSOR_TRAIL_MIN_DISTANCE := 8.0
const STEALTH_FOG_CURSOR_TRAIL_COUNT := 6

@export var game_scene_path: String = GAME_SCENE_PATH
@export var game_viewport_size: Vector2i = DEFAULT_VIEWPORT_SIZE
@export var screen_size: Vector2 = Vector2(18.4, 10.35)
@export var screen_tilt_degrees: float = 0.0
@export var enable_legacy_3d_shell: bool = false
@export var use_flat_match_view: bool = true
@export var show_stealth_fog_3d: bool = false

var _game_viewport: SubViewport = null
var _game_instance: Node = null
var _three_d_world: Node3D = null
var _flat_canvas_layer: CanvasLayer = null
var _stealth_fog_top_ui_layer: CanvasLayer = null
var _stealth_fog_top_ui_root: Control = null
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
var _stealth_fog_hover_clear_rects: Array[Rect2] = []
var _stealth_fog_top_ui_copies: Dictionary = {}
var _stealth_fog_refresh_elapsed: float = 999.0
var _stealth_fog_motion_elapsed: float = 0.0
var _screen_world_height: float = 0.0
var _fog_cursor_actual_position: Vector2 = Vector2.INF
var _fog_cursor_position: Vector2 = Vector2.INF
var _fog_cursor_clear_strength: float = 0.0
var _fog_cursor_trail: Array[Dictionary] = []
var _previous_use_accumulated_input: bool = true
var _previous_vsync_mode: int = -1
var _software_cursor_layer: CanvasLayer = null
var _software_cursor_root: Node2D = null
var _software_cursor_sprite: Sprite2D = null
var _default_software_cursor_texture: Texture2D = null
var _locked_power_software_cursor_texture: Texture2D = null
var _software_cursor_showing_locked_power: bool = false
var _legacy_3d_shell_active: bool = false
var _snow_v2_weather_controller: Node = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_previous_use_accumulated_input = Input.use_accumulated_input
	Input.use_accumulated_input = false
	process_priority = -100
	var launch_args := _parse_user_args(OS.get_cmdline_user_args())
	if WindowsSelfUpdaterScript.is_update_launch(launch_args):
		var updater := WindowsSelfUpdaterScript.new()
		add_child(updater)
		updater.start(launch_args)
		return
	if _should_boot_server_runtime(launch_args):
		_load_original_scene_directly()
		return

	_previous_vsync_mode = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	var legacy_3d_requested := _is_truthy_arg(launch_args.get(LEGACY_3D_ARG, false))
	_legacy_3d_shell_active = enable_legacy_3d_shell or legacy_3d_requested
	if legacy_3d_requested:
		use_flat_match_view = false
		show_stealth_fog_3d = true

	if _legacy_3d_shell_active:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		_build_3d_shell()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_build_flat_canvas()
	# Load the embedded game scene first so the menu becomes interactive ASAP;
	# cursor/snow are presentation-only and are built deferred (their _process
	# consumers are null-guarded).
	_load_game_into_viewport()
	GameCursorScript.ensure_registered()
	_sync_cursor_presentation()
	call_deferred("_build_software_cursor")
	call_deferred("_build_snow_v2_weather")
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
	_build_table()
	_build_game_screen()
	_build_camera()
	_build_lighting()
	_build_flat_canvas()
	_build_stealth_fog_top_ui_layer()
	_sync_3d_display_to_window()

func _build_snow_v2_weather() -> void:
	var controller := SnowV2WeatherControllerScript.new()
	controller.name = "SnowV2WeatherController"
	add_child(controller)
	_snow_v2_weather_controller = controller
	if _three_d_world != null and controller.has_method("attach_3d_world"):
		controller.call("attach_3d_world", _three_d_world)

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Input.use_accumulated_input = _previous_use_accumulated_input
	if _previous_vsync_mode >= 0:
		DisplayServer.window_set_vsync_mode(_previous_vsync_mode as DisplayServer.VSyncMode)

func _build_software_cursor() -> void:
	_software_cursor_layer = CanvasLayer.new()
	_software_cursor_layer.name = "SoftwareCursorLayer"
	_software_cursor_layer.layer = SOFTWARE_CURSOR_LAYER
	add_child(_software_cursor_layer)

	_software_cursor_root = Node2D.new()
	_software_cursor_root.name = "SoftwareCursor"
	_software_cursor_layer.add_child(_software_cursor_root)

	var texture := GameCursorScript.build_texture()
	if texture != null:
		_default_software_cursor_texture = texture
		_software_cursor_sprite = Sprite2D.new()
		_software_cursor_sprite.name = "CursorVisual"
		_software_cursor_sprite.centered = false
		_software_cursor_root.add_child(_software_cursor_sprite)
		_apply_default_software_cursor()
	_locked_power_software_cursor_texture = _load_cropped_cursor_texture(
		LOCKED_POWER_CURSOR_TEXTURE_PATH,
		LOCKED_POWER_CURSOR_TARGET_HEIGHT
	)
	_update_software_cursor_position(get_viewport().get_mouse_position())

func _load_cropped_cursor_texture(texture_path: String, target_height: int) -> Texture2D:
	var source_texture := load(texture_path) as Texture2D
	if source_texture == null:
		return null
	var source_image := source_texture.get_image()
	if source_image == null or source_image.is_empty():
		return null
	var used_rect := source_image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return null
	var cursor_image := source_image.get_region(used_rect)
	if cursor_image == null or cursor_image.is_empty():
		return null
	var cursor_scale := float(target_height) / float(cursor_image.get_height())
	var target_width := maxi(1, int(round(cursor_image.get_width() * cursor_scale)))
	cursor_image.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(cursor_image)

func _apply_default_software_cursor() -> void:
	if _software_cursor_sprite == null or not is_instance_valid(_software_cursor_sprite):
		return
	_software_cursor_sprite.texture = _default_software_cursor_texture
	_software_cursor_sprite.scale = Vector2.ONE
	_software_cursor_sprite.position = -GameCursorScript.get_hotspot(_default_software_cursor_texture)
	_software_cursor_showing_locked_power = false

func _apply_locked_power_software_cursor() -> void:
	if _software_cursor_sprite == null or not is_instance_valid(_software_cursor_sprite):
		return
	_software_cursor_sprite.texture = _locked_power_software_cursor_texture
	_software_cursor_sprite.scale = Vector2.ONE
	var cursor_size := _locked_power_software_cursor_texture.get_size()
	_software_cursor_sprite.position = -Vector2(
		cursor_size.x * LOCKED_POWER_CURSOR_HOTSPOT_RATIO.x,
		cursor_size.y * LOCKED_POWER_CURSOR_HOTSPOT_RATIO.y
	)
	_software_cursor_showing_locked_power = true

func _update_software_cursor_position(window_position: Vector2) -> void:
	if _software_cursor_root == null or not is_instance_valid(_software_cursor_root):
		return
	_software_cursor_root.position = window_position

func _has_viewport_meta(meta_name: StringName) -> bool:
	var root_viewport := get_viewport()
	if root_viewport != null and _is_cursor_meta_active(root_viewport.get_meta(meta_name, false)):
		return true
	return _game_viewport != null \
		and _is_cursor_meta_active(_game_viewport.get_meta(meta_name, false))

func _is_cursor_meta_active(meta_value: Variant) -> bool:
	if meta_value is Dictionary:
		for owner in (meta_value as Dictionary).values():
			if owner is Object:
				if is_instance_valid(owner):
					return true
			elif bool(owner):
				return true
		return false
	return bool(meta_value)

func _has_custom_cursor_active() -> bool:
	return _has_viewport_meta(CUSTOM_CURSOR_ACTIVE_META)

func _has_software_custom_cursor_active() -> bool:
	var root_viewport := get_viewport()
	if root_viewport != null and _is_software_custom_cursor_meta(root_viewport.get_meta(CUSTOM_CURSOR_ACTIVE_META, false)):
		return true
	return _game_viewport != null \
		and _is_software_custom_cursor_meta(_game_viewport.get_meta(CUSTOM_CURSOR_ACTIVE_META, false))

func _is_software_custom_cursor_meta(meta_value: Variant) -> bool:
	if not (meta_value is Dictionary):
		return false
	return bool((meta_value as Dictionary).get("software_cursor", false))

# Returns true when an embedded popup Window (ConfirmationDialog, AcceptDialog,
# FileDialog, etc.) is currently visible in the game subtree. Such popups render
# as real OS sub-windows, so the layer-1000 software cursor cannot draw over
# them; while one is open we must fall back to the hardware cursor so the player
# still sees a pointer over the dialog.
func _has_open_embedded_popup_window() -> bool:
	var root := _game_instance
	if root == null or not is_instance_valid(root):
		return false
	return _has_visible_window_in_subtree(root)

func _has_visible_window_in_subtree(node: Node) -> bool:
	if node == null:
		return false
	if node is Window and node != get_window():
		# Embedded popup windows are parented inside the game subtree. A popup
		# is "open" when it is both in the tree and visible.
		if node.is_inside_tree() and node.visible:
			return true
	for child in node.get_children():
		if _has_visible_window_in_subtree(child):
			return true
	return false

func _sync_cursor_presentation() -> void:
	var locked_power_cursor_active := _has_viewport_meta(LOCKED_POWER_CURSOR_ACTIVE_META)
	var custom_cursor_active := _has_custom_cursor_active()
	var software_custom_cursor_active := _has_software_custom_cursor_active()
	var popup_window_open := _has_open_embedded_popup_window()
	var flat_default_pointer := _should_show_flat_2d() \
		and not software_custom_cursor_active \
		and not locked_power_cursor_active \
		and not custom_cursor_active
	if _software_cursor_sprite == null or not is_instance_valid(_software_cursor_sprite):
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	# Flat menu screens should never briefly lose the hardware pointer while the
	# optional software cursor layer catches up.
	var suppress_software_cursor := popup_window_open or flat_default_pointer
	var use_locked_power_software_cursor := locked_power_cursor_active \
		and _locked_power_software_cursor_texture != null \
		and not suppress_software_cursor
	if use_locked_power_software_cursor and not _software_cursor_showing_locked_power:
		_apply_locked_power_software_cursor()
	elif not use_locked_power_software_cursor and _software_cursor_showing_locked_power:
		_apply_default_software_cursor()
	if _software_cursor_root != null and is_instance_valid(_software_cursor_root):
		_software_cursor_root.visible = use_locked_power_software_cursor \
			or (not suppress_software_cursor and not locked_power_cursor_active and not custom_cursor_active)
	var show_hardware_cursor := suppress_software_cursor \
		or (not software_custom_cursor_active \
			and not use_locked_power_software_cursor \
			and (custom_cursor_active or locked_power_cursor_active))
	var desired_mouse_mode := Input.MOUSE_MODE_VISIBLE if show_hardware_cursor else Input.MOUSE_MODE_HIDDEN
	if Input.mouse_mode != desired_mouse_mode:
		Input.set_mouse_mode(desired_mouse_mode)

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

func _build_stealth_fog_top_ui_layer() -> void:
	_stealth_fog_top_ui_layer = CanvasLayer.new()
	_stealth_fog_top_ui_layer.name = "StealthFogTopUI"
	_stealth_fog_top_ui_layer.layer = 90
	_stealth_fog_top_ui_layer.visible = false
	add_child(_stealth_fog_top_ui_layer)

	_stealth_fog_top_ui_root = Control.new()
	_stealth_fog_top_ui_root.name = "StealthFogTopUIRoot"
	_stealth_fog_top_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stealth_fog_top_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stealth_fog_top_ui_layer.add_child(_stealth_fog_top_ui_root)

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
	if not _legacy_3d_shell_active:
		_update_software_cursor_position(get_viewport().get_mouse_position())
		_sync_cursor_presentation()
		_refresh_display_mode()
		return
	_update_software_cursor_position(get_viewport().get_mouse_position())
	_sync_cursor_presentation()
	_age_stealth_fog_cursor_trail(delta)
	_sync_3d_display_to_window()
	_refresh_display_mode()
	_refresh_stealth_fog_cursor_from_window(delta)
	_stealth_fog_hover_clear_rects = _get_visible_stealth_fog_hover_clear_rects()
	_refresh_stealth_fog_top_ui_overlay()
	_stealth_fog_motion_elapsed += delta
	_stealth_fog_refresh_elapsed += delta
	if _stealth_fog_refresh_elapsed >= 0.12:
		_stealth_fog_refresh_elapsed = 0.0
		_update_stealth_fog_emitters()
	else:
		_update_existing_stealth_fog_cursor_effect()
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
	if not _legacy_3d_shell_active:
		return true
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
		var variant_seed := _get_stealth_fog_variant_seed(control)
		var fog_cluster := _stealth_fog_emitters.get(key, null) as Node3D
		if fog_cluster == null or not is_instance_valid(fog_cluster):
			fog_cluster = _create_stealth_fog_cluster(variant_seed)
			_stealth_fog_emitters[key] = fog_cluster
			_stealth_fog_root.add_child(fog_cluster)
		_configure_stealth_fog_cluster_variant(fog_cluster, variant_seed)
		_place_stealth_fog_cluster(fog_cluster, control)

	for key in _stealth_fog_emitters.keys():
		if active_keys.has(key):
			continue
		var stale := _stealth_fog_emitters.get(key, null) as Node
		if stale != null and is_instance_valid(stale):
			stale.queue_free()
		_stealth_fog_emitters.erase(key)
		_stealth_fog_control_rects.erase(key)

func _update_existing_stealth_fog_cursor_effect() -> void:
	for key in _stealth_fog_emitters.keys():
		var fog_cluster := _stealth_fog_emitters.get(key, null) as Node3D
		if fog_cluster == null or not is_instance_valid(fog_cluster):
			continue
		var rect_value = _stealth_fog_control_rects.get(key, null)
		if not (rect_value is Rect2):
			continue
		_update_stealth_fog_cursor_effect(fog_cluster, rect_value)

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
		var cluster_phase := float(fog_cluster.get_meta("fog_phase", float(fog_cluster.get_instance_id() % 1000) * 0.017))
		var sway_multiplier := float(fog_cluster.get_meta("fog_sway_multiplier", 1.0))
		var speed_multiplier := float(fog_cluster.get_meta("fog_speed_multiplier", 1.0))
		for i in range(mist.get_child_count()):
			var layer := mist.get_child(i) as MeshInstance3D
			if layer == null:
				continue
			var layer_phase := cluster_phase + float(i) * 1.73
			var speed_x := (0.36 + float(i) * 0.10) * speed_multiplier
			var speed_y := (0.29 + float(i) * 0.08) * speed_multiplier
			var sway_x := sin(_stealth_fog_motion_elapsed * speed_x + layer_phase) * (0.034 + float(i) * 0.015) * sway_multiplier
			var sway_y := cos(_stealth_fog_motion_elapsed * speed_y + layer_phase * 0.82) * (0.026 + float(i) * 0.011) * sway_multiplier
			layer.position = Vector3(sway_x, sway_y, STEALTH_FOG_LAYER_Z_BASE + float(i) * STEALTH_FOG_LAYER_Z_STEP)
			layer.rotation.z = sin(_stealth_fog_motion_elapsed * 0.24 * speed_multiplier + layer_phase) * (0.025 + float(i) * 0.014) * sway_multiplier

func _refresh_stealth_fog_cursor_from_window(_delta: float) -> void:
	if _game_viewport == null or _screen_mesh == null or _camera == null or _is_flat_2d_mode:
		_clear_stealth_fog_cursor_motion()
		return
	var mapped_position = _map_window_position_to_game_viewport(
		get_viewport().get_mouse_position() + STEALTH_FOG_CURSOR_CENTER_OFFSET
	)
	if not (mapped_position is Vector2):
		_clear_stealth_fog_cursor_motion()
		return
	var game_position: Vector2 = mapped_position
	_update_stealth_fog_cursor_motion(game_position)

func _update_stealth_fog_cursor_motion(game_position: Vector2) -> void:
	if _fog_cursor_actual_position != Vector2.INF \
			and _fog_cursor_actual_position.distance_to(game_position) >= STEALTH_FOG_CURSOR_TRAIL_MIN_DISTANCE:
		_fog_cursor_trail.push_front({
			"position": _fog_cursor_actual_position,
			"age": 0.0,
		})
		if _fog_cursor_trail.size() > STEALTH_FOG_CURSOR_TRAIL_COUNT:
			_fog_cursor_trail.resize(STEALTH_FOG_CURSOR_TRAIL_COUNT)
	_fog_cursor_actual_position = game_position
	_fog_cursor_clear_strength = 1.0
	_apply_stealth_fog_cursor_prediction()

func _age_stealth_fog_cursor_trail(delta: float) -> void:
	for i in range(_fog_cursor_trail.size() - 1, -1, -1):
		var sample := _fog_cursor_trail[i]
		var age := float(sample.get("age", 0.0)) + delta
		if age >= STEALTH_FOG_CURSOR_TRAIL_LIFETIME:
			_fog_cursor_trail.remove_at(i)
			continue
		sample["age"] = age
		_fog_cursor_trail[i] = sample

func _apply_stealth_fog_cursor_prediction() -> void:
	if _fog_cursor_actual_position == Vector2.INF:
		_fog_cursor_position = Vector2.INF
		return
	_fog_cursor_position = _fog_cursor_actual_position

func _decay_stealth_fog_cursor_motion(_delta: float) -> void:
	if _fog_cursor_actual_position == Vector2.INF:
		return
	_fog_cursor_clear_strength = 1.0
	_apply_stealth_fog_cursor_prediction()

func _clear_stealth_fog_cursor_motion() -> void:
	_fog_cursor_actual_position = Vector2.INF
	_fog_cursor_position = Vector2.INF
	_fog_cursor_clear_strength = 0.0

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

func _get_visible_stealth_fog_hover_clear_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	if _game_viewport == null or get_tree() == null:
		return result
	for node in get_tree().get_nodes_in_group(STEALTH_FOG_CLEAR_UI_GROUP):
		var control := node as Control
		if control == null or not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		if control.get_viewport() != _game_viewport:
			continue
		var rect := control.get_global_rect()
		if rect.size.x <= 1.0 or rect.size.y <= 1.0:
			continue
		result.append(rect.grow(6.0))
	return result

func _refresh_stealth_fog_top_ui_overlay() -> void:
	if _stealth_fog_top_ui_layer == null or _stealth_fog_top_ui_root == null:
		return
	var should_show := show_stealth_fog_3d and not _is_flat_2d_mode and _game_viewport != null
	_stealth_fog_top_ui_layer.visible = should_show
	if not should_show:
		_clear_stealth_fog_top_ui_copies()
		return
	var game_size := Vector2(_game_viewport.size)
	var view_size := get_viewport().get_visible_rect().size
	if game_size.x <= 0.0 or game_size.y <= 0.0 or view_size.x <= 0.0 or view_size.y <= 0.0:
		_clear_stealth_fog_top_ui_copies()
		return
	_stealth_fog_top_ui_root.size = view_size
	var scale := Vector2(view_size.x / game_size.x, view_size.y / game_size.y)
	var active_keys: Dictionary = {}
	for node in get_tree().get_nodes_in_group(STEALTH_FOG_TOP_UI_GROUP):
		var control := node as Control
		if control == null or not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		if control.get_viewport() != _game_viewport:
			continue
		var rect := control.get_global_rect()
		if rect.size.x <= 1.0 or rect.size.y <= 1.0 or not _rect_over_active_stealth_fog(rect):
			continue
		var key := str(control.get_instance_id())
		active_keys[key] = true
		var copy := _stealth_fog_top_ui_copies.get(key, null) as Control
		if copy == null or not is_instance_valid(copy):
			copy = _make_stealth_fog_top_ui_copy(control)
			if copy == null:
				continue
			_stealth_fog_top_ui_copies[key] = copy
			_stealth_fog_top_ui_root.add_child(copy)
		_sync_stealth_fog_top_ui_copy(copy, control, rect, scale)
	var stale_keys: Array = []
	for key in _stealth_fog_top_ui_copies.keys():
		if active_keys.has(key):
			continue
		var stale := _stealth_fog_top_ui_copies.get(key, null) as Node
		if stale != null and is_instance_valid(stale):
			stale.queue_free()
		stale_keys.append(key)
	for key in stale_keys:
		_stealth_fog_top_ui_copies.erase(key)

func _clear_stealth_fog_top_ui_copies() -> void:
	for key in _stealth_fog_top_ui_copies.keys():
		var copy := _stealth_fog_top_ui_copies.get(key, null) as Node
		if copy != null and is_instance_valid(copy):
			copy.queue_free()
	_stealth_fog_top_ui_copies.clear()

func _rect_over_active_stealth_fog(rect: Rect2) -> bool:
	for rect_value in _stealth_fog_control_rects.values():
		if not (rect_value is Rect2):
			continue
		var fog_rect := rect_value as Rect2
		if fog_rect.grow(4.0).intersects(rect):
			return true
	return false

func _make_stealth_fog_top_ui_copy(source: Control) -> Control:
	if source is PanelContainer:
		var panel := PanelContainer.new()
		panel.name = "StealthFogTopUICopy"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var source_panel := source as PanelContainer
		var stylebox := source_panel.get_theme_stylebox("panel")
		if stylebox != null:
			panel.add_theme_stylebox_override("panel", stylebox.duplicate(true))
		var source_label := _find_first_label(source)
		if source_label != null:
			panel.add_child(_make_stealth_fog_top_ui_label_copy(source_label))
		return panel
	if source is Label:
		return _make_stealth_fog_top_ui_label_copy(source as Label)
	return null

func _make_stealth_fog_top_ui_label_copy(source_label: Label) -> Label:
	var label := Label.new()
	label.name = "StealthFogTopUILabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = source_label.horizontal_alignment
	label.vertical_alignment = source_label.vertical_alignment
	label.text = source_label.text
	label.add_theme_font_size_override("font_size", source_label.get_theme_font_size("font_size"))
	label.add_theme_color_override("font_color", source_label.get_theme_color("font_color"))
	return label

func _sync_stealth_fog_top_ui_copy(copy: Control, source: Control, rect: Rect2, scale: Vector2) -> void:
	copy.position = rect.position * scale
	copy.size = rect.size * scale
	copy.visible = true
	var source_label := _find_first_label(source)
	var copy_label := _find_first_label(copy)
	if source_label != null and copy_label != null:
		copy_label.text = source_label.text
		copy_label.add_theme_font_size_override("font_size", source_label.get_theme_font_size("font_size"))
		copy_label.add_theme_color_override("font_color", source_label.get_theme_color("font_color"))

func _find_first_label(root: Node) -> Label:
	var label := root as Label
	if label != null:
		return label
	for child in root.get_children():
		var found := _find_first_label(child)
		if found != null:
			return found
	return null

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
		STEALTH_FOG_PLANE_Z
	)

	var local_size := Vector2(
		rect.size.x / viewport_size.x * screen_size.x,
		rect.size.y / viewport_size.y * screen_size.y
	)
	_update_steady_stealth_mist(fog_cluster, local_size)
	_update_stealth_fog_cursor_effect(fog_cluster, rect)
	_update_native_stealth_fog_volume(fog_cluster, local_size)

func _create_stealth_fog_cluster(variant_seed: int) -> Node3D:
	var fog_cluster := Node3D.new()
	fog_cluster.name = "StealthFog3D"
	fog_cluster.add_child(_make_steady_stealth_mist())
	_configure_stealth_fog_cluster_variant(fog_cluster, variant_seed)
	return fog_cluster

func _get_stealth_fog_variant_seed(control: Control) -> int:
	var seed_parts: Array[String] = []
	var zone := control.get("zone") as Zone
	if zone != null:
		seed_parts.append(str(zone.zone_type))
		seed_parts.append(str(zone.zone_index))
		if not zone.cards.is_empty():
			var card := zone.cards[0] as Card
			if card != null:
				if "uid" in card and str(card.uid).strip_edges() != "":
					seed_parts.append(str(card.uid))
				else:
					seed_parts.append(card.card_name)
					seed_parts.append(card.art_path)
	if seed_parts.is_empty():
		seed_parts.append(str(control.get_instance_id()))
	return posmod("|".join(seed_parts).hash(), 1000000)

func _seeded_unit(seed: int, salt: int) -> float:
	return float(posmod(("%d:%d" % [seed, salt]).hash(), 10000)) / 10000.0

func _seeded_range(seed: int, salt: int, min_value: float, max_value: float) -> float:
	return lerpf(min_value, max_value, _seeded_unit(seed, salt))

func _configure_stealth_fog_cluster_variant(fog_cluster: Node3D, variant_seed: int) -> void:
	if fog_cluster == null or not is_instance_valid(fog_cluster):
		return
	fog_cluster.set_meta("fog_variant_seed", variant_seed)
	fog_cluster.set_meta("fog_phase", _seeded_range(variant_seed, 1, 0.0, TAU))
	fog_cluster.set_meta("fog_sway_multiplier", _seeded_range(variant_seed, 2, 0.72, 1.06))
	fog_cluster.set_meta("fog_speed_multiplier", _seeded_range(variant_seed, 3, 0.84, 1.22))

	var angle := _seeded_range(variant_seed, 4, 0.0, TAU)
	var drift_direction := Vector2(cos(angle), sin(angle) * 0.72)
	if drift_direction.length_squared() <= 0.001:
		drift_direction = Vector2(1.0, -0.55)
	drift_direction = drift_direction.normalized()

	var mist := fog_cluster.get_node_or_null("SteadyMist") as Node3D
	if mist == null:
		return
	for i in range(mist.get_child_count()):
		var layer := mist.get_child(i) as MeshInstance3D
		if layer == null:
			continue
		var material := layer.get_active_material(0) as ShaderMaterial
		if material == null:
			continue
		var layer_seed := variant_seed + i * 101
		material.set_shader_parameter("phase", float(i) * 3.17 + _seeded_range(layer_seed, 10, 0.0, TAU))
		material.set_shader_parameter("fog_alpha", (0.42 - float(i) * 0.060) * _seeded_range(layer_seed, 11, 0.88, 1.10))
		material.set_shader_parameter("cloud_scale", (1.12 + float(i) * 0.26) * _seeded_range(layer_seed, 12, 0.90, 1.18))
		material.set_shader_parameter("drift_speed", (0.090 + float(i) * 0.034) * _seeded_range(layer_seed, 13, 0.82, 1.28))
		material.set_shader_parameter("variant_uv_offset_a", Vector2(
			_seeded_range(layer_seed, 14, -0.18, 0.18),
			_seeded_range(layer_seed, 15, -0.16, 0.16)
		))
		material.set_shader_parameter("variant_uv_offset_b", Vector2(
			_seeded_range(layer_seed, 16, -0.14, 0.14),
			_seeded_range(layer_seed, 17, -0.18, 0.18)
		))
		material.set_shader_parameter("variant_drift", drift_direction.rotated(_seeded_range(layer_seed, 18, -0.38, 0.38)))
		material.set_shader_parameter("smoke_scale", _seeded_range(layer_seed, 19, 0.82, 1.20))
		material.set_shader_parameter("density_bias", _seeded_range(layer_seed, 20, -0.035, 0.045))
		material.set_shader_parameter("texture_mix", _seeded_range(layer_seed, 21, 0.36, 0.58))
		material.set_shader_parameter("smoke_rotation", Vector3(
			_seeded_range(layer_seed, 22, 0.0, TAU),
			_seeded_range(layer_seed, 23, 0.0, TAU),
			_seeded_range(layer_seed, 24, 0.0, TAU)
		))
		material.set_shader_parameter("smoke_flip", Vector2(
			-1.0 if _seeded_unit(layer_seed, 25) < 0.5 else 1.0,
			-1.0 if _seeded_unit(layer_seed, 26) < 0.5 else 1.0
		))
		material.set_shader_parameter("smoke_anchor", Vector2(
			_seeded_range(layer_seed, 27, -0.22, 0.22),
			_seeded_range(layer_seed, 28, -0.20, 0.20)
		))

func _make_native_stealth_fog_volume() -> FogVolume:
	var volume := FogVolume.new()
	volume.name = "NativeFogVolume"
	volume.position.z = STEALTH_FOG_PLANE_Z
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
		layer.position.z = STEALTH_FOG_LAYER_Z_BASE + float(i) * STEALTH_FOG_LAYER_Z_STEP
		mist.add_child(layer)
	return mist

func _update_steady_stealth_mist(fog_cluster: Node3D, local_size: Vector2) -> void:
	var mist := fog_cluster.get_node_or_null("SteadyMist") as Node3D
	if mist == null:
		return
	var base_scale := Vector2(maxf(0.52, local_size.x * 1.01), maxf(0.42, local_size.y * 1.00))
	for i in range(mist.get_child_count()):
		var layer := mist.get_child(i) as MeshInstance3D
		if layer == null:
			continue
		var layer_scale := 1.0 + float(i) * 0.015
		layer.scale = Vector3(base_scale.x * layer_scale, base_scale.y * layer_scale, 1.0)
		var material := layer.get_active_material(0) as ShaderMaterial
		if material != null and local_size.x > 0.0 and local_size.y > 0.0:
			material.set_shader_parameter("layer_card_scale", Vector2(
				layer.scale.x / local_size.x,
				layer.scale.y / local_size.y
			))

func _update_stealth_fog_cursor_effect(fog_cluster: Node3D, control_rect: Rect2) -> void:
	var cursor_uv := Vector2(-10.0, -10.0)
	var clear_strength := 0.0
	var brush_radius := 0.18
	var cursor_trail: Array[Vector4] = []
	cursor_trail.resize(STEALTH_FOG_CURSOR_TRAIL_COUNT)
	cursor_trail.fill(Vector4(-10.0, -10.0, 0.0, brush_radius))
	var hover_clear_uv_min := Vector2(2.0, 2.0)
	var hover_clear_uv_max := Vector2(-1.0, -1.0)
	var influence_rect := control_rect.grow(maxf(control_rect.size.x, control_rect.size.y) * 0.72)
	if _fog_cursor_actual_position != Vector2.INF \
			and control_rect.size.x > 0.0 \
			and control_rect.size.y > 0.0 \
			and influence_rect.has_point(_fog_cursor_actual_position):
		cursor_uv = Vector2(
			(_fog_cursor_actual_position.x - control_rect.position.x) / control_rect.size.x,
			(_fog_cursor_actual_position.y - control_rect.position.y) / control_rect.size.y
		)
		clear_strength = _fog_cursor_clear_strength
		brush_radius = STEALTH_FOG_CURSOR_EFFECT_RADIUS_PIXELS / maxf(control_rect.size.x, control_rect.size.y)
	for i in range(mini(_fog_cursor_trail.size(), STEALTH_FOG_CURSOR_TRAIL_COUNT)):
		var sample := _fog_cursor_trail[i]
		var sample_position := sample.get("position", Vector2.INF) as Vector2
		if sample_position == Vector2.INF or not influence_rect.has_point(sample_position):
			continue
		var sample_age := float(sample.get("age", STEALTH_FOG_CURSOR_TRAIL_LIFETIME))
		var sample_strength := pow(
			clampf(1.0 - sample_age / STEALTH_FOG_CURSOR_TRAIL_LIFETIME, 0.0, 1.0),
			1.35
		)
		cursor_trail[i] = Vector4(
			(sample_position.x - control_rect.position.x) / control_rect.size.x,
			(sample_position.y - control_rect.position.y) / control_rect.size.y,
			sample_strength,
			brush_radius
		)
	if control_rect.size.x > 0.0 and control_rect.size.y > 0.0:
		for clear_rect in _stealth_fog_hover_clear_rects:
			var overlap := control_rect.intersection(clear_rect)
			if overlap.size.x <= 0.0 or overlap.size.y <= 0.0:
				continue
			var clear_min := Vector2(
				(overlap.position.x - control_rect.position.x) / control_rect.size.x,
				(overlap.position.y - control_rect.position.y) / control_rect.size.y
			)
			var clear_max := Vector2(
				(overlap.position.x + overlap.size.x - control_rect.position.x) / control_rect.size.x,
				(overlap.position.y + overlap.size.y - control_rect.position.y) / control_rect.size.y
			)
			hover_clear_uv_min = Vector2(
				minf(hover_clear_uv_min.x, clear_min.x),
				minf(hover_clear_uv_min.y, clear_min.y)
			)
			hover_clear_uv_max = Vector2(
				maxf(hover_clear_uv_max.x, clear_max.x),
				maxf(hover_clear_uv_max.y, clear_max.y)
			)
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
			material.set_shader_parameter("cursor_clear_strength", clear_strength)
			material.set_shader_parameter("cursor_brush_radius", brush_radius)
			for i in range(STEALTH_FOG_CURSOR_TRAIL_COUNT):
				material.set_shader_parameter("cursor_trail_%d" % i, cursor_trail[i])
			material.set_shader_parameter("hover_clear_uv_min", hover_clear_uv_min)
			material.set_shader_parameter("hover_clear_uv_max", hover_clear_uv_max)

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
uniform float cursor_clear_strength = 0.0;
uniform float cursor_brush_radius = 0.18;
uniform vec4 cursor_trail_0 = vec4(-10.0, -10.0, 0.0, 0.18);
uniform vec4 cursor_trail_1 = vec4(-10.0, -10.0, 0.0, 0.18);
uniform vec4 cursor_trail_2 = vec4(-10.0, -10.0, 0.0, 0.18);
uniform vec4 cursor_trail_3 = vec4(-10.0, -10.0, 0.0, 0.18);
uniform vec4 cursor_trail_4 = vec4(-10.0, -10.0, 0.0, 0.18);
uniform vec4 cursor_trail_5 = vec4(-10.0, -10.0, 0.0, 0.18);
uniform vec2 hover_clear_uv_min = vec2(2.0, 2.0);
uniform vec2 hover_clear_uv_max = vec2(-1.0, -1.0);
uniform vec2 layer_card_scale = vec2(1.0, 1.0);
uniform vec2 variant_uv_offset_a = vec2(0.0, 0.0);
uniform vec2 variant_uv_offset_b = vec2(0.0, 0.0);
uniform vec2 variant_drift = vec2(1.0, -0.55);
uniform float smoke_scale = 1.0;
uniform vec3 smoke_rotation = vec3(0.0, 2.1, 4.2);
uniform vec2 smoke_flip = vec2(1.0, 1.0);
uniform vec2 smoke_anchor = vec2(0.0, 0.0);
uniform float density_bias = 0.0;
uniform float texture_mix = 0.46;

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

vec3 gradient_hash(vec3 p) {
	p = vec3(
		dot(p, vec3(127.1, 311.7, 74.7)),
		dot(p, vec3(269.5, 183.3, 246.1)),
		dot(p, vec3(113.5, 271.9, 124.6))
	);
	return normalize(-1.0 + 2.0 * fract(sin(p) * 43758.5453123));
}

float gradient_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);

	float n000 = dot(gradient_hash(i + vec3(0.0, 0.0, 0.0)), f - vec3(0.0, 0.0, 0.0));
	float n100 = dot(gradient_hash(i + vec3(1.0, 0.0, 0.0)), f - vec3(1.0, 0.0, 0.0));
	float n010 = dot(gradient_hash(i + vec3(0.0, 1.0, 0.0)), f - vec3(0.0, 1.0, 0.0));
	float n110 = dot(gradient_hash(i + vec3(1.0, 1.0, 0.0)), f - vec3(1.0, 1.0, 0.0));
	float n001 = dot(gradient_hash(i + vec3(0.0, 0.0, 1.0)), f - vec3(0.0, 0.0, 1.0));
	float n101 = dot(gradient_hash(i + vec3(1.0, 0.0, 1.0)), f - vec3(1.0, 0.0, 1.0));
	float n011 = dot(gradient_hash(i + vec3(0.0, 1.0, 1.0)), f - vec3(0.0, 1.0, 1.0));
	float n111 = dot(gradient_hash(i + vec3(1.0, 1.0, 1.0)), f - vec3(1.0, 1.0, 1.0));

	float nx00 = mix(n000, n100, u.x);
	float nx10 = mix(n010, n110, u.x);
	float nx01 = mix(n001, n101, u.x);
	float nx11 = mix(n011, n111, u.x);
	float nxy0 = mix(nx00, nx10, u.y);
	float nxy1 = mix(nx01, nx11, u.y);
	return mix(nxy0, nxy1, u.z) * 0.5 + 0.5;
}

float gradient_fbm(vec3 p) {
	float value = 0.0;
	float amplitude = 0.58;
	for (int i = 0; i < 4; i++) {
		value += amplitude * gradient_noise(p);
		p = p * 2.03 + vec3(17.1, 11.7, 7.3);
		amplitude *= 0.50;
	}
	return clamp(value, 0.0, 1.0);
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

float soft_rect_mask(vec2 p, vec2 rect_min, vec2 rect_max, float softness) {
	float left = smoothstep(rect_min.x - softness, rect_min.x + softness, p.x);
	float right = 1.0 - smoothstep(rect_max.x - softness, rect_max.x + softness, p.x);
	float top = smoothstep(rect_min.y - softness, rect_min.y + softness, p.y);
	float bottom = 1.0 - smoothstep(rect_max.y - softness, rect_max.y + softness, p.y);
	return clamp(left * right * top * bottom, 0.0, 1.0);
}

float cursor_trail_field(vec2 uv, vec4 sample_data) {
	vec2 sample_uv = vec2(0.5) + (sample_data.xy - vec2(0.5)) / max(layer_card_scale, vec2(0.001));
	float sample_radius = sample_data.w;
	return smoothstep(sample_radius, 0.0, length(uv - sample_uv)) * sample_data.z;
}

void fragment() {
	vec2 uv = UV;
	vec2 remapped_cursor_uv = vec2(0.5) + (cursor_uv - vec2(0.5)) / max(layer_card_scale, vec2(0.001));
	vec2 to_cursor = uv - remapped_cursor_uv;
	float motion_strength = clamp(cursor_clear_strength, 0.0, 1.0);
	float cursor_distance = length(to_cursor);
	float brush_radius = cursor_brush_radius;
	float brush_field = smoothstep(brush_radius, 0.0, cursor_distance);
	float pressure_radius = brush_radius * 1.36;
	float pressure_field = smoothstep(pressure_radius, 0.0, cursor_distance);
	float gust_field = max(brush_field * 0.88, pressure_field * 0.42) * motion_strength;
	float healing_clear = 0.0;
	healing_clear = max(healing_clear, cursor_trail_field(uv, cursor_trail_0));
	healing_clear = max(healing_clear, cursor_trail_field(uv, cursor_trail_1));
	healing_clear = max(healing_clear, cursor_trail_field(uv, cursor_trail_2));
	healing_clear = max(healing_clear, cursor_trail_field(uv, cursor_trail_3));
	healing_clear = max(healing_clear, cursor_trail_field(uv, cursor_trail_4));
	healing_clear = max(healing_clear, cursor_trail_field(uv, cursor_trail_5));
	vec2 radial_push = normalize(to_cursor + vec2(0.0001, 0.0001)) * gust_field * 0.18;
	vec2 stirred_uv = uv + radial_push;
	vec2 drift = variant_drift * TIME * drift_speed + vec2(phase * 0.017, phase * 0.013);
	float flow_time = TIME * (0.42 + drift_speed * 1.8) + phase;
	float broad = fbm(stirred_uv * cloud_scale + drift);
	float rolling = fbm(stirred_uv * cloud_scale * 1.72 - drift * 0.88 + phase);
	float fine = fbm(stirred_uv * cloud_scale * 3.1 + drift * 1.6 + phase);
	float ridge = smoothstep(0.060, 0.0, abs(cursor_distance - brush_radius)) * motion_strength * 0.035;
	float smoke_mask = 1.0;
	if (use_smoke_texture) {
		vec2 smoke_offset_a = vec2(sin(flow_time * 0.71), cos(flow_time * 0.53)) * 0.076;
		vec2 smoke_offset_b = vec2(cos(flow_time * 0.47 + 1.4), sin(flow_time * 0.61 - 0.8)) * 0.060;
		vec2 smoke_offset_c = vec2(sin(flow_time * 0.39 - 0.9), cos(flow_time * 0.44 + 1.1)) * 0.050;
		vec2 smoke_coord = (uv - vec2(0.5)) * smoke_flip + vec2(0.5) + smoke_anchor;
		vec2 smoke_base_a = (smoke_coord - vec2(0.5)) * smoke_scale + vec2(0.5) + variant_uv_offset_a;
		vec2 smoke_base_b = (smoke_coord - vec2(0.5)) * (smoke_scale * 1.08) + vec2(0.5) + variant_uv_offset_b;
		vec2 smoke_base_c = (smoke_coord - vec2(0.5)) * (smoke_scale * 0.92) + vec2(0.5) - variant_uv_offset_a * 0.6;
		vec2 smoke_uv_a = clamp(rotate_uv(smoke_base_a + smoke_offset_a, smoke_rotation.x + sin(flow_time * 0.33 + phase) * 0.105), vec2(0.0), vec2(1.0));
		vec2 smoke_uv_b = clamp(rotate_uv(smoke_base_b - smoke_offset_b, smoke_rotation.y - sin(flow_time * 0.29 + 0.6 + phase) * 0.085), vec2(0.0), vec2(1.0));
		vec2 smoke_uv_c = clamp(rotate_uv(smoke_base_c + smoke_offset_c, smoke_rotation.z + sin(flow_time * 0.25 + 1.9 + phase) * 0.070), vec2(0.0), vec2(1.0));
		float smoke_a = texture(smoke_texture, smoke_uv_a).a;
		float smoke_b = texture(smoke_texture, smoke_uv_b).a;
		float smoke_c = texture(smoke_texture, smoke_uv_c).a;
		smoke_mask = smoothstep(0.018, 0.62, max(max(smoke_a, smoke_b * 0.88), smoke_c * 0.76));
	}
	vec3 fog_field_a = vec3(
		stirred_uv * cloud_scale * 1.16 + drift * 1.15 + variant_uv_offset_a,
		phase * 0.19 + TIME * drift_speed * 0.66
	);
	vec3 fog_field_b = vec3(
		stirred_uv * cloud_scale * 2.05 - drift * 0.74 + variant_uv_offset_b,
		phase * 0.11 - TIME * drift_speed * 0.48
	);
	float gradient_cloud = gradient_fbm(fog_field_a);
	float gradient_detail = gradient_fbm(fog_field_b);
	float procedural_mist = smoothstep(0.16, 0.78, gradient_cloud * 0.68 + gradient_detail * 0.32);
	float density = 0.08 + density_bias + smoke_mask * (0.62 + broad * 0.20 + rolling * 0.14) + procedural_mist * 0.12 + fine * 0.035;
	if (use_cloud_texture) {
		vec2 cloud_uv_a = fract(stirred_uv * (cloud_scale * 0.58) + drift * 1.35 + vec2(phase * 0.037, phase * 0.021) + variant_uv_offset_a);
		vec2 cloud_uv_b = fract(stirred_uv * (cloud_scale * 0.91) - drift * 1.05 + vec2(phase * 0.019, -phase * 0.031) + variant_uv_offset_b);
		float texture_cloud = texture(cloud_texture, cloud_uv_a).r * 0.62 + texture(cloud_texture, cloud_uv_b).r * 0.38;
		density = mix(density, texture_cloud + smoke_mask * 0.55 + density_bias * 0.5, texture_mix * 0.16);
	}
	if (use_detail_texture) {
		vec2 detail_uv = fract(stirred_uv * (cloud_scale * 2.65) + drift * 2.20 + vec2(phase * 0.017, phase * 0.047) + variant_uv_offset_b * 1.7);
		float detail_noise = texture(detail_texture, detail_uv).r;
		density += (detail_noise - 0.5) * 0.075 * (1.0 - gust_field * 0.45);
	}
	density *= 0.94 + sin(flow_time * 0.66) * 0.060;
	vec2 remapped_hover_clear_min = vec2(0.5) + (hover_clear_uv_min - vec2(0.5)) / max(layer_card_scale, vec2(0.001));
	vec2 remapped_hover_clear_max = vec2(0.5) + (hover_clear_uv_max - vec2(0.5)) / max(layer_card_scale, vec2(0.001));
	float hover_clear = soft_rect_mask(uv, remapped_hover_clear_min, remapped_hover_clear_max, 0.026);
	density = clamp(density + ridge - gust_field * 1.18 - healing_clear * 1.06, 0.0, 1.0);
	density *= 1.0 - hover_clear;
	float edge_x = smoothstep(0.0, 0.075, uv.x) * smoothstep(0.0, 0.075, 1.0 - uv.x);
	float edge_y = smoothstep(0.0, 0.085, uv.y) * smoothstep(0.0, 0.085, 1.0 - uv.y);
	float feather = pow(edge_x * edge_y, 0.78);
	ALBEDO = fog_color.rgb;
	ALPHA = fog_alpha * density * feather;
}
"""
	material.shader = shader
	material.set_shader_parameter("fog_alpha", 0.42 - float(layer_index) * 0.060)
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
	if event is InputEventMouseMotion:
		_update_software_cursor_position((event as InputEventMouseMotion).position)
	if not _legacy_3d_shell_active:
		return
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
	var fog_mapped_position = _map_window_position_to_game_viewport(
		event.position + STEALTH_FOG_CURSOR_CENTER_OFFSET
	)
	if fog_mapped_position is Vector2:
		_update_stealth_fog_cursor_motion(fog_mapped_position)
	_update_existing_stealth_fog_cursor_effect()
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
	var fog_mapped_position = _map_window_position_to_game_viewport(
		event.position + STEALTH_FOG_CURSOR_CENTER_OFFSET
	)
	if fog_mapped_position is Vector2:
		_update_stealth_fog_cursor_motion(fog_mapped_position)
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

func _is_truthy_arg(value: Variant) -> bool:
	var text := str(value).strip_edges().to_lower()
	return text == "1" or text == "true" or text == "yes" or text == "on"

func _should_boot_server_runtime(launch_args: Dictionary) -> bool:
	if str(launch_args.get(MATCH_CONFIG_ARG, "")).strip_edges() != "":
		return true
	var requested_mode := str(launch_args.get(SERVER_MODE_ARG, "")).strip_edges().to_lower()
	if requested_mode == "lobby":
		return true
	return OS.has_feature("dedicated_server")
