shader_type canvas_item;
render_mode unshaded;

uniform float opacity : hint_range(0.0, 1.0) = 0.25;
uniform float angular_speed : hint_range(-0.1, 0.1) = 0.0;
uniform vec2 orbit_half_size = vec2(460.0, 321.0);

void vertex() {
	// Rotate in orbital coordinates so the engraving stays inside its frame.
	vec2 p = (VERTEX - orbit_half_size) / orbit_half_size;
	float angle = TIME * angular_speed;
	float c = cos(angle);
	float s = sin(angle);
	p = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	VERTEX = orbit_half_size + p * orbit_half_size;
}

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 ink = COLOR;
	float wear = 0.80 + 0.20 * grain(floor(FRAGCOORD.xy * 0.75));
	float breath = 0.88 + 0.12 * sin(TIME * 0.42);
	float awake = pow(max(0.0, sin(FRAGCOORD.y * 0.011 - TIME * 0.19)), 18.0);
	float relic = pow(0.5 + 0.5 * sin(FRAGCOORD.x * 0.019 + FRAGCOORD.y * 0.012), 3.0);
	vec3 bronze = ink.rgb * vec3(0.64, 0.48, 0.29);
	vec3 pale_gold = mix(ink.rgb, vec3(0.94, 0.79, 0.49), 0.65);
	vec3 engraving = mix(bronze, pale_gold, relic * 0.85 + awake * 0.15);
	COLOR = vec4(engraving, ink.a * opacity * wear * min(1.0, breath + awake * 0.12));
}
