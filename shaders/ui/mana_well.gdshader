shader_type canvas_item;
render_mode unshaded;

uniform float activity : hint_range(0.0, 1.0) = 1.0;
uniform float effect_time = 0.0;
uniform float swirl_speed : hint_range(-2.0, 2.0) = 0.55;
uniform float steam_strength : hint_range(0.0, 1.0) = 0.36;

// UV coordinates refer to the full, shared 1254px canvas, including the hatch.
// This ellipse sits inside the liquid so the rim and snow cannot rotate.
uniform vec2 pool_center = vec2(0.503, 0.630);
uniform vec2 pool_radius = vec2(0.188, 0.148);
uniform float steam_height = 0.26;

varying vec4 vertex_tint;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 fraction = fract(point);
	vec2 blend = fraction * fraction * (3.0 - 2.0 * fraction);
	return mix(
		mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x),
		blend.y
	);
}

float billows(vec2 point) {
	float density = 0.5 * value_noise(point);
	point = point * 2.03 + vec2(8.1, 19.7);
	density += 0.25 * value_noise(point);
	point = point * 2.03 + vec2(8.1, 19.7);
	return density + 0.125 * value_noise(point);
}

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float steam_alpha = 0.0;
	if (activity > 0.0) {
		vec2 point = (UV - pool_center) / pool_radius;
		float radius = length(point);
		if (radius < 0.98) {
			float edge = 1.0 - smoothstep(0.80, 0.98, radius);
			float angle = effect_time * swirl_speed * (1.2 - 0.35 * radius);
			float sine = sin(angle);
			float cosine = cos(angle);
			vec2 flowing = vec2(
				cosine * point.x - sine * point.y,
				sine * point.x + cosine * point.y
			);
			// Radial rotation keeps every sample inside the pool; the edge stays still.
			flowing *= 1.0 + 0.008 * sin(radius * 38.0 - effect_time * 2.3);
			vec4 liquid = texture(TEXTURE, pool_center + flowing * pool_radius);
			art = mix(art, liquid, edge * activity);
		}

		// Advection moves the noise upward while the plume billows and dissipates.
		float rise = (pool_center.y + 0.045 - UV.y) / steam_height;
		if (rise > 0.0 && rise < 1.0) {
			float sway = 0.012 * sin(rise * 7.0 - effect_time * 0.5);
			float half_width = mix(0.040, 0.095, rise);
			float across = abs(UV.x - pool_center.x - sway) / half_width;
			if (across < 1.0) {
				vec2 drift = vec2(effect_time * 0.12, effect_time * 0.70);
				float density = billows(UV * vec2(40.0, 28.0) + drift);
				float sides = 1.0 - smoothstep(0.15, 1.0, across);
				float ends = smoothstep(0.0, 0.15, rise) * (1.0 - smoothstep(0.65, 1.0, rise));
				steam_alpha = smoothstep(0.30, 0.65, density) * sides * ends * steam_strength * activity;
			}
		}
	}

	// Straight-alpha over: steam can extend beyond opaque art without a matte.
	vec3 steam_color = vec3(0.77, 0.87, 0.96);
	float alpha = steam_alpha + art.a * (1.0 - steam_alpha);
	vec3 rgb = (steam_color * steam_alpha + art.rgb * art.a * (1.0 - steam_alpha)) / max(alpha, 0.00001);
	COLOR = vec4(rgb, alpha) * vertex_tint;
}
