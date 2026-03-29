extends Control

## 备战阶段主界面
## 任务 2.1-2.5: UI + 生成 + 拖拽 + 合成 + 献祭

# ---- 节点引用 ----
@onready var gold_label: Label = $MainLayout/TopBar/GoldLabel
@onready var energy_label: Label = $MainLayout/TopBar/EnergyLabel
@onready var round_label: Label = $MainLayout/TopBar/RoundLabel
@onready var relic_label: Label = $MainLayout/RelicBar/RelicLabel
@onready var grid_container: GridContainer = $MainLayout/BoardCenter/GridContainer
@onready var spawn_warrior: Button = $MainLayout/BottomBar/SpawnRow/SpawnWarrior
@onready var spawn_mage: Button = $MainLayout/BottomBar/SpawnRow/SpawnMage
@onready var spawn_priest: Button = $MainLayout/BottomBar/SpawnRow/SpawnPriest
@onready var end_turn_button: Button = $MainLayout/BottomBar/ActionRow/EndTurnButton
@onready var back_button: Button = $MainLayout/BottomBar/ActionRow/BackButton
@onready var item_button: Button = $MainLayout/MiddleBar/ItemButton
@onready var dorm_button: Button = $MainLayout/MiddleBar/DormButton
@onready var shop_button: Button = $MainLayout/MiddleBar/ShopButton

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

# ---- 宿舍面板 ----
var dorm_panel: PanelContainer = null
var dorm_visible: bool = false


func _ready() -> void:
	_connect_signals()
	_setup_board_ui()
	_setup_dorm_panel()
	_update_resource_labels()
	print(">>> [GameBoard] 备战阶段界面已加载")


# ---- 信号连接 ----

func _connect_signals() -> void:
	spawn_warrior.pressed.connect(_on_spawn_pressed.bind(DataModels.Job.WARRIOR))
	spawn_mage.pressed.connect(_on_spawn_pressed.bind(DataModels.Job.MAGE))
	spawn_priest.pressed.connect(_on_spawn_pressed.bind(DataModels.Job.PRIEST))
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	back_button.pressed.connect(_on_back_pressed)
	dorm_button.pressed.connect(_on_dorm_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	item_button.pressed.connect(_on_item_pressed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.energy_changed.connect(_on_energy_changed)
	GameManager.round_changed.connect(_on_round_changed)


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
	title.text = "宿舍 (%d人)" % GameManager.board_data.dormitory.size()
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
		take_btn.text = "取出"
		take_btn.pressed.connect(_on_dorm_take_pressed.bind(i))
		row.add_child(take_btn)

	if GameManager.board_data.dormitory.size() == 0:
		var empty := Label.new()
		empty.text = "宿舍为空"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_on_dorm_close)
	vbox.add_child(close_btn)


# ---- 棋盘格点击处理 (任务 2.3 拖拽/选中) ----

func _on_cell_gui_input(event: InputEvent, cell_index: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed:
		return

	var bd: BoardData = GameManager.board_data
	var ch: DataModels.CharacterData = bd.get_character_at_index(cell_index)

	# 左键: 选中 / 移动 / 合成
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if selected_index == -1:
			# 没有选中, 尝试选中
			if ch != null:
				selected_index = cell_index
				_refresh_board_display()
				print(">>> [GameBoard] 选中 %s Lv.%d 于格 %d" % [ch.get_job_name(), ch.level, cell_index])
		else:
			# 已有选中, 执行操作
			if cell_index == selected_index:
				# 点击同一个格子: 取消选中
				selected_index = -1
				_refresh_board_display()
			else:
				_handle_cell_action(cell_index)

	# 右键: 献祭 (任务 2.5)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
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
	match job:
		DataModels.Job.WARRIOR: return COLOR_WARRIOR
		DataModels.Job.MAGE: return COLOR_MAGE
		DataModels.Job.PRIEST: return COLOR_PRIEST
		_: return Color.WHITE


# ---- 资源标签更新 ----

func _update_resource_labels() -> void:
	gold_label.text = "金币: %d" % GameManager.gold
	energy_label.text = "能量: %d/%d" % [GameManager.energy, GameManager.max_energy]
	round_label.text = "回合: %d" % GameManager.current_round


func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "金币: %d" % new_gold


func _on_energy_changed(new_energy: int) -> void:
	energy_label.text = "能量: %d/%d" % [new_energy, GameManager.max_energy]


func _on_round_changed(new_round: int) -> void:
	round_label.text = "回合: %d" % new_round


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
	var ch: DataModels.CharacterData = CharacterFactory.create_character(job, level)

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
	# 道具栏弹窗
	_show_item_panel()


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
	title.text = "道具栏 (%d个)" % GameManager.items.size()
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
		use_btn.text = "使用"
		use_btn.pressed.connect(_on_use_item.bind(i))
		row.add_child(use_btn)

	if GameManager.items.size() == 0:
		var empty := Label.new()
		empty.text = "无道具"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)

	var close_btn := Button.new()
	close_btn.text = "关闭"
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
		_refresh_board_display()
	else:
		print(">>> [GameBoard] 使用道具失败 (可能需要先选中一个角色)")
