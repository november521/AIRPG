shader_type canvas_item;
render_mode unshaded;

uniform float drift_strength : hint_range(0.0, 0.04) = 0.018;
uniform float exposure : hint_range(0.0, 1.5) = 0.82;
uniform float motion_speed : hint_range(0.0, 2.0) = 1.0;
uniform float depth_strength : hint_range(0.0, 1.0) = 0.7;
varying vec4 tint;
void vertex() { tint = COLOR; }
vec2 flow_field(vec2 p, float t) {
	return vec2(sin(p.y * 1.6 + t) + sin(p.x + p.y * 0.6 - t * 0.7),
		cos(p.x * 1.2 - t * 0.8) + sin(p.y - p.x * 0.7 + t * 0.5));
}
void fragment() {
	float t = TIME * motion_speed;
	vec2 edge = smoothstep(vec2(0.0), vec2(0.12), UV) *
		(1.0 - smoothstep(vec2(0.88), vec2(1.0), UV));
	// Three depths share the existing plate, with bounded, counter-moving currents.
	vec2 base_uv = UV + flow_field(UV * vec2(7.0, 4.0), t * 0.11) * drift_strength * edge;
	vec2 far_uv = (UV - 0.5) * 0.90 + 0.5;
	far_uv += flow_field(UV * vec2(4.0, 3.0) + 2.7, -t * 0.075) * drift_strength * 1.4 * edge;
	vec2 near_uv = (UV - 0.5) * 0.78 + 0.5;
	near_uv += flow_field(UV * vec2(9.0, 5.0) - 1.9, t * 0.17) * drift_strength * 2.0 * edge;
	vec3 base = texture(TEXTURE, clamp(base_uv, vec2(0.0), vec2(1.0))).rgb;
	vec3 far_smoke = texture(TEXTURE, clamp(far_uv, vec2(0.0), vec2(1.0))).rgb;
	vec3 near_smoke = texture(TEXTURE, clamp(near_uv, vec2(0.0), vec2(1.0))).rgb;
	// Do not wash out the title/menu or brighten the screen by stacking additively.
	float clear_center = smoothstep(0.12, 0.42, abs(UV.x - 0.5));
	float layers = depth_strength * edge.x * edge.y * mix(0.20, 1.0, clear_center);
	vec3 smoke = mix(base, base * 0.45 + far_smoke * 0.35 + near_smoke * 0.20, layers);
	float breath = 0.96 + 0.04 * sin(t * 0.19 + UV.y * 4.0);
	COLOR = vec4(smoke * exposure * breath, 1.0) * tint;
}
