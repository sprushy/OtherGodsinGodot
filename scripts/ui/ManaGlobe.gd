extends Control

const ORB_TEXTURE := preload("res://images/ui/ManaOrb.png")
const GLOBE_SHADER := preload("res://shaders/ui/mana_globe.gdshader")
const DISPLAY_SIZE := Vector2(84.6, 104.6)
const CAPTION_HEIGHT := 26.0
const CAPTION_OVERLAP := 6.0

var _mana: int = 0
var _scale_max: int = 20
var _orb: TextureRect
var _mana_label: Label
var _globe_material: ShaderMaterial


func _init() -> void:
	custom_minimum_size = DISPLAY_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_tooltip()


func _ready() -> void:
	_globe_material = ShaderMaterial.new()
	_globe_material.shader = GLOBE_SHADER
	_orb = TextureRect.new()
	_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orb.texture = ORB_TEXTURE
	_orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_orb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_orb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_orb.material = _globe_material
	add_child(_orb)
	_mana_label = Label.new()
	_mana_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mana_label.add_theme_font_size_override("font_size", 20)
	_mana_label.add_theme_color_override("font_color", Color(0.83, 0.91, 1.0))
	_mana_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.07, 0.95))
	_mana_label.add_theme_constant_override("outline_size", 3)
	add_child(_mana_label)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	resized.connect(_layout_globe)
	_layout_globe()
	_update_display()


func set_mana(value: int) -> void:
	_mana = maxi(0, value)
	# Re-evaluate on spending as well as gaining mana. The display caps at 100.
	if _mana >= 40:
		_scale_max = 100
	elif _mana >= 20:
		_scale_max = 40
	else:
		_scale_max = 20
	_update_tooltip()
	_update_display()


func _update_tooltip() -> void:
	tooltip_text = "Mana: %d\nScale: 0–%d • each division = %d mana" % [_mana, _scale_max, _scale_max / 10]
	if _mana >= 100:
		tooltip_text += "\nGlobe is full at 100 mana."


func _update_display() -> void:
	if _globe_material == null:
		return
	_globe_material.set_shader_parameter("fill_amount", clampf(float(_mana) / float(_scale_max), 0.0, 1.0))
	_mana_label.text = str(_mana)


func _set_hovered(hovered: bool) -> void:
	_globe_material.set_shader_parameter("show_divisions", hovered)


func _layout_globe() -> void:
	var side := maxf(0.0, minf(size.x, size.y - CAPTION_HEIGHT + CAPTION_OVERLAP))
	var origin := (size - Vector2(side, side + CAPTION_HEIGHT - CAPTION_OVERLAP)) * 0.5
	_orb.position = origin
	_orb.size = Vector2.ONE * side
	_mana_label.position = origin + Vector2(0.0, side - CAPTION_OVERLAP)
	_mana_label.size = Vector2(side, CAPTION_HEIGHT)
