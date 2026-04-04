shader_type canvas_item;

uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	
	// 混合原色和纯白色
	vec3 white = vec3(1.0, 1.0, 1.0);
	vec3 final_color = mix(tex.rgb, white, flash_intensity);
	
	COLOR = vec4(final_color, tex.a);
}
