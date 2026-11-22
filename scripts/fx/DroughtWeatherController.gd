extends CanvasLayer

const CONTROL_GROUP := "other_gods_drought_control"
const SCREEN_WEATHER_LAYER := 150
const SUNLIGHT_SHADER := preload("res://shaders/fx/drought_sunlight.gdshader")

var _overlay: ColorRect
var _sunlight_material: ShaderMaterial
var _active: bool = false
var _fade: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	layer = SCREEN_WEATHER_LAYER
	visible = false
	add_to_group(CONTROL_GROUP)
	_sunlight_material = ShaderMaterial.new()
	_sunlight_material.shader = SUNLIGHT_SHADER
	_overlay = ColorRect.new()
	_overlay.name = "DroughtSunlight"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.material = _sunlight_material
	add_child(_overlay)
	get_viewport().size_changed.connect(_sync_viewport_bounds)
	_sync_viewport_bounds()
	set_process(false)

func set_drought_profile(brightness: float = 1.0, ray_strength: float = 1.0) -> void:
	_sunlight_material.set_shader_parameter("brightness", clampf(brightness, 0.0, 1.5))
	_sunlight_material.set_shader_parameter("ray_strength", clampf(ray_strength, 0.0, 1.5))
	set_drought_active(brightness > 0.01)

func set_drought_active(active: bool) -> void:
	if active == _active:
		return
	_active = active
	if active:
		visible = true
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	_fade = move_toward(_fade, 1.0 if _active else 0.0, delta * 1.5)
	_sunlight_material.set_shader_parameter("effect_time", _time)
	_sunlight_material.set_shader_parameter("fade", _fade)
	if not _active and _fade <= 0.0:
		visible = false
		set_process(false)

func _sync_viewport_bounds() -> void:
	_overlay.position = Vector2.ZERO
	_overlay.size = get_viewport().get_visible_rect().size
	_sunlight_material.set_shader_parameter("aspect_ratio", _overlay.size.x / maxf(_overlay.size.y, 1.0))
