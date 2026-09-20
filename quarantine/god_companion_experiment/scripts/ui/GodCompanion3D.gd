class_name GodCompanion3D
extends SubViewportContainer

const VIEWPORT_SIZE := Vector2i(224, 224)
const FRONT_MESH_PATH := "res://images/fx/god_companion/companion_front_small.obj"
const DIFFUSE_TEXTURE_PATH := "res://images/fx/god_companion/companion_diffuse.png"

const MODEL_MIN := Vector3(-0.083982, 0.000006, -0.205153)
const MODEL_MAX := Vector3(0.062406, 0.635457, 0.205612)
const MODEL_CENTER := (MODEL_MIN + MODEL_MAX) * 0.5

var _viewport: SubViewport = null
var _world_root: Node3D = null
var _companion_root: Node3D = null
var _visual_root: Node3D = null
var _body_root: Node3D = null
var _walk_time: float = 0.0
var _god_card_name: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	custom_minimum_size = Vector2(112.0, 112.0)
	size = custom_minimum_size
	_build_viewport()
	_build_world()
	set_process(true)

func set_god_card(card: Card) -> void:
	var next_name := card.card_name if card != null else ""
	if next_name == _god_card_name:
		return
	_god_card_name = next_name
	_walk_time = _get_card_walk_seed(_god_card_name)

func _process(delta: float) -> void:
	if _companion_root == null or not is_instance_valid(_companion_root):
		return
	_walk_time += delta
	var orbit_angle := _walk_time * 0.66
	var stride := _walk_time * 7.0
	_companion_root.position = Vector3(cos(orbit_angle) * 0.13, 0.0, sin(orbit_angle) * 0.07)
	_companion_root.rotation.y = -orbit_angle * 0.35
	if _body_root != null:
		_body_root.position.y = absf(sin(stride)) * 0.025
		_body_root.rotation.z = sin(stride * 0.5) * 0.035
		_body_root.rotation.x = sin(stride) * 0.018

func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "GodCompanionViewport"
	_viewport.size = VIEWPORT_SIZE
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

func _build_world() -> void:
	_world_root = Node3D.new()
	_world_root.name = "CompanionWorld"
	_viewport.add_child(_world_root)

	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0.0, 0.72, 2.25)
	camera.fov = 24.0
	camera.near = 0.02
	camera.far = 12.0
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.66, 0.0), Vector3.UP)
	_world_root.add_child(camera)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.light_energy = 1.35
	key_light.rotation_degrees = Vector3(-46.0, -24.0, 0.0)
	_world_root.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.name = "FillLight"
	fill_light.position = Vector3(0.45, 1.25, 1.1)
	fill_light.light_energy = 0.75
	fill_light.omni_range = 3.0
	_world_root.add_child(fill_light)

	_companion_root = Node3D.new()
	_companion_root.name = "CompanionRoot"
	_world_root.add_child(_companion_root)

	_body_root = Node3D.new()
	_body_root.name = "BodyRoot"
	_body_root.scale = Vector3.ONE * 1.75
	_companion_root.add_child(_body_root)
	_build_textured_figure(_body_root)
	_build_shadow(_companion_root)

func _build_textured_figure(parent: Node3D) -> void:
	var mesh := _load_obj_mesh(FRONT_MESH_PATH)
	if mesh == null:
		push_warning("God companion mesh could not be loaded: %s" % FRONT_MESH_PATH)
		return

	_visual_root = Node3D.new()
	_visual_root.name = "FrontFigureRoot"
	_visual_root.rotation.y = PI * 0.5
	parent.add_child(_visual_root)

	var instance := MeshInstance3D.new()
	instance.name = "CloakedCompanion"
	instance.mesh = mesh
	instance.material_override = _make_companion_material()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = Vector3(-MODEL_CENTER.x, -MODEL_MIN.y, -MODEL_CENTER.z)
	_visual_root.add_child(instance)

func _load_obj_mesh(path: String) -> ArrayMesh:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null

	var source_vertices := PackedVector3Array()
	var source_uvs := PackedVector2Array()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#") or line.begins_with("o "):
			continue
		if line.begins_with("v "):
			var parts := line.split(" ", false)
			if parts.size() >= 4:
				source_vertices.append(Vector3(parts[1].to_float(), parts[2].to_float(), parts[3].to_float()))
		elif line.begins_with("vt "):
			var parts := line.split(" ", false)
			if parts.size() >= 3:
				source_uvs.append(Vector2(parts[1].to_float(), 1.0 - parts[2].to_float()))
		elif line.begins_with("f "):
			var parts := line.split(" ", false)
			if parts.size() < 4:
				continue
			for i in range(1, 4):
				var indices := parts[i].split("/")
				var vertex_index := indices[0].to_int() - 1
				var uv_index := indices[1].to_int() - 1 if indices.size() > 1 and not indices[1].is_empty() else -1
				if vertex_index < 0 or vertex_index >= source_vertices.size():
					continue
				if uv_index >= 0 and uv_index < source_uvs.size():
					surface.set_uv(source_uvs[uv_index])
				else:
					surface.set_uv(Vector2.ZERO)
				surface.add_vertex(source_vertices[vertex_index])

	surface.generate_normals()
	return surface.commit()

func _make_companion_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.roughness = 0.88
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var texture := load(DIFFUSE_TEXTURE_PATH)
	if texture is Texture2D:
		material.albedo_texture = texture
	return material

func _build_shadow(parent: Node3D) -> void:
	var shadow_material := StandardMaterial3D.new()
	shadow_material.albedo_color = Color(0.0, 0.0, 0.0, 0.28)
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := CylinderMesh.new()
	mesh.height = 0.01
	mesh.top_radius = 0.32
	mesh.bottom_radius = 0.32
	mesh.radial_segments = 28
	var shadow := MeshInstance3D.new()
	shadow.name = "GroundShadow"
	shadow.mesh = mesh
	shadow.material_override = shadow_material
	shadow.scale = Vector3(1.25, 1.0, 0.50)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shadow)

func _get_card_walk_seed(card_name: String) -> float:
	var hash_value: int = absi(card_name.hash())
	return float(hash_value % 1000) / 1000.0 * TAU
