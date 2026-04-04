shader_type canvas_item;

// 从上往下淡入效果
// fade_amount: 1 = 完全隐藏, 0 = 完全显示
uniform float fade_amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 color = COLOR;
	
	// 从上到下的淡入效果
	// UV.y = 0 是顶部, UV.y = 1 是底部
	// fade_amount = 1 时完全隐藏, = 0 时完全显示
	float reveal_line = fade_amount;
	
	if (UV.y > 1.0 - reveal_line) {
		// 尚未显示区域（底部先隐藏）
		color.a = 0.0;
	} else if (UV.y > 1.0 - reveal_line - 0.15) {
		// 淡入边缘，渐变效果
		float edge_alpha = (1.0 - reveal_line - UV.y) / 0.15;
		color.a *= edge_alpha;
	}
	
	COLOR = color;
}
