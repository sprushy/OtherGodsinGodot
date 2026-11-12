shader_type spatial;
render_mode specular_schlick_ggx;

uniform float eye_radius = 0.135;
uniform float pupil_width = 0.27;
varying vec3 eye_position;

void vertex() {
	eye_position = VERTEX / eye_radius;
}

void fragment() {
	vec2 iris = eye_position.xy;
	float radius = length(iris);
	float angle = atan(iris.y, iris.x + 0.00001);
	float footprint = max(length(dFdx(iris)), length(dFdy(iris)));
	float detail = 1.0 - smoothstep(0.04, 0.18, footprint);
	float filaments = 0.5 + 0.5 * sin(angle * 43.0 + sin(radius * 27.0) * 1.4);
	filaments = mix(0.5, filaments, detail);
	float veins = 0.5 + 0.5 * sin(angle * 79.0 - radius * 33.0);
	float limbus = smoothstep(0.72, 0.98, radius);
	float pupil_distance = length(iris / vec2(pupil_width, 0.52));
	float pupil_edge = max(fwidth(pupil_distance), 0.025);
	float pupil = 1.0 - smoothstep(1.0 - pupil_edge, 1.0 + pupil_edge, pupil_distance);
	vec3 emerald = mix(vec3(0.012, 0.12, 0.008), vec3(0.16, 0.70, 0.025), filaments);
	emerald += vec3(0.13, 0.17, 0.015) * veins * detail * (1.0 - radius) * 0.35;
	emerald = mix(emerald, vec3(0.004, 0.025, 0.003), limbus);
	ALBEDO = mix(emerald, vec3(0.001, 0.004, 0.001), pupil);
	EMISSION = emerald * (1.0 - pupil) * (1.0 - limbus) * 0.6;
	METALLIC = 0.03;
	ROUGHNESS = 0.13;
	SPECULAR = 0.55;
	CLEARCOAT = 0.85;
	CLEARCOAT_ROUGHNESS = 0.08;
}
