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
const PATH_ITEMS_COUNT := "ScrollContainer/ContentHBox/ZoneB/Control/ItemsCountLabel"
const PATH_ZONE_B := "ScrollContainer/ContentHBox/ZoneB"
const PATH_TASK_PANEL := "ScrollContainer/ContentHBox/ZoneC"

# 提交按钮引用
var _submit_btn: TextureButton = null
# 局外道具图标引用
@onready var _items_image: TextureRect = $ScrollContainer/ContentHBox/ZoneB/VBoxB/ItemsImage
# 当前显示的局外道具 ID
var _current_out_item_id: int = -1
# 任务栏节点引用（场景中的静态节点）
@onready var _task_item_icon: TextureRect = $ScrollContainer/ContentHBox/ZoneC/TaskHBox/TaskItemIcon
@onready var _task_star_label: Label = $ScrollContainer/ContentHBox/ZoneC/TaskHBox/TaskStarHBox/TaskStarLabel
@onready var _task_count_label: Label = $ScrollContainer/ContentHBox/ZoneC/TaskHBox/TaskVBox/TaskCountLabel
@onready var _task_progress_bar: ProgressBar = $ScrollContainer/ContentHBox/ZoneC/TaskHBox/TaskVBox/TaskProgressBar
@onready var _build_list_btn: Button = $ScrollContainer/ContentHBox/ZoneA/VBoxA/BuildListBtn
@onready var _build_list_star_icon: TextureRect = $ScrollContainer/ContentHBox/ZoneA/VBoxA/BuildListBtn/StarHBox/StarIcon
@onready var _build_list_star_label: Label = $ScrollContainer/ContentHBox/ZoneA/VBoxA/BuildListBtn/StarHBox/StarLabel

func _ready() -> void:
	_build_list_btn.pressed.connect(_on_build_list_pressed)
	TaskManager.stars_changed.connect(_on_stars_changed)
	TaskManager.task_progress_updated.connect(_on_task_progress_updated)
	TaskManager.task_completed.connect(_on_task_completed)
	GameManager.out_items_changed.connect(_on_out_items_changed)
	# 连接局外道具图标点击
	if _items_image != null:
		_items_image.gui_input.connect(_on_item_icon_input)
	# 初始化提交按钮
	_init_submit_button_overlay()
	_update_build_list_btn()
	# 初始化局外道具显示
	_refresh_out_items()
	# 监听ItemManager加载完成信号，确保物品配置加载后再刷新任务显示
	# 始终先连接信号（防止后续加载完成时错过）
	ItemManager.items_loaded.connect(_update_task_display)
	# 如果已加载，立即调用一次
	if ItemManager.is_loaded:
		call_deferred("_update_task_display")


func _on_out_items_changed() -> void:
	_refresh_out_items()


func _refresh_out_items() -> void:
	var item_ids: Array[int] = GameManager.get_out_items()
	update_out_items(item_ids)


func _on_build_list_pressed() -> void:
	SoundSystem.play_button_click()
	build_list_pressed.emit()


func _on_stars_changed(_new_stars: int) -> void:
	_update_build_list_btn()


## 更新建造清单按钮显示（星星图标+数量）
func _update_build_list_btn() -> void:
	_build_list_btn.visible = true
	var current_stars: int = TaskManager.get_stars()
	_build_list_star_label.text = str(current_stars)


## 设置局外道具堆显示（只显示最后一个道具+总数量）
## Feature 3 & 7: 默认隐藏，有道具时显示，只显示最后一个+数量
func update_out_items(item_ids: Array[int]) -> void:
	var zone_b: PanelContainer = get_node_or_null(PATH_ZONE_B)
	var items_count_label: Label = get_node_or_null(PATH_ITEMS_COUNT)

	if item_ids.is_empty():
		if zone_b:
			zone_b.visible = false
		_current_out_item_id = -1
		return

	# 有道具时显示ZoneB
	if zone_b:
		zone_b.visible = true
	if items_count_label:
		items_count_label.text = str(item_ids.size())

	# 只显示最后一个道具（最近获得的）
	var last_item_id: int = item_ids[item_ids.size() - 1]
	_set_item_image(last_item_id)


func _set_item_image(item_id: int) -> void:
	_current_out_item_id = item_id
	if _items_image == null:
		return

	# 获取物品sprite
	var sprite_path: String = ItemManager.get_sprite_path(item_id)
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		_items_image.texture = load(sprite_path)
		_items_image.modulate = Color.WHITE
	else:
		_items_image.modulate = Color(0.5, 0.5, 0.5, 0.5)


func _on_item_icon_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _current_out_item_id > 0:
				out_item_clicked.emit(_current_out_item_id)


func _on_task_progress_updated(_task_id: int, _progress: float) -> void:
	_update_task_display()


func _on_task_completed(_task_id: int, _reward: Dictionary) -> void:
	_update_task_display()
	_refresh_out_items()


# ================================= 重建任务栏（Feature 5）=================================
# 新布局：星星在上方，物品居中，进度在下方，完成按钮叠加在任务单上


## 初始化完成按钮（叠加在任务单上）
func _init_submit_button_overlay() -> void:
	var zone_c: PanelContainer = get_node_or_null(PATH_TASK_PANEL)
	if zone_c == null:
		return
	
	var submit_container: Control = zone_c.get_node_or_null("SubmitBtnContainer")
	if submit_container == null:
		return
	
	var btn: TextureButton = submit_container.get_node_or_null("SubmitButton")
	if btn == null:
		return
	
	# 连接信号
	if not btn.pressed.is_connected(_on_submit_pressed):
		btn.pressed.connect(_on_submit_pressed)
	btn.visible = false
	_submit_btn = btn


## 刷新任务栏显示（公开方法，供外部调用）
func refresh_task_display() -> void:
	_update_task_display()


## 更新任务栏显示
func _update_task_display() -> void:
	# 如果ItemManager未加载，延迟重试
	if not ItemManager.is_loaded:
		await get_tree().create_timer(0.1).timeout
		if not ItemManager.is_loaded:
			return

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

	# 使用保存的引用（而非find_child）
	if _task_star_label != null:
		_task_star_label.text = "+%d" % star_reward

	# 显示任务物品图标（取第一个）
	if _task_item_icon and not need_items.is_empty():
		var item_id: int = int(need_items[0])

		var sprite_path: String = ItemManager.get_sprite_path(item_id)

		if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
			var tex: Texture2D = load(sprite_path)
			_task_item_icon.texture = tex
			_task_item_icon.modulate = Color.WHITE
		else:
			_task_item_icon.modulate = Color(0.5, 0.5, 0.5, 0.5)

	# 进度显示
	var require_count: int = need_items.size()
	var current_count: int = int(progress * require_count)
	if _task_count_label != null:
		_task_count_label.text = "%d/%d" % [current_count, require_count]

	if _task_progress_bar != null:
		_task_progress_bar.max_value = require_count
		_task_progress_bar.value = current_count

	# 任务满足时显示提交按钮（叠加在任务单上）
	if _submit_btn != null:
		_submit_btn.visible = (progress >= 1.0)


## 提交按钮点击
func _on_submit_pressed() -> void:
	SoundSystem.play_button_click()
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
