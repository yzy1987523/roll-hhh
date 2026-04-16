extends Node

# 过渡面板预制体
var transition_scene: PackedScene = preload("res://scenes/transition_panel.tscn")
var transition_instance: CanvasLayer = null
var is_transitioning: bool = false

# 进入过渡动画（从上往下滑入）
func transition_in() -> void:
	if is_transitioning:
		return
	is_transitioning = true

	# 实例化预制体（如果不存在）
	if transition_instance == null:
		transition_instance = transition_scene.instantiate()
		get_tree().root.add_child(transition_instance)

	# 获取Backdrop用于动画
	var backdrop: Control = transition_instance.find_child("Backdrop", true, false)
	if backdrop == null:
		return

	backdrop.visible = true
	# 使用 scale 动画，从 scale=0 展开到 scale=1
	# pivot_offset.y = 0 让缩放以顶部为中心点，实现从上往下展开效果
	backdrop.pivot_offset.y = 0
	backdrop.scale.y = 0.0

	# 动画：从上往下滑入（scale 从 0 到 1）
	var tween := transition_instance.create_tween()
	tween.set_parallel(true)
	tween.tween_property(backdrop, "scale:y", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

# 退出过渡动画（从下往上滑出）
func transition_out() -> void:
	if transition_instance == null:
		return

	var backdrop: Control = transition_instance.find_child("Backdrop", true, false)
	if backdrop == null:
		return

	# 动画：从上往下收拢（scale 从 1 到 0）
	var tween := transition_instance.create_tween()
	tween.set_parallel(true)
	tween.tween_property(backdrop, "scale:y", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	backdrop.visible = false
	backdrop.scale.y = 1.0  # 重置
	is_transitioning = false

# 带过渡的场景切换
func change_scene_with_transition(path: String) -> void:
	if is_transitioning:
		return

	# 进入过渡（滑入）
	await transition_in()

	# 切换场景
	get_tree().change_scene_to_file(path)

	# 等待足够时间让新场景完全加载（WASM需要更多时间）
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# 退出过渡（滑出）
	transition_out()
