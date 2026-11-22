shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec4 paper_color : source_color = vec4(0.94, 0.87, 0.70, 1.0);
uniform float grain_strength : hint_range(0.0, 0.2) = 0.045;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float grain = hash(floor(UV * 920.0));
	float fibers = sin(UV.y * 1800.0 + sin(UV.x * 73.0) * 2.0);
	ALBEDO = paper_color.rgb * (1.0 + (grain - 0.5) * grain_strength + fibers * 0.009);
	ROUGHNESS = 0.94;
	SPECULAR = 0.12;
}
