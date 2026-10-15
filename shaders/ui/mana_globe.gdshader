shader_type canvas_item;
render_mode unshaded;

uniform float fill_amount : hint_range(0.0, 1.0) = 0.0;
uniform bool show_divisions = false;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float radius = length(UV - vec2(0.5));
	float pixel = max(TEXTURE_PIXEL_SIZE.x, fwidth(UV.y));
	float interior = 1.0 - smoothstep(0.430, 0.438, radius);
	// Keep the original gold rim; mask the square background outside the globe.
	float silhouette = 1.0 - smoothstep(0.487, 0.497, radius);
	float depth = clamp((0.935 - UV.y) / 0.87, 0.0, 1.0);
	float filled = 0.0;
	if (fill_amount > 0.0) {
		filled = 1.0 - smoothstep(fill_amount - pixel, fill_amount + pixel, depth);
	}
	if (fill_amount >= 1.0) {
		filled = 1.0;
	}
	float grey = dot(art.rgb, vec3(0.299, 0.587, 0.114));
	vec3 empty_color = mix(vec3(grey), art.rgb, 0.2) * 0.16;
	vec3 glass = mix(empty_color, art.rgb, filled);
	// Ten horizontal bands: 2, 4 or 10 mana per band for each scale.
	float nearest_break = floor(depth * 10.0 + 0.5);
	float break_distance = abs(depth - nearest_break / 10.0) * 0.87;
	float division = (1.0 - smoothstep(pixel * 0.4, pixel * 1.1, break_distance));
	division *= step(1.0, nearest_break) * step(nearest_break, 9.0);
	if (show_divisions) {
		glass = mix(glass, vec3(0.64, 0.82, 0.96), division * 0.48);
	}
	if (fill_amount > 0.0 && fill_amount < 1.0) {
		float surface = 1.0 - smoothstep(pixel * 0.5, pixel * 1.5, abs(depth - fill_amount) * 0.87);
		glass = mix(glass, vec3(0.5, 0.88, 1.0), surface * 0.8);
	}
	COLOR = tint * vec4(mix(art.rgb, glass, interior), art.a * silhouette);
}
