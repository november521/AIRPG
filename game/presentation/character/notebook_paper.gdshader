shader_type canvas_item;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rounded_box(vec2 p, vec2 center, vec2 half_size, float radius) {
	vec2 q = abs(p - center) - half_size + vec2(radius);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 p = UV;
	if (rounded_box(p, vec2(0.5), vec2(0.5), 0.045) > 0.0) { discard; }
	float fine = grain(floor(p * vec2(820.0, 570.0))) - 0.5;
	float fiber = grain(floor(p * vec2(138.0, 93.0))) - 0.5;
	float stain = grain(floor(p * vec2(26.0, 18.0))) - 0.5;
	vec3 leather = vec3(0.13, 0.075, 0.045) + fine * 0.045 + stain * 0.027;
	float cover_edge = abs(rounded_box(p, vec2(0.5), vec2(0.48, 0.474), 0.036));
	leather += vec3(0.18, 0.11, 0.058) * (1.0 - smoothstep(0.0, 0.004, cover_edge)) * 0.48;
	float left_page = rounded_box(p, vec2(0.264, 0.500), vec2(0.222, 0.455), 0.030);
	float right_page = rounded_box(p, vec2(0.736, 0.500), vec2(0.222, 0.455), 0.030);
	float page = min(left_page, right_page);
	vec3 color = leather;
	float stack = min(
		rounded_box(p, vec2(0.264, 0.508), vec2(0.229, 0.457), 0.032),
		rounded_box(p, vec2(0.736, 0.508), vec2(0.229, 0.457), 0.032)
	);
	if (stack < 0.0) {
		float leaf = sin(p.y * 850.0) * 0.018;
		color = vec3(0.59, 0.47, 0.32) + fine * 0.035 + leaf;
	}
	if (page < 0.0) {
		vec3 paper = vec3(0.91, 0.84, 0.70) + fine * 0.031 + fiber * 0.021 + stain * 0.015;
		float aged_edge = 1.0 - smoothstep(-0.085, -0.005, page);
		paper -= vec3(0.10, 0.085, 0.06) * aged_edge;
		float line = pow(max(cos((p.y - 0.14) * 147.0), 0.0), 54.0);
		paper -= vec3(0.042, 0.044, 0.043) * line * step(0.15, p.y) * step(p.y, 0.92);
		float margin = min(abs(p.x - 0.070), abs(p.x - 0.537));
		paper -= vec3(0.095, 0.045, 0.032) * (1.0 - smoothstep(0.0, 0.0016, margin)) * 0.43;
		color = paper;
	}
	float seam = abs(p.x - 0.5);
	if (seam < 0.026) { color *= 1.0 - (0.30 * (1.0 - seam / 0.026)); }
	if (seam < 0.004) { color = mix(color, leather * 1.32, 0.72); }
	float stitch = step(0.011, p.x) * (1.0 - step(0.014, p.x));
	stitch += step(0.986, p.x) * (1.0 - step(0.989, p.x));
	stitch *= step(0.42, fract(p.y * 140.0));
	color = mix(color, vec3(0.56, 0.40, 0.24), stitch * 0.45);
	COLOR = vec4(color, 1.0);
}
