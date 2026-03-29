extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

func _on_start_pressed() -> void:
	print(">>> [MainMenu] 开始游戏按钮被点击")
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")

func _on_settings_pressed() -> void:
	print(">>> [MainMenu] 设置按钮被点击")
