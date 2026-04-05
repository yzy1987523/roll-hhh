extends Control

## 新手教程系统 (game_board用)
## 步骤: 生成战士(5次) → 合成 → 结束回合 → (battle_scene: play按钮)

# ---- 信号 ----
signal tutorial_step_completed(step: int)
signal tutorial_finished()

# ---- 教程步骤 ----
enum TutorialStep {
	NONE = 0,
	SPAWN_WARRIOR = 1,    # 点击5次生成战士
	MERGE = 2,             # 拖拽合成
	END_TURN = 3,          # 点击结束回合
}

# ---- 当前状态 ----
var current_step: TutorialStep = TutorialStep.NONE
var is_tutorial_active: bool = false
var spawn_click_count: int = 0
var spawn_click_target: int = 5  # 需要点击5次

# ---- UI 节点 ----
var overlay_container: Control = null  # 遮罩容器
var overlay_top: ColorRect = null      # 上方遮罩
var overlay_bottom: ColorRect = null   # 下方遮罩
var overlay_left: ColorRect = null     # 左侧遮罩
var overlay_right: ColorRect = null    # 右侧遮罩
var hint_panel: PanelContainer = null
var hint_label: Label = null
var hint_arrow: Label = null
var target_control: Control = null

# ---- 步骤配置 ----
const STEP_INFO := {
	TutorialStep.SPAWN_WARRIOR: {
		"hint": "tutorial.step1_action",
		"target_path": "MainLayout/BottomBar/SpawnRow/SpawnButtons/SpawnWarrior",
		"arrow_pos": "bottom",
	},
	TutorialStep.MERGE: {
		"hint": "tutorial.step2_merge",
		"target_path": "MainLayout/BoardCenter/GridContainer",
		"arrow_pos": "top",
	},
	TutorialStep.END_TURN: {
		"hint": "tutorial.step3_endturn",
		"target_path": "MainLayout/DetailActionBar/EndTurnButton",
		"arrow_pos": "top",
	},
}



func _ready() -> void:
	# 设置教程系统节点填满整个屏幕
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0.0
	offset_bottom = 0.0
	# 关键修复：父节点本身不拦截鼠标事件，让输入穿透到子节点
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if should_show_tutorial():
		# 延迟一帧启动教程，确保场景布局完成
		call_deferred("_start_tutorial")
	else:
		queue_free()


func should_show_tutorial() -> bool:
	if GameManager.has_tutorial_completed:
		return false
	if GameManager.current_round > 1:
		return false
	return true


func _start_tutorial() -> void:
	is_tutorial_active = true
	current_step = TutorialStep.SPAWN_WARRIOR
	spawn_click_count = 0
	_setup_ui()
	_show_step(current_step)
	_connect_game_signals()
	print(">>> [Tutorial] 新手教程开始")


func _setup_ui() -> void:
	# 1. 创建镂空遮罩容器（填满整个屏幕）
	overlay_container = Control.new()
	overlay_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 容器本身不拦截
	# 关键修复：设置 clip_contents = false，确保容器不会裁剪子节点
	overlay_container.clip_contents = false
	add_child(overlay_container)
	
	# 2. 创建4个遮罩矩形（围绕目标区域，形成镂空效果）
	var mask_color := Color(0.0, 0.0, 0.0, 0.6)
	
	# 上方遮罩（从屏幕顶部到镂空区域顶部）
	overlay_top = ColorRect.new()
	overlay_top.color = mask_color
	overlay_top.mouse_filter = Control.MOUSE_FILTER_STOP
	# 移除锚点预设，使用默认锚点（避免事件检测问题）
	overlay_top.position = Vector2(0, 0)
	overlay_top.size = Vector2(0, 0)  # 初始大小为0，避免覆盖屏幕
	overlay_container.add_child(overlay_top)
	
	# 下方遮罩（从镂空区域底部到屏幕底部）
	overlay_bottom = ColorRect.new()
	overlay_bottom.color = mask_color
	overlay_bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_bottom.position = Vector2(0, 0)
	overlay_bottom.size = Vector2(0, 0)  # 初始大小为0
	overlay_container.add_child(overlay_bottom)
	
	# 左侧遮罩（镂空区域左侧）
	overlay_left = ColorRect.new()
	overlay_left.color = mask_color
	overlay_left.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_left.position = Vector2(0, 0)
	overlay_left.size = Vector2(0, 0)  # 初始大小为0
	overlay_container.add_child(overlay_left)
	
	# 右侧遮罩（镂空区域右侧）
	overlay_right = ColorRect.new()
	overlay_right.color = mask_color
	overlay_right.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_right.position = Vector2(0, 0)
	overlay_right.size = Vector2(0, 0)  # 初始大小为0
	overlay_container.add_child(overlay_right)
	
	# 3. 创建提示面板
	_create_hint_panel()


func _create_hint_panel() -> void:
	hint_panel = PanelContainer.new()
	# 移除锚点预设，使用默认锚点（避免位置设置问题）
	hint_panel.custom_minimum_size = Vector2(400, 120)  # 放大面板尺寸以适应更大字体
	hint_panel.size = Vector2(400, 120)
	hint_panel.z_index = 100
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.position = Vector2(0, 0)  # 初始位置
	add_child(hint_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.25, 0.95)
	panel_style.border_color = Color(1.0, 0.8, 0.0, 0.9)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	hint_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	hint_panel.add_child(vbox)

	hint_label = Label.new()
	hint_label.text = ""
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 28)  # 放大到2倍
	vbox.add_child(hint_label)

	# 使用三角形替代箭头文字（避免字体问题）
	hint_arrow = PanelContainer.new()
	hint_arrow.custom_minimum_size = Vector2(40, 30)
	hint_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arrow_style := StyleBoxFlat.new()
	arrow_style.bg_color = Color(1.0, 0.8, 0.0)
	arrow_style.corner_radius_top_left = 8
	arrow_style.corner_radius_top_right = 8
	arrow_style.corner_radius_bottom_left = 0
	arrow_style.corner_radius_bottom_right = 0
	hint_arrow.add_theme_stylebox_override("panel", arrow_style)
	vbox.add_child(hint_arrow)


func _connect_game_signals() -> void:
	# 连接合成信号
	GameManager.character_merged.connect(_on_character_merged)


func _on_character_merged(merged_level: int) -> void:
	if current_step == TutorialStep.MERGE:
		print(">>> [Tutorial] 检测到合成(等级%d)，进入结束回合步骤" % merged_level)
		_advance_step()


func _show_step(step: TutorialStep) -> void:
	if not STEP_INFO.has(step):
		return

	# 断开之前目标按钮的信号
	_disconnect_target_signal()

	var info: Dictionary = STEP_INFO[step]
	var hint_text: String = LocalizationSystem.get_text(info["hint"])

	# 步骤1需要显示点击次数
	if step == TutorialStep.SPAWN_WARRIOR:
		hint_label.text = "%s (%d/%d)" % [hint_text, spawn_click_count, spawn_click_target]
	else:
		hint_label.text = hint_text

	var path: String = info["target_path"]
	target_control = _get_node_by_path(path)

	# 连接目标按钮的信号（用于统计点击次数）
	if target_control != null:
		_connect_target_signal()
		_update_highlight(target_control, info["arrow_pos"])
	else:
		# 隐藏所有遮罩
		overlay_top.visible = false
		overlay_bottom.visible = false
		overlay_left.visible = false
		overlay_right.visible = false

	print(">>> [Tutorial] 步骤 %d: %s" % [step, info["hint"]])


func _get_node_by_path(path: String) -> Control:
	var root: Node = get_tree().root.get_node("GameBoard")
	if root == null:
		root = get_parent()
		print(">>> [Tutorial] 使用parent作为root: %s" % root.name)
	else:
		print(">>> [Tutorial] 找到GameBoard作为root")
	
	var parts: Array = path.split("/")
	var current: Node = root
	for part in parts:
		if part.is_empty():
			continue
		if not current.has_node(part):
			print(">>> [Tutorial] 未找到节点 '%s'，路径: %s，当前节点: %s" % [part, path, current.name])
			return null
		current = current.get_node(part)
	
	print(">>> [Tutorial] 找到节点: %s" % current.name)
	return current as Control


func _update_highlight(target: Control, arrow_pos: String) -> void:
	if target == null:
		return

	var global_rect: Rect2 = target.get_global_rect()
	var padding: int = 10
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	
	# 检查位置是否有效（非零）
	if global_rect.position.x < 1 and global_rect.position.y < 1:
		# 位置还是(0,0)，延迟重试（最多3次）
		if not has_meta("_highlight_retry_count"):
			set_meta("_highlight_retry_count", 0)
		var retry_count: int = get_meta("_highlight_retry_count")
		if retry_count < 3:
			set_meta("_highlight_retry_count", retry_count + 1)
			print(">>> [Tutorial] 目标位置无效(0,0)，延迟重试 (%d/3)" % (retry_count + 1))
			await get_tree().create_timer(0.1).timeout
			_update_highlight(target, arrow_pos)
			return
		else:
			# 超过重试次数，隐藏所有遮罩
			print(">>> [Tutorial] 目标位置仍然无效，放弃定位")
			overlay_top.visible = false
			overlay_bottom.visible = false
			overlay_left.visible = false
			overlay_right.visible = false
			return
	
	# 位置有效，清除重试计数
	if has_meta("_highlight_retry_count"):
		remove_meta("_highlight_retry_count")
	
	# 镂空区域（带padding）
	var hole_pos: Vector2 = global_rect.position - Vector2(padding, padding)
	var hole_end: Vector2 = global_rect.end + Vector2(padding, padding)
	var hole_size: Vector2 = hole_end - hole_pos
	
	# 调试输出（仅第一次）
	if not overlay_top.visible:
		print(">>> [Tutorial] 镂空遮罩位置:")
		print("    目标按钮位置: %s, 大小: %s" % [global_rect.position, global_rect.size])
		print("    镂空区域: pos=%s, end=%s, size=%s" % [hole_pos, hole_end, hole_size])
		print("    屏幕大小: %s" % screen_size)
	
	# 更新4个遮罩的位置和大小，并确保它们可见
	# 上方遮罩：从屏幕顶部到镂空区域顶部
	overlay_top.visible = true
	overlay_top.position = Vector2(0, 0)
	overlay_top.size = Vector2(screen_size.x, max(0, hole_pos.y))
	
	# 下方遮罩：从镂空区域底部到屏幕底部
	overlay_bottom.visible = true
	overlay_bottom.position = Vector2(0, hole_end.y)
	overlay_bottom.size = Vector2(screen_size.x, max(0, screen_size.y - hole_end.y))
	
	# 左侧遮罩：镂空区域左侧（垂直方向与镂空区域对齐）
	overlay_left.visible = true
	overlay_left.position = Vector2(0, hole_pos.y)
	overlay_left.size = Vector2(max(0, hole_pos.x), hole_size.y)
	
	# 右侧遮罩：镂空区域右侧（垂直方向与镂空区域对齐）
	overlay_right.visible = true
	overlay_right.position = Vector2(hole_end.x, hole_pos.y)
	overlay_right.size = Vector2(max(0, screen_size.x - hole_end.x), hole_size.y)

	# 计算提示面板位置
	var panel_pos: Vector2
	var arrow_rotation: float

	match arrow_pos:
		"bottom":
			panel_pos = Vector2(
				global_rect.position.x + global_rect.size.x / 2.0 - 200.0,  # 调整为面板宽度的一半(400/2)
				global_rect.end.y + 20
			)
			arrow_rotation = 0  # 指向上
		"top":
			panel_pos = Vector2(
				global_rect.position.x + global_rect.size.x / 2.0 - 200.0,  # 调整为面板宽度的一半(400/2)
				global_rect.position.y - 150  # 调整为面板高度+间距
			)
			arrow_rotation = 180  # 指向下
		"right":
			panel_pos = Vector2(global_rect.end.x + 20, global_rect.position.y)
			arrow_rotation = -90  # 指向左
		"left":
			panel_pos = Vector2(global_rect.position.x - 420, global_rect.position.y)  # 调整为面板宽度+间距
			arrow_rotation = 90  # 指向右
		_:
			panel_pos = Vector2(global_rect.position.x, global_rect.end.y + 20)
			arrow_rotation = 0

	hint_panel.position = panel_pos
	hint_arrow.rotation_degrees = arrow_rotation


func _connect_target_signal() -> void:
	# 为步骤1连接生成按钮的pressed信号
	if current_step == TutorialStep.SPAWN_WARRIOR:
		if target_control is BaseButton or target_control is TextureButton:
			if not target_control.pressed.is_connected(_on_target_pressed):
				target_control.pressed.connect(_on_target_pressed)
				print(">>> [Tutorial] 已连接目标按钮的pressed信号: %s" % target_control.name)
			else:
				print(">>> [Tutorial] 目标按钮信号已连接")
		else:
			print(">>> [Tutorial] 目标不是按钮类型: %s" % target_control.get_class())


func _disconnect_target_signal() -> void:
	# 断开之前目标按钮的信号
	if target_control != null and is_instance_valid(target_control):
		if target_control is BaseButton or target_control is TextureButton:
			if target_control.pressed.is_connected(_on_target_pressed):
				target_control.pressed.disconnect(_on_target_pressed)


func _on_target_pressed() -> void:
	# 统计步骤1的点击次数
	if current_step == TutorialStep.SPAWN_WARRIOR:
		spawn_click_count += 1
		# 更新显示的点击次数
		var hint_text: String = LocalizationSystem.get_text(STEP_INFO[current_step]["hint"])
		hint_label.text = "%s (%d/%d)" % [hint_text, spawn_click_count, spawn_click_target]


func _process(_delta: float) -> void:
	if not is_tutorial_active:
		return

	# 持续更新高亮框和提示面板位置（因为目标节点位置可能会变化）
	if target_control != null:
		var info: Dictionary = STEP_INFO[current_step]
		_update_highlight(target_control, info["arrow_pos"])

	match current_step:
		TutorialStep.SPAWN_WARRIOR:
			_check_spawn_condition()
		TutorialStep.END_TURN:
			_check_endturn_condition()


func _check_spawn_condition() -> void:
	# 点击5次后进入下一步
	if spawn_click_count >= spawn_click_target:
		print(">>> [Tutorial] 完成生成步骤，进入合成步骤")
		_advance_step()


func _check_endturn_condition() -> void:
	# 结束回合条件: 检测游戏阶段变为战斗
	if GameManager.phase == GameManager.PHASE_BATTLE:
		print(">>> [Tutorial] 进入战斗，game_board教程结束，battle_scene继续")
		# 清理UI但不设置tutorial_completed，让battle_scene继续步骤4
		_cleanup_for_scene_switch()


func _cleanup_for_scene_switch() -> void:
	# 清理教程UI，临时挂起教程等待battle_scene继续
	is_tutorial_active = false
	_disconnect_target_signal()

	if overlay_container != null:
		overlay_container.queue_free()
		overlay_container = null
	if hint_panel != null:
		hint_panel.queue_free()
		hint_panel = null

	print(">>> [Tutorial] game_board教程UI已清理，等待battle_scene继续")
	queue_free()


func _advance_step() -> void:
	tutorial_step_completed.emit(current_step)
	current_step += 1

	if current_step > TutorialStep.END_TURN:
		# 教程在进入battle时暂时挂起
		pass
	else:
		_show_step(current_step)


func complete_tutorial() -> void:
	_do_complete()


func _do_complete() -> void:
	is_tutorial_active = false
	_disconnect_target_signal()
	GameManager.set_tutorial_completed(true)
	tutorial_finished.emit()

	if overlay_container != null:
		overlay_container.queue_free()
		overlay_container = null
	if hint_panel != null:
		hint_panel.queue_free()
		hint_panel = null

	print(">>> [Tutorial] 新手教程完成")
	queue_free()


func force_complete() -> void:
	_do_complete()
