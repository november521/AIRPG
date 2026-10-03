shader_type canvas_item;
render_mode unshaded;

// Procedural stand-in for the reference page backdrop: a dim interior with one
// warm lamp pool on the left, a softer cool pool high-right, film grain and a
// vignette. No external art asset is required, so the page carries no new
// binary dependency.

uniform vec3 base_color : source_color = vec3(0.048, 0.058, 0.064);
uniform vec3 warm_color : source_color = vec3(0.44, 0.27, 0.12);
uniform vec3 cool_color : source_color = vec3(0.11, 0.14, 0.17);
uniform float grain : hint_range(0.0, 0.2) = 0.05;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		total += amplitude * value_noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return total;
}

void fragment() {
	vec2 uv = UV;
	vec2 aspect = vec2(1.78, 1.0);
	float lamp = pow(1.0 - smoothstep(0.0, 0.78, length((uv - vec2(0.05, 0.46)) * aspect)), 3.0);
	float fill_light = pow(1.0 - smoothstep(0.0, 0.95, length((uv - vec2(0.90, 0.06)) * aspect)), 2.5);
	vec3 color = base_color;
	color += warm_color * lamp * 0.30;
	color += cool_color * fill_light * 0.38;
	// Large soft blotches so the backdrop never reads as a flat gradient.
	color += warm_color * (fbm(uv * 3.2) - 0.5) * 0.10;
	color += cool_color * (fbm(uv * 1.7 + 11.3) - 0.5) * 0.20;
	// Ceiling darker than the floor.
	color *= mix(0.76, 1.12, smoothstep(0.0, 1.0, uv.y));
	color += (hash21(uv * vec2(1920.0, 1080.0)) - 0.5) * grain;
	float edge = smoothstep(1.25, 0.35, length((uv - 0.5) * aspect));
	color *= mix(1.0 - vignette_strength, 1.0, edge);
	COLOR = vec4(max(color, vec3(0.012)), 1.0);
}
