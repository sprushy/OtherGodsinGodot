class_name StealthFogOverlay
extends Control

const OVERLAY_NAME := "StealthFogOverlay"
const FOG_TEXTURE_PATHS := [
	"res://images/ui/stealth_fog/shadow_fog_03.png",
	"res://images/ui/stealth_fog/shadow_fog_05.png",
	"res://images/ui/stealth_fog/shadow_fog_08.png",
	"res://images/ui/stealth_fog/shadow_fog_09.png",
	"res://images/ui/stealth_fog/shadow_fog_10.png",
	"res://images/ui/stealth_fog/shadow_fog_15.png",
]
const ANIMATION_UPDATE_INTERVAL := 1.0 / 24.0

static var _texture_cache: Array[Texture2D] = []
static var _additive_material: CanvasItemMaterial = null

var fog_alpha: float = 0.18
var _puffs: Array[TextureRect] = []
var _time: float = 0.0
var _animation_accumulator: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	resized.connect(_layout_puffs)
	_build_puffs()
	call_deferred("_layout_puffs")

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		_animation_accumulator = 0.0
		return
	_animation_accumulator += delta
	if _animation_accumulator < ANIMATION_UPDATE_INTERVAL:
		return
	var elapsed := _animation_accumulator
	_animation_accumulator = 0.0
	_time = fmod(_time + elapsed, 1000.0)
	_layout_puffs()
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var pulse := 0.78 + sin(_time * 1.4) * 0.22
	var edge_alpha := fog_alpha * pulse
	var rect := Rect2(Vector2.ZERO, size)
	_draw_rounded_outline(rect.grow(-2.0), 7.0, Color(0.04, 0.04, 0.055, 0.48 * edge_alpha), 3.0)
	_draw_rounded_outline(rect.grow(-5.0), 5.0, Color(0.20, 0.22, 0.28, 0.18 * edge_alpha), 2.0)
	var edge := maxf(8.0, minf(size.x, size.y) * 0.16)
	draw_rect(Rect2(0.0, 0.0, size.x, edge), Color(0.02, 0.02, 0.03, 0.11 * edge_alpha), true)
	draw_rect(Rect2(0.0, size.y - edge, size.x, edge), Color(0.02, 0.02, 0.03, 0.10 * edge_alpha), true)
	draw_rect(Rect2(0.0, 0.0, edge, size.y), Color(0.02, 0.02, 0.03, 0.11 * edge_alpha), true)
	draw_rect(Rect2(size.x - edge, 0.0, edge, size.y), Color(0.02, 0.02, 0.03, 0.09 * edge_alpha), true)

func _build_puffs() -> void:
	for child in get_children():
		child.queue_free()
	_puffs.clear()
	var fog_textures := _get_fog_textures()
	for i in range(fog_textures.size()):
		var puff := TextureRect.new()
		puff.texture = fog_textures[i]
		puff.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		puff.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		puff.mouse_filter = Control.MOUSE_FILTER_IGNORE
		puff.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		puff.material = _get_additive_material()
		add_child(puff)
		_puffs.append(puff)

static func _get_fog_textures() -> Array[Texture2D]:
	if not _texture_cache.is_empty():
		return _texture_cache
	for path in FOG_TEXTURE_PATHS:
		var texture := _load_fog_texture(path)
		if texture != null:
			_texture_cache.append(texture)
	return _texture_cache

static func _load_fog_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path, "Texture2D"):
		var imported_texture := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
		if imported_texture != null:
			return imported_texture
	var image := Image.new()
	if image.load(path) == OK:
		return ImageTexture.create_from_image(image)
	return null

static func _get_additive_material() -> CanvasItemMaterial:
	if _additive_material == null:
		_additive_material = CanvasItemMaterial.new()
		_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive_material

func _layout_puffs() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var max_dim := maxf(size.x, size.y)
	for i in range(_puffs.size()):
		var puff := _puffs[i]
		if puff == null or not is_instance_valid(puff):
			continue
		var phase := _get_phase(i)
		var drift := Vector2(
			sin(_time * _get_speed(i) + phase) * size.x * 0.055,
			cos(_time * (_get_speed(i) * 0.74) + phase * 1.7) * size.y * 0.045
		)
		var puff_size := Vector2.ONE * max_dim * _get_scale(i)
		var center := size * _get_anchor(i) + drift
		puff.size = puff_size
		puff.pivot_offset = puff_size * 0.5
		puff.position = center - puff_size * 0.5
		puff.rotation = _get_base_rotation(i) + sin(_time * 0.18 + phase) * 0.16
		var pulse := 0.82 + sin(_time * 0.75 + phase) * 0.18
		puff.modulate = Color(0.55, 0.58, 0.66, fog_alpha * _get_alpha_multiplier(i) * pulse)

func _draw_rounded_outline(rect: Rect2, radius: float, color: Color, width: float) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	draw_arc(rect.position + Vector2(radius, radius), radius, PI, PI * 1.5, 12, color, width)
	draw_arc(rect.position + Vector2(rect.size.x - radius, radius), radius, PI * 1.5, TAU, 12, color, width)
	draw_arc(rect.position + rect.size - Vector2(radius, radius), radius, 0.0, PI * 0.5, 12, color, width)
	draw_arc(rect.position + Vector2(radius, rect.size.y - radius), radius, PI * 0.5, PI, 12, color, width)
	draw_line(rect.position + Vector2(radius, 0.0), rect.position + Vector2(rect.size.x - radius, 0.0), color, width)
	draw_line(rect.position + Vector2(rect.size.x, radius), rect.position + Vector2(rect.size.x, rect.size.y - radius), color, width)
	draw_line(rect.position + Vector2(radius, rect.size.y), rect.position + Vector2(rect.size.x - radius, rect.size.y), color, width)
	draw_line(rect.position + Vector2(0.0, radius), rect.position + Vector2(0.0, rect.size.y - radius), color, width)

func _get_anchor(index: int) -> Vector2:
	match index % 6:
		0:
			return Vector2(0.18, 0.28)
		1:
			return Vector2(0.78, 0.24)
		2:
			return Vector2(0.20, 0.76)
		3:
			return Vector2(0.82, 0.70)
		4:
			return Vector2(0.50, 0.10)
	return Vector2(0.52, 0.90)

func _get_scale(index: int) -> float:
	match index % 6:
		0:
			return 0.86
		1:
			return 0.78
		2:
			return 0.82
		3:
			return 0.80
		4:
			return 0.70
	return 0.74

func _get_alpha_multiplier(index: int) -> float:
	match index % 6:
		0:
			return 1.0
		1:
			return 0.9
		2:
			return 0.95
		3:
			return 0.86
		4:
			return 0.74
	return 0.80

func _get_speed(index: int) -> float:
	return 0.26 + float(index % 6) * 0.035

func _get_phase(index: int) -> float:
	return float(index) * 1.31

func _get_base_rotation(index: int) -> float:
	return [-0.45, 0.34, 0.78, -0.62, 0.12, -0.18][index % 6]
