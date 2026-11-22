shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float brightness : hint_range(0.0, 1.5) = 1.0;
uniform float ray_strength : hint_range(0.0, 1.5) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float aspect_ratio = 1.777778;
uniform float effect_time = 0.0;

void fragment() {
	// An upper-right sun sends long, softly moving shafts across the board.
	vec2 from_sun = (UV - vec2(0.88, 0.025)) * vec2(aspect_ratio, 1.0);
	float radius = length(from_sun);
	float angle = atan(from_sun.y, from_sun.x);
	float broad_rays = pow(max(0.0, sin(angle * 17.0 + sin(effect_time * 0.13) * 0.25)), 12.0);
	float fine_rays = pow(max(0.0, sin(angle * 31.0 - effect_time * 0.025)), 36.0);
	float ray_falloff = exp(-radius * 1.1) * smoothstep(0.035, 0.16, radius);
	float rays = (broad_rays * 0.22 + fine_rays * 0.09) * ray_falloff * ray_strength;
	float halo = exp(-radius * 7.0) * 0.48;
	float corona = exp(-radius * 22.0) * 0.65;
	float sun = (1.0 - smoothstep(0.02, 0.055, radius)) * 1.3;
	float warm_haze = 0.025 + exp(-radius * 1.8) * 0.035;
	vec3 light = vec3(1.0, 0.72, 0.30) * (rays + halo + warm_haze);
	light += vec3(1.0, 0.94, 0.72) * (sun + corona);
	COLOR = vec4(light * brightness, fade);
}
