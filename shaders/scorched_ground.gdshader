shader_type canvas_item;
render_mode unshaded;

uniform int stone_count = 0;
uniform vec4 stone_tiles[10];
uniform sampler2D stone_mask_atlas : filter_linear, repeat_disable;
varying vec2 ground_position;
varying float mark_opacity;

void vertex() {
	ground_position = VERTEX;
	mark_opacity = COLOR.a;
}

void fragment() {
	vec4 stamp = texture(TEXTURE, UV);
	float stone = 0.0;
	for (int i = 0; i < 10; i++) {
		if (i >= stone_count) { break; }
		vec4 tile = stone_tiles[i];
		vec2 tile_uv = (ground_position - tile.xy) / max(tile.zw * 2.0, vec2(1.0)) + 0.5;
		if (tile_uv.x >= 0.0 && tile_uv.x <= 1.0 && tile_uv.y >= 0.0 && tile_uv.y <= 1.0) {
			vec2 atlas_uv = vec2((float(i) + tile_uv.x) / 10.0, tile_uv.y);
			stone = max(stone, texture(stone_mask_atlas, atlas_uv).r);
		}
	}
	float grain = stamp.r;
	float fine = stamp.g;
	float coverage = smoothstep(0.08, 0.65, stamp.a);
	float lightning = step(0.99, stamp.b);
	// Stone retains its texture under a dry, granular heat stain.
	float stone_alpha = coverage * mix(0.28 + fine * 0.3, 0.96, lightning);
	vec3 stone_char = mix(vec3(0.12, 0.105, 0.085), vec3(0.23, 0.21, 0.18), grain);
	// Burned grass has a brown singed fringe and dark, crisp blade-like flecks.
	float blades = smoothstep(0.37, 0.68, fine);
	float grass_alpha = coverage * (0.88 + blades * 0.1);
	vec3 grass_char = mix(vec3(0.055, 0.024, 0.008), vec3(0.008, 0.009, 0.005), coverage * (0.7 + blades * 0.3));
	vec3 char_color = mix(grass_char, stone_char, stone);
	char_color = mix(char_color, vec3(0.018, 0.012, 0.008), lightning);
	// Use the original vertex opacity: COLOR.a already contains stamp alpha,
	// which used to attenuate the grass damage twice and leave its green visible.
	COLOR = vec4(char_color, mix(grass_alpha, stone_alpha, stone) * mark_opacity);
}
