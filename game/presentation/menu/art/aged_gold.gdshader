shader_type canvas_item;
render_mode unshaded;

// Sample only the original mark's occupied area, preserving every glyph and flourish.
uniform vec4 source_region = vec4(0.070175, 0.298245, 0.869219, 0.363636);
uniform vec4 dark_gold : source_color = vec4(0.30, 0.20, 0.095, 1.0);
uniform vec4 body_gold : source_color = vec4(0.79, 0.655, 0.36, 1.0);
uniform vec4 light_gold : source_color = vec4(0.94, 0.86, 0.63, 1.0);
varying vec4 canvas_tint;

void vertex() {
	canvas_tint = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float grain(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 sample_uv = source_region.xy + UV * source_region.zw;
	float mask = texture(TEXTURE, sample_uv).r;
	float alpha = smoothstep(0.07, 0.86, mask);
	float coarse = grain(UV * vec2(42.0, 17.5));
	float fine = grain(UV * vec2(720.0, 300.0));
	float middle = exp(-pow((UV.y - 0.40) * 2.8, 2.0));
	float sheen = clamp(0.24 + middle * 0.43 + (coarse - 0.5) * 0.20, 0.0, 1.0);
	vec3 metal = mix(body_gold.rgb, light_gold.rgb, sheen);
	// Sparse oxidation preserves broad intact gold leaf instead of muddying every pixel.
	float corrosion = (1.0 - smoothstep(0.18, 0.34, coarse)) * 0.62;
	float pits = (1.0 - smoothstep(0.12, 0.24, fine)) * 0.38;
	metal = mix(metal, dark_gold.rgb, clamp(corrosion + pits, 0.0, 0.72));
	metal *= 0.96 + fine * 0.07;
	float scoring = smoothstep(0.86, 0.97, grain(UV * vec2(48.0, 320.0)));
	metal = mix(metal, dark_gold.rgb, scoring * 0.36);
	// Opposing edge samples suggest a shallow inscription, without an outer glow.
	float upper_edge = texture(TEXTURE, sample_uv - TEXTURE_PIXEL_SIZE * vec2(0.8, 1.0)).r;
	float lower_edge = texture(TEXTURE, sample_uv + TEXTURE_PIXEL_SIZE * vec2(0.8, 1.0)).r;
	metal += light_gold.rgb * max(0.0, mask - upper_edge) * 0.10;
	metal *= 1.0 - max(0.0, mask - lower_edge) * 0.17;
	float sweep_position = mod(TIME * 0.045, 1.8) - 0.4;
	float sweep = exp(-pow((UV.x + UV.y * 0.10 - sweep_position) * 18.0, 2.0));
	metal += light_gold.rgb * sweep * 0.035;
	COLOR = vec4(metal, alpha) * canvas_tint;
}
