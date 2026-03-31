extends Control

## 备战阶段主界面
## 任务 2.1-2.5: UI + 生成 + 拖拽 + 合成 + 献祭

# ---- 节点引用 ----
@onready var gold_label: Label = $MainLayout/TopBar/GoldLabel
@onready var energy_label: Label = $MainLayout/TopBar/EnergyLabel
@onready var round_label: Label = $MainLayout/TopBar/RoundLabel
@onready var settings_button: Button = $MainLayout/TopBar/SettingsButton
@onready var relic_button: Button = $MainLayout/RelicBar/RelicHeader/RelicButton
@onready var relic_panel: PanelContainer = $MainLayout/RelicBar/RelicPanel
@onready var relic_list: HFlowContainer = $MainLayout/RelicBar/RelicPanel/ScrollContainer/RelicList
@onready var grid_container: GridContainer = $MainLayout/BoardCenter/GridContainer
@onready var spawn_warrior: Button = $MainLayout/BottomBar/SpawnRow/SpawnWarrior
@onready var spawn_mage: Button = $MainLayout/BottomBar/SpawnRow/SpawnMage
@onready var spawn_priest: Button = $MainLayout/BottomBar/SpawnRow/SpawnPriest
@onready var end_turn_button: Button = $MainLayout/BottomBar/ActionRow/EndTurnButton
@onready var back_button: Button = $MainLayout/BottomBar/ActionRow/BackButton
@onready var item_bar: HBoxContainer = $MainLayout/MiddleBar/ItemBar
@onready var dorm_button: Button = $MainLayout/MiddleBar/DormButton
@onready var shop_button: Button = $MainLayout/MiddleBar/ShopButton

# ---- 设置面板节点 ----
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var settings_vbox: VBoxContainer = $SettingsPanel/SettingsVBox
@onready var settings_title: Label = $SettingsPanel/SettingsVBox/SettingsTitle
@onready var language_button: Button = $SettingsPanel/SettingsVBox/LanguageRow/LanguageButton
@onready var language_label: Label = $SettingsPanel/SettingsVBox/LanguageRow/LanguageLabel
@onready var volume_slider: HSlider = $SettingsPanel/SettingsVBox/VolumeRow/VolumeSlider
@onready var volume_label: Label = $SettingsPanel/SettingsVBox/VolumeRow/VolumeLabel
@onready var reset_tutorial_button: Button = $SettingsPanel/SettingsVBox/ResetTutorialButton
@onready var close_settings_button: Button = $SettingsPanel/SettingsVBox/CloseButton
@onready var reset_confirm_label: Label = $SettingsPanel/ResetConfirmLabel

# ---- 常量 ----
const GRID_SIZE := 6
const CELL_SIZE := 70

# ---- 棋盘格子颜色 ----
const COLOR_EMPTY_EVEN := Color("#3A5A8A")
const COLOR_EMPTY_ODD := Color("#2A4A7A")
const COLOR_WARRIOR := Color("#D94040")
const COLOR_MAGE := Color("#6040D9")
const COLOR_PRIEST := Color("#40B040")
const COLOR_SELECTED := Color("#FFD700")  # 选中高亮边框色
const COLOR_MERGE_HINT := Color("#FF8C00")  # 可合成提示色

# ---- 棋盘格子引用 ----
var cell_rects: Array = []     # ColorRect 背景
var cell_labels: Array = []    # Label 角色信息
var cell_panels: Array = []    # PanelContainer 格子容器

# ---- 选中状态 (任务 2.3 拖拽) ----
var selected_index: int = -1   # 当前选中的棋盘格索引, -1=无选中

# ---- 拖拽状态 ----
var is_dragging: bool = false   # 是否正在拖拽
var drag_index: int = -1        # 拖拽源的格子索引
var drag_preview: Control = null # 拖拽预览节点
var hover_index: int = -1       # 当前悬停的格子索引
var is_hovering_dorm: bool = false  # 是否悬停在宿舍按钮上

# ---- 宿舍面板 ----
var dorm_panel: PanelContainer = null
var dorm_visible: bool = false

# ---- 遗物栏面板 ----
var relic_panel_visible: bool = false

# ---- 道具栏格子 ----
const ITEM_SLOT_COUNT := 3
var item_slot_nodes: Array = []
var item_slot_labels: Array = []
var item_slot_overlays: Array = []

# ---- 教程系统 ----
var tutorial_instance: Control = null


func _ready() -> void:
	_connect_signals()
	_setup_board_ui()
	_setup_dorm_panel()
	_setup_item_slots()
	_update_resource_labels()
	_refresh_relic_panel()
	_refresh_item_slots()
	_start_tutorial()
	print(">>> [GameBoard] 备战阶段界面已加载")


func _start_tutorial() -> void:
	# 只有在第一回合且未完成教程时显示教程
	if GameManager.current_round == 1 and not GameManager.tutorial_completed:
		tutorial_instance = preload("res://scripts/tutorial_system.gd").new()
		add_child(tutorial_instance)


# ---- 信号连接 ----

func _connect_signals() -> void:
	spawn_warrior.pressed.connect(_on_spawn_pressed.bind(DataModels.Job.WARRIOR))
	spawn_mage.pressed.connect(_on_spawn_pressed.bind(DataModels.Job.MAGE))
	spawn_priest.pressed.connect(_on_spawn_pressed.bind(DataModels.Job.PRIEST))
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	back_button.pressed.connect(_on_back_pressed)
	dorm_button.pressed.connect(_on_dorm_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	relic_button.pressed.connect(_on_relic_toggle)
	settings_button.pressed.connect(_on_settings_pressed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.energy_changed.connect(_on_energy_changed)
	GameManager.round_changed.connect(_on_round_changed)
	GameManager.relics_changed.connect(_on_relics_changed)
	# 设置面板信号
	language_button.pressed.connect(_on_language_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	reset_tutorial_button.pressed.connect(_on_reset_tutorial_pressed)
	close_settings_button.pressed.connect(_on_close_settings)


# ---- 棋盘 UI 构建 ----

func _setup_board_ui() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	cell_rects.clear()
	cell_labels.clear()
	cell_panels.clear()

	grid_container.columns = GRID_SIZE

	for i in range(GRID_SIZE * GRID_SIZE):
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)

		# 背景色
		var bg := ColorRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		@warning_ignore("integer_division")
		var row := i / GRID_SIZE
		var col := i % GRID_SIZE
		var is_even := (row + col) % 2 == 0
		bg.color = COLOR_EMPTY_EVEN if is_even else COLOR_EMPTY_ODD
		cell.add_child(bg)

		# 角色信息标签
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 11)
		cell.add_child(lbl)

		# 点击事件
		cell.gui_input.connect(_on_cell_gui_input.bind(i))

		grid_container.add_child(cell)
		cell_rects.append(bg)
		cell_labels.append(lbl)
		cell_panels.append(cell)

	_refresh_board_display()
	print(">>> [GameBoard] %dx%d 棋盘格已生成" % [GRID_SIZE, GRID_SIZE])


# ---- 宿舍面板 ----

func _setup_dorm_panel() -> void:
	dorm_panel = PanelContainer.new()
	dorm_panel.visible = false
	dorm_panel.set_anchors_preset(Control.PRESET_CENTER)
	dorm_panel.custom_minimum_size = Vector2(300, 200)
	dorm_panel.offset_left = -150
	dorm_panel.offset_top = -100
	dorm_panel.offset_right = 150
	dorm_panel.offset_bottom = 100
	add_child(dorm_panel)


func _refresh_dorm_panel() -> void:
	# 清空旧内容
	for child in dorm_panel.get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	dorm_panel.add_child(vbox)

	var title := Label.new()
	title.text = LocalizationSystem.get_text("game_board.dorm_title", {"count": GameManager.board_data.dormitory.size()})
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 120)
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for i in range(GameManager.board_data.dormitory.size()):
		var ch: DataModels.CharacterData = GameManager.board_data.dormitory[i]
		var row := HBoxContainer.new()
		list.add_child(row)

		var info := Label.new()
		info.text = "%s Lv.%d  HP:%d/%d" % [ch.get_job_name(), ch.level, ch.hp, ch.max_hp]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var take_btn := Button.new()
		take_btn.text = LocalizationSystem.get_text("game_board.dorm_take")
		take_btn.pressed.connect(_on_dorm_take_pressed.bind(i))
		row.add_child(take_btn)

	if GameManager.board_data.dormitory.size() == 0:
		var empty := Label.new()
		empty.text = LocalizationSystem.get_text("game_board.dorm_empty")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)

	var close_btn := Button.new()
	close_btn.text = LocalizationSystem.get_text("game_board.back")
	close_btn.pressed.connect(_on_dorm_close)
	vbox.add_child(close_btn)


# ---- 棋盘格拖拽处理 (任务 2.3 拖拽/选中) ----

func _on_cell_gui_input(event: InputEvent, cell_index: int) -> void:
	var bd: BoardData = GameManager.board_data
	var ch: DataModels.CharacterData = bd.get_character_at_index(cell_index)

	# 鼠标按下: 开始拖拽或选中
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# 按下左键: 有角色则开始拖拽
				if ch != null:
					_start_drag(cell_index, mb.global_position)
				else:
					# 空格子且有选中: 移动到此处
					if selected_index >= 0:
						_handle_cell_action(cell_index)
			else:
				# 释放左键: 结束拖拽
				if is_dragging:
					_end_drag(cell_index)
				else:
					# 无拖拽: 取消选中
					selected_index = -1
					_refresh_board_display()

	# 鼠标移动: 更新拖拽预览位置
	elif event is InputEventMouseMotion:
		if is_dragging:
			_update_drag_preview(event.global_position)

	# 右键: 献祭 (任务 2.5)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if ch != null:
				_sacrifice_character(cell_index)


func _handle_cell_action(target_index: int) -> void:
	var bd: BoardData = GameManager.board_data
	var source_ch: DataModels.CharacterData = bd.get_character_at_index(selected_index)
	var target_ch: DataModels.CharacterData = bd.get_character_at_index(target_index)

	if source_ch == null:
		selected_index = -1
		_refresh_board_display()
		return

	if target_ch == null:
		# 目标为空: 移动
		var src_pos: Vector2i = BoardData.index_to_pos(selected_index)
		var tgt_pos: Vector2i = BoardData.index_to_pos(target_index)
		bd.swap_positions(src_pos, tgt_pos)
		print(">>> [GameBoard] 移动 %s 从格 %d 到格 %d" % [source_ch.get_job_name(), selected_index, target_index])
	elif target_ch.job == source_ch.job and target_ch.level == source_ch.level:
		# 同职业同等级: 合成 (任务 2.4)
		_merge_at(selected_index, target_index)
	else:
		# 不同角色: 交换位置
		var src_pos: Vector2i = BoardData.index_to_pos(selected_index)
		var tgt_pos: Vector2i = BoardData.index_to_pos(target_index)
		bd.swap_positions(src_pos, tgt_pos)
		print(">>> [GameBoard] 交换 格%d ↔ 格%d" % [selected_index, target_index])

	selected_index = -1
	_refresh_board_display()


# ---- 角色合成 (任务 2.4) ----

func _merge_at(src_index: int, tgt_index: int) -> void:
	var bd: BoardData = GameManager.board_data
	var src_ch: DataModels.CharacterData = bd.get_character_at_index(src_index)
	var tgt_ch: DataModels.CharacterData = bd.get_character_at_index(tgt_index)

	var merged: DataModels.CharacterData = CharacterFactory.merge_characters(src_ch, tgt_ch)
	if merged == null:
		print(">>> [GameBoard] 合成失败")
		return

	# 移除两个原角色
	bd.remove_character(BoardData.index_to_pos(src_index))
	bd.remove_character(BoardData.index_to_pos(tgt_index))

	# 放置新角色到目标位置
	var tgt_pos: Vector2i = BoardData.index_to_pos(tgt_index)
	bd.place_character(merged, tgt_pos)

	print(">>> [GameBoard] 合成完成: %s Lv.%d 于格 %d" % [merged.get_job_name(), merged.level, tgt_index])

	# 发出合成信号
	GameManager.character_merged.emit(merged.level)


# ---- 献祭 (任务 2.5) ----

func _sacrifice_character(cell_index: int) -> void:
	var bd: BoardData = GameManager.board_data
	var pos: Vector2i = BoardData.index_to_pos(cell_index)
	var ch: DataModels.CharacterData = bd.get_character_at(pos)
	if ch == null:
		return

	var refund: int = GameManager.calc_sacrifice_energy(ch.level)
	bd.remove_character(pos)
	GameManager.restore_energy(refund)

	print(">>> [GameBoard] 献祭 %s Lv.%d, 返还能量 %d" % [ch.get_job_name(), ch.level, refund])
	selected_index = -1
	_refresh_board_display()


# ---- 拖拽系统 (任务 2.3) ----

func _start_drag(cell_index: int, mouse_pos: Vector2) -> void:
	is_dragging = true
	drag_index = cell_index
	selected_index = cell_index

	# 创建拖拽预览
	drag_preview = _create_drag_preview(cell_index)
	add_child(drag_preview)
	drag_preview.global_position = mouse_pos - Vector2(CELL_SIZE / 2, CELL_SIZE / 2)

	# 隐藏原始格子
	cell_panels[cell_index].modulate.a = 0.3

	print(">>> [GameBoard] 开始拖拽格 %d" % cell_index)


func _create_drag_preview(cell_index: int) -> Control:
	var bd: BoardData = GameManager.board_data
	var ch: DataModels.CharacterData = bd.get_character_at_index(cell_index)

	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 让事件穿透到下层

	# 背景
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = _get_job_color(ch.job)
	preview.add_child(bg)

	# 标签
	var lbl := Label.new()
	lbl.text = "%s\nLv.%d" % [ch.get_job_name(), ch.level]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 11)
	preview.add_child(lbl)

	# 添加阴影效果
	var shadow := PanelContainer.new()
	shadow.modulate.a = 0.3
	shadow.offset_left = 3
	shadow.offset_top = 3
	shadow.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	var shadow_bg := ColorRect.new()
	shadow_bg.color = Color(0, 0, 0, 0.5)
	shadow.add_child(shadow_bg)
	preview.add_child(shadow)
	preview.move_child(shadow, 0)

	return preview


func _update_drag_preview(mouse_pos: Vector2) -> void:
	if drag_preview == null:
		return
	drag_preview.global_position = mouse_pos - Vector2(CELL_SIZE / 2, CELL_SIZE / 2)

	# 高亮悬停的格子
	hover_index = _get_hovered_cell_index(mouse_pos)
	is_hovering_dorm = _is_hovering_dorm_button(mouse_pos)
	_refresh_board_display()

	# 临时高亮目标格子
	if hover_index >= 0 and hover_index != drag_index:
		var bd: BoardData = GameManager.board_data
		var target_ch: DataModels.CharacterData = bd.get_character_at_index(hover_index)
		var sel_ch: DataModels.CharacterData = bd.get_character_at_index(drag_index)

		if target_ch == null:
			# 移动到空格子
			cell_rects[hover_index].color = COLOR_SELECTED
		elif target_ch.job == sel_ch.job and target_ch.level == sel_ch.level:
			# 可合成
			cell_rects[hover_index].color = COLOR_MERGE_HINT
		else:
			# 交换
			cell_rects[hover_index].color = Color("#888888")


func _get_hovered_cell_index(mouse_pos: Vector2) -> int:
	# 将鼠标位置转换为格子索引
	var grid_rect: Rect2 = grid_container.get_global_rect()
	if not grid_rect.has_point(mouse_pos):
		return -1

	var local_pos := mouse_pos - grid_rect.position
	var col := int(local_pos.x / (grid_rect.size.x / GRID_SIZE))
	var row := int(local_pos.y / (grid_rect.size.y / GRID_SIZE))

	if row < 0 or row >= GRID_SIZE or col < 0 or col >= GRID_SIZE:
		return -1

	return row * GRID_SIZE + col


func _is_hovering_dorm_button(mouse_pos: Vector2) -> bool:
	var dorm_rect: Rect2 = dorm_button.get_global_rect()
	return dorm_rect.has_point(mouse_pos)


func _end_drag(_target_index: int) -> void:
	if not is_dragging:
		return

	# 恢复原始格子透明度
	if drag_index >= 0 and drag_index < cell_panels.size():
		cell_panels[drag_index].modulate.a = 1.0

	# 销毁拖拽预览
	if drag_preview != null:
		drag_preview.queue_free()
		drag_preview = null

	# 检查是否拖放到宿舍
	if is_hovering_dorm:
		_drag_to_dorm()
		is_dragging = false
		drag_index = -1
		hover_index = -1
		is_hovering_dorm = false
		return

	# 执行放置操作: 使用悬停的格子作为目标
	if hover_index >= 0 and hover_index != drag_index:
		selected_index = drag_index
		_handle_cell_action(hover_index)
	elif hover_index == drag_index or hover_index < 0:
		# 释放到原格子或无效区域: 取消选中
		selected_index = -1
		_refresh_board_display()

	is_dragging = false
	drag_index = -1
	hover_index = -1
	is_hovering_dorm = false
	print(">>> [GameBoard] 结束拖拽")


# ---- 棋盘显示刷新 ----

func _refresh_board_display() -> void:
	var bd: BoardData = GameManager.board_data
	for i in range(BoardData.BOARD_SLOTS):
		var ch: DataModels.CharacterData = bd.get_character_at_index(i)
		if ch != null:
			var base_color: Color = _get_job_color(ch.job)
			# 选中高亮
			if i == selected_index:
				cell_rects[i].color = COLOR_SELECTED
			# 可合成提示: 与选中角色同职业同等级
			elif selected_index >= 0:
				var sel_ch: DataModels.CharacterData = bd.get_character_at_index(selected_index)
				if sel_ch != null and ch.job == sel_ch.job and ch.level == sel_ch.level:
					cell_rects[i].color = COLOR_MERGE_HINT
				else:
					cell_rects[i].color = base_color
			else:
				cell_rects[i].color = base_color
			cell_labels[i].text = "%s\nLv.%d\n%d/%d" % [
				ch.get_job_name(), ch.level, ch.hp, ch.max_hp
			]
		else:
			@warning_ignore("integer_division")
			var row := i / GRID_SIZE
			var col := i % GRID_SIZE
			var is_even := (row + col) % 2 == 0
			cell_rects[i].color = COLOR_EMPTY_EVEN if is_even else COLOR_EMPTY_ODD
			cell_labels[i].text = ""


func _get_job_color(job: int) -> Color:
	# 转职职业: 使用基础职业颜色但更亮
	if JobAdvanced.is_advanced_job(job):
		if job >= 30: return Color("#50D050")  # 牧师系转职 - 亮绿
		if job >= 20: return Color("#8060E0")  # 法师系转职 - 亮紫
		return Color("#E05050")                # 战士系转职 - 亮红
	match job:
		DataModels.Job.WARRIOR: return COLOR_WARRIOR
		DataModels.Job.MAGE: return COLOR_MAGE
		DataModels.Job.PRIEST: return COLOR_PRIEST
		_: return Color.WHITE


# ---- 资源标签更新 ----

func _update_resource_labels() -> void:
	gold_label.text = LocalizationSystem.get_text("game_board.gold", {"value": GameManager.gold})
	energy_label.text = LocalizationSystem.get_text("game_board.energy", {"current": GameManager.energy, "max": GameManager.max_energy})
	round_label.text = LocalizationSystem.get_text("game_board.round", {"value": GameManager.current_round})


func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = LocalizationSystem.get_text("game_board.gold", {"value": new_gold})


func _on_energy_changed(new_energy: int) -> void:
	energy_label.text = LocalizationSystem.get_text("game_board.energy", {"current": new_energy, "max": GameManager.max_energy})


func _on_round_changed(new_round: int) -> void:
	round_label.text = LocalizationSystem.get_text("game_board.round", {"value": new_round})


# ---- 角色生成 (任务 2.2) ----

func _on_spawn_pressed(job: int) -> void:
	if not GameManager.spend_energy(1):
		print(">>> [GameBoard] 生成失败: 能量不足")
		return

	if GameManager.board_data.is_board_full():
		GameManager.restore_energy(1)
		print(">>> [GameBoard] 生成失败: 棋盘已满")
		return

	var level: int = randi_range(1, 3)

	# 遗物: 经验药水(ID18) 10%概率直升2级
	if ItemDatabase.has_relic(18, GameManager.relics) and randf() < 0.1:
		level = mini(level + 1, 3)
		print(">>> [GameBoard] 遗物[经验药水]触发, 等级+1")

	# 遗物: 稀有召唤符(ID20) 5%概率直接3级
	if ItemDatabase.has_relic(20, GameManager.relics) and randf() < 0.05:
		level = 3
		print(">>> [GameBoard] 遗物[稀有召唤符]触发, 直接3级")

	var ch: DataModels.CharacterData = CharacterFactory.create_character(job, level)

	# 转职概率检查 (5% + 转职令牌遗物+5%)
	var has_relic_17: bool = ItemDatabase.has_relic(17, GameManager.relics)
	JobAdvanced.check_advance_on_spawn(ch, has_relic_17)

	var pos: Vector2i = GameManager.board_data.place_character_first_empty(ch)
	if pos == Vector2i(-1, -1):
		GameManager.restore_energy(1)
		print(">>> [GameBoard] 生成失败: 无法放置")
		return

	print(">>> [GameBoard] 生成 %s Lv.%d 于 (%d, %d)" % [ch.get_job_name(), ch.level, pos.x, pos.y])
	_refresh_board_display()


# ---- 宿舍操作 ----

func _on_dorm_pressed() -> void:
	dorm_visible = !dorm_visible
	dorm_panel.visible = dorm_visible
	if dorm_visible:
		_refresh_dorm_panel()


func _on_dorm_take_pressed(dorm_index: int) -> void:
	if GameManager.board_data.is_board_full():
		print(">>> [GameBoard] 取出失败: 棋盘已满")
		return
	var ch: DataModels.CharacterData = GameManager.board_data.take_from_dormitory(dorm_index)
	if ch == null:
		return
	var pos: Vector2i = GameManager.board_data.place_character_first_empty(ch)
	print(">>> [GameBoard] 从宿舍取出 %s Lv.%d 到 (%d,%d)" % [ch.get_job_name(), ch.level, pos.x, pos.y])
	_refresh_dorm_panel()
	_refresh_board_display()


func _on_dorm_close() -> void:
	dorm_visible = false
	dorm_panel.visible = false


func _drag_to_dorm() -> void:
	if drag_index < 0:
		return
	var bd: BoardData = GameManager.board_data
	var ch: DataModels.CharacterData = bd.get_character_at_index(drag_index)
	if ch == null:
		return
	var pos: Vector2i = BoardData.index_to_pos(drag_index)
	bd.board_to_dormitory(pos)
	print(">>> [GameBoard] 拖拽存入宿舍: %s Lv.%d" % [ch.get_job_name(), ch.level])
	selected_index = -1
	_refresh_board_display()


# ---- 遗物栏操作（常驻显示）----

func _on_relic_toggle() -> void:
	relic_panel_visible = !relic_panel_visible
	relic_panel.visible = relic_panel_visible
	if relic_panel_visible:
		_refresh_relic_panel()


func _refresh_relic_panel() -> void:
	# 清空旧内容
	for child in relic_list.get_children():
		child.queue_free()

	# 更新按钮文本
	var relic_count: int = GameManager.relics.size()
	relic_button.text = LocalizationSystem.get_text("game_board.relics", {"count": relic_count})

	# 显示遗物列表
	for i in range(GameManager.relics.size()):
		var relic: DataModels.ItemData = GameManager.relics[i]
		var relic_item: PanelContainer = PanelContainer.new()
		relic_item.custom_minimum_size = Vector2(80, 60)

		var vbox := VBoxContainer.new()
		relic_item.add_child(vbox)

		var name_lbl := Label.new()
		name_lbl.text = relic.name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 10)
		vbox.add_child(name_lbl)

		var count_lbl := Label.new()
		count_lbl.text = LocalizationSystem.get_text("game_board.relic_count", {"count": relic.stack_count})
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.add_theme_font_size_override("font_size", 9)
		vbox.add_child(count_lbl)

		relic_list.add_child(relic_item)


func _on_relics_changed() -> void:
	_refresh_relic_panel()


# ---- 棋盘→宿舍 (长按或双击可扩展, 暂用选中+宿舍按钮) ----

func _input(event: InputEvent) -> void:
	# 按 D 键将选中角色存入宿舍
	if event is InputEventKey and event.pressed and event.keycode == KEY_D:
		if selected_index >= 0:
			var bd: BoardData = GameManager.board_data
			var ch: DataModels.CharacterData = bd.get_character_at_index(selected_index)
			if ch != null:
				var pos: Vector2i = BoardData.index_to_pos(selected_index)
				bd.board_to_dormitory(pos)
				print(">>> [GameBoard] 存入宿舍: %s Lv.%d" % [ch.get_job_name(), ch.level])
				selected_index = -1
				_refresh_board_display()


# ---- 按钮回调 ----

func _on_end_turn_pressed() -> void:
	selected_index = -1
	print(">>> [GameBoard] 结束回合, 进入战斗阶段")
	GameManager.enter_battle_phase()
	get_tree().change_scene_to_file("res://scenes/battle_scene.tscn")


func _on_back_pressed() -> void:
	print(">>> [GameBoard] 返回主菜单")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_shop_pressed() -> void:
	print(">>> [GameBoard] 打开商店")
	get_tree().change_scene_to_file("res://scenes/shop_scene.tscn")


func _on_item_pressed() -> void:
	# 道具栏弹窗 (备用)
	_show_item_panel()


# ---- 道具栏格子 (3个固定格子) ----

func _setup_item_slots() -> void:
	item_slot_nodes.clear()
	item_slot_labels.clear()
	item_slot_overlays.clear()

	for i in range(ITEM_SLOT_COUNT):
		var slot: PanelContainer = item_bar.get_child(i)
		item_slot_nodes.append(slot)

		# 清除旧内容
		for child in slot.get_children():
			child.queue_free()

		# 背景色
		var bg := ColorRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.color = Color("#1A2A4A")
		slot.add_child(bg)

		# 标签显示道具名
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.clip_text = true
		slot.add_child(lbl)
		item_slot_labels.append(lbl)

		# 点击事件
		slot.gui_input.connect(_on_item_slot_input.bind(i))


func _refresh_item_slots() -> void:
	for i in range(ITEM_SLOT_COUNT):
		if i < GameManager.items.size():
			var item: DataModels.ItemData = GameManager.items[i]
			item_slot_labels[i].text = item.name
			item_slot_nodes[i].modulate = Color.WHITE
		else:
			item_slot_labels[i].text = ""
			item_slot_nodes[i].modulate = Color(0.5, 0.5, 0.5, 0.3)


func _on_item_slot_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_use_item_at_slot(slot_index)


func _use_item_at_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= GameManager.items.size():
		return

	# 查找选中的角色
	if selected_index < 0:
		print(">>> [GameBoard] 使用道具失败: 请先选中一个角色")
		return

	var item: DataModels.ItemData = GameManager.items[slot_index]
	var success: bool = ItemDatabase.use_consumable(item, selected_index)
	if success:
		GameManager.remove_item(slot_index)
		_refresh_item_slots()
		_refresh_board_display()
	else:
		print(">>> [GameBoard] 使用道具失败")


# ---- 道具栏面板 ----

var item_panel: PanelContainer = null
var item_panel_visible: bool = false

func _show_item_panel() -> void:
	if item_panel == null:
		_create_item_panel()
	item_panel_visible = !item_panel_visible
	item_panel.visible = item_panel_visible
	if item_panel_visible:
		_refresh_item_panel()


func _create_item_panel() -> void:
	item_panel = PanelContainer.new()
	item_panel.visible = false
	item_panel.set_anchors_preset(Control.PRESET_CENTER)
	item_panel.custom_minimum_size = Vector2(320, 220)
	item_panel.offset_left = -160
	item_panel.offset_top = -110
	item_panel.offset_right = 160
	item_panel.offset_bottom = 110
	add_child(item_panel)


func _refresh_item_panel() -> void:
	for child in item_panel.get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	item_panel.add_child(vbox)

	var title := Label.new()
	title.text = LocalizationSystem.get_text("game_board.item_title", {"count": GameManager.items.size()})
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 140)
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for i in range(GameManager.items.size()):
		var item: DataModels.ItemData = GameManager.items[i]
		var row := HBoxContainer.new()
		list.add_child(row)

		var info := Label.new()
		info.text = "%s - %s" % [item.name, item.description]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.clip_text = true
		row.add_child(info)

		var use_btn := Button.new()
		use_btn.text = LocalizationSystem.get_text("game_board.item_use")
		use_btn.pressed.connect(_on_use_item.bind(i))
		row.add_child(use_btn)

	if GameManager.items.size() == 0:
		var empty := Label.new()
		empty.text = LocalizationSystem.get_text("game_board.item_empty")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)

	var close_btn := Button.new()
	close_btn.text = LocalizationSystem.get_text("game_board.back")
	close_btn.pressed.connect(func(): item_panel.visible = false; item_panel_visible = false)
	vbox.add_child(close_btn)


func _on_use_item(item_index: int) -> void:
	if item_index < 0 or item_index >= GameManager.items.size():
		return
	var item: DataModels.ItemData = GameManager.items[item_index]

	# 需要指定目标的道具, 使用选中的格子
	var target_idx: int = selected_index
	var success: bool = ItemDatabase.use_consumable(item, target_idx)
	if success:
		GameManager.remove_item(item_index)
		_refresh_item_panel()
		_refresh_item_slots()
		_refresh_board_display()
	else:
		print(">>> [GameBoard] 使用道具失败 (可能需要先选中一个角色)")


# ---- 设置面板 ----

func _on_settings_pressed() -> void:
	_show_settings_panel()


func _show_settings_panel() -> void:
	settings_panel.visible = true
	_update_settings_ui()
	_update_settings_texts()


func _hide_settings_panel() -> void:
	settings_panel.visible = false


func _update_settings_ui() -> void:
	_update_language_button_text()
	volume_slider.value = _load_volume()


func _update_settings_texts() -> void:
	settings_title.text = LocalizationSystem.get_text("settings.title")
	language_label.text = LocalizationSystem.get_text("settings.language")
	volume_label.text = LocalizationSystem.get_text("settings.volume")
	reset_tutorial_button.text = LocalizationSystem.get_text("settings.reset_tutorial")
	close_settings_button.text = LocalizationSystem.get_text("settings.close")
	_reset_confirm_label_visible(false)


func _on_language_toggled() -> void:
	var current_lang: String = LocalizationSystem.current_lang
	if current_lang == "en":
		LocalizationSystem.set_language("zh")
	else:
		LocalizationSystem.set_language("en")

	_update_language_button_text()
	_update_settings_texts()
	_refresh_relic_panel()
	print(">>> [GameBoard] 语言切换为: %s" % LocalizationSystem.current_lang)


func _update_language_button_text() -> void:
	if LocalizationSystem.current_lang == "en":
		language_button.text = "EN"
	else:
		language_button.text = "中文"


func _on_volume_changed(value: float) -> void:
	_save_volume(value)


func _on_reset_tutorial_pressed() -> void:
	GameManager.reset_tutorial()
	_reset_confirm_label_visible(true)


func _reset_confirm_label_visible(visible: bool) -> void:
	reset_confirm_label.visible = visible
	if visible:
		reset_confirm_label.text = LocalizationSystem.get_text("settings.reset_confirm")


func _on_close_settings() -> void:
	_hide_settings_panel()


func _load_volume() -> float:
	var config := ConfigFile.new()
	var err := config.load("user://settings.cfg")
	if err == OK:
		return config.get_value("audio", "volume", 1.0)
	return 1.0


func _save_volume(value: float) -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "volume", value)
	config.save("user://settings.cfg")
