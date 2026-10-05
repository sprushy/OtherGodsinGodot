extends TextureRect
class_name StorySnowMap

const NORMAL_PATH := "res://images/story/snow_forest/normal.png"
const HEIGHT_PATH := "res://images/story/snow_forest/height.png"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -100
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D terrain_normal;
uniform sampler2D terrain_height;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 normal = normalize(texture(terrain_normal, UV).rgb * 2.0 - 1.0);
	float height = texture(terrain_height, UV).r;
	vec3 light_direction = normalize(vec3(-0.35, -0.58, 0.74));
	float diffuse = clamp(dot(normal, light_direction) * 0.36 + 0.64, 0.0, 1.0);
	float snow_depth = mix(0.92, 1.08, height);
	COLOR = vec4(base.rgb * diffuse * snow_depth, base.a);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("terrain_normal", load(NORMAL_PATH) as Texture2D)
	material.set_shader_parameter("terrain_height", load(HEIGHT_PATH) as Texture2D)
	self.material = material
