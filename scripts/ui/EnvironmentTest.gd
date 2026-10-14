extends CanvasLayer

signal closed

const WeatherScript := preload("res://scripts/fx/DroughtWeatherController.gd")

var _weather: WeatherScript
var _strength: HSlider
var _rays: HSlider
var _status: Label

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = WeatherScript.SCREEN_WEATHER_LAYER - 1
	var background := ColorRect.new()
	background.color = Color(0.32, 0.27, 0.20)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	_weather = WeatherScript.new()
	_weather.name = "TestWeather"
	add_child(_weather)
	# Keep the test independent of match/story weather broadcasts.
	_weather.remove_from_group(WeatherScript.CONTROL_GROUP)

	var controls_layer := CanvasLayer.new()
	controls_layer.layer = WeatherScript.SCREEN_WEATHER_LAYER + 1
	add_child(controls_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24.0, 24.0)
	panel.custom_minimum_size = Vector2(380.0, 0.0)
	controls_layer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	margin.add_child(controls)
	var title := Label.new()
	title.text = "Environment Test: Drought"
	title.add_theme_font_size_override("font_size", 22)
	controls.add_child(title)
	_strength = _add_slider(controls, "Sun brightness", 0.05, 1.5, 1.0)
	_rays = _add_slider(controls, "Sun rays", 0.0, 1.5, 1.0)
	_strength.value_changed.connect(_on_profile_changed)
	_rays.value_changed.connect(_on_profile_changed)
	var actions := HBoxContainer.new()
	controls.add_child(actions)
	var replay := Button.new()
	replay.text = "Replay Drought"
	replay.pressed.connect(_replay)
	actions.add_child(replay)
	var clear := Button.new()
	clear.text = "Clear"
	clear.pressed.connect(_clear)
	actions.add_child(clear)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(request_close)
	actions.add_child(back)
	_status = Label.new()
	controls.add_child(_status)
	_apply_profile()

func _add_slider(parent: VBoxContainer, caption: String, minimum: float, maximum: float, initial: float) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 125.0
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	return slider

func _on_profile_changed(_value: float) -> void:
	_apply_profile()

func _apply_profile() -> void:
	_weather.set_drought_profile(_strength.value, _rays.value)
	_status.text = "Sun %.2f | Rays %.2f | Esc to return" % [_strength.value, _rays.value]

func _replay() -> void:
	# Recreate the effect so replay also restarts its fade and ray animation.
	_weather.visible = false
	_weather.queue_free()
	_weather = WeatherScript.new()
	_weather.name = "TestWeather"
	add_child(_weather)
	_weather.remove_from_group(WeatherScript.CONTROL_GROUP)
	_apply_profile()

func _clear() -> void:
	_weather.set_drought_active(false)
	_status.text = "Cleared | Esc to return"

func request_close() -> void:
	_clear()
	closed.emit()
	queue_free()
