extends Control

@onready var start_button: Button = $StartButton
@onready var title: Sprite2D = $Title

# Web 环境必须用 preload 预加载字体，不能动态 load
@onready var chinese_font = preload("res://fonts/AlimamaFangYuanTiVF-Thin-2.ttf")

# 淡入 shader 材质
var title_material: ShaderMaterial

# 按钮目标位置
var button_target_y: float = 0.0
const BUTTON_OFFSET_Y: float = 300.0  # 从下方移入的距离


func _ready() -> void:
	print(">>> [MainMenu] _ready 开始")
	# 播放主菜单BGM
	print(">>> [MainMenu] Calling SoundSystem.play_menu_bgm()")
	SoundSystem.play_menu_bgm()
	# 全局设置中文字体（所有 Label 生效）
	ThemeDB.set_fallback_font(chinese_font)

	# 设置 title 的淡入 shader
	title_material = ShaderMaterial.new()
	title_material.shader = preload("res://shaders/fade_in_top.gdshader")
	title_material.set_shader_parameter("fade_amount", 1.0)
	title.material = title_material
	
	# 记录按钮目标位置，然后移到下方
	button_target_y = start_button.position.y
	start_button.position.y += BUTTON_OFFSET_Y
	start_button.modulate.a = 0.0  # 初始隐藏

	# 连接按钮信号
	print(">>> [MainMenu] start_button=", start_button, " is_null=", start_button == null)
	start_button.pressed.connect(_on_start_pressed)
	
	# 延迟一帧后开始动画（确保场景完全加载）
	call_deferred("_start_intro_animation")
	print(">>> [MainMenu] _ready 完成")


func _start_intro_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	
	# Title 从上往下淡入（fade_amount: 1 -> 0）
	tween.tween_property(title_material, "shader_parameter/fade_amount", 0.0, 0.8)
	
	# 按钮延迟 0.5 秒后开始移入
	tween.chain().tween_interval(0.5)
	tween.chain().set_parallel(true)
	tween.chain().tween_property(start_button, "position:y", button_target_y, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(start_button, "modulate:a", 1.0, 0.3)


func _on_start_pressed() -> void:
	print(">>> [MainMenu] 开始游戏按钮被点击")
	SoundSystem.play_button_click()
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")
