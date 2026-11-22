shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float phase = 0.0;
uniform float energy = 0.0;
uniform float opacity = 1.0;

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 h = fract(sin(vec4(dot(i, vec2(127.1, 311.7)), dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7)), dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7)), dot(i + vec2(1.0), vec2(127.1, 311.7)))) * 43758.5453);
	return mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x) - phase;
	float warp = noise(vec2(a * 2.5, r * 8.0 - phase)) - 0.5;
	float ring = exp(-pow((r - 0.68 - warp * 0.035) * 55.0, 2.0));
	float inner = exp(-pow((r - 0.51 - sin(a * 5.0 + phase) * 0.025) * 85.0, 2.0));
	float spiral = pow(max(0.0, sin(a * 5.0 + r * 21.0)), 20.0);
	spiral *= smoothstep(0.2, 0.5, r) * (1.0 - smoothstep(0.68, 0.95, r));
	float dust = pow(noise(p * 75.0 + phase * 0.2), 14.0) * smoothstep(0.35, 0.6, r) * (1.0 - smoothstep(0.7, 0.98, r));
	float halo = exp(-pow((r - 0.6) * 6.0, 2.0)) * 0.10;
	float alpha = (ring * 0.75 + inner * 0.55 + spiral * (0.16 + energy * 0.35) + dust * 2.0 + halo) * opacity;
	vec3 pink = mix(vec3(0.95, 0.025, 0.44), vec3(1.0, 0.72, 0.95), ring * (0.3 + energy * 0.3));
	COLOR = vec4(pink, clamp(alpha, 0.0, 1.0));
}
