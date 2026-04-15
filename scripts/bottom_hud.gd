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
const PATH_TASK_PANEL := "ScrollContainer/ContentHBox/ZoneC"
const PATH_TASK_ITEM_ICON := "ScrollContainer/ContentHBox/ZoneC/TaskHBox/TaskItemIcon"
const PATH_TASK_COUNT := "ScrollContainer/ContentHBox/ZoneC/TaskHBox/TaskVBox/TaskCountLabel"
const PATH_TASK_PROGRESS := "ScrollContainer/ContentHBox/ZoneC/TaskHBox/TaskVBox/TaskProgressBar"
const PATH_TASK_STAR_ICON := "ScrollContainer/ContentHBox/ZoneC/TaskHBox/TaskStarHBox/TaskStarIcon"
const PATH_TASK_STAR_LABEL := "ScrollContainer/ContentHBox/ZoneC/TaskHBox/TaskStarHBox/TaskStarLabel"
const PATH_SUBMIT_BTN_CONTAINER := "ScrollContainer/ContentHBox/ZoneC/TaskHBox/SubmitBtnContainer"

# 局外道具堆最大显示数量
const MAX_VISIBLE_ITEMS: int = 5
# 道具图标引用
var _out_items_icons: Array[TextureRect] = []
# 提交按钮引用
var _submit_btn: TextureButton = null

func _ready() -> void:
	var build_list_btn: Button = get_node(PATH_BUILD_LIST_BTN)
	build_list_btn.pressed.connect(_on_build_list_pressed)
	TaskManager.stars_changed.connect(_on_stars_changed)
	TaskManager.task_progress_updated.connect(_on_task_progress_updated)
	TaskManager.task_completed.connect(_on_task_completed)
	GameManager.out_items_changed.connect(_on_out_items_changed)
	# 初始化提交按钮（必须在 _update_task_display 之前）
	_init_submit_button()
	_update_task_display()
	_update_build_list_btn()
	# 初始化局外道具显示（默认添加背包）
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


## 更新建造清单按钮显示
func _update_build_list_btn() -> void:
	var build_list_btn: Button = get_node(PATH_BUILD_LIST_BTN)
	var current_stars: int = TaskManager.get_stars()

	# 清除按钮原有子节点
	for child in build_list_btn.get_children():
		child.queue_free()

	# 创建水平容器
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 6)

	# 星星图标
	var star_icon := TextureRect.new()
	star_icon.texture = load("res://art/sprites/UI/icon/star.png")
	star_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	star_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star_icon.custom_minimum_size = Vector2(28, 28)

	# 星星数量
	var star_label := Label.new()
	star_label.text = str(current_stars)
	star_label.add_theme_font_size_override("font_size", 22)

	hbox.add_child(star_icon)
	hbox.add_child(star_label)
	build_list_btn.add_child(hbox)


## 设置局外道具堆显示
## @param item_ids Array of item_ids
func update_out_items(item_ids: Array[int]) -> void:
	# 清空现有显示
	for icon in _out_items_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	_out_items_icons.clear()

	var items_count_label: Label = get_node(PATH_ITEMS_COUNT)
	var items_stack: VBoxContainer = get_node(PATH_ITEMS_STACK)

	if item_ids.is_empty():
		items_count_label.text = "0"
		return

	# 显示数量
	items_count_label.text = str(item_ids.size())

	# 计算要显示的物品（最后获得的在上面，所以倒序取）
	var display_count := mini(item_ids.size(), MAX_VISIBLE_ITEMS)
	var start_idx := item_ids.size() - display_count

	# 创建图标（最后获得的在上面）
	for i in range(start_idx, item_ids.size()):
		_add_item_icon(item_ids[i], items_stack)


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


func _on_item_icon_input(event: InputEvent, item_id: int, icon: TextureRect) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			out_item_clicked.emit(item_id)


func _on_item_icon_pressed(item_id: int) -> void:
	out_item_clicked.emit(item_id)


func _on_task_progress_updated(_task_id: int, progress: float) -> void:
	_update_task_display()


func _on_task_completed(_task_id: int, _reward: Dictionary) -> void:
	_update_task_display()
	_refresh_out_items()  # 刷新局外道具显示（任务物品图标）


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


	# 显示星星奖励
	var task_star_label: Label = get_node(PATH_TASK_STAR_LABEL)
	task_star_label.text = "+%d" % star_reward

	# 显示任务物品图标（取第一个）
	var task_item_icon: TextureRect = get_node(PATH_TASK_ITEM_ICON)
	if not need_items.is_empty():
		var item_id: int = need_items[0]
		var sprite_path: String = ItemManager.get_sprite_path(item_id)
		if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
			task_item_icon.texture = load(sprite_path)
		else:
			task_item_icon.modulate = Color(0.5, 0.5, 0.5, 0.5)

	# 进度显示
	var require_count: int = need_items.size()
	var current_count: int = int(progress * require_count)
	var task_count_label: Label = get_node(PATH_TASK_COUNT)
	task_count_label.text = "%d/%d" % [current_count, require_count]

	var task_progress_bar: ProgressBar = get_node(PATH_TASK_PROGRESS)
	task_progress_bar.max_value = require_count
	task_progress_bar.value = current_count

	# 任务满足时显示提交按钮
	var submit_container: Control = find_child("SubmitBtnContainer", true, false)
	if submit_container == null:
		submit_container = find_child("SubmitBtnContainer", true, true)
	if submit_container != null:
		submit_container.visible = (progress >= 1.0)
	if _submit_btn != null:
		_submit_btn.visible = (progress >= 1.0)


## 初始化提交按钮
func _init_submit_button() -> void:
	# 查找 TaskHBox
	var task_hbox: HBoxContainer = find_child("TaskHBox", true, false)
	if task_hbox == null:
		task_hbox = find_child("TaskHBox", true, true)
	if task_hbox == null:
		return

	# 动态创建提交按钮
	var btn: TextureButton = TextureButton.new()
	btn.name = "SubmitButton"
	btn.custom_minimum_size = Vector2(120, 60)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

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
	label.add_theme_font_size_override("font_size", 24)

	btn.add_child(label)
	btn.pressed.connect(_on_submit_pressed)
	task_hbox.add_child(btn)
	_submit_btn = btn


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
