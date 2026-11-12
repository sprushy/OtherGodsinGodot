shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec2 scale_count = vec2(54.0, 20.0);
uniform vec3 dark_hide : source_color = vec3(0.025, 0.027, 0.017);
uniform vec3 bronze_hide : source_color = vec3(0.58, 0.52, 0.30);
uniform bool raised_plate = false;
uniform sampler2D card_art : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 art_region = vec4(0.0, 0.0, 1.0, 1.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float soft_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 weight = fract(p);
	weight = weight * weight * (3.0 - 2.0 * weight);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), weight.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), weight.x),
		weight.y
	);
}

float scale_height(vec2 p) {
	p.y += mod(floor(p.x), 2.0) * 0.5;
	vec2 cell = fract(p) - 0.5;
	float plate = max(0.0, 1.0 - dot(cell * vec2(1.8, 1.65), cell * vec2(1.8, 1.65)));
	return pow(plate, 0.7) * (1.0 - smoothstep(0.35, 0.49, abs(cell.x)));
}

float plate_pores(vec2 uv, float seed) {
	return soft_noise(uv * vec2(48.0, 34.0) + vec2(seed, seed * 0.37));
}

void fragment() {
	if (raised_plate) {
		// Instance colors retain the art's gold islands; fine wear catches the light.
		float seed = hash21(COLOR.rg * 117.0) * 100.0;
		float footprint = max(length(dFdx(UV)), length(dFdy(UV)));
		float detail = 1.0 - smoothstep(0.012, 0.055, footprint);
		float pores = mix(0.5, plate_pores(UV, seed), detail);
		float rim = smoothstep(0.32, 0.49, length((UV - 0.5) * vec2(0.95, 1.05)));
		float scratches = pow(0.5 + 0.5 * sin(UV.x * 170.0 + soft_noise(UV * 18.0 + seed) * 2.4), 20.0) * detail;
		vec3 palette = COLOR.rgb * vec3(1.0, 0.98, 0.91);
		// A fixed sample on each plate carries the painted pigment through every pose.
		vec2 anchor = vec2(hash21(vec2(seed, 3.1)), hash21(vec2(8.6, seed)));
		vec2 patch_uv = mix(vec2(0.1), vec2(0.9), anchor) + (UV - 0.5) * 0.16;
		vec3 pigment = texture(card_art, art_region.xy + patch_uv * art_region.zw).rgb;
		float pigment_light = dot(pigment, vec3(0.2126, 0.7152, 0.0722));
		float gold = clamp(max(palette.r, palette.g), 0.0, 1.0);
		float painted_weight = mix(0.22, 0.74, smoothstep(0.08, 0.60, gold));
		vec3 painted = mix(pigment * 0.65, pigment, smoothstep(0.025, 0.40, pigment_light));
		vec3 color = mix(palette, painted, painted_weight);
		ALBEDO = color * (0.96 + pores * 0.08) + color * rim * scratches * 0.08;
		METALLIC = 0.10 + gold * 0.14;
		ROUGHNESS = 0.43 + pores * 0.07 - rim * 0.08 + scratches * 0.04 - pigment_light * 0.11;
		SPECULAR = 0.55;
		CLEARCOAT = 0.17;
		CLEARCOAT_ROUGHNESS = 0.30;
		AO = 1.0 - rim * 0.12;
		vec2 slope = vec2(
			plate_pores(UV + vec2(0.001, 0.0), seed) - plate_pores(UV - vec2(0.001, 0.0), seed),
			plate_pores(UV + vec2(0.0, 0.001), seed) - plate_pores(UV - vec2(0.0, 0.001), seed)
		);
		NORMAL_MAP = normalize(vec3(-slope * 0.85 * detail, 1.0)) * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = 0.35;
	} else {
		vec2 lattice = UV * scale_count;
		float height = scale_height(lattice);
		float pixel_span = max(length(dFdx(lattice)), length(dFdy(lattice)));
		float detail = 1.0 - smoothstep(0.20, 0.80, pixel_span);
		float grain = soft_noise(UV * vec2(640.0, 160.0));
		float pores = mix(0.5, grain, 1.0 - smoothstep(0.025, 0.18, pixel_span));
		float variation = hash21(floor(lattice));
		float dorsal = pow(0.5 + 0.5 * sin(UV.y * 6.2831853), 3.0);
		float ribbon = 0.5 + 0.5 * cos(UV.y * 18.84956 + sin(lattice.x * 0.27) * 1.2);
		float gilding = smoothstep(0.58, 0.86, ribbon) * (0.55 + variation * 0.45);
		vec3 hide = mix(dark_hide, bronze_hide * 0.26, variation * 0.7);
		vec3 gold = mix(bronze_hide, vec3(0.84, 0.81, 0.59), variation * variation);
		vec3 color = mix(hide, gold, gilding * height);
		color *= mix(0.88, 1.0, dorsal) * (0.96 + pores * 0.08);
		ALBEDO = color;
		METALLIC = 0.14 + gilding * 0.10;
		ROUGHNESS = mix(0.56, 0.34, height) + pores * 0.04;
		SPECULAR = 0.55;
		AO = mix(0.60, 1.0, height);
		CLEARCOAT = 0.22;
		CLEARCOAT_ROUGHNESS = 0.30;
		RIM = 0.12;
		RIM_TINT = 0.35;
		vec2 slope = vec2(
			scale_height(lattice + vec2(0.015, 0.0)) - scale_height(lattice - vec2(0.015, 0.0)),
			scale_height(lattice + vec2(0.0, 0.015)) - scale_height(lattice - vec2(0.0, 0.015))
		);
		NORMAL_MAP = normalize(vec3(-slope * 5.0 * detail, 1.0)) * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = 0.65;
	}
}
