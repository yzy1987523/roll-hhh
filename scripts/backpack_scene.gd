extends Control

## 背包界面
## 显示背包中的物品，点击可标记移出到棋盘

const CELL_SIZE := 140

# 节点引用
@onready var backdrop: ColorRect = $Backdrop
@onready var grid_container: GridContainer = $BackpackPanel/VBox/GridCenter/GridContainer
@onready var close_button: TextureButton = $BackpackPanel/VBox/TitleBarMargin/TitleBar/CloseButton
@onready var title_label: Label = $BackpackPanel/VBox/TitleBarMargin/TitleBar/Title

# 标记移出的物品索引
var _marked_indices: Array[int] = []

# 信号
signal close_requested
signal items_taken(marked_indices: Array[int])


func _ready():
	# 移除 PanelContainer 默认黑底
	var backpack_panel = $BackpackPanel
	var empty_style := StyleBoxEmpty.new()
	backpack_panel.add_theme_stylebox_override("panel", empty_style)

	# 连接信号
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
		_add_button_feedback(close_button)

	if backdrop:
		backdrop.gui_input.connect(_on_backdrop_input)

	# 连接任务物品更新信号
	TaskManager.task_items_updated.connect(_on_task_items_updated)

	# 设置层级
	backdrop.z_index = 100
	backdrop.z_as_relative = false

	# 设置标题
	if title_label:
		title_label.text = LocalizationSystem.get_text("game_board.backpack")


func refresh(backpack_items: Array) -> void:
	# 清空旧格子
	for child in grid_container.get_children():
		child.queue_free()

	# 排序：等级高的在前
	var sorted_items: Array = []
	for i in range(backpack_items.size()):
		var item: DataModels.BoardItemData = backpack_items[i]
		sorted_items.append({"original_index": i, "item": item, "level": item.level})

	sorted_items.sort_custom(func(a, b):
		if a["level"] != b["level"]:
			return a["level"] > b["level"]
		return a["original_index"] < b["original_index"]
	)

	# 获取任务物品信息
	var task_info: Dictionary = TaskManager.get_task_items_info()
	var backpack_task_indices: Array = []
	for item_data in task_info.get("backpack", []):
		backpack_task_indices.append(item_data["index"])

	# 创建格子 (4x4 = 16 slots)
	for i in range(16):
		var cell := _create_cell(i, sorted_items, backpack_items, backpack_task_indices)
		grid_container.add_child(cell)


func _create_cell(index: int, sorted_items: Array, backpack_items: Array, backpack_task_indices: Array) -> Control:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	# 移除默认黑底
	var empty_style := StyleBoxEmpty.new()
	container.add_theme_stylebox_override("panel", empty_style)

	# 背景层
	var bg := TextureRect.new()
	bg.texture = preload("res://art/sprites/UI/items/smallItem/cell_0.png")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(bg)

	# 选择框叠加层（初始隐藏）
	var overlay := TextureRect.new()
	overlay.name = "Overlay"
	overlay.texture = preload("res://art/sprites/UI/items/smallItem/cell_1.png")
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	container.add_child(overlay)

	# 判断是否有物品
	var is_occupied := index < sorted_items.size()
	if is_occupied:
		var sorted_data: Dictionary = sorted_items[index]
		var original_index: int = sorted_data["original_index"]
		var item: DataModels.BoardItemData = sorted_data["item"]
		var is_marked: bool = _marked_indices.has(original_index)

		# 物品居中容器
		var center := CenterContainer.new()
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.add_child(center)

		# 物品图片
		var sprite := TextureRect.new()
		sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.custom_minimum_size = Vector2(120, 120)

		var sprite_path: String = item.get_sprite_path()
		if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
			sprite.texture = load(sprite_path)

		center.add_child(sprite)

		# 标记状态：显示选择框
		if is_marked:
			overlay.visible = true
			sprite.modulate = Color(0.5, 0.5, 0.5, 1.0)  # 灰色表示已标记

		# 任务物品图标（左下角标记）
		if backpack_task_indices.has(original_index):
			var task_icon := TextureRect.new()
			task_icon.name = "TaskIcon"
			task_icon.texture = preload("res://art/sprites/UI/icon/p1_2.png")
			task_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			task_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			task_icon.custom_minimum_size = Vector2(36, 36)
			task_icon.anchor_left = 0.0
			task_icon.anchor_top = 1.0
			task_icon.anchor_right = 0.0
			task_icon.anchor_bottom = 1.0
			task_icon.offset_left = 2.0
			task_icon.offset_top = -38.0
			task_icon.offset_right = 38.0
			task_icon.offset_bottom = -2.0
			task_icon.pivot_offset = Vector2(18, 18)
			task_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			task_icon.z_index = 15
			container.add_child(task_icon)

		# 连接点击信号
		container.gui_input.connect(_on_cell_gui_input.bind(original_index, item))
	else:
		# 空格子：添加空占位符
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.add_child(spacer)

	return container


func _on_cell_gui_input(event: InputEvent, original_index: int, item: DataModels.BoardItemData) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			SoundSystem.play_button_click()
			if _marked_indices.has(original_index):
				# 已选中，取消标记
				_marked_indices.erase(original_index)
			else:
				# 未选中，标记为即将移出
				_marked_indices.append(original_index)
			refresh(GameManager.backpack_items)


## 任务物品更新时刷新显示
func _on_task_items_updated(_task_items_info: Dictionary) -> void:
	if visible:
		refresh(GameManager.backpack_items)


func _on_close_pressed() -> void:
	SoundSystem.play_button_click()
	if _marked_indices.size() > 0:
		items_taken.emit(_marked_indices)
	_marked_indices.clear()
	close_requested.emit()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_on_close_pressed()


## 为按钮添加hover和press视觉反馈
func _add_button_feedback(btn: BaseButton) -> void:
	btn.mouse_entered.connect(_on_button_mouse_entered.bind(btn))
	btn.mouse_exited.connect(_on_button_mouse_exited.bind(btn))
	btn.button_down.connect(_on_button_down.bind(btn))
	btn.button_up.connect(_on_button_up.bind(btn))


func _on_button_mouse_entered(btn: BaseButton) -> void:
	var alpha := btn.modulate.a
	btn.modulate = Color(0.9, 0.9, 0.9, alpha)


func _on_button_mouse_exited(btn: BaseButton) -> void:
	var alpha := btn.modulate.a
	btn.modulate = Color(1, 1, 1, alpha)


func _on_button_down(btn: BaseButton) -> void:
	var alpha := btn.modulate.a
	btn.modulate = Color(0.8, 0.8, 0.8, alpha)


func _on_button_up(btn: BaseButton) -> void:
	var alpha := btn.modulate.a
	btn.modulate = Color(0.9, 0.9, 0.9, alpha) if btn.get_global_rect().has_point(btn.get_viewport().get_mouse_position()) else Color(1, 1, 1, alpha)
