shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
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
	vec2 d_uv = (SCREEN_UV * s - 0.5) * dither_scale;

	// Use SCREEN_UV for screen space effects
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;
	
	// Optional: Pixelate the screen texture lookup if desired, but usually dither is applied on top
	// To match the object shader exactly, we might want to pixelate the lookup:
	// vec3 col = texture(screen_texture, round(SCREEN_UV * s) / s).rgb; 
	// However, for pure screen post-process, standard UV sampling is often safer to avoid artifacts, 
	// let's stick to the original logic's intent of pixelating:
	col = texture(screen_texture, round(SCREEN_UV * s) / s).rgb;


	float d1 = texture(dither_tex_1, d_uv).r;
	float d2 = texture(dither_tex_2, d_uv).r;
	float d3 = texture(dither_tex_3, d_uv).r;

	float g = 1.0 - clamp((col.r + col.g + col.b) / 3.0, 0.0, 1.0);

	if (g <= mix(dither_range_low, dither_range_high, 0.25)) {
		COLOR.rgb = col;
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
			COLOR.rgb = col;
		} else {
			COLOR.rgb = clamp(col * col * dither * strength, 0.0, 1.0);
		}
	}
}
