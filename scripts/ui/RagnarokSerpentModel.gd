extends Node3D

## Lit geometry in an isolated transparent viewport; no dependency on the 3D shell.
const SKIN_SHADER := preload("res://shaders/ragnarok_serpent_skin.gdshader")
const EYE_SHADER := preload("res://shaders/ragnarok_serpent_eye.gdshader")
const CARD_ART := preload("res://images/card_art/powers/RagnarokEdit.png")
const EYE_RADIUS := 0.135
const EYE_STATION := 0.36
const EYE_ANGLE := 0.56
const SIDES := 40
const HEAD_SIDES := 64
const SCALE_SIDES := 20
const BODY_SUBDIVISIONS := 2
const SCALE_STRIDE := 2 * BODY_SUBDIVISIONS
const VENOM_SUBDIVISIONS := 8
const BODY_RADIUS_RATIO := 0.48
const MOUTH_FORWARD_RATIO := 1.4
const UPPER_HINGE := Vector3(-0.55, 0, 0.02)
const LOWER_HINGE := Vector3(-0.60, 0, -0.12)

var _body: MeshInstance3D
var _body_mesh := ArrayMesh.new()
var _plates: MultiMeshInstance3D
var _head := Node3D.new()
var _upper := Node3D.new()
var _lower := Node3D.new()
var _breath := OmniLight3D.new()
var _skin: ShaderMaterial
var _iris: ShaderMaterial
var _indices := PackedInt32Array()
var _ring_count := 0
var _scale_variation := PackedVector3Array()
var _venom_segments: Array[MeshInstance3D] = []
var _venom_drops: Array[MeshInstance3D] = []


func _ready() -> void:
	_skin = ShaderMaterial.new()
	_skin.shader = SKIN_SHADER
	_body = MeshInstance3D.new()
	_body.mesh = _body_mesh
	_body.material_override = _skin
	add_child(_body)
	_plates = MultiMeshInstance3D.new()
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = _make_scale_mesh()
	_plates.multimesh = instances
	_plates.material_override = _painted_scale_material(Vector4(0.26, 0.72, 0.46, 0.105))
	add_child(_plates)
	_iris = ShaderMaterial.new()
	_iris.shader = EYE_SHADER
	_iris.set_shader_parameter("eye_radius", EYE_RADIUS)
	_build_head()
	_build_lighting()


func _painted_scale_material(art_region: Vector4) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SKIN_SHADER
	material.set_shader_parameter("raised_plate", true)
	material.set_shader_parameter("card_art", CARD_ART)
	material.set_shader_parameter("art_region", art_region)
	return material


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	return result


func _build_lighting() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.44, 0.49, 0.52)
	environment.environment.ambient_light_energy = 0.72
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, -28, -22)
	key.light_color = Color(1.0, 0.84, 0.59)
	key.light_energy = 2.1
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 5000.0
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(38, 52, 155)
	rim.light_color = Color(0.27, 0.72, 0.94)
	rim.light_energy = 1.15
	add_child(rim)
	_breath.light_color = Color(0.32, 1.0, 0.16)
	add_child(_breath)


func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _build_head() -> void:
	add_child(_head)
	_head.add_child(_upper)
	_head.add_child(_lower)
	var head_skin := ShaderMaterial.new()
	head_skin.shader = SKIN_SHADER
	head_skin.set_shader_parameter("scale_count", Vector2(11, 14))
	# A broad crown tapers into the short, rounded snout in the painting.
	var skull := [
		Vector4(-1.05, 0.39, 0.035, 0.30), Vector4(-0.70, 0.63, 0.12, 0.39),
		Vector4(-0.20, 0.83, 0.17, 0.42), Vector4(0.35, 0.75, 0.12, 0.38),
		Vector4(0.95, 0.59, 0.055, 0.29), Vector4(1.23, 0.51, 0.015, 0.24),
		Vector4(1.39, 0.34, -0.01, 0.17), Vector4(1.46, 0.005, -0.025, 0.03),
	]
	_add_mesh(_upper, _profile_mesh(skull, true), head_skin)
	_build_head_shields(skull)
	var jaw := [
		Vector4(-0.75, 0.25, -0.15, 0.12), Vector4(-0.28, 0.69, -0.19, 0.15),
		Vector4(0.45, 0.73, -0.22, 0.14), Vector4(1.12, 0.55, -0.16, 0.10),
		Vector4(1.36, 0.29, -0.10, 0.08), Vector4(1.42, 0.005, -0.10, 0.02),
	]
	_add_mesh(_lower, _profile_mesh(jaw), head_skin)
	var mouth := _material(Color(0.07, 0.025, 0.025), 0.05, 0.31)
	var palate := SphereMesh.new()
	palate.radius = 0.8
	palate.height = 1.6
	var palate_mesh := _add_mesh(_lower, palate, mouth, Vector3(0.3, 0, -0.06))
	palate_mesh.scale = Vector3(1.35, 0.9, 0.065)
	var roof := _add_mesh(_upper, palate, mouth, Vector3(0.28, 0, -0.12))
	roof.scale = Vector3(1.27, 0.84, 0.045)
	var cavity := _add_mesh(_head, palate, _material(Color(0.006, 0.009, 0.004), 0.0, 0.95), Vector3(-0.25, 0, -0.02))
	cavity.scale = Vector3(0.6, 0.72, 0.5)
	var ivory := _material(Color(0.80, 0.79, 0.58), 0.08, 0.24)
	var fang_mesh := _make_fang_mesh()
	for side in [-1.0, 1.0]:
		for tooth in range(4):
			var fang := _add_mesh(_upper, fang_mesh, ivory, Vector3(0.30 + float(tooth) * 0.28, side * (0.68 - float(tooth) * 0.10), -0.07))
			fang.scale = Vector3.ONE * (0.75 if tooth == 1 else 0.34)
			var lower_tooth := _add_mesh(_lower, fang_mesh, ivory, Vector3(0.3 + float(tooth) * 0.27, side * (0.63 - float(tooth) * 0.09), -0.12))
			lower_tooth.rotation.x = PI
			lower_tooth.scale = Vector3.ONE * 0.22
		_build_eye(skull, side)
		_build_lip_crease(skull, side)
		var nostril := SphereMesh.new()
		nostril.radius = 0.045
		nostril.height = 0.09
		var nose_angle := 0.96 if side > 0.0 else PI - 0.96
		var nose_frame := _skull_frame(skull, 0.67, nose_angle)
		var nose := _add_mesh(_upper, nostril, mouth)
		nose.transform = nose_frame.scaled_local(Vector3(1.25, 0.64, 0.26))
	_build_venom()
	# Preserve the rest shape while rotating each jaw around its rear hinge.
	_upper.position = UPPER_HINGE
	for child in _upper.get_children():
		(child as Node3D).position -= UPPER_HINGE
	_lower.position = LOWER_HINGE
	for child in _lower.get_children():
		(child as Node3D).position -= LOWER_HINGE


func _build_eye(profile: Array, side: float) -> void:
	var eye := SphereMesh.new()
	eye.radius = EYE_RADIUS
	eye.height = EYE_RADIUS * 2.0
	var angle := EYE_ANGLE if side > 0.0 else PI - EYE_ANGLE
	var socket := _skull_frame(profile, EYE_STATION, angle)
	var surround := _add_mesh(_upper, eye, _material(Color(0.012, 0.018, 0.007), 0.0, 0.40))
	surround.transform = socket.scaled_local(Vector3(1.42, 1.02, 0.37))
	var iris := _add_mesh(_upper, eye, _iris)
	socket.origin -= socket.basis.z * 0.026
	iris.transform = socket.scaled_local(Vector3(1.02, 0.77, 0.68))


func _scale_color(row: float, angle: float, seed: float, facial: bool = false) -> Color:
	# Broken longitudinal gold islands over black/olive hide, matching RagnarokEdit.
	var fleck := fposmod(sin(seed * 12.9898 + 78.233) * 43758.5453, 1.0)
	var ribbon := 0.5 + 0.5 * cos(angle * 3.0 + sin(row * 0.27) * 1.2)
	var gold := smoothstep(0.58, 0.86, ribbon) * (0.55 + fleck * 0.45)
	if facial:
		gold = maxf(gold, smoothstep(0.44, 0.90, fleck) * 0.85)
	var hide := Color(0.025, 0.027, 0.017).lerp(Color(0.16, 0.145, 0.072), fleck * 0.75)
	var highlight := Color(0.40, 0.36, 0.19).lerp(Color(0.84, 0.81, 0.59), fleck * fleck)
	return hide.lerp(highlight, gold)


func _build_head_shields(profile: Array) -> void:
	const ROWS := 10
	const COLUMNS := 9
	var poses: Array[Transform3D] = []
	var colors := PackedColorArray()
	for row in ROWS:
		for column in COLUMNS:
			var index := row * COLUMNS + column
			var variation := _plate_variation(index + 137)
			var station := 0.17 + (float(row) + float(column % 2) * 0.32) / float(ROWS - 1) * 0.73
			var angle := PI * (0.085 + float(column) / float(COLUMNS - 1) * 0.83)
			angle += variation.z * 0.42
			var near_eye := absf(station - EYE_STATION) < 0.11 and absf(minf(angle, PI - angle) - EYE_ANGLE) < 0.29
			if near_eye:
				continue
			var frame := _skull_frame(profile, station, angle)
			# Angle the tips toward the neck, with broader scales down the crown.
			frame.basis.x = -frame.basis.x
			frame.basis.y = -frame.basis.y
			frame.origin += frame.basis.z * 0.004
			var width := minf(0.13, _profile_at(profile, station).y * 0.25)
			poses.append(frame.scaled_local(Vector3(0.145 * variation.x, width * variation.y, 0.047)))
			var color := _scale_color(float(row) + 7.0, angle, float(index) + 137.0, true)
			var cheek := 1.0 - smoothstep(0.34, 0.86, sin(angle))
			colors.append(color.darkened(cheek * 0.58))
	var plates := MultiMeshInstance3D.new()
	plates.multimesh = MultiMesh.new()
	plates.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	plates.multimesh.use_colors = true
	plates.multimesh.mesh = _plates.multimesh.mesh
	plates.multimesh.instance_count = poses.size()
	plates.material_override = _painted_scale_material(Vector4(0.284, 0.250, 0.086, 0.039))
	_upper.add_child(plates)
	for index in poses.size():
		plates.multimesh.set_instance_transform(index, poses[index])
		plates.multimesh.set_instance_color(index, colors[index])


func _plate_variation(index: int) -> Vector3:
	var seed := float(index)
	return Vector3(
		lerpf(0.82, 1.16, fposmod(seed * 0.618034, 1.0)),
		lerpf(0.86, 1.15, fposmod(seed * 0.414214, 1.0)),
		lerpf(-0.105, 0.105, fposmod(seed * 0.732051, 1.0))
	)


func _build_lip_crease(profile: Array, side: float) -> void:
	var lip := CylinderMesh.new()
	lip.top_radius = 0.016
	lip.bottom_radius = 0.016
	lip.height = 1.0
	lip.radial_segments = 8
	var crease := _material(Color(0.008, 0.012, 0.004), 0.0, 0.33)
	for index in range(14):
		var a := _profile_at(profile, 0.28 + float(index) / 14.0 * 0.68)
		var b := _profile_at(profile, 0.28 + float(index + 1) / 14.0 * 0.68)
		var start := Vector3(a.x, side * a.y * 0.92, a.z - a.w * 0.35)
		var finish := Vector3(b.x, side * b.y * 0.92, b.z - b.w * 0.35)
		var direction := finish - start
		var segment := _add_mesh(_upper, lip, crease, (start + finish) * 0.5)
		segment.basis = Basis(Quaternion(Vector3.UP, direction.normalized())) * Basis.from_scale(Vector3(1.0, direction.length(), 1.0))


func _build_venom() -> void:
	var slime := _material(Color(0.13, 0.55, 0.025), 0.02, 0.13)
	slime.clearcoat_enabled = true
	slime.clearcoat = 0.8
	slime.emission_enabled = true
	slime.emission = Color(0.10, 0.48, 0.015)
	slime.emission_energy_multiplier = 0.4
	var thread := CylinderMesh.new()
	thread.top_radius = 0.014
	thread.bottom_radius = 0.014
	thread.height = 1.0
	thread.radial_segments = 8
	var drop := SphereMesh.new()
	drop.radius = 0.027
	drop.height = 0.054
	for index in range(3):
		for _piece in VENOM_SUBDIVISIONS:
			_venom_segments.append(_add_mesh(_head, thread, slime))
		_venom_drops.append(_add_mesh(_head, drop, slime))


func _update_venom(jaw: float, age: float) -> void:
	for index in range(3):
		var x := 0.82 + float(index) * 0.19
		var side := -0.43 + float(index) * 0.42
		var start := _upper.transform * (Vector3(x, side, -0.12) - UPPER_HINGE)
		var finish := _lower.transform * (Vector3(x + 0.03, side * 0.9, -0.10) - LOWER_HINGE)
		var sag := 0.21 + jaw * 0.12 + sin(age * 2.0 + float(index)) * 0.035
		var control := (start + finish) * 0.5 - Vector3(0, 0, sag * 2.0)
		for piece in VENOM_SUBDIVISIONS:
			var t0 := float(piece) / float(VENOM_SUBDIVISIONS)
			var t1 := float(piece + 1) / float(VENOM_SUBDIVISIONS)
			var a := start.lerp(control, t0).lerp(control.lerp(finish, t0), t0)
			var b := start.lerp(control, t1).lerp(control.lerp(finish, t1), t1)
			var direction := b - a
			var strand := _venom_segments[index * VENOM_SUBDIVISIONS + piece]
			var thickness := 0.55 + sin((t0 + t1) * 0.5 * PI) * 0.45
			strand.position = (a + b) * 0.5
			strand.basis = Basis(Quaternion(Vector3.UP, direction.normalized())) * Basis.from_scale(Vector3(thickness, direction.length(), thickness))
		_venom_drops[index].position = (start + finish) * 0.5 - Vector3(0, 0, sag)
		_venom_drops[index].scale = Vector3(0.8, 0.8, 1.5)


func set_pose(spine: PackedVector2Array, radii: PackedFloat32Array, heading: Vector2, jaw: float, unit: float, age: float) -> void:
	if spine.size() < 2:
		return
	# Smooth the surface while retaining the existing movement control points.
	var surface_spine := PackedVector2Array()
	var surface_radii := PackedFloat32Array()
	for index in range(spine.size() - 1):
		for sample in BODY_SUBDIVISIONS:
			var t := float(sample) / float(BODY_SUBDIVISIONS)
			surface_spine.append(spine[index].cubic_interpolate(spine[index + 1], spine[maxi(0, index - 1)], spine[mini(spine.size() - 1, index + 2)], t))
			surface_radii.append(lerpf(radii[index], radii[index + 1], t))
	surface_spine.append(spine[spine.size() - 1])
	surface_radii.append(radii[radii.size() - 1])
	_update_body(surface_spine, surface_radii, unit, age)
	# Head proportions follow the neck, never the row width or swallowing bulge.
	var radius := minf(radii[0], unit * BODY_RADIUS_RATIO)
	var growth := radius / (unit * BODY_RADIUS_RATIO)
	_head.position = _world_point(spine[0], _body_height(0, radius, unit, age))
	var facing := Basis(Vector3.BACK, -heading.angle())
	var lift := Basis(Vector3.UP, -0.22 - jaw * 0.10)
	_head.basis = facing * lift * Basis(Vector3.RIGHT, 0.19 * (1.0 - jaw * 0.65))
	_head.scale = Vector3(radius * 1.40, radius * 1.30, radius * 1.20)
	_upper.rotation.y = -jaw * 0.28
	_lower.rotation.y = jaw * 0.85
	_iris.set_shader_parameter("pupil_width", lerpf(0.24, 0.32, jaw))
	_update_venom(jaw, age)
	_breath.position = _head.position + Vector3(heading.x, -heading.y, 0.3) * unit * 0.8
	_breath.omni_range = unit * 4.0
	_breath.light_energy = (0.25 + jaw * 1.4) * growth


func _world_point(point: Vector2, height: float) -> Vector3:
	return Vector3(point.x, -point.y, height)

func _body_height(ring: float, radius: float, unit: float, age: float) -> float:
	return unit * (0.25 + sin(float(ring) * 0.14 - age * 1.6) * 0.10) * minf(1.0, radius / (unit * 0.12))


func _update_body(spine: PackedVector2Array, radii: PackedFloat32Array, unit: float, age: float) -> void:
	if _ring_count != spine.size():
		_ring_count = spine.size()
		_indices = _tube_indices(_ring_count, SIDES)
		_plates.multimesh.instance_count = ((_ring_count + SCALE_STRIDE - 3) / SCALE_STRIDE) * SCALE_SIDES
		_scale_variation.resize(_plates.multimesh.instance_count)
		for index in _plates.multimesh.instance_count:
			var row := float(index / SCALE_SIDES)
			var side_angle := float(index % SCALE_SIDES) / float(SCALE_SIDES) * TAU
			_plates.multimesh.set_instance_color(index, _scale_color(row, side_angle, float(index)))
			_scale_variation[index] = _plate_variation(index)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var count := _ring_count * (SIDES + 1)
	vertices.resize(count)
	normals.resize(count)
	tangents.resize(count * 4)
	uvs.resize(count)
	var centers := PackedVector3Array()
	for ring in _ring_count:
		centers.append(_world_point(spine[ring], _body_height(float(ring) / float(BODY_SUBDIVISIONS), radii[ring], unit, age)))
	var plate_index := 0
	for ring in _ring_count:
		var before := centers[maxi(0, ring - 1)]
		var after := centers[mini(_ring_count - 1, ring + 1)]
		var forward := (before - after).normalized()
		if forward.is_zero_approx():
			forward = Vector3.RIGHT
		var across := Vector3(forward.y, -forward.x, 0.0).normalized()
		if across.is_zero_approx():
			across = Vector3.UP
		var up := across.cross(forward).normalized()
		var center := centers[ring]
		var radius := radii[ring]
		for side in range(SIDES + 1):
			var angle := float(side) / float(SIDES) * TAU
			var normal := across * cos(angle) + up * sin(angle)
			var index := ring * (SIDES + 1) + side
			vertices[index] = center + normal * radius
			normals[index] = normal
			uvs[index] = Vector2(float(ring) / float(_ring_count - 1), float(side) / float(SIDES))
			tangents[index * 4] = -forward.x
			tangents[index * 4 + 1] = -forward.y
			tangents[index * 4 + 2] = -forward.z
			tangents[index * 4 + 3] = -1.0
		if ring > 0 and ring < _ring_count - 1 and (ring - 1) % SCALE_STRIDE == 0:
			for side in SCALE_SIDES:
				if plate_index >= _plates.multimesh.instance_count:
					break
				var row := (ring - 1) / SCALE_STRIDE
				var variation := _scale_variation[plate_index]
				var angle := (float(side) + (0.5 if row % 2 == 0 else 0.0)) / float(SCALE_SIDES) * TAU + variation.z * 0.32
				var normal := across * cos(angle) + up * sin(angle)
				var circumference := -across * sin(angle) + up * cos(angle)
				var basis := Basis(-forward, -circumference, normal)
				var plate_size := Vector3(minf(unit * 0.145, radius * 0.65) * variation.x, maxf(0.5, radius * 0.33 * variation.y), maxf(0.3, radius * 0.10))
				basis = basis * Basis.from_scale(plate_size)
				_plates.multimesh.set_instance_transform(plate_index, Transform3D(basis, center + normal * radius * 0.997))
				plate_index += 1
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	_body_mesh.clear_surfaces()
	_body_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _tube_indices(rings: int, sides: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for ring in range(rings - 1):
		for side in sides:
			var a := ring * (sides + 1) + side
			var b := a + sides + 1
			indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	return indices


func _profile_mesh(profile: Array, face: bool = false) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	const RINGS := 65
	for ring in RINGS:
		var t := float(ring) / float(RINGS - 1)
		var shape := _profile_at(profile, t)
		var before := _profile_at(profile, maxf(0.0, t - 0.002))
		var after := _profile_at(profile, minf(1.0, t + 0.002))
		for side in range(HEAD_SIDES + 1):
			var angle := float(side) / float(HEAD_SIDES) * TAU
			vertices.append(_profile_point(shape, angle, face))
			var along := (_profile_point(after, angle, face) - _profile_point(before, angle, face)).normalized()
			var across := _profile_point(shape, angle + 0.005, face) - _profile_point(shape, angle - 0.005, face)
			normals.append(across.cross(along).normalized())
			tangents.append_array(PackedFloat32Array([along.x, along.y, along.z, -1.0]))
			uvs.append(Vector2(float(ring) / float(RINGS - 1), float(side) / float(HEAD_SIDES)))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = _tube_indices(RINGS, HEAD_SIDES)
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _profile_point(shape: Vector4, angle: float, face: bool) -> Vector3:
	var point := Vector3(shape.x, cos(angle) * shape.y, shape.z + sin(angle) * shape.w)
	if face and sin(angle) > 0.0:
		var side_angle := acos(absf(cos(angle)))
		var orbit := Vector2((shape.x - 0.085) / 0.25, (side_angle - EYE_ANGLE) / 0.23)
		var socket := exp(-orbit.length_squared())
		var ridge := Vector2((shape.x - 0.015) / 0.53, (side_angle - 0.92) / 0.27)
		var brow := exp(-ridge.length_squared())
		point.y *= 1.0 - socket * 0.095
		point.z += brow * 0.075 - socket * 0.066
	return point

func _skull_frame(profile: Array, station: float, angle: float) -> Transform3D:
	var shape := _profile_at(profile, station)
	var before := _profile_point(_profile_at(profile, station - 0.002), angle, true)
	var after := _profile_point(_profile_at(profile, station + 0.002), angle, true)
	var along := (after - before).normalized()
	var across := _profile_point(shape, angle + 0.005, true) - _profile_point(shape, angle - 0.005, true)
	var normal := across.cross(along).normalized()
	return Transform3D(Basis(along, normal.cross(along), normal), _profile_point(shape, angle, true))

func _profile_at(profile: Array, progress: float) -> Vector4:
	var sample := progress * float(profile.size() - 1)
	var index := mini(profile.size() - 2, int(sample))
	var t := sample - float(index)
	var a: Vector4 = profile[maxi(0, index - 1)]
	var b: Vector4 = profile[index]
	var c: Vector4 = profile[index + 1]
	var d: Vector4 = profile[mini(profile.size() - 1, index + 2)]
	var shape := 0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t)
	shape.y = maxf(0.005, shape.y)
	shape.w = maxf(0.005, shape.w)
	return shape


func _make_scale_mesh() -> ArrayMesh:
	# The painting's scales have uneven polygonal borders and broad gold faces.
	const OUTLINE := 8
	const RINGS := 3
	var outline := PackedVector2Array([
		Vector2(1.0, 0.0), Vector2(0.62, 0.64), Vector2(-0.05, 0.90), Vector2(-0.76, 0.68),
		Vector2(-0.98, 0.06), Vector2(-0.70, -0.65), Vector2(0.03, -0.88), Vector2(0.68, -0.62),
	])
	var vertices := PackedVector3Array([Vector3(0.08, 0, 0.34)])
	for ring in RINGS:
		var radius := float(ring + 1) / float(RINGS)
		for index in OUTLINE:
			var x := outline[index].x * radius
			var y := outline[index].y * radius
			# The edges curve into the skin, with the trailing tip raised slightly.
			var z := 0.34 * (1.0 - radius * radius) - 0.51 * y * y - 0.07 * x * x
			z += smoothstep(0.3, 0.95, x) * 0.095
			vertices.append(Vector3(x, y, z))
	var indices := PackedInt32Array()
	for index in OUTLINE:
		indices.append_array(PackedInt32Array([0, 1 + (index + 1) % OUTLINE, 1 + index]))
	for ring in range(RINGS - 1):
		for index in OUTLINE:
			var a := 1 + ring * OUTLINE + index
			var b := 1 + ring * OUTLINE + (index + 1) % OUTLINE
			var c := a + OUTLINE
			var d := b + OUTLINE
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		var vertex := vertices[index]
		surface.set_uv(Vector2(vertex.x, vertex.y) * 0.5 + Vector2.ONE * 0.5)
		surface.add_vertex(vertex)
	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()


func _make_fang_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices := PackedVector3Array()
	const RINGS := 12
	const FANG_SIDES := 10
	for ring in RINGS:
		var t := float(ring) / float(RINGS - 1)
		var radius := 0.09 * pow(1.0 - t, 0.75) + 0.001
		for side in range(FANG_SIDES + 1):
			var angle := float(side) / float(FANG_SIDES) * TAU
			vertices.append(Vector3(cos(angle) * radius - t * t * 0.15, sin(angle) * radius, -t * 0.67))
	for index in _tube_indices(RINGS, FANG_SIDES):
		surface.add_vertex(vertices[index])
	surface.generate_normals()
	return surface.commit()
