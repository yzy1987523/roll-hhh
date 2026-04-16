extends Control

## 底部横向滑动HUD
## 包含: A-建造清单, B-局外道具堆, C-任务栏

signal build_list_pressed()
signal out_items_pressed()
signal out_item_clicked(item_id: int)
signal submit_requested()  # 请求提交任务，由game_board处理动画

# 节点路径 (从父节点BottomHUDContainer算起)
const PATH_BUILD_LIST_BTN := "ScrollContainer/ContentHBox/ZoneA/VBoxA/BuildListBtn"
const PATH_ITEMS_STACK := "ScrollContainer/ContentHBox/ZoneB/VBoxB/ItemsStack"
const PATH_ITEMS_COUNT := "ScrollContainer/ContentHBox/ZoneB/ItemsCountLabel"
const PATH_ZONE_B := "ScrollContainer/ContentHBox/ZoneB"
const PATH_TASK_PANEL := "ScrollContainer/ContentHBox/ZoneC"

# 提交按钮引用
var _submit_btn: TextureButton = null
# 局外道具图标引用
var _out_items_icons: Array[TextureRect] = []

func _ready() -> void:
	var build_list_btn: Button = get_node(PATH_BUILD_LIST_BTN)
	build_list_btn.pressed.connect(_on_build_list_pressed)
	TaskManager.stars_changed.connect(_on_stars_changed)
	TaskManager.task_progress_updated.connect(_on_task_progress_updated)
	TaskManager.task_completed.connect(_on_task_completed)
	GameManager.out_items_changed.connect(_on_out_items_changed)
	# 初始化任务栏（重建ZoneC内容）
	_rebuild_task_panel()
	_update_task_display()
	_update_build_list_btn()
	# 初始化局外道具显示
	_refresh_out_items()


func _on_out_items_changed() -> void:
	_refresh_out_items()


func _refresh_out_items() -> void:
	var item_ids: Array[int] = GameManager.get_out_items()
	update_out_items(item_ids)


func _on_build_list_pressed() -> void:
	build_list_pressed.emit()


func _on_stars_changed(_new_stars: int) -> void:
	_update_build_list_btn()


## 更新建造清单按钮显示（星星图标+数量）
func _update_build_list_btn() -> void:
	var build_list_btn: Button = get_node(PATH_BUILD_LIST_BTN)
	build_list_btn.visible = true
	var current_stars: int = TaskManager.get_stars()

	# 清除按钮原有子节点
	for child in build_list_btn.get_children():
		child.queue_free()

	# 创建水平容器
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 星星图标
	var star_icon := TextureRect.new()
	star_icon.texture = load("res://art/sprites/UI/icon/star.png")
	star_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	star_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star_icon.custom_minimum_size = Vector2(28, 28)
	star_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 星星数量
	var star_label := Label.new()
	star_label.text = str(current_stars)
	star_label.add_theme_font_size_override("font_size", 22)
	star_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	hbox.add_child(star_icon)
	hbox.add_child(star_label)
	build_list_btn.add_child(hbox)


## 设置局外道具堆显示（只显示最后一个道具+总数量）
## Feature 3 & 7: 默认隐藏，有道具时显示，只显示最后一个+数量
func update_out_items(item_ids: Array[int]) -> void:
	# 清空现有显示
	for icon in _out_items_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	_out_items_icons.clear()

	var zone_b: PanelContainer = get_node(PATH_ZONE_B)
	var items_count_label: Label = get_node(PATH_ITEMS_COUNT)
	var items_stack: VBoxContainer = get_node(PATH_ITEMS_STACK)

	if item_ids.is_empty():
		zone_b.visible = false
		return

	# 有道具时显示ZoneB
	zone_b.visible = true
	items_count_label.text = str(item_ids.size())

	# 只显示最后一个道具（最近获得的）
	var last_item_id: int = item_ids[item_ids.size() - 1]
	_add_item_icon(last_item_id, items_stack)


func _add_item_icon(item_id: int, parent: VBoxContainer) -> void:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(60, 60)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# 获取物品sprite
	var sprite_path: String = ItemManager.get_sprite_path(item_id)
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		icon.texture = load(sprite_path)
	else:
		icon.modulate = Color(0.5, 0.5, 0.5, 0.5)

	# 添加点击处理
	icon.gui_input.connect(_on_item_icon_input.bind(item_id, icon))

	parent.add_child(icon)
	_out_items_icons.append(icon)


func _on_item_icon_input(event: InputEvent, item_id: int, _icon: TextureRect) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			out_item_clicked.emit(item_id)


func _on_task_progress_updated(_task_id: int, _progress: float) -> void:
	_update_task_display()


func _on_task_completed(_task_id: int, _reward: Dictionary) -> void:
	_update_task_display()
	_refresh_out_items()


# ================================= 重建任务栏（Feature 5）=================================
# 新布局：星星在上方，物品居中，进度在下方，完成按钮叠加在任务单上
func _rebuild_task_panel() -> void:
	var zone_c: PanelContainer = get_node(PATH_TASK_PANEL)

	# 删除除了PanelBg之外的所有子节点
	for child in zone_c.get_children():
		if child.name.begins_with("PanelBg"):
			continue
		child.queue_free()

	# 创建主容器（垂直布局）
	var main_vbox := VBoxContainer.new()
	main_vbox.name = "TaskMainVBox"
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 4)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone_c.add_child(main_vbox)

	# 第1行：星星奖励（顶部）
	var star_row := HBoxContainer.new()
	star_row.name = "StarRow"
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override("separation", 4)
	star_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(star_row)

	var star_icon := TextureRect.new()
	star_icon.name = "TaskStarIcon"
	star_icon.texture = load("res://art/sprites/UI/icon/star.png")
	star_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	star_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star_icon.custom_minimum_size = Vector2(24, 24)
	star_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_row.add_child(star_icon)

	var star_label := Label.new()
	star_label.name = "TaskStarLabel"
	star_label.text = "+0"
	star_label.add_theme_font_size_override("font_size", 18)
	star_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.1, 1))
	star_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_row.add_child(star_label)

	# 第2行：物品图标（居中）
	var item_center := CenterContainer.new()
	item_center.name = "ItemCenter"
	item_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(item_center)

	var item_icon := TextureRect.new()
	item_icon.name = "TaskItemIcon"
	item_icon.custom_minimum_size = Vector2(60, 60)
	item_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_center.add_child(item_icon)

	# 第3行：进度（物品下方）
	var progress_vbox := VBoxContainer.new()
	progress_vbox.name = "ProgressVBox"
	progress_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	progress_vbox.add_theme_constant_override("separation", 2)
	progress_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(progress_vbox)

	var count_label := Label.new()
	count_label.name = "TaskCountLabel"
	count_label.text = "0/1"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 16)
	count_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_vbox.add_child(count_label)

	var progress_bar := ProgressBar.new()
	progress_bar.name = "TaskProgressBar"
	progress_bar.custom_minimum_size = Vector2(0, 10)
	progress_bar.max_value = 1.0
	progress_bar.step = 1.0
	progress_bar.show_percentage = false
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_vbox.add_child(progress_bar)

	# 叠加层：完成按钮（覆盖在任务单中心偏下）
	_init_submit_button_overlay(zone_c)


## 初始化完成按钮（叠加在任务单上）
func _init_submit_button_overlay(zone_c: PanelContainer) -> void:
	var btn := TextureButton.new()
	btn.name = "SubmitButton"
	btn.custom_minimum_size = Vector2(120, 50)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

	# 使用锚点定位到ZoneC中心偏下
	btn.anchor_left = 0.5
	btn.anchor_top = 0.6
	btn.anchor_right = 0.5
	btn.anchor_bottom = 0.6
	btn.offset_left = -60
	btn.offset_top = -10
	btn.offset_right = 60
	btn.offset_bottom = 40
	btn.z_index = 10

	# 加载纹理
	var tex_path := "res://art/sprites/UI/icon/btn.png"
	if ResourceLoader.exists(tex_path):
		btn.texture_normal = load(tex_path)

	# 添加文字标签
	var label := Label.new()
	label.name = "Label"
	label.text = "完成"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	label.add_theme_font_size_override("font_size", 22)

	btn.add_child(label)
	btn.pressed.connect(_on_submit_pressed)
	btn.visible = false
	zone_c.add_child(btn)
	_submit_btn = btn


## 刷新任务栏显示（公开方法，供外部调用）
func refresh_task_display() -> void:
	_update_task_display()


## 更新任务栏显示
func _update_task_display() -> void:
	var current_task: Dictionary = TaskManager.get_current_task()
	var task_panel: PanelContainer = get_node(PATH_TASK_PANEL)

	if current_task.is_empty():
		task_panel.visible = false
		return

	task_panel.visible = true

	# 任务需求物品
	var need_items: Array = current_task.get("needItems", [])
	var reward: Dictionary = current_task.get("reward", {})
	var star_reward: int = reward.get("star", 0)
	var progress: float = TaskManager.get_current_task_progress()

	# 使用 find_child 查找动态创建的节点
	var task_star_label: Label = find_child("TaskStarLabel", true, false)
	if task_star_label:
		task_star_label.text = "+%d" % star_reward

	# 显示任务物品图标（取第一个）
	var task_item_icon: TextureRect = find_child("TaskItemIcon", true, false)
	if task_item_icon and not need_items.is_empty():
		var item_id: int = need_items[0]
		var sprite_path: String = ItemManager.get_sprite_path(item_id)
		if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
			task_item_icon.texture = load(sprite_path)
			task_item_icon.modulate = Color.WHITE
		else:
			task_item_icon.modulate = Color(0.5, 0.5, 0.5, 0.5)

	# 进度显示
	var require_count: int = need_items.size()
	var current_count: int = int(progress * require_count)
	var task_count_label: Label = find_child("TaskCountLabel", true, false)
	if task_count_label:
		task_count_label.text = "%d/%d" % [current_count, require_count]

	var task_progress_bar: ProgressBar = find_child("TaskProgressBar", true, false)
	if task_progress_bar:
		task_progress_bar.max_value = require_count
		task_progress_bar.value = current_count

	# 任务满足时显示提交按钮（叠加在任务单上）
	if _submit_btn != null:
		_submit_btn.visible = (progress >= 1.0)


## 提交按钮点击
func _on_submit_pressed() -> void:
	if _submit_btn == null:
		return
	# 播放点击动效：放大1.1倍再缩回1倍，总用时0.3秒
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_submit_btn, "scale", Vector2(1.1, 1.1), 0.15)
	tween.tween_property(_submit_btn, "scale", Vector2(1.0, 1.0), 0.15).set_delay(0.15)
	tween.finished.connect(_on_submit_animation_complete)


func _on_submit_animation_complete() -> void:
	# 发出信号让game_board处理物品飞行动画
	submit_requested.emit()


## 获取建造清单按钮全局位置（用于星星飞行终点）
func get_build_list_btn_global_center() -> Vector2:
	var btn: Button = get_node(PATH_BUILD_LIST_BTN)
	return btn.global_position + Vector2(btn.size.x / 2, btn.size.y / 2)


## 获取任务面板全局中心（用于动画）
func get_task_panel_global_center() -> Vector2:
	var task_panel: PanelContainer = get_node(PATH_TASK_PANEL)
	return task_panel.global_position + Vector2(task_panel.size.x / 2, task_panel.size.y / 2)


## 隐藏完成按钮（提交动画开始时调用）
func hide_submit_button() -> void:
	if _submit_btn != null:
		_submit_btn.visible = false
