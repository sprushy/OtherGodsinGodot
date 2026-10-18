extends Control

## Cosmetic marks heal over three global turn advances. They are not an
## active effect and never hold priority, input, or grave departures open.
const MAX_MARKS := 48
const GROUND_SHADER := preload("res://shaders/scorched_ground.gdshader")
const SOOT_OPACITY := 0.96
const MARK_SIZE_SCALE := 3.0
const CINDER_SECONDS := 2.8
const HEAL_TURNS := 3
const SLAB_MASK_SIZE := 64
# Angle, length, width and branching depth. Each silhouette stays compact,
# but varies between a split trunk, fern, fan and short radial discharge.
const LIGHTNING_SCAR_PATTERNS := [
	[Vector4(-90, 74, 3.2, 4), Vector4(85, 62, 2.5, 3), Vector4(-161, 56, 2.0, 3), Vector4(-22, 58, 2.0, 3)],
	[Vector4(-108, 68, 3.1, 4), Vector4(-56, 65, 2.5, 3), Vector4(-149, 48, 1.8, 3), Vector4(-12, 50, 1.8, 3), Vector4(94, 46, 2.2, 3)],
	[Vector4(-77, 78, 3.2, 4), Vector4(139, 61, 2.6, 4), Vector4(40, 56, 2.4, 3)],
	[Vector4(-132, 70, 3.0, 4), Vector4(-28, 59, 2.5, 3), Vector4(63, 67, 2.7, 4), Vector4(167, 43, 1.8, 3)],
	[Vector4(-96, 77, 3.2, 4), Vector4(78, 68, 2.7, 4), Vector4(-150, 42, 1.6, 3), Vector4(-33, 44, 1.7, 3), Vector4(158, 37, 1.5, 3)],
	[Vector4(-94, 62, 3.0, 4), Vector4(-34, 55, 2.3, 3), Vector4(24, 48, 1.8, 3), Vector4(86, 58, 2.7, 3), Vector4(149, 51, 2.1, 3), Vector4(-154, 47, 1.8, 3)],
]
static var _soot_textures: Array[Texture2D] = []
static var _lightning_textures: Array[Texture2D] = []
static var _slab_masks: Dictionary = {}

var _geometry: Callable
var _board: Dictionary = {}
var _marks: Array[Dictionary] = []
var _refresh_elapsed := 0.0
var _cinder_glow: GradientTexture2D
var _surface: ScorchSurface
var _stone_masks: Array[Image] = []
var _stone_texture_ids: Array[int] = []
var _variant_rng := RandomNumberGenerator.new()
var _last_lightning_variant := -1

class ScorchSurface extends Control:
	var stamps: Array[Dictionary] = []

	func _draw() -> void:
		for stamp in stamps:
			draw_texture_rect_region(stamp["texture"], stamp["region"], stamp["source"], Color(1.0, 1.0, 1.0, SOOT_OPACITY * float(stamp["opacity"])))


func setup(board_geometry: Callable) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_variant_rng.randomize()
	_geometry = board_geometry
	_board = _geometry.call()
	if _soot_textures.is_empty():
		_bake_soot_textures()
	if _lightning_textures.is_empty():
		_bake_lightning_textures()
	_surface = ScorchSurface.new()
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.show_behind_parent = true
	var ground_material := ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	_surface.material = ground_material
	add_child(_surface)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.15, 0.45, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.6), Color(1.0, 1.0, 1.0, 0.1), Color.TRANSPARENT])
	_cinder_glow = GradientTexture2D.new()
	_cinder_glow.gradient = gradient
	_cinder_glow.width = 32
	_cinder_glow.height = 32
	_cinder_glow.fill = GradientTexture2D.FILL_RADIAL
	_cinder_glow.fill_from = Vector2(0.5, 0.5)
	_cinder_glow.fill_to = Vector2(1.0, 0.5)


static func _bake_soot_textures() -> void:
	for variant in range(4):
		var noise := FastNoiseLite.new()
		noise.seed = 1873 + variant * 7919
		noise.frequency = 0.085
		var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
		for y in range(96):
			for x in range(96):
				var p := (Vector2(x, y) + Vector2.ONE * 0.5) / 48.0 - Vector2.ONE
				var grain := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
				var fine := noise.get_noise_2d(float(x) * 4.0, float(y) * 4.0) * 0.5 + 0.5
				var radius := p.length() + (grain - 0.5) * 0.37
				var edge := 1.0 - smoothstep(0.65, 0.78, radius)
				var alpha := edge * (0.60 + grain * 0.25 + fine * 0.15)
				# Encode grain and short vertical blade detail for the ground shader.
				var blades := noise.get_noise_2d(float(x) * 8.0, float(y) * 1.5) * 0.5 + 0.5
				image.set_pixel(x, y, Color(grain, blades, 0.0, alpha))
		_soot_textures.append(ImageTexture.create_from_image(image))


static func _bake_lightning_textures() -> void:
	for variant in range(LIGHTNING_SCAR_PATTERNS.size()):
		var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.25, 0.65, 1.0, 0.0))
		var rng := RandomNumberGenerator.new()
		rng.seed = 9341 + variant * 1877
		var origin := Vector2(128.0, 128.0)
		# One connected, fern-like discharge scar, with a dark trunk and finer
		# branching filaments. It does not reuse the fire's rounded soot stamps.
		for ray: Vector4 in LIGHTNING_SCAR_PATTERNS[variant]:
			var direction := Vector2.from_angle(deg_to_rad(ray.x + rng.randf_range(-5.0, 5.0)))
			_grow_char_branch(image, origin, direction, ray.y, ray.z, int(ray.w), rng)
		_lightning_textures.append(ImageTexture.create_from_image(image))


static func _grow_char_branch(image: Image, start: Vector2, direction: Vector2, length: float, width: float, depth: int, rng: RandomNumberGenerator) -> void:
	var point := start
	var heading := direction.normalized()
	for segment in range(7):
		heading = heading.rotated(rng.randf_range(-0.25, 0.25))
		var next := point + heading * length / 7.0 * rng.randf_range(0.75, 1.2)
		_char_line(image, point, next, maxf(0.4, width * (1.0 - float(segment) * 0.09)))
		if depth > 0 and segment >= 1 and rng.randf() < 0.43:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			_grow_char_branch(image, next, heading.rotated(side * rng.randf_range(0.48, 1.05)), length * rng.randf_range(0.35, 0.57), width * 0.55, depth - 1, rng)
		point = next


static func _char_line(image: Image, start: Vector2, end: Vector2, width: float) -> void:
	var steps := maxi(1, int(ceil(start.distance_to(end) * 1.5)))
	var radius := int(ceil(width + 1.0))
	for step_index in range(steps + 1):
		var point := start.lerp(end, float(step_index) / float(steps))
		var pixel := Vector2i(point.floor())
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var at := pixel + Vector2i(x, y)
				if at.x < 0 or at.y < 0 or at.x >= image.get_width() or at.y >= image.get_height():
					continue
				var distance := (Vector2(at) + Vector2.ONE * 0.5).distance_to(point)
				var alpha := 1.0 - smoothstep(width * 0.45, width * 0.45 + 0.75, distance)
				if alpha > image.get_pixelv(at).a:
					image.set_pixelv(at, Color(0.25, 0.65, 1.0, alpha))


func add_mark(board_uv: Vector2, radius_ratio: float, seed_value: float, kind: String = "meteor") -> void:
	if _geometry.is_valid():
		_board = _geometry.call()
	var variant_count := _lightning_textures.size() if kind == "lightning" else _soot_textures.size()
	var variant := _variant_rng.randi_range(0, variant_count - 1)
	if kind == "lightning":
		if variant_count > 1 and variant == _last_lightning_variant:
			variant = (variant + _variant_rng.randi_range(1, variant_count - 1)) % variant_count
		_last_lightning_variant = variant
	_marks.append({
		"uv": board_uv, "radius": radius_ratio,
		"rotation": seed_value,
		"variant": variant,
		"born": Time.get_ticks_msec(),
		"born_turn": int(_board.get("turn", 0)), "opacity": 1.0,
		"kind": kind,
	})
	if _marks.size() > MAX_MARKS:
		_marks.pop_front()
	_redraw_surface()
	queue_redraw()


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	var healing := false
	var current_turn := int(_board.get("turn", 0))
	for mark in _marks:
		var elapsed_turns := maxi(0, current_turn - int(mark["born_turn"]))
		var target_opacity := clampf(1.0 - float(elapsed_turns) / float(HEAL_TURNS), 0.0, 1.0)
		var opacity := move_toward(float(mark["opacity"]), target_opacity, delta * 1.4)
		if not is_equal_approx(opacity, float(mark["opacity"])):
			mark["opacity"] = opacity
			healing = true
	if healing:
		for index in range(_marks.size() - 1, -1, -1):
			if float(_marks[index]["opacity"]) <= 0.0:
				_marks.remove_at(index)
		_redraw_surface()
		queue_redraw()
	if not _marks.is_empty() and Time.get_ticks_msec() - int(_marks.back()["born"]) < int(CINDER_SECONDS * 1000.0):
		queue_redraw()
	if _refresh_elapsed < 0.1 or not _geometry.is_valid():
		return
	_refresh_elapsed = 0.0
	var live_board: Dictionary = _geometry.call()
	if live_board != _board:
		_board = live_board
		_redraw_surface()
		queue_redraw()


func _draw() -> void:
	if _board.is_empty():
		return
	var bounds: Rect2 = _board["bounds"]
	var unit := float(_board["unit"])
	var occupied: Array = _board["occupied"]
	for mark in _marks:
		var center: Vector2 = bounds.position + bounds.size * Vector2(mark["uv"])
		var radius := unit * float(mark["radius"]) * MARK_SIZE_SCALE
		var age := float(Time.get_ticks_msec() - int(mark["born"])) / 1000.0
		if age < CINDER_SECONDS:
			_draw_cinders(center, radius, age, float(mark["rotation"]), occupied)


func _redraw_surface() -> void:
	if _board.is_empty() or not is_instance_valid(_surface):
		return
	var tiles := PackedVector4Array()
	var stones: Array = _board.get("stone", [])
	for index in range(10):
		var rect: Rect2 = stones[index] if index < stones.size() else Rect2()
		tiles.append(Vector4(rect.get_center().x, rect.get_center().y, rect.size.x * 0.5, rect.size.y * 0.5))
	var ground_material := _surface.material as ShaderMaterial
	ground_material.set_shader_parameter("stone_count", mini(10, stones.size()))
	ground_material.set_shader_parameter("stone_tiles", tiles)
	_sync_stone_masks()
	_surface.stamps.clear()
	var bounds: Rect2 = _board["bounds"]
	var unit := float(_board["unit"])
	for mark in _marks:
		var center: Vector2 = bounds.position + bounds.size * Vector2(mark["uv"])
		var radius := unit * float(mark["radius"]) * MARK_SIZE_SCALE
		var extent := Vector2(radius, radius * 0.65)
		var area := Rect2(center - extent, extent * 2.0)
		var texture := _lightning_textures[int(mark["variant"])] if str(mark["kind"]) == "lightning" else _soot_textures[int(mark["variant"])]
		for region in _uncovered_regions(area, _board["occupied"]):
			var source := Rect2((region.position - area.position) / area.size * texture.get_size(), region.size / area.size * texture.get_size())
			_surface.stamps.append({"texture": texture, "region": region, "source": source, "opacity": mark["opacity"]})
	_surface.queue_redraw()


func _point_on_stone(point: Vector2) -> bool:
	var stones: Array = _board.get("stone", [])
	for index in mini(stones.size(), _stone_masks.size()):
		var rect: Rect2 = stones[index]
		if not rect.has_point(point):
			continue
		var uv := (point - rect.position) / rect.size
		var mask := _stone_masks[index]
		var pixel := Vector2i(clampi(int(uv.x * SLAB_MASK_SIZE), 0, SLAB_MASK_SIZE - 1), clampi(int(uv.y * SLAB_MASK_SIZE), 0, SLAB_MASK_SIZE - 1))
		if mask.get_pixelv(pixel).r > 0.5:
			return true
	return false


func _sync_stone_masks() -> void:
	var textures: Array = _board.get("stone_textures", [])
	var ids: Array[int] = []
	for texture: Texture2D in textures:
		ids.append(texture.get_instance_id() if texture != null else 0)
	if ids == _stone_texture_ids:
		return
	_stone_texture_ids = ids
	_stone_masks.clear()
	var atlas := Image.create(SLAB_MASK_SIZE * 10, SLAB_MASK_SIZE, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.BLACK)
	for index in mini(10, textures.size()):
		var texture: Texture2D = textures[index]
		var key := ids[index]
		if not _slab_masks.has(key):
			var mask := Image.create(SLAB_MASK_SIZE, SLAB_MASK_SIZE, false, Image.FORMAT_RGBA8)
			mask.fill(Color.BLACK)
			if texture != null:
				var source := texture.get_image()
				if source != null:
					if source.is_compressed():
						source.decompress()
					source.resize(SLAB_MASK_SIZE, SLAB_MASK_SIZE, Image.INTERPOLATE_LANCZOS)
					for y in range(SLAB_MASK_SIZE):
						for x in range(SLAB_MASK_SIZE):
							# The soft cast shadow is grass, not stone. Only the
							# opaque slab silhouette is used by both shader and sparks.
							var value := smoothstep(0.94, 0.995, source.get_pixel(x, y).a)
							mask.set_pixel(x, y, Color(value, value, value, 1.0))
			_slab_masks[key] = mask
		var mask: Image = _slab_masks[key]
		_stone_masks.append(mask)
		atlas.blit_rect(mask, Rect2i(0, 0, SLAB_MASK_SIZE, SLAB_MASK_SIZE), Vector2i(index * SLAB_MASK_SIZE, 0))
	var ground_material := _surface.material as ShaderMaterial
	ground_material.set_shader_parameter("stone_mask_atlas", ImageTexture.create_from_image(atlas))


func _draw_cinders(center: Vector2, radius: float, age: float, seed_value: float, occupied: Array) -> void:
	var cooling := pow(1.0 - clampf(age / CINDER_SECONDS, 0.0, 1.0), 1.6)
	for ember in range(6):
		var angle := float(ember) * 2.399 + seed_value
		var point := center + Vector2(cos(angle), sin(angle) * 0.55) * radius * (0.15 + float(ember % 3) * 0.17)
		var covered := false
		for card_rect: Rect2 in occupied:
			if card_rect.has_point(point):
				covered = true
		if covered:
			continue
		if _point_on_stone(point):
			# Stone sheds a short, moving spark; nothing smoulders on it.
			if age < 0.32:
				var velocity := Vector2(cos(angle), sin(angle) - 0.8) * radius
				var spark := point + velocity * age + Vector2(0.0, radius * age * age)
				draw_line(spark - velocity * 0.04, spark, Color(1.0, 0.72, 0.24, 1.0 - age / 0.32), maxf(0.7, radius * 0.013), true)
			continue
		var flicker := 0.65 + 0.35 * sin(age * (11.0 + float(ember)) + angle * 3.0)
		var alpha := cooling * flicker
		var glow_extent := Vector2.ONE * maxf(2.0, radius * 0.16)
		draw_texture_rect(_cinder_glow, Rect2(point - glow_extent, glow_extent * 2.0), false, Color(1.0, 0.22, 0.015, alpha * 0.8))
		draw_circle(point, maxf(0.55, radius * 0.015), Color(1.0, 0.53, 0.08, alpha))


func _uncovered_regions(area: Rect2, occupied: Array) -> Array[Rect2]:
	var regions: Array[Rect2] = [area]
	for blocker: Rect2 in occupied:
		var next: Array[Rect2] = []
		for region in regions:
			if not region.intersects(blocker):
				next.append(region)
				continue
			var overlap := region.intersection(blocker)
			var pieces: Array[Rect2] = [
				Rect2(region.position, Vector2(overlap.position.x - region.position.x, region.size.y)),
				Rect2(Vector2(overlap.end.x, region.position.y), Vector2(region.end.x - overlap.end.x, region.size.y)),
				Rect2(Vector2(overlap.position.x, region.position.y), Vector2(overlap.size.x, overlap.position.y - region.position.y)),
				Rect2(Vector2(overlap.position.x, overlap.end.y), Vector2(overlap.size.x, region.end.y - overlap.end.y)),
			]
			for piece in pieces:
				if piece.has_area():
					next.append(piece)
		regions = next
	return regions
