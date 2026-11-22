shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float effect_time = 0.0;
uniform float seed = 0.0;
uniform float intensity = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		value += amplitude * noise(p);
		p = p * 2.07 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 uv = UV;
	float t = effect_time;
	vec2 flow = vec2(uv.x * 6.0 + seed, uv.y * 11.0 + t * 4.5);
	float turbulence = fbm(flow);
	float wake = smoothstep(0.0, 0.8, uv.y);
	float axis = uv.x - 0.5 + (turbulence - 0.5) * 0.24 * (1.0 - wake);
	float width = mix(0.018, 0.30, pow(wake, 0.7));
	width *= 0.65 + 0.6 * turbulence;
	float plume = 1.0 - smoothstep(width * 0.35, width, abs(axis));
	plume *= smoothstep(0.02, 0.23, uv.y) * (1.0 - smoothstep(0.77, 0.97, uv.y));
	float tongues = fbm(flow * vec2(2.3, 0.8) + vec2(0.0, t * 3.0));
	plume *= smoothstep(0.18, 0.64, tongues + wake * 0.35);
	vec2 head_uv = vec2((uv.x - 0.5) * 4.5, (uv.y - 0.80) * 13.5);
	float head_dist = length(head_uv);
	float head = 1.0 - smoothstep(0.35, 1.0 + turbulence * 0.22, head_dist);
	float corona = exp(-head_dist * head_dist * 1.8) * 0.4;
	float heat = max(plume * (0.35 + wake * 0.55), head);
	vec3 fire = mix(vec3(0.95, 0.055, 0.003), vec3(1.0, 0.40, 0.025), smoothstep(0.1, 0.55, heat));
	fire = mix(fire, vec3(1.0, 0.88, 0.35), smoothstep(0.5, 0.82, heat));
	fire = mix(fire, vec3(1.0, 0.98, 0.87), smoothstep(0.8, 1.0, heat));
	float alpha = max(plume, head) + corona;
	alpha *= smoothstep(0.0, 0.07, uv.x) * (1.0 - smoothstep(0.93, 1.0, uv.x));
	COLOR = vec4(fire * intensity, clamp(alpha, 0.0, 1.0));
}
