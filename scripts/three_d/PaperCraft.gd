extends RefCounted
## Small, real paper meshes: printed faces, exposed cream edges and folded feet.

const PAPER_SHADER = preload("res://shaders/popup_paper.gdshader")
const CREAM := Color("f9efd7")
const INK := Color("374c50")
const GOLD := Color("d9aa55")
const CORAL := Color("bd6050")
const TEAL := Color("578b85")

var _materials: Dictionary = {}
var book_font: SystemFont

func _init() -> void:
	book_font = SystemFont.new()
	book_font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "DejaVu Serif"])

func material(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if not _materials.has(key):
		var result := ShaderMaterial.new()
		result.shader = PAPER_SHADER
		result.set_shader_parameter("paper_color", color)
		_materials[key] = result
	return _materials[key]

func box(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color)
	instance.position = at
	parent.add_child(instance)
	return instance

func polygon(parent: Node3D, points: PackedVector2Array, color: Color, depth: float = 0.028) -> MeshInstance3D:
	var triangles := Geometry2D.triangulate_polygon(points)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [1.0, -1.0]:
		for index in triangles:
			var point := points[index]
			surface.set_normal(Vector3(0, 0, side))
			surface.set_uv(point * 0.23)
			surface.add_vertex(Vector3(point.x, point.y, depth * 0.5 * side))
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var normal := Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		for vertex in [Vector3(a.x, a.y, depth * 0.5), Vector3(b.x, b.y, depth * 0.5), Vector3(b.x, b.y, -depth * 0.5), Vector3(a.x, a.y, depth * 0.5), Vector3(b.x, b.y, -depth * 0.5), Vector3(a.x, a.y, -depth * 0.5)]:
			surface.set_normal(normal)
			surface.set_uv(Vector2(vertex.x, vertex.y) * 0.23)
			surface.add_vertex(vertex)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material(color)
	parent.add_child(instance)
	return instance

func cutout(parent: Node3D, points: PackedVector2Array, color: Color, at: Vector3 = Vector3.ZERO) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	var edge := polygon(root, points, CREAM, 0.055)
	edge.scale = Vector3(1.065, 1.045, 1.0)
	var face := polygon(root, points, color)
	face.position.z = 0.035
	return root

func disc(parent: Node3D, at: Vector3, radius: float, color: Color, sides: int = 20) -> MeshInstance3D:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := TAU * float(i) / float(sides)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	var mesh := polygon(parent, points, color)
	mesh.position = at
	return mesh

func label(parent: Node3D, text: String, at: Vector3, font_size: int = 40, color: Color = INK, pixel_size: float = 0.007) -> Label3D:
	var result := Label3D.new()
	result.text = text
	result.font = book_font
	result.font_size = font_size
	result.pixel_size = pixel_size
	result.modulate = color
	result.outline_size = 0
	result.no_depth_test = false
	result.position = at
	parent.add_child(result)
	return result

func strip(parent: Node3D, from: Vector3, to: Vector3, width: float, color: Color) -> MeshInstance3D:
	var result := box(parent, (from + to) * 0.5, Vector3(width, width, from.distance_to(to)), color)
	if not from.is_equal_approx(to):
		var up := Vector3.RIGHT if absf((to - from).normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP
		result.look_at_from_position((from + to) * 0.5, to, up)
	return result

func tree(parent: Node3D, at: Vector3, height: float, color: Color, evergreen: bool = true) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	box(root, Vector3(0, height * 0.24, 0), Vector3(0.12, height * 0.48, 0.055), Color("997451"))
	if evergreen:
		for i in range(3):
			var bottom := height * (0.21 + i * 0.20)
			var half_width := height * (0.32 - i * 0.065)
			cutout(root, PackedVector2Array([Vector2(-half_width, bottom), Vector2(0, bottom + height * 0.47), Vector2(half_width, bottom)]), color.lightened(i * 0.08), Vector3(0, 0, i * 0.045))
	else:
		for i in range(3):
			disc(root, Vector3((i - 1) * height * 0.18, height * (0.66 + (0.15 if i == 1 else 0.0)), i * 0.025), height * 0.29, CREAM, 12)
			disc(root, Vector3((i - 1) * height * 0.18, height * (0.66 + (0.15 if i == 1 else 0.0)), i * 0.025 + 0.035), height * 0.27, color.lightened(i * 0.06), 12)
	box(root, Vector3(0, 0.025, 0.15), Vector3(0.32, 0.035, 0.48), CREAM)
	return root

func cloud(parent: Node3D, at: Vector3, size: float, color: Color = CREAM) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	var points := PackedVector2Array([Vector2(-1, 0), Vector2(-1.12, 0.18), Vector2(-1.02, 0.41), Vector2(-0.69, 0.48), Vector2(-0.56, 0.74), Vector2(-0.23, 0.83), Vector2(0.06, 0.64), Vector2(0.35, 0.79), Vector2(0.66, 0.65), Vector2(0.71, 0.44), Vector2(1.02, 0.4), Vector2(1.15, 0.17), Vector2(1, 0)])
	cutout(root, points, color)
	root.scale = Vector3.ONE * size
	return root

func star(parent: Node3D, at: Vector3, radius: float, color: Color = GOLD) -> MeshInstance3D:
	var points := PackedVector2Array()
	for i in range(10):
		var angle := PI * 0.5 + TAU * float(i) / 10.0
		points.append(Vector2(cos(angle), sin(angle)) * radius * (1.0 if i % 2 == 0 else 0.43))
	var result := polygon(parent, points, color)
	result.position = at
	return result

func figure(parent: Node3D, kind: String, color: Color) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	# The rear easel and fold tab make every figure visibly part of the book.
	var easel := polygon(root, PackedVector2Array([Vector2(-0.27, 0), Vector2(0.27, 0), Vector2(0.0, 0.80)]), CREAM)
	easel.rotation.y = PI * 0.5
	easel.position = Vector3(0, 0, -0.22)
	box(root, Vector3(0, 0.025, 0.05), Vector3(0.66, 0.04, 0.48), CREAM)
	if kind == "lion" or kind == "wolf":
		_animal(root, kind, color)
	else:
		_person(root, kind, color)
	return root

func _person(root: Node3D, kind: String, color: Color) -> void:
	var mage := kind in ["mage", "mummu"]
	var body := PackedVector2Array([Vector2(-0.44, 0.16), Vector2(-0.28, 0.86), Vector2(-0.49, 0.66), Vector2(-0.6, 0.83), Vector2(-0.30, 1.15), Vector2(0.29, 1.15), Vector2(0.55, 0.77), Vector2(0.42, 0.64), Vector2(0.29, 0.85), Vector2(0.44, 0.16)])
	cutout(root, body, color)
	# Contrasting inset is printed on a second piece of paper.
	polygon(root, PackedVector2Array([Vector2(-0.08, 0.20), Vector2(-0.15, 0.93), Vector2(0.12, 0.93), Vector2(0.24, 0.20)]), color.lightened(0.23)).position.z = 0.065
	box(root, Vector3(0, 0.60, 0.09), Vector3(0.65, 0.09, 0.035), GOLD)
	disc(root, Vector3(0, 1.28, 0.08), 0.255, CREAM, 12)
	disc(root, Vector3(0, 1.28, 0.11), 0.208, Color("e8bb89"), 12)
	for x in [-0.072, 0.072]:
		disc(root, Vector3(x, 1.31, 0.14), 0.019, INK, 8)
	if mage:
		cutout(root, PackedVector2Array([Vector2(-0.32, 1.45), Vector2(-0.15, 1.77), Vector2(0.07, 1.91), Vector2(0.24, 1.45)]), color.darkened(0.15), Vector3(0, 0, 0.10))
		cutout(root, PackedVector2Array([Vector2(-0.18, 1.22), Vector2(0, 0.81), Vector2(0.18, 1.22)]), Color("e0d5b6"), Vector3(0, 0, 0.15))
		box(root, Vector3(0.53, 0.90, 0.11), Vector3(0.055, 1.78, 0.045), Color("a17c51"))
		star(root, Vector3(0.53, 1.86, 0.13), 0.22)
	elif kind == "byggvir":
		cutout(root, PackedVector2Array([Vector2(-0.27, 1.41), Vector2(-0.22, 1.58), Vector2(0.19, 1.58), Vector2(0.30, 1.41)]), TEAL, Vector3(0, 0, 0.13))
		box(root, Vector3(0.45, 0.88, 0.13), Vector3(0.25, 0.32, 0.12), GOLD)
		label(root, "~", Vector3(0.44, 1.15, 0.20), 26, CREAM)
	else:
		cutout(root, PackedVector2Array([Vector2(-0.28, 1.40), Vector2(-0.22, 1.60), Vector2(0.22, 1.60), Vector2(0.28, 1.40)]), Color("a7b7b1"), Vector3(0, 0, 0.13))
		for sign_value in [-1.0, 1.0]:
			cutout(root, PackedVector2Array([Vector2(0.19 * sign_value, 1.46), Vector2(0.48 * sign_value, 1.67), Vector2(0.37 * sign_value, 1.35)]), GOLD, Vector3(0, 0, 0.1))
		cutout(root, PackedVector2Array([Vector2(-0.18, 1.23), Vector2(-0.11, 0.96), Vector2(0.12, 0.98), Vector2(0.18, 1.23)]), CORAL.lightened(0.2), Vector3(0, 0, 0.15))
		if kind == "thor":
			box(root, Vector3(0.54, 1.01, 0.11), Vector3(0.075, 0.78, 0.055), Color("997451"))
			box(root, Vector3(0.54, 1.37, 0.11), Vector3(0.49, 0.29, 0.13), Color("b9c6be"))
			star(root, Vector3(-0.45, 1.91, 0.08), 0.17, GOLD)
		else:
			disc(root, Vector3(-0.43, 0.68, 0.15), 0.31, CREAM, 12)
			disc(root, Vector3(-0.43, 0.68, 0.18), 0.265, color.darkened(0.20), 12)
			disc(root, Vector3(-0.43, 0.68, 0.21), 0.075, GOLD, 10)
			box(root, Vector3(0.47, 1.08, 0.10), Vector3(0.065, 1.18, 0.045), Color("b9c6be"))
			box(root, Vector3(0.47, 0.78, 0.12), Vector3(0.31, 0.07, 0.055), GOLD)
	for x in [-0.20, 0.20]:
		box(root, Vector3(x, 0.09, 0.07), Vector3(0.24, 0.16, 0.09), INK)

func _animal(root: Node3D, kind: String, color: Color) -> void:
	var lion := kind == "lion"
	var body := PackedVector2Array([Vector2(-0.66, 0.18), Vector2(-0.62, 0.80), Vector2(-0.30, 1.04), Vector2(0.40, 1.02), Vector2(0.63, 0.83), Vector2(0.62, 0.18), Vector2(0.39, 0.18), Vector2(0.31, 0.63), Vector2(-0.31, 0.63), Vector2(-0.41, 0.18)])
	cutout(root, body, color)
	if lion:
		var wing := PackedVector2Array([Vector2(-0.18, 0.89), Vector2(-0.62, 1.78), Vector2(-0.22, 1.65), Vector2(-0.02, 1.43), Vector2(0.02, 1.67), Vector2(0.23, 1.45), Vector2(0.45, 1.20), Vector2(0.29, 0.91)])
		cutout(root, wing, Color("b8c9b3"), Vector3(0, 0, -0.08))
		for i in range(4):
			strip(root, Vector3(-0.12 + i * 0.11, 0.98, 0.04), Vector3(-0.49 + i * 0.19, 1.58 - i * 0.09, 0.04), 0.025, CREAM)
		disc(root, Vector3(-0.52, 1.11, 0.10), 0.42, CORAL, 12)
		disc(root, Vector3(-0.52, 1.13, 0.14), 0.28, color.lightened(0.16), 12)
	else:
		cutout(root, PackedVector2Array([Vector2(-0.78, 0.88), Vector2(-0.85, 1.38), Vector2(-0.57, 1.20), Vector2(-0.36, 1.40), Vector2(-0.30, 0.89)]), color, Vector3(0, 0, 0.08))
		cutout(root, PackedVector2Array([Vector2(0.48, 0.84), Vector2(1.00, 1.11), Vector2(0.79, 0.66)]), color, Vector3(0, 0, -0.08))
	for x in [-0.64, -0.42]:
		disc(root, Vector3(x, 1.20 if lion else 1.12, 0.18), 0.025, INK, 8)
	disc(root, Vector3(-0.56, 1.04 if lion else 0.99, 0.19), 0.045, INK, 8)
	for x in [-0.51, 0.50]:
		box(root, Vector3(x, 0.13, 0.07), Vector3(0.27, 0.12, 0.10), color.darkened(0.18))
