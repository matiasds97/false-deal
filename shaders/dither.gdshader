shader_type spatial;
render_mode unshaded;

uniform sampler2D main_tex : source_color;
uniform sampler2D dither_tex_1;
uniform sampler2D dither_tex_2;
uniform sampler2D dither_tex_3;

uniform float pixel_scale = 1.0;
uniform float dither_scale = 1.0;
uniform float dither_range_low = 0.0;
uniform float dither_range_high = 0.0;
uniform float strength = 1.0;

void fragment() {
	float r = 5.0 / 4.0;
	vec2 s = vec2(pixel_scale * r, pixel_scale / r);
	vec2 d_uv = (UV * s - 0.5) * dither_scale;

	vec3 col = texture(main_tex, round(UV * s) / s).rgb;
	float d1 = texture(dither_tex_1, d_uv).r;
	float d2 = texture(dither_tex_2, d_uv).r;
	float d3 = texture(dither_tex_3, d_uv).r;

	float g = 1.0 - clamp((col.r + col.g + col.b) / 3.0, 0.0, 1.0);

	if (g <= mix(dither_range_low, dither_range_high, 0.25)) {
		ALBEDO = col;
	} else {
		float dither = 0.0;
		if (g <= mix(dither_range_low, dither_range_high, 0.5)) {
			dither = d1;
		} else if (g <= mix(dither_range_low, dither_range_high, 0.75)) {
			dither = d2;
		} else {
			dither = d3;
		}

		if (dither == 0.0) {
			ALBEDO = col;
		} else {
			ALBEDO = clamp(col * col * dither * strength, 0.0, 1.0);
		}
	}
}