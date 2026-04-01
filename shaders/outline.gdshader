shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 color = tex;

	if (tex.a > 0.0) {
		// Check neighboring pixels for outline
		vec2 pixel_size = vec2(outline_width) / vec2(textureSize(TEXTURE, 0));

		float alpha = tex.a;
		alpha = max(alpha, texture(TEXTURE, UV + vec2(pixel_size.x, 0)).a);
		alpha = max(alpha, texture(TEXTURE, UV + vec2(-pixel_size.x, 0)).a);
		alpha = max(alpha, texture(TEXTURE, UV + vec2(0, pixel_size.y)).a);
		alpha = max(alpha, texture(TEXTURE, UV + vec2(0, -pixel_size.y)).a);

		// If this pixel is transparent but has opaque neighbors, it's an outline pixel
		if (tex.a < 0.1 && alpha > 0.1) {
			color = vec4(outline_color.rgb, alpha);
		}
	}

	COLOR = color;
}