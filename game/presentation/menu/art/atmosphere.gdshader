shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec2 canvas_size = vec2(1920.0, 1080.0);
uniform float motion_speed : hint_range(0.0, 2.0) = 1.0;
uniform float brilliance : hint_range(0.0, 1.5) = 1.0;

float hash(float p) { return fract(sin(p * 127.1) * 43758.5453); }

void fragment() {
	vec3 dust = vec3(0.0);
	float t = TIME * motion_speed;
	// 18 distant specks, 12 middle motes, 6 soft foreground embers.
	// Fixed visual seeds never consume the gameplay random source.
	for (int i = 0; i < 36; i++) {
		float seed = float(i) + 1.0;
		float tier = mod(float(i), 6.0);
		float depth = tier < 0.5 ? 1.0 : (tier < 2.5 ? 0.5 : 0.0);
		float speed = mix(0.002, 0.009, depth) + hash(seed) * mix(0.002, 0.003, depth);
		float phase = fract(hash(seed + 8.0) + t * speed);
		vec2 mote = vec2(0.06 + hash(seed) * 0.88, 1.05 - phase * 1.10);
		mote.x += sin(t * mix(0.07, 0.16, depth) + seed) * mix(0.009, 0.028, depth);
		mote.x += sin(t * 0.31 + seed * 2.3) * 0.003 * depth;
		vec2 distance_px = (UV - mote) * canvas_size;
		float life = smoothstep(0.0, 0.12, phase) * (1.0 - smoothstep(0.86, 1.0, phase));
		float radius = mix(0.65, 3.2, depth) + hash(seed + 29.0) * mix(0.45, 1.2, depth);
		float ember = exp(-dot(distance_px, distance_px) / (radius * radius));
		float halo = exp(-dot(distance_px, distance_px) / (radius * radius * 18.0)) * 0.06;
		float twinkle = 0.76 + 0.24 * sin(t * (0.24 + hash(seed + 4.0) * 0.30) + seed * 2.1);
		float center_quiet = 0.35 + 0.65 * smoothstep(0.10, 0.34, abs(mote.x - 0.5));
		vec3 gold = mix(vec3(1.0, 0.58, 0.20), vec3(1.0, 0.83, 0.52), hash(seed + 17.0) * 0.55);
		float softness = mix(0.34, 0.20, depth);
		dust += gold * (ember + halo) * life * center_quiet * twinkle * softness;
	}
	COLOR = vec4(dust * brilliance, 1.0) * COLOR;
}
