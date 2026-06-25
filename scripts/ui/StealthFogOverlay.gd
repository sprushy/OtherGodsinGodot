class_name StealthFogOverlay
extends Control

const OVERLAY_NAME := "StealthFogOverlay"
const SMOKE_TEXTURE_PATH := "res://images/ui/stealth_fog/lelu_smoke_b7.png"
const CLOUD_TEXTURE_PATH := "res://images/ui/stealth_fog/lelu_cloud_noise_tiled.png"
const DETAIL_TEXTURE_PATH := "res://images/ui/stealth_fog/seamless_noise_02.png"
const MIST_LAYER_COUNT := 2
const CURSOR_EFFECT_RADIUS_PIXELS := 52.0
const CURSOR_CENTER_OFFSET_PIXELS := Vector2.ZERO
const CURSOR_TRAIL_LIFETIME := 1.65
const CURSOR_TRAIL_MIN_DISTANCE := 6.5
const CURSOR_TRAIL_COUNT := 7

static var _shader_cache: Shader = null
static var _smoke_texture_cache: Texture2D = null
static var _cloud_texture_cache: Texture2D = null
static var _detail_texture_cache: Texture2D = null

var fog_alpha: float = 0.42:
	set(value):
		fog_alpha = value
		_update_alpha()
var variant_seed: int = 0:
	set(value):
		if variant_seed == value:
			return
		variant_seed = value
		_configure_variant()

var _layer_materials: Array[ShaderMaterial] = []
var _cursor_actual_position: Vector2 = Vector2.INF
var _cursor_clear_strength: float = 0.0
var _cursor_trail: Array[Dictionary] = []
var _motion_elapsed: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	resized.connect(_sync_layer_size)
	_build_mist_layers()
	_configure_variant()
	_update_alpha()
	_sync_layer_size()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		_cursor_actual_position = Vector2.INF
		_cursor_clear_strength = 0.0
		return
	_motion_elapsed = fmod(_motion_elapsed + delta, 1000.0)
	_age_cursor_trail(delta)
	_refresh_cursor_motion()
	_sync_cursor_shader_parameters()
	_animate_mist_layers()

func refresh_cursor_state() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_refresh_cursor_motion()
	_sync_cursor_shader_parameters()

func push_cursor_hotspot_position(global_hotspot_position: Vector2) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_refresh_cursor_motion_at(global_hotspot_position + CURSOR_CENTER_OFFSET_PIXELS)
	_sync_cursor_shader_parameters()

func _build_mist_layers() -> void:
	for i in range(MIST_LAYER_COUNT):
		var layer := ColorRect.new()
		layer.name = "WrapperMistLayer%d" % i
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.color = Color.WHITE
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.z_index = i
		var material := _make_layer_material(i)
		layer.material = material
		_layer_materials.append(material)
		add_child(layer)

func _make_layer_material(layer_index: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_mist_shader()
	material.set_shader_parameter("fog_alpha", fog_alpha - float(layer_index) * 0.060)
	material.set_shader_parameter("cloud_scale", 1.12 + float(layer_index) * 0.26)
	material.set_shader_parameter("drift_speed", 0.090 + float(layer_index) * 0.034)
	material.set_shader_parameter("phase", float(layer_index) * 3.17)
	material.set_shader_parameter("layer_card_scale", Vector2.ONE)
	material.set_shader_parameter("cursor_uv", Vector2(-10.0, -10.0))
	material.set_shader_parameter("cursor_clear_strength", 0.0)
	material.set_shader_parameter("cursor_brush_radius", 0.18)
	material.set_shader_parameter("hover_clear_uv_min", Vector2(2.0, 2.0))
	material.set_shader_parameter("hover_clear_uv_max", Vector2(-1.0, -1.0))
	for i in range(CURSOR_TRAIL_COUNT):
		material.set_shader_parameter("cursor_trail_%d" % i, Vector4(-10.0, -10.0, 0.0, 0.18))
	var smoke_texture := _get_smoke_texture()
	if smoke_texture != null:
		material.set_shader_parameter("smoke_texture", smoke_texture)
		material.set_shader_parameter("use_smoke_texture", true)
	var cloud_texture := _get_cloud_texture()
	if cloud_texture != null:
		material.set_shader_parameter("cloud_texture", cloud_texture)
		material.set_shader_parameter("use_cloud_texture", true)
	var detail_texture := _get_detail_texture()
	if detail_texture != null:
		material.set_shader_parameter("detail_texture", detail_texture)
		material.set_shader_parameter("use_detail_texture", true)
	material.set_meta("layer_index", layer_index)
	return material

func _sync_layer_size() -> void:
	if _layer_materials.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	for i in range(_layer_materials.size()):
		var material := _layer_materials[i]
		if material == null:
			continue
		var layer_scale := 1.0 + float(i) * 0.015
		material.set_shader_parameter("layer_card_scale", Vector2(layer_scale, layer_scale))

func _animate_mist_layers() -> void:
	if _layer_materials.is_empty():
		return
	var seed := variant_seed if variant_seed != 0 else get_instance_id()
	var cluster_phase := _seeded_range(seed, 1, 0.0, TAU)
	var sway_multiplier := _seeded_range(seed, 2, 0.72, 1.06)
	var speed_multiplier := _seeded_range(seed, 3, 0.84, 1.22)
	for i in range(_layer_materials.size()):
		var material := _layer_materials[i]
		if material == null:
			continue
		var layer_phase := cluster_phase + float(i) * 1.73
		var speed_x := (0.36 + float(i) * 0.10) * speed_multiplier
		var speed_y := (0.29 + float(i) * 0.08) * speed_multiplier
		var sway_x := sin(_motion_elapsed * speed_x + layer_phase) * (0.034 + float(i) * 0.015) * sway_multiplier
		var sway_y := cos(_motion_elapsed * speed_y + layer_phase * 0.82) * (0.026 + float(i) * 0.011) * sway_multiplier
		material.set_shader_parameter("layer_motion_offset", Vector2(sway_x, sway_y))

func _refresh_cursor_motion() -> void:
	_refresh_cursor_motion_at(get_global_mouse_position() + CURSOR_CENTER_OFFSET_PIXELS)

func _refresh_cursor_motion_at(mouse_position: Vector2) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		_clear_cursor_motion()
		return
	var rect := get_global_rect()
	var influence_rect := rect.grow(maxf(rect.size.x, rect.size.y) * 0.72)
	if not influence_rect.has_point(mouse_position):
		_clear_cursor_motion(true)
		return
	var local_position := mouse_position - rect.position
	if _cursor_actual_position != Vector2.INF \
			and _cursor_actual_position.distance_to(local_position) >= CURSOR_TRAIL_MIN_DISTANCE:
		_push_cursor_trail_sample(_cursor_actual_position)
	_cursor_actual_position = local_position
	_cursor_clear_strength = 1.0

func _clear_cursor_motion(add_last_sample: bool = false) -> void:
	if add_last_sample and _cursor_actual_position != Vector2.INF:
		_push_cursor_trail_sample(_cursor_actual_position)
	_cursor_actual_position = Vector2.INF
	_cursor_clear_strength = 0.0

func _push_cursor_trail_sample(position: Vector2) -> void:
	_cursor_trail.push_front({
		"position": position,
		"age": 0.0,
	})
	if _cursor_trail.size() > CURSOR_TRAIL_COUNT:
		_cursor_trail.resize(CURSOR_TRAIL_COUNT)

func _age_cursor_trail(delta: float) -> void:
	for i in range(_cursor_trail.size() - 1, -1, -1):
		var sample := _cursor_trail[i]
		var age := float(sample.get("age", 0.0)) + delta
		if age >= CURSOR_TRAIL_LIFETIME:
			_cursor_trail.remove_at(i)
			continue
		sample["age"] = age
		_cursor_trail[i] = sample

func _sync_cursor_shader_parameters() -> void:
	if _layer_materials.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	var brush_radius := CURSOR_EFFECT_RADIUS_PIXELS / maxf(size.x, size.y)
	var cursor_uv := Vector2(-10.0, -10.0)
	var clear_strength := 0.0
	if _cursor_actual_position != Vector2.INF:
		cursor_uv = Vector2(
			_cursor_actual_position.x / size.x,
			_cursor_actual_position.y / size.y
		)
		clear_strength = _cursor_clear_strength
	var trail_values: Array[Vector4] = []
	for i in range(CURSOR_TRAIL_COUNT):
		var trail_value := Vector4(-10.0, -10.0, 0.0, brush_radius)
		if i < _cursor_trail.size():
			var sample := _cursor_trail[i]
			var sample_position := sample.get("position", Vector2.INF) as Vector2
			if sample_position != Vector2.INF:
				var sample_age := float(sample.get("age", CURSOR_TRAIL_LIFETIME))
				var sample_strength := pow(
					clampf(1.0 - sample_age / CURSOR_TRAIL_LIFETIME, 0.0, 1.0),
					1.35
				)
				trail_value = Vector4(
					sample_position.x / size.x,
					sample_position.y / size.y,
					sample_strength,
					brush_radius
				)
		trail_values.append(trail_value)
	for material in _layer_materials:
		if material == null:
			continue
		material.set_shader_parameter("cursor_uv", cursor_uv)
		material.set_shader_parameter("cursor_clear_strength", clear_strength)
		material.set_shader_parameter("cursor_brush_radius", brush_radius)
		for i in range(CURSOR_TRAIL_COUNT):
			material.set_shader_parameter("cursor_trail_%d" % i, trail_values[i])

func _update_alpha() -> void:
	for i in range(_layer_materials.size()):
		var material := _layer_materials[i]
		if material == null:
			continue
		var seed := variant_seed if variant_seed != 0 else get_instance_id()
		var layer_seed := seed + i * 101
		material.set_shader_parameter(
			"fog_alpha",
			maxf(0.0, fog_alpha - float(i) * 0.060) * _seeded_range(layer_seed, 11, 0.88, 1.10)
		)

func _configure_variant() -> void:
	if _layer_materials.is_empty():
		return
	var seed := variant_seed
	if seed == 0:
		seed = get_instance_id()
	var angle := _seeded_range(seed, 4, 0.0, TAU)
	var drift_direction := Vector2(cos(angle), sin(angle) * 0.72)
	if drift_direction.length_squared() <= 0.001:
		drift_direction = Vector2(1.0, -0.55)
	drift_direction = drift_direction.normalized()

	for i in range(_layer_materials.size()):
		var material := _layer_materials[i]
		if material == null:
			continue
		var layer_seed := seed + i * 101
		material.set_shader_parameter("phase", float(i) * 3.17 + _seeded_range(layer_seed, 10, 0.0, TAU))
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
	_update_alpha()

static func _get_mist_shader() -> Shader:
	if _shader_cache != null:
		return _shader_cache
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform vec4 fog_color : source_color = vec4(0.80, 0.82, 0.84, 0.34);
uniform float fog_alpha = 0.42;
uniform float cloud_scale = 2.3;
uniform float drift_speed = 0.025;
uniform float phase = 0.0;
uniform sampler2D smoke_texture : filter_linear, repeat_disable;
uniform sampler2D cloud_texture : filter_linear, repeat_enable;
uniform sampler2D detail_texture : filter_linear, repeat_enable;
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
uniform vec4 cursor_trail_6 = vec4(-10.0, -10.0, 0.0, 0.18);
uniform vec2 hover_clear_uv_min = vec2(2.0, 2.0);
uniform vec2 hover_clear_uv_max = vec2(-1.0, -1.0);
uniform vec2 layer_card_scale = vec2(1.0, 1.0);
uniform vec2 layer_motion_offset = vec2(0.0, 0.0);
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
	vec2 uv = vec2(0.5) + (UV - vec2(0.5)) / max(layer_card_scale, vec2(0.001)) - layer_motion_offset;
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
	healing_clear = max(healing_clear, cursor_trail_field(uv, cursor_trail_6));
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
	float edge_x = smoothstep(0.0, 0.075, UV.x) * smoothstep(0.0, 0.075, 1.0 - UV.x);
	float edge_y = smoothstep(0.0, 0.085, UV.y) * smoothstep(0.0, 0.085, 1.0 - UV.y);
	float feather = pow(edge_x * edge_y, 0.78);
	COLOR = vec4(fog_color.rgb, fog_alpha * density * feather);
}
"""
	_shader_cache = shader
	return _shader_cache

static func _get_smoke_texture() -> Texture2D:
	if _smoke_texture_cache != null:
		return _smoke_texture_cache
	_smoke_texture_cache = _load_texture(SMOKE_TEXTURE_PATH)
	return _smoke_texture_cache

static func _get_cloud_texture() -> Texture2D:
	if _cloud_texture_cache != null:
		return _cloud_texture_cache
	_cloud_texture_cache = _load_texture(CLOUD_TEXTURE_PATH)
	return _cloud_texture_cache

static func _get_detail_texture() -> Texture2D:
	if _detail_texture_cache != null:
		return _detail_texture_cache
	_detail_texture_cache = _load_texture(DETAIL_TEXTURE_PATH)
	return _detail_texture_cache

static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path, "Texture2D"):
		var imported_texture := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
		if imported_texture != null:
			return imported_texture
	var image := Image.new()
	if image.load(path) == OK:
		return ImageTexture.create_from_image(image)
	return null

func _seeded_unit(seed: int, salt: int) -> float:
	return float(posmod(("%d:%d" % [seed, salt]).hash(), 10000)) / 10000.0

func _seeded_range(seed: int, salt: int, min_value: float, max_value: float) -> float:
	return lerpf(min_value, max_value, _seeded_unit(seed, salt))
