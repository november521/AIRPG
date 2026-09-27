shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec2 canvas_size = vec2(1920.0, 1080.0);
uniform float brilliance : hint_range(0.0, 2.0) = 0.9;
uniform float motion_speed : hint_range(0.0, 2.0) = 1.0;

float star(vec2 p, float extent) {
	float core = exp(-dot(p, p) / (extent * 0.11));
	float rays = exp(-abs(p.x) * 1.8 - abs(p.y) / extent)
		+ exp(-abs(p.y) * 1.8 - abs(p.x) / (extent * 0.55));
	float halo = exp(-dot(p, p) / (extent * extent * 0.60)) * 0.09;
	return core * 0.8 + rays * 0.75 + halo;
}
void fragment() {
	vec2 pixel = UV * canvas_size;
	float t = TIME * motion_speed;
	vec3 gold = vec3(1.0, 0.62, 0.22);
	vec3 ivory = vec3(1.0, 0.88, 0.59);
	float north_pulse = 0.82 + 0.18 * sin(t * 0.41);
	float south_pulse = 0.82 + 0.18 * sin(t * 0.33 + 2.4);
	vec3 light = ivory * (star(pixel - vec2(960.0, 62.0), 17.0) * north_pulse
		+ star(pixel - vec2(960.0, 704.0), 15.0) * south_pulse);
	// One slow orbit; motes move while the interface stays still.
	for (int i = 0; i < 5; i++) {
		float angle = float(i) * 1.256637 + 0.31 + t * 0.014;
		vec2 point = vec2(960.0, 383.0) + vec2(cos(angle) * 455.0, sin(angle) * 316.0);
		vec2 delta = pixel - point;
		float bead = exp(-dot(delta, delta) / 6.0);
		float glow = exp(-dot(delta, delta) / 115.0) * 0.10;
		float pulse = 0.78 + 0.22 * sin(t * (0.36 + float(i) * 0.037) + float(i) * 2.1);
		light += gold * (bead * 0.65 + glow) * pulse;
	}
	float first = pow(max(0.0, sin(t * 0.23)), 6.0);
	float second = pow(max(0.0, sin(t * 0.23 + 2.1)), 6.0);
	float third = pow(max(0.0, sin(t * 0.23 + 4.2)), 6.0);
	light += ivory * star(pixel - vec2(790.0, 310.0), 15.0) * first * 0.52;
	light += ivory * star(pixel - vec2(1420.0, 302.0), 13.0) * second * 0.46;
	light += ivory * star(pixel - vec2(706.0, 381.0), 11.0) * third * 0.40;
	COLOR = vec4(light * brilliance, 1.0) * COLOR;
}
