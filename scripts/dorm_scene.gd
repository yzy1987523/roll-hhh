extends Control

## 宿舍界面
## 显示宿舍中的角色，点击可弹出详情

const CELL_SIZE := 140

# 节点引用
@onready var backdrop: ColorRect = $Backdrop
@onready var grid_container: GridContainer = $DormPanel/VBox/GridCenter/GridContainer
@onready var close_button: TextureButton = $DormPanel/VBox/TitleBarMargin/TitleBar/CloseButton
@onready var title_label: Label = $DormPanel/VBox/TitleBarMargin/TitleBar/Title

# 排序后的宿舍索引
var _dorm_sort_order: Array = []

# 信号
signal close_requested


func _ready() -> void:
	# 移除 PanelContainer 默认黑底
	var dorm_panel = $DormPanel
	var empty_style := StyleBoxEmpty.new()
	dorm_panel.add_theme_stylebox_override("panel", empty_style)
	
	# 连接信号
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
		_add_button_feedback(close_button)
	
	if backdrop:
		backdrop.gui_input.connect(_on_backdrop_input)
	
	# 设置层级
	backdrop.z_index = 100
	backdrop.z_as_relative = false

	# 设置标题
	if title_label:
		title_label.text = LocalizationSystem.get_text("game_board.dorm")


func refresh(dormitory: Array) -> void:
	# 清空旧格子
	for child in grid_container.get_children():
		child.queue_free()
	
	# 排序：等级高的在前
	_dorm_sort_order.clear()
	var dorm_data: Array = []
	for i in range(dormitory.size()):
		var ch: DataModels.CharacterData = dormitory[i]
		dorm_data.append({"index": i, "level": ch.level, "job": ch.job})
	
	dorm_data.sort_custom(func(a, b): 
		if a["level"] != b["level"]:
			return a["level"] > b["level"]
		return a["job"] < b["job"]
	)
	
	for data in dorm_data:
		_dorm_sort_order.append(data["index"])
	
	# 创建格子
	for i in range(16):  # 4x4 格子
		var cell := _create_cell(i, dormitory)
		grid_container.add_child(cell)


func _create_cell(index: int, dormitory: Array) -> Control:
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
	
	# 判断是否有角色
	var is_occupied := index < _dorm_sort_order.size()
	if is_occupied:
		var dorm_idx: int = _dorm_sort_order[index]
		var ch: DataModels.CharacterData = dormitory[dorm_idx]
		var is_marked: bool = GameManager.board_data.is_marked_for_removal(dorm_idx)
		
		# 角色居中容器
		var center := CenterContainer.new()
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.add_child(center)
		
		# 角色图片
		var sprite := TextureRect.new()
		sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.custom_minimum_size = Vector2(120, 120)

		var sprite_folder: String = ch.get_sprite_folder()
		var sprite_name: String = ch.get_sprite_path(1, 1)  # 待机动画第1帧
		var sprite_path: String = "res://art/sprites/chars/" + sprite_folder + "/" + sprite_name + ".png"
		if ResourceLoader.exists(sprite_path):
			sprite.texture = load(sprite_path)
		
		center.add_child(sprite)
		
		# 标记状态：显示选择框
		if is_marked:
			overlay.visible = true
			sprite.modulate = Color(0.5, 0.5, 0.5, 1.0)  # 灰色表示已标记
		
		# 连接点击信号
		container.gui_input.connect(_on_cell_gui_input.bind(dorm_idx))
	else:
		# 空格子：添加空占位符
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.add_child(spacer)
	
	return container


func _on_cell_gui_input(event: InputEvent, dorm_index: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			SoundSystem.play_button_click()
			var bd: BoardData = GameManager.board_data
			if bd.is_marked_for_removal(dorm_index):
				# 已选中，取消标记
				bd.unmark_for_removal(dorm_index)
				TipManager.show_tip(LocalizationSystem.get_text("game_board.dorm_unmarked"))
			else:
				# 未选中，标记为即将移除
				bd.mark_for_removal(dorm_index)
				TipManager.show_tip(LocalizationSystem.get_text("game_board.dorm_marked_for_removal"))
			refresh(GameManager.board_data.dormitory)


func _on_close_pressed() -> void:
	SoundSystem.play_button_click()
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