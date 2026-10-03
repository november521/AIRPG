shader_type canvas_item;

float noise(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = UV;
	vec2 q = abs(p - vec2(0.5)) - vec2(0.49, 0.47);
	float corner = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
	if (corner > 0.0) { discard; }
	float fine = noise(floor(p * vec2(480.0, 260.0))) - 0.5;
	float blotch = noise(floor(p * vec2(31.0, 18.0))) - 0.5;
	float edge = min(min(p.x, 1.0 - p.x), min(p.y, 1.0 - p.y));
	vec3 paper = vec3(0.85, 0.76, 0.60) + fine * 0.042 + blotch * 0.035;
	paper -= vec3(0.08, 0.065, 0.045) * (1.0 - smoothstep(0.012, 0.14, edge));
	COLOR = vec4(paper, 1.0);
}
