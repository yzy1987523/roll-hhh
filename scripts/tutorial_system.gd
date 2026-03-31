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
var overlay: ColorRect = null
var hint_panel: PanelContainer = null
var hint_label: Label = null
var hint_arrow: Label = null
var target_control: Control = null
var highlight_rect: ColorRect = null

# ---- 颜色 ----
const HIGHLIGHT_COLOR := Color(1.0, 0.9, 0.0, 0.5)

# ---- 步骤配置 ----
const STEP_INFO := {
	TutorialStep.SPAWN_WARRIOR: {
		"hint": "tutorial.step1_action",
		"target_path": "MainLayout/BottomBar/SpawnRow/SpawnWarrior",
		"arrow_pos": "bottom",
	},
	TutorialStep.MERGE: {
		"hint": "tutorial.step2_merge",
		"target_path": "MainLayout/BoardCenter/GridContainer",
		"arrow_pos": "top",
	},
	TutorialStep.END_TURN: {
		"hint": "tutorial.step3_endturn",
		"target_path": "MainLayout/BottomBar/ActionRow/EndTurnButton",
		"arrow_pos": "top",
	},
}


func _ready() -> void:
	if should_show_tutorial():
		_start_tutorial()
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
	# 遮罩层 - 半透明黑色背景
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# 高亮框
	highlight_rect = ColorRect.new()
	highlight_rect.color = HIGHLIGHT_COLOR
	highlight_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(highlight_rect)

	# 提示面板
	_create_hint_panel()


func _create_hint_panel() -> void:
	hint_panel = PanelContainer.new()
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.custom_minimum_size = Vector2(280, 70)
	hint_panel.z_index = 100
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
	hint_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(hint_label)

	hint_arrow = Label.new()
	hint_arrow.text = "▼"
	hint_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_arrow.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	hint_arrow.add_theme_font_size_override("font_size", 24)
	vbox.add_child(hint_arrow)


func _connect_game_signals() -> void:
	# 连接生成按钮的信号来跟踪点击
	var spawn_warrior: Button = _get_node_by_path("MainLayout/BottomBar/SpawnRow/SpawnWarrior") as Button
	if spawn_warrior != null:
		spawn_warrior.pressed.connect(_on_spawn_warrior_clicked)

	# 连接合成信号
	GameManager.character_merged.connect(_on_character_merged)


func _on_character_merged(merged_level: int) -> void:
	if current_step == TutorialStep.MERGE:
		print(">>> [Tutorial] 检测到合成(等级%d)，进入结束回合步骤" % merged_level)
		_advance_step()


func _on_spawn_warrior_clicked() -> void:
	if current_step == TutorialStep.SPAWN_WARRIOR:
		spawn_click_count += 1
		# 更新显示的点击次数
		var hint_text: String = LocalizationSystem.get_text(STEP_INFO[current_step]["hint"])
		hint_label.text = "%s (%d/%d)" % [hint_text, spawn_click_count, spawn_click_target]
		print(">>> [Tutorial] 生成点击 %d/%d" % [spawn_click_count, spawn_click_target])


func _show_step(step: TutorialStep) -> void:
	if not STEP_INFO.has(step):
		return

	var info: Dictionary = STEP_INFO[step]
	var hint_text: String = LocalizationSystem.get_text(info["hint"])

	# 步骤1需要显示点击次数
	if step == TutorialStep.SPAWN_WARRIOR:
		hint_label.text = "%s (%d/%d)" % [hint_text, spawn_click_count, spawn_click_target]
	else:
		hint_label.text = hint_text

	var path: String = info["target_path"]
	target_control = _get_node_by_path(path)

	if target_control != null:
		_update_highlight(target_control, info["arrow_pos"])
	else:
		highlight_rect.visible = false

	print(">>> [Tutorial] 步骤 %d: %s" % [step, info["hint"]])


func _get_node_by_path(path: String) -> Control:
	var root: Node = get_tree().root.get_node("GameBoard")
	if root == null:
		root = get_parent()
	var parts: Array = path.split("/")
	var current: Node = root
	for part in parts:
		if part.is_empty():
			continue
		if not current.has_node(part):
			return null
		current = current.get_node(part)
	return current as Control


func _update_highlight(target: Control, arrow_pos: String) -> void:
	if target == null:
		return

	var global_rect: Rect2 = target.get_global_rect()
	var padding: int = 10

	highlight_rect.visible = true
	highlight_rect.global_position = global_rect.position - Vector2(padding, padding)
	highlight_rect.custom_minimum_size = global_rect.size + Vector2(padding * 2, padding * 2)

	var panel_pos: Vector2
	var arrow_text: String

	match arrow_pos:
		"bottom":
			panel_pos = Vector2(
				global_rect.position.x + global_rect.size.x / 2.0 - 140.0,
				global_rect.end.y + 20
			)
			arrow_text = "▲"
		"top":
			panel_pos = Vector2(
				global_rect.position.x + global_rect.size.x / 2.0 - 140.0,
				global_rect.position.y - 95
			)
			arrow_text = "▼"
		"right":
			panel_pos = Vector2(global_rect.end.x + 20, global_rect.position.y)
			arrow_text = "◀"
		"left":
			panel_pos = Vector2(global_rect.position.x - 300, global_rect.position.y)
			arrow_text = "▶"
		_:
			panel_pos = Vector2(global_rect.position.x, global_rect.end.y + 20)
			arrow_text = "▲"

	hint_panel.global_position = panel_pos
	hint_arrow.text = arrow_text


func _process(_delta: float) -> void:
	if not is_tutorial_active:
		return

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

	if overlay != null:
		overlay.queue_free()
		overlay = null
	if highlight_rect != null:
		highlight_rect.queue_free()
		highlight_rect = null
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
	GameManager.set_tutorial_completed(true)
	tutorial_finished.emit()

	if overlay != null:
		overlay.queue_free()
		overlay = null
	if highlight_rect != null:
		highlight_rect.queue_free()
		highlight_rect = null
	if hint_panel != null:
		hint_panel.queue_free()
		hint_panel = null

	print(">>> [Tutorial] 新手教程完成")
	queue_free()


func force_complete() -> void:
	_do_complete()
