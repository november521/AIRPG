shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 gold : source_color = vec4(0.92, 0.65, 0.27, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float breath = 0.92 + 0.08 * sin(TIME * 0.65);
	float haze = exp(-p.x * p.x * 6.0 - p.y * p.y * 3.0) * 0.20;
	float foot = exp(-p.x * p.x * 22.0 - pow((p.y - 0.63) * 22.0, 2.0)) * 0.55;
	float ray = (smoothstep(0.27, 0.32, abs(p.x)) - smoothstep(0.84, 1.0, abs(p.x)))
		* exp(-p.y * p.y * 4600.0) * 0.78;
	float diamond_distance = abs(abs(p.x) - 0.58) / 0.017 + abs(p.y) / 0.16;
	float diamond = (1.0 - smoothstep(0.85, 1.10, diamond_distance)) * 0.92;
	float alpha = clamp(haze + foot + ray + diamond, 0.0, 1.0);
	vec3 ink = mix(gold.rgb, vec3(1.0, 0.91, 0.70), clamp(diamond + foot, 0.0, 1.0));
	COLOR = vec4(ink, alpha * intensity * breath) * COLOR;
}
