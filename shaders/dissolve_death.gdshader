shader_type canvas_item;

// 从上至下渐隐效果
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fade_color : source_color = vec4(0.3, 0.3, 0.3, 1.0);

void fragment() {
	vec4 color = COLOR;
	
	// 从上到下的溶解效果
	// UV.y = 0 是顶部, UV.y = 1 是底部
	// dissolve_amount = 0 时完全显示, = 1 时完全消失
	float dissolve_line = dissolve_amount;
	
	if (UV.y < dissolve_line) {
		// 已溶解区域（顶部先溶解）
		color.a = 0.0;
	} else if (UV.y < dissolve_line + 0.1) {
		// 溶解边缘，渐变效果
		float edge_alpha = (UV.y - dissolve_line) / 0.1;
		color = mix(fade_color, color, edge_alpha);
		color.a *= edge_alpha;
	}
	
	COLOR = color;
}
