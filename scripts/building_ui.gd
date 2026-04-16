extends CanvasLayer

const BuildListScene = preload("res://scenes/build_list_scene.tscn")
var _build_list_instance: Control = null

# Play按钮点击 - 进入合成界面
func _on_play_pressed() -> void:
	print(">>> [BuildingUI] 点击播放按钮，进入合成界面")
	SoundSystem.play_button_click()
	TransitionManager.change_scene_with_transition("res://scenes/game_board.tscn")

# 建造清单按钮点击 - 弹出建造清单
func _on_build_list_pressed() -> void:
	print(">>> [BuildingUI] 点击建造清单按钮")
	SoundSystem.play_button_click()
	# 如果已显示则不再显示
	if _build_list_instance != null and is_instance_valid(_build_list_instance):
		return
	# 创建并显示建造清单
	_build_list_instance = BuildListScene.instantiate()
	_build_list_instance.build_completed.connect(_on_build_completed)
	add_child(_build_list_instance)


func _on_build_completed(build_id: int) -> void:
	print(">>> [BuildingUI] 建造完成: %d" % build_id)
	# 获取经验值
	var build_config = BuildConfigLoader.new().get_build(build_id)
	if build_config.is_empty():
		return
	var exp_reward: int = build_config.get("expReward", 0)
	if exp_reward <= 0:
		return
	# 获取经验条位置（终点）
	var exp_bar_path := "TopLeftUI/LevelContainer/ExpProgressBar"
	var exp_bar: ProgressBar = get_node(exp_bar_path)
	if exp_bar == null:
		return
	var end_pos: Vector2 = exp_bar.global_position + Vector2(exp_bar.size.x / 2, exp_bar.size.y / 2)
	# 起始位置：屏幕中央偏下（模拟从建造结果处升起）
	var start_pos: Vector2 = Vector2(540, 400)
	# 播放经验粒子特效
	_play_exp_particle_effect(start_pos, end_pos, exp_reward)


func _play_exp_particle_effect(start_pos: Vector2, end_pos: Vector2, exp_amount: int) -> void:
	# 经验图标
	var EXP_ICON := preload("res://art/sprites/UI/icon/jingyan.png")
	# 创建粒子容器
	var particle_container := Node2D.new()
	particle_container.global_position = start_pos
	add_child(particle_container)
	# 粒子数量根据经验值调整
	var particle_count := mini(maxi(exp_amount / 50, 1), 10)
	# 为每个粒子创建动画
	for i in range(particle_count):
		var particle := Sprite2D.new()
		particle.texture = EXP_ICON
		particle.scale = Vector2(0.5, 0.5)
		particle.global_position = start_pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		particle.modulate = Color(0.3, 0.8, 1.0, 0.9)
		particle_container.add_child(particle)
		# 创建飞行动画
		var tween := create_tween()
		var random_offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
		var mid_pos: Vector2 = (start_pos + end_pos) / 2.0 + random_offset + Vector2(0, -50)
		tween.tween_property(particle, "global_position", mid_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "global_position", end_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(particle, "scale", Vector2(0.8, 0.8), 0.15)
		tween.tween_property(particle, "scale", Vector2(0.5, 0.5), 0.25)
		tween.tween_property(particle, "modulate:a", 0.0, 0.1).set_delay(0.35)
		tween.finished.connect(func():
			if is_instance_valid(particle):
				particle.queue_free()
		, CONNECT_ONE_SHOT)
	# 延迟清理容器
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(particle_container):
		particle_container.queue_free()
