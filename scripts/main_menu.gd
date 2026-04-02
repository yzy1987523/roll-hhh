extends Control

@onready var start_button: Button = $StartButton

# Web 环境必须用 preload 预加载字体，不能动态 load
@onready var chinese_font = preload("res://fonts/AlimamaFangYuanTiVF-Thin-2.ttf")


func _ready() -> void:
	print(">>> [MainMenu] _ready 开始")
	# 全局设置中文字体（所有 Label 生效）
	ThemeDB.set_fallback_font(chinese_font)

	# 连接按钮信号
	print(">>> [MainMenu] start_button=", start_button, " is_null=", start_button == null)
	start_button.pressed.connect(_on_start_pressed)
	print(">>> [MainMenu] _ready 完成")


func _on_start_pressed() -> void:
	print(">>> [MainMenu] 开始游戏按钮被点击")
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")
