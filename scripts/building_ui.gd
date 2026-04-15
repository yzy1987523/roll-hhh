extends CanvasLayer

# Play按钮点击 - 进入合成界面
func _on_play_pressed() -> void:
	print(">>> [BuildingUI] 点击播放按钮，进入合成界面")
	SoundSystem.play_button_click()
	TransitionManager.change_scene_with_transition("res://scenes/game_board.tscn")

# 建造清单按钮点击 - 弹出建造清单
func _on_build_list_pressed() -> void:
	print(">>> [BuildingUI] 点击建造清单按钮")
	SoundSystem.play_button_click()
	# TODO: 弹出建造清单界面
