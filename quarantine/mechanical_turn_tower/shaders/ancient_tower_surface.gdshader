shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(0.30, 0.20, 0.10, 1.0);
uniform vec4 patina_color : source_color = vec4(0.10, 0.23, 0.19, 1.0);
uniform vec4 wear_color : source_color = vec4(0.57, 0.42, 0.22, 1.0);
uniform float metalness : hint_range(0.0, 1.0) = 0.65;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.72;
uniform float aging : hint_range(0.0, 1.0) = 0.55;
// 0: cast metal, 1: stone, 2: twisted hemp, 3: worn wood.
uniform int surface_kind = 0;

varying vec3 object_position;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3(cell), hash3(cell + vec3(1, 0, 0)), f.x),
			mix(hash3(cell + vec3(0, 1, 0)), hash3(cell + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(cell + vec3(0, 0, 1)), hash3(cell + vec3(1, 0, 1)), f.x),
			mix(hash3(cell + vec3(0, 1, 1)), hash3(cell + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	object_position = VERTEX;
}

void fragment() {
	vec3 p = object_position;
	float broad = noise3(p * 3.4);
	float grain = noise3(p * 47.0);
	float pitting = smoothstep(0.64, 0.88, noise3(p * 95.0));
	float crust = smoothstep(0.34, 0.71, broad + noise3(p * 9.0) * 0.18) * aging;
	vec3 color = mix(base_color.rgb, patina_color.rgb, crust);
	float worn = smoothstep(0.66, 0.86, broad * 0.4 + grain * 0.6);
	color = mix(color, wear_color.rgb, worn * 0.48);
	color *= 0.79 + grain * 0.30 - pitting * 0.24;
	float relief = grain * 0.0015 - pitting * 0.001;
	float roughness = surface_roughness + crust * 0.20 + pitting * 0.12;
	float metallic = metalness * (1.0 - crust * 0.75);

	if (surface_kind == 1) {
		// Mineral flecks, dark fissures, and moss gathered in the stone's pores.
		float seams = 1.0 - smoothstep(0.012, 0.045, abs(noise3(p * 7.0) - 0.5));
		color = mix(base_color.rgb, wear_color.rgb, broad * 0.72);
		color = mix(color, patina_color.rgb, crust * 0.65);
		color *= 0.80 + grain * 0.3 - seams * 0.23;
		relief = grain * 0.003 - seams * 0.002;
		roughness = 0.96;
		metallic = 0.0;
	} else if (surface_kind == 2) {
		float twist = sin(atan(p.z, p.x) * 3.0 - p.y * 115.0);
		float fibers = noise3(vec3(p.x * 280.0, p.y * 13.0, p.z * 280.0));
		color = mix(patina_color.rgb, base_color.rgb, smoothstep(-0.8, 0.65, twist));
		color *= 0.82 + fibers * 0.33;
		relief = twist * 0.001 + fibers * 0.0005;
		roughness = 0.98;
		metallic = 0.0;
	} else if (surface_kind == 3) {
		float wood = noise3(vec3(p.x * 86.0, p.y * 5.0, p.z * 86.0));
		color = mix(patina_color.rgb, base_color.rgb, wood);
		color = mix(color, wear_color.rgb, smoothstep(0.65, 0.9, grain) * 0.32);
		relief = wood * 0.0015;
		roughness = 0.90;
		metallic = 0.0;
	}

	ALBEDO = color;
	ROUGHNESS = clamp(roughness, 0.3, 1.0);
	METALLIC = metallic;
	SPECULAR = 0.38;
	// Derivative bump mapping works on the native meshes without UV textures.
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 r1 = cross(dy, NORMAL);
	vec3 r2 = cross(NORMAL, dx);
	float determinant = dot(dx, r1);
	vec3 gradient = dFdx(relief) * r1 + dFdy(relief) * r2;
	if (abs(determinant) > 0.0000001) {
		NORMAL = normalize(abs(determinant) * NORMAL - sign(determinant) * gradient);
	}
}
