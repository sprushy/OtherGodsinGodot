extends Node3D
## Geometry only: the slotted casing and the internal pulley turn on one bearing.

const SLOT_HALF := 0.96
const ROPE_TOP := 2.02
const ROPE_REST := 0.95
const AGED_SURFACE := preload("res://quarantine/mechanical_turn_tower/shaders/ancient_tower_surface.gdshader")

var casing: Node3D
var grip: Node3D
var _bell_pivot: Node3D
var _rope: MeshInstance3D
var _rope_mesh: CylinderMesh
var _pulley: MeshInstance3D
var _bronze: ShaderMaterial
var _iron: ShaderMaterial
var _trim: ShaderMaterial
var _casing_metal: ShaderMaterial
var _rope_material: ShaderMaterial
var _wood: ShaderMaterial
var _swing_time := 10.0
var _strike_strength := 0.0


func _ready() -> void:
	_bronze = _material(Color("986333"), Color("35594a"), Color("bc955c"), 0.70, 0.63, 0.52)
	_iron = _material(Color("302b25"), Color("503724"), Color("736651"), 0.50, 0.82, 0.70)
	_trim = _material(Color("a17b44"), Color("4d6248"), Color("ceb17a"), 0.68, 0.61, 0.40)
	_casing_metal = _material(Color("665035"), Color("2f5144"), Color("a5804c"), 0.60, 0.77, 0.78)
	_rope_material = _material(Color("b59968"), Color("55412c"), Color("d3bd8d"), 0.0, 0.98, 0.3, 2)
	_wood = _material(Color("715032"), Color("30241a"), Color("ac8957"), 0.0, 0.90, 0.5, 3)
	_build_base()
	_build_casing()
	_build_bell()
	_build_pull_mechanism()


func _process(delta: float) -> void:
	if _swing_time < 3.0:
		_swing_time += delta
		_bell_pivot.rotation.z = sin(_swing_time * 12.0) * exp(-2.3 * _swing_time) * _strike_strength * 0.19
	else:
		_bell_pivot.rotation.z = 0.0


func strike(strength: float) -> void:
	_strike_strength = strength
	_swing_time = 0.0


func set_pull(amount: float) -> void:
	var bottom := ROPE_REST - amount * 0.40
	_rope_mesh.height = ROPE_TOP - bottom
	_rope.position.y = (ROPE_TOP + bottom) * 0.5
	grip.position.y = bottom
	_pulley.rotation.z = amount * 1.4
	if _swing_time >= 3.0:
		_bell_pivot.rotation.z = -amount * 0.08


func _material(color: Color, patina: Color, wear: Color, metal: float, roughness: float, aging: float, kind: int = 0) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = AGED_SURFACE
	result.set_shader_parameter("base_color", color)
	result.set_shader_parameter("patina_color", patina)
	result.set_shader_parameter("wear_color", wear)
	result.set_shader_parameter("metalness", metal)
	result.set_shader_parameter("surface_roughness", roughness)
	result.set_shader_parameter("aging", aging)
	result.set_shader_parameter("surface_kind", kind)
	return result


func _mesh(parent: Node3D, mesh: Mesh, material: Material, position: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node3D, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	return _mesh(parent, mesh, material, position)


func _box(parent: Node3D, dimensions: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _mesh(parent, mesh, material, position)


func _sphere(parent: Node3D, radius: float, position: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	_mesh(parent, mesh, material, position)


func _ring(parent: Node3D, radius: float, thickness: float, height: float, material: Material) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 64
	mesh.ring_segments = 10
	_mesh(parent, mesh, material, Vector3(0.0, height, 0.0))


func _build_base() -> void:
	var stone := _material(Color("514c3b"), Color("3e4a30"), Color("a09473"), 0.0, 0.96, 0.60, 1)
	_mesh(self, _worn_plinth(), stone, Vector3.ZERO)
	_cylinder(self, 1.02, 0.12, Vector3(0.0, 0.22, 0.0), _iron)
	_ring(self, 1.015, 0.028, 0.18, _trim)
	_ring(self, 0.99, 0.025, 0.32, _trim)
	for step in range(24):
		var angle := float(step) * TAU / 24.0
		var height := 0.085 + sin(float(step) * 2.7) * 0.012
		var tooth := _box(self, Vector3(0.12, height, 0.10), Vector3(sin(angle), 0.27, cos(angle)), _bronze)
		tooth.rotation.y = angle
	# Two fixed feet establish which side of the table the tower belongs to.
	for side in [-1.0, 1.0]:
		_box(self, Vector3(0.35, 0.09, 0.20), Vector3(0.0, 0.16, side * 1.04), _iron)
		_sphere(self, 0.045, Vector3(0.0, 0.22, side * 1.04), _trim)


func _build_casing() -> void:
	casing = Node3D.new()
	casing.name = "RotatingCasing"
	add_child(casing)
	# Hand-cast bronze shell, with the full functional slot kept clear.
	_mesh(casing, _sector(0.88, 0.96, 0.43, 2.43, SLOT_HALF, TAU - SLOT_HALF), _casing_metal, Vector3.ZERO)
	# The slot extends into the roof, so the overhead camera can see the bell.
	_mesh(casing, _sector(0.02, 1.015, 2.43, 2.54, SLOT_HALF, TAU - SLOT_HALF), _casing_metal, Vector3.ZERO)
	_mesh(casing, _sector(0.94, 1.005, 2.34, 2.43, SLOT_HALF, TAU - SLOT_HALF), _trim, Vector3.ZERO)
	_ring(casing, 0.95, 0.045, 0.43, _bronze)
	for edge in [-SLOT_HALF, SLOT_HALF]:
		var position := Vector3(sin(edge) * 0.96, 1.43, cos(edge) * 0.96)
		var jamb := _box(casing, Vector3(0.075, 2.02, 0.10), position, _trim)
		jamb.rotation.y = edge
	for step in range(7):
		var angle := lerpf(SLOT_HALF + 0.08, TAU - SLOT_HALF - 0.08, float(step) / 6.0)
		var rib := _box(casing, Vector3(0.065, 1.76, 0.045), Vector3(sin(angle) * 0.98, 1.40, cos(angle) * 0.98), _bronze)
		rib.rotation.y = angle
		for height in [0.55, 2.30]:
			_sphere(casing, 0.035, Vector3(sin(angle) * 1.002, height, cos(angle) * 1.002), _trim)
	_build_ornament()
	# A central spindle supports the bell without covering the viewing slot.
	_cylinder(self, 0.07, 0.18, Vector3(0.0, 2.21, 0.0), _iron)
	_box(self, Vector3(1.23, 0.11, 0.13), Vector3(0.0, 2.16, 0.0), _bronze)
	for x in [-0.61, 0.61]:
		_cylinder(self, 0.035, 1.72, Vector3(x, 1.30, -0.20), _iron)


func _build_bell() -> void:
	_bell_pivot = Node3D.new()
	_bell_pivot.name = "BellPivot"
	_bell_pivot.position = Vector3(0.0, 2.06, 0.0)
	add_child(_bell_pivot)
	var profile: Array[Vector2] = [
		Vector2(0.07, 0.0), Vector2(0.15, -0.10), Vector2(0.20, -0.28),
		Vector2(0.26, -0.57), Vector2(0.38, -0.78), Vector2(0.49, -0.88),
		Vector2(0.50, -0.94), Vector2(0.44, -0.95), Vector2(0.36, -0.83),
		Vector2(0.23, -0.58), Vector2(0.14, -0.20), Vector2(0.0, -0.12),
	]
	_mesh(_bell_pivot, _lathe(profile), _bronze, Vector3.ZERO)
	_ring(_bell_pivot, 0.47, 0.025, -0.91, _trim)
	_ring(_bell_pivot, 0.255, 0.014, -0.56, _trim)
	_ring(_bell_pivot, 0.18, 0.016, -0.19, _trim)
	_cylinder(_bell_pivot, 0.023, 0.70, Vector3(0.0, -0.54, 0.0), _iron)
	_sphere(_bell_pivot, 0.075, Vector3(0.0, -0.94, 0.0), _iron)


func _build_pull_mechanism() -> void:
	# The rope guide travels with the sleeve, presenting the same grip to each side.
	_box(casing, Vector3(0.10, 0.12, 0.50), Vector3(0.43, 2.09, 0.26), _iron)
	_pulley = _cylinder(casing, 0.13, 0.055, Vector3(0.43, 2.04, 0.50), _bronze)
	_pulley.rotation.x = PI * 0.5
	_sphere(casing, 0.04, Vector3(0.43, 2.04, 0.54), _trim)
	# A short link drives the bell's yoke when the rope is pulled.
	_box(casing, Vector3(0.44, 0.04, 0.04), Vector3(0.22, 2.04, 0.25), _iron)
	_rope_mesh = CylinderMesh.new()
	_rope_mesh.top_radius = 0.025
	_rope_mesh.bottom_radius = 0.025
	_rope_mesh.radial_segments = 12
	_rope = _mesh(casing, _rope_mesh, _rope_material, Vector3(0.43, 1.3, 0.55))
	grip = Node3D.new()
	grip.name = "RopeGrip"
	grip.position = Vector3(0.43, ROPE_REST, 0.55)
	casing.add_child(grip)
	var handle := _cylinder(grip, 0.055, 0.32, Vector3.ZERO, _wood)
	handle.rotation.z = PI * 0.5
	for x in [-0.13, 0.13]:
		_sphere(grip, 0.065, Vector3(x, 0.0, 0.0), _iron)
	_ring(grip, 0.033, 0.008, 0.075, _rope_material)
	set_pull(0.0)


func _worn_plinth() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile: Array[Vector2] = [Vector2(1.00, 0.015), Vector2(1.11, 0.065), Vector2(1.09, 0.135), Vector2(0.98, 0.19)]
	var rings: Array[PackedVector3Array] = []
	for band in range(profile.size()):
		var points := PackedVector3Array()
		for step in range(32):
			var side := step / 4
			var blend := float(step % 4) / 4.0
			var start := Vector2(sin(float(side) * TAU / 8.0), cos(float(side) * TAU / 8.0))
			var finish := Vector2(sin(float(side + 1) * TAU / 8.0), cos(float(side + 1) * TAU / 8.0))
			var edge := start.lerp(finish, blend)
			var chip := 1.0 - absf(sin(float(step) * 5.17 + float(band))) * 0.018
			var height := profile[band].y + sin(float(step) * 2.31) * 0.006
			points.append(Vector3(edge.x * profile[band].x * chip, height, edge.y * profile[band].x * chip))
		rings.append(points)
	for band in range(rings.size() - 1):
		for step in range(32):
			var next := (step + 1) % 32
			_quad(surface, rings[band][step], rings[band + 1][step], rings[band + 1][next], rings[band][next])
	for step in range(32):
		var next := (step + 1) % 32
		for vertex in [Vector3(0.0, 0.19, 0.0), rings[3][step], rings[3][next]]:
			surface.add_vertex(vertex)
		for vertex in [Vector3(0.0, 0.015, 0.0), rings[0][next], rings[0][step]]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()


func _build_ornament() -> void:
	# The raised over-and-under bands echo the game's carved knotwork frames.
	for height in [0.73, 2.16]:
		_mesh(casing, _sector(0.958, 0.975, height - 0.087, height + 0.087, SLOT_HALF, TAU - SLOT_HALF), _iron, Vector3.ZERO)
		for strand in range(2):
			var points: Array[Vector3] = []
			for step in range(97):
				var fraction := float(step) / 96.0
				var angle := lerpf(SLOT_HALF + 0.025, TAU - SLOT_HALF - 0.025, fraction)
				var braid := fraction * TAU * 8.0 + float(strand) * PI
				points.append(_point(0.992 + cos(braid) * 0.012, height + sin(braid) * 0.047, angle))
			_mesh(casing, _tube_path(points, 0.017), _trim, Vector3.ZERO)
	# Paired scrolls and lozenges are relief ornament, with no modern lettering.
	for angle in [2.09, PI, 4.19]:
		var diamond: Array[Vector3] = []
		for point in [Vector2(-0.13, 0.0), Vector2(0.0, 0.21), Vector2(0.13, 0.0), Vector2(0.0, -0.21), Vector2(-0.13, 0.0)]:
			diamond.append(_point(1.014, 1.43 + point.y, angle + point.x))
		_mesh(casing, _tube_path(diamond, 0.021), _trim, Vector3.ZERO)
		for side in [-1.0, 1.0]:
			var scroll: Array[Vector3] = []
			for step in range(41):
				var progress := float(step) / 40.0
				var curl := progress * PI * 3.1
				var radius := lerpf(0.13, 0.025, progress)
				var x: float = side * (0.25 + cos(curl) * radius)
				var y := 1.46 + sin(curl) * radius
				scroll.append(_point(1.016, y, angle + x))
			_mesh(casing, _tube_path(scroll, 0.015), _bronze, Vector3.ZERO)


func _tube_path(points: Array[Vector3], radius: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for step in range(points.size()):
		var tangent := (points[mini(step + 1, points.size() - 1)] - points[maxi(0, step - 1)]).normalized()
		var reference := Vector3.FORWARD if absf(tangent.dot(Vector3.UP)) > 0.9 else Vector3.UP
		var normal := tangent.cross(reference).normalized()
		var binormal := tangent.cross(normal).normalized()
		var ring := PackedVector3Array()
		for vertex in range(6):
			var angle := float(vertex) * TAU / 6.0
			ring.append(points[step] + (normal * cos(angle) + binormal * sin(angle)) * radius)
		rings.append(ring)
	for step in range(points.size() - 1):
		for vertex in range(6):
			var next := (vertex + 1) % 6
			_quad(surface, rings[step][vertex], rings[step + 1][vertex], rings[step + 1][next], rings[step][next])
	surface.generate_normals()
	return surface.commit()


func _point(radius: float, height: float, angle: float) -> Vector3:
	return Vector3(sin(angle) * radius, height, cos(angle) * radius)


func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for vertex in [a, b, c, a, c, d]:
		surface.add_vertex(vertex)


func _sector(inner: float, outer: float, bottom: float, top: float, start: float, finish: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in range(64):
		var a := lerpf(start, finish, float(step) / 64.0)
		var b := lerpf(start, finish, float(step + 1) / 64.0)
		_quad(surface, _point(outer, bottom, a), _point(outer, top, a), _point(outer, top, b), _point(outer, bottom, b))
		_quad(surface, _point(inner, bottom, b), _point(inner, top, b), _point(inner, top, a), _point(inner, bottom, a))
		_quad(surface, _point(inner, top, a), _point(inner, top, b), _point(outer, top, b), _point(outer, top, a))
		_quad(surface, _point(inner, bottom, b), _point(inner, bottom, a), _point(outer, bottom, a), _point(outer, bottom, b))
	for angle in [start, finish]:
		_quad(surface, _point(inner, bottom, angle), _point(inner, top, angle), _point(outer, top, angle), _point(outer, bottom, angle))
	surface.generate_normals()
	return surface.commit()


func _lathe(profile: Array[Vector2]) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(profile.size() - 1):
		for step in range(64):
			var a := TAU * float(step) / 64.0
			var b := TAU * float(step + 1) / 64.0
			var upper := profile[row]
			var lower := profile[row + 1]
			_quad(surface, _point(upper.x, upper.y, a), _point(lower.x, lower.y, a), _point(lower.x, lower.y, b), _point(upper.x, upper.y, b))
	surface.generate_normals()
	return surface.commit()
