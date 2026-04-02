extends Control

## 新手教程系统 (battle_scene用)
## 步骤: 点击play按钮开始战斗

# ---- 信号 ----
signal tutorial_step_completed(step: int)
signal tutorial_finished()

# ---- 教程步骤 ----
enum TutorialStep {
	PLAY = 4,  # 延续game_board的步骤编号
}

# ---- 当前状态 ----
var current_step: TutorialStep = TutorialStep.PLAY
var is_tutorial_active: bool = false

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
	TutorialStep.PLAY: {
		"hint": "tutorial.step4_play",
		"target_path": "MainLayout/BottomBar/PlayButton",
		"arrow_pos": "bottom",
	},
}


func _ready() -> void:
	if should_show_tutorial():
		_start_tutorial()
	else:
		queue_free()


func should_show_tutorial() -> bool:
	# 只有当教程已完成game_board部分但未完成battle部分时显示
	# 即: 第一回合 且 tutorial_completed为false(因为game_board没设为true)
	if GameManager.has_tutorial_completed:
		return false
	if GameManager.current_round > 1:
		return false
	return true


func _start_tutorial() -> void:
	is_tutorial_active = true
	_setup_ui()
	_show_step(current_step)
	_connect_game_signals()
	print(">>> [BattleTutorial] 开始战斗场景教程")


func _setup_ui() -> void:
	# 遮罩层 - 半透明黑色背景
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_CENTER)
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
	# 连接play按钮的信号
	var play_button: Button = _get_node_by_path("MainLayout/BottomBar/PlayButton") as Button
	if play_button != null:
		play_button.pressed.connect(_on_play_clicked)


func _on_play_clicked() -> void:
	if current_step == TutorialStep.PLAY:
		_complete_tutorial()


func _get_node_by_path(path: String) -> Control:
	var root: Node = get_tree().root.get_node("BattleScene")
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


func _show_step(step: TutorialStep) -> void:
	if not STEP_INFO.has(step):
		return

	var info: Dictionary = STEP_INFO[step]
	hint_label.text = LocalizationSystem.get_text(info["hint"])

	var path: String = info["target_path"]
	target_control = _get_node_by_path(path)

	if target_control != null:
		_update_highlight(target_control, info["arrow_pos"])
	else:
		highlight_rect.visible = false

	print(">>> [BattleTutorial] 步骤: %s" % info["hint"])


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


func _complete_tutorial() -> void:
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

	print(">>> [BattleTutorial] 新手教程完成")
	queue_free()


func force_complete() -> void:
	_complete_tutorial()
