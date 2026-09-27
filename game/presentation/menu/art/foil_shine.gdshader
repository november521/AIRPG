shader_type canvas_item;
render_mode unshaded;

uniform float reflection_strength : hint_range(0.0, 0.2) = 0.095;
uniform float motion_speed : hint_range(0.0, 2.0) = 1.0;
uniform float shimmer_strength : hint_range(0.0, 0.1) = 0.025;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec4 logo = texture(TEXTURE, UV);
	float t = TIME * motion_speed;
	float passage = mod(t * 0.052, 1.6) - 0.3;
	float reflection = exp(-pow((UV.x + UV.y * 0.17 - passage) * 24.0, 2.0));
	float metal_face = smoothstep(0.35, 0.90, max(logo.r, logo.g));
	// Highlights travel across the metal, not a whole-word opacity flash.
	float shimmer = pow(0.5 + 0.5 * sin(UV.x * 19.0 - UV.y * 7.0 - t * 0.42), 4.0);
	float sheen = reflection * reflection_strength + shimmer * shimmer_strength;
	logo.rgb += vec3(1.0, 0.86, 0.57) * metal_face * sheen;
	COLOR = logo * tint;
}
