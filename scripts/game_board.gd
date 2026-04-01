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
@onready var encyclopedia_button: Button = $MainLayout/MiddleBar/EncyclopediaButton

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
var cell_sprites: Array = []   # TextureRect 角色精灵图

# ---- 选中状态 (任务 2.3 拖拽) ----
var selected_index: int = -1   # 当前选中的棋盘格索引, -1=无选中

# ---- 拖拽状态 ----
var is_dragging: bool = false   # 是否正在拖拽
var drag_index: int = -1        # 拖拽源的格子索引
var drag_preview: Control = null # 拖拽预览节点
var hover_index: int = -1       # 当前悬停的格子索引
var is_hovering_dorm: bool = false  # 是否悬停在宿舍按钮上

# ---- 教学系统 ----
var tutorial_overlay = null

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

# ---- 道具详情弹窗 ----
var item_detail_popup: PanelContainer = null
var item_detail_backdrop: Control = null
var item_detail_popup_slot: int = -1
var item_detail_visible: bool = false

# ---- 目标选择指针 ----
var target_cursor: Control = null
var is_selecting_target: bool = false
var target_select_item_slot: int = -1

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
	encyclopedia_button.pressed.connect(_on_encyclopedia_pressed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.energy_changed.connect(_on_energy_changed)
	GameManager.round_changed.connect(_on_round_changed)
	GameManager.relics_changed.connect(_on_relics_changed)
	# 设置面板信号
	language_button.pressed.connect(_on_language_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	reset_tutorial_button.pressed.connect(_on_reset_tutorial_pressed)
	close_settings_button.pressed.connect(_on_close_settings)
	# 语言切换信号
	LocalizationSystem.language_changed.connect(_on_localization_changed)


# ---- 棋盘 UI 构建 ----

func _setup_board_ui() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	cell_rects.clear()
	cell_labels.clear()
	cell_panels.clear()
	cell_sprites.clear()

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

		# 角色精灵图（覆盖整个格子）
		var sprite := TextureRect.new()
		sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		sprite.position = Vector2(0, 0)
		sprite.pivot_offset = Vector2(CELL_SIZE / 2, CELL_SIZE / 2)  # 以中央为缩放中心
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.visible = false
		cell.add_child(sprite)

		# 角色信息标签（覆盖在精灵图下方）
		var lbl := Label.new()
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.anchor_top = 0.6  # 从60%高度开始
		lbl.anchor_bottom = 1.0
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 10)
		cell.add_child(lbl)

		# 点击事件
		cell.gui_input.connect(_on_cell_gui_input.bind(i))

		grid_container.add_child(cell)
		cell_rects.append(bg)
		cell_labels.append(lbl)
		cell_panels.append(cell)
		cell_sprites.append(sprite)

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
	# 目标选择模式: 点击角色使用道具
	if is_selecting_target and event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var bd: BoardData = GameManager.board_data
			var ch: DataModels.CharacterData = bd.get_character_at_index(cell_index)
			if ch != null:
				_use_item_on_target(cell_index)
				return
			else:
				# 点击空格子取消选择
				_end_target_selection()
				return

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
		# 目标为空: 直接移动，无需动画
		_do_swap_or_move(selected_index, target_index)
		selected_index = -1
		_refresh_board_display()
		_try_advance_tutorial(2)
	elif target_ch.job == source_ch.job and target_ch.level == source_ch.level:
		# 同职业同等级: 合成 (任务 2.4)
		_merge_at(selected_index, target_index)
	else:
		# 不同角色: 交换位置
		_play_swap_animation(selected_index, target_index)


## 交换角色：被换的角色播放移动动画到源位置
func _play_swap_animation(src_index: int, tgt_index: int) -> void:
	# 隐藏拖拽预览
	if drag_preview != null:
		drag_preview.queue_free()
		drag_preview = null

	# 获取被换角色（tgt_index）的sprite和位置
	var tgt_sprite: Control = cell_sprites[tgt_index]
	if tgt_sprite == null:
		_do_swap_or_move(src_index, tgt_index)
		_refresh_board_display()
		selected_index = -1
		_try_advance_tutorial(2)
		return

	# 记录角色B当前位置（格子tgt_index，即B原来的位置）
	var b_start_pos: Vector2 = tgt_sprite.global_position

	# 记录角色A目标位置（格子src_index，即A原来的位置，B要去的地方）
	var b_end_pos: Vector2 = tgt_sprite.global_position  # 临时，后面会重新获取

	# 执行数据交换
	_do_swap_or_move(src_index, tgt_index)

	# 刷新显示（此时src_index显示被换的角色B，tgt_index显示源角色A）
	_refresh_board_display()

	# 获取角色A的目标位置（B要去的位置 = A原来的位置 = src_index的位置）
	var a_pos: Control = cell_sprites[src_index]
	if a_pos == null or not is_instance_valid(a_pos):
		selected_index = -1
		_try_advance_tutorial(2)
		return
	b_end_pos = a_pos.global_position

	# 角色B现在在src_index，先设置到B原来的位置（起点）
	var b_sprite: Control = cell_sprites[src_index]
	if b_sprite == null or not is_instance_valid(b_sprite):
		selected_index = -1
		_try_advance_tutorial(2)
		return
	b_sprite.global_position = b_start_pos

	# 把sprite移到父节点最前面，避免被格子背景挡住
	var parent: Control = b_sprite.get_parent()
	if parent != null:
		parent.move_child(b_sprite, parent.get_child_count() - 1)

	# 让B播放移动动画到A原来的位置
	var tween := create_tween()
	tween.set_parallel(false)
	tween.tween_property(b_sprite, "global_position", b_end_pos, 0.2)

	await tween.finished

	selected_index = -1
	_try_advance_tutorial(2)


## 执行实际的交换或移动（数据层）
func _do_swap_or_move(src_index: int, tgt_index: int) -> void:
	var bd: BoardData = GameManager.board_data
	var source_ch: DataModels.CharacterData = bd.get_character_at_index(src_index)

	if source_ch == null:
		return

	var target_ch: DataModels.CharacterData = bd.get_character_at_index(tgt_index)

	if target_ch == null:
		# 移动
		var src_pos: Vector2i = BoardData.index_to_pos(src_index)
		var tgt_pos: Vector2i = BoardData.index_to_pos(tgt_index)
		bd.swap_positions(src_pos, tgt_pos)
		print(">>> [GameBoard] 移动 %s 从格 %d 到格 %d" % [source_ch.get_job_name(), src_index, tgt_index])
	else:
		# 交换
		var src_pos: Vector2i = BoardData.index_to_pos(src_index)
		var tgt_pos: Vector2i = BoardData.index_to_pos(tgt_index)
		bd.swap_positions(src_pos, tgt_pos)
		print(">>> [GameBoard] 交换 格%d ↔ 格%d" % [src_index, tgt_index])


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
	if is_instance_valid(get_node_or_null("/root/SaveSystem")):
		SaveSystem.unlock_encyclopedia(merged.job, merged.level)

	# 发出合成信号
	GameManager.character_merged.emit(merged.level)

	# 刷新棋盘显示
	_refresh_board_display()

	# 播放合成动画: 0.8 -> 1.1 -> 1.0
	_play_merge_animation(tgt_index)


func _play_merge_animation(cell_index: int) -> void:
	if cell_index < 0 or cell_index >= cell_sprites.size():
		print(">>> [Debug] MergeAnim: invalid cell_index %d" % cell_index)
		return
	var sprite: Control = cell_sprites[cell_index]
	if sprite == null:
		print(">>> [Debug] MergeAnim: sprite is null")
		return

	print(">>> [Debug] MergeAnim: playing on cell %d" % cell_index)

	# 重置scale
	sprite.scale = Vector2(1.0, 1.0)
	# 重置颜色
	sprite.modulate = Color.WHITE

	# 创建缩放动画 Tween (sequential by default)
	var tween := create_tween()
	tween.set_parallel(false)

	# 0.8 -> 1.1 -> 1.0
	tween.tween_property(sprite, "scale", Vector2(0.8, 0.8), 0.1).from(Vector2(1.0, 1.0))
	tween.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.15)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)

	# 白色闪烁
	var tween2 := create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.05)
	tween2.tween_property(sprite, "modulate", Color(1.0, 1.0, 0.5, 1.0), 0.1)
	tween2.tween_property(sprite, "modulate", Color.WHITE, 0.25)


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
	# Tutorial: advance after sacrifice (step 3 = details/sacrifice/encyclopedia)
	_try_advance_tutorial(3)


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


func _create_drag_preview(cell_index: int, with_outline: bool = false) -> Control:
	var bd: BoardData = GameManager.board_data
	var ch: DataModels.CharacterData = bd.get_character_at_index(cell_index)

	# 根节点只用于定位，不显示背景
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 让事件穿透到下层

	# 精灵图
	var sprite_folder: String = ch.get_sprite_folder()
	var sprite_name: String = ch.get_sprite_path(1, 1)
	var sprite_path: String = "res://art/sprites/chars/" + sprite_folder + "/" + sprite_name + ".png"
	var tex := load(sprite_path) if FileAccess.file_exists(sprite_path) else null
	if tex:
		var sprite := TextureRect.new()
		sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.texture = tex

		# 如果可合成，添加Outline效果
		if with_outline:
			var outline_mat := ShaderMaterial.new()
			outline_mat.shader = preload("res://shaders/outline.gdshader")
			outline_mat.set_shader_parameter("outline_color", Color(1.0, 0.8, 0.0, 1.0))  # 金色outline
			outline_mat.set_shader_parameter("outline_width", 3.0)
			sprite.material = outline_mat

		preview.add_child(sprite)

	return preview


func _update_drag_preview(mouse_pos: Vector2) -> void:
	if drag_preview == null:
		return
	drag_preview.global_position = mouse_pos - Vector2(CELL_SIZE / 2, CELL_SIZE / 2)

	# 高亮悬停的格子
	hover_index = _get_hovered_cell_index(mouse_pos)
	is_hovering_dorm = _is_near_dorm_button(mouse_pos)
	_refresh_board_display()

	# 临时高亮目标格子 & 更新拖拽预览Outline
	var is_over_mergeable: bool = false
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
			is_over_mergeable = true
		else:
			# 交换
			cell_rects[hover_index].color = Color("#888888")

	# 更新拖拽预览的Outline效果
	_update_drag_preview_outline(is_over_mergeable)

	# 高亮宿舍按钮（靠近时）
	_update_dorm_highlight()


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


func _is_near_dorm_button(mouse_pos: Vector2) -> bool:
	# 扩展检测区域：宿舍按钮本身 + 周围扩展区域
	var dorm_rect: Rect2 = dorm_button.get_global_rect()
	var expand: int = 50  # 扩展50像素
	dorm_rect.position -= Vector2(expand, expand)
	dorm_rect.size += Vector2(expand * 2, expand * 2)
	return dorm_rect.has_point(mouse_pos)


func _update_dorm_highlight() -> void:
	if is_dragging:
		if is_hovering_dorm:
			# 高亮：金色调 + 稍亮
			dorm_button.modulate = Color(1.3, 1.1, 0.7, 1.0)
		else:
			# 恢复默认
			dorm_button.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _update_drag_preview_outline(show_outline: bool) -> void:
	if drag_preview == null:
		return
	var sprite: TextureRect = drag_preview.get_child(0) as TextureRect
	if sprite == null:
		return
	if show_outline:
		if sprite.material == null:
			var outline_mat := ShaderMaterial.new()
			outline_mat.shader = preload("res://shaders/outline.gdshader")
			outline_mat.set_shader_parameter("outline_color", Color(1.0, 0.8, 0.0, 1.0))
			outline_mat.set_shader_parameter("outline_width", 3.0)
			sprite.material = outline_mat
	else:
		sprite.material = null


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
		# 恢复宿舍按钮颜色
		dorm_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
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
	# 恢复宿舍按钮颜色
	dorm_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	print(">>> [GameBoard] 结束拖拽")


# ---- 棋盘显示刷新 ----

func _refresh_board_display() -> void:
	var bd: BoardData = GameManager.board_data
	for i in range(BoardData.BOARD_SLOTS):
		@warning_ignore("integer_division")
		var row := i / GRID_SIZE
		var col := i % GRID_SIZE
		var is_even := (row + col) % 2 == 0
		var empty_color: Color = COLOR_EMPTY_EVEN if is_even else COLOR_EMPTY_ODD

		var ch: DataModels.CharacterData = bd.get_character_at_index(i)
		if ch != null:
			# 角色格子：背景使用空格子颜色（不显示职业颜色）
			if i == selected_index:
				cell_rects[i].color = COLOR_SELECTED
			# 可合成提示: 与选中角色同职业同等级
			elif selected_index >= 0:
				var sel_ch: DataModels.CharacterData = bd.get_character_at_index(selected_index)
				if sel_ch != null and ch.job == sel_ch.job and ch.level == sel_ch.level:
					cell_rects[i].color = COLOR_MERGE_HINT
				else:
					cell_rects[i].color = empty_color
			else:
				cell_rects[i].color = empty_color

			# 加载角色精灵图
			var sprite_folder: String = ch.get_sprite_folder()
			var sprite_name: String = ch.get_sprite_path(1, 1)  # 待机动画第1帧
			var sprite_path: String = "res://art/sprites/chars/" + sprite_folder + "/" + sprite_name + ".png"
			var tex_exists: bool = FileAccess.file_exists(sprite_path)
			var tex := load(sprite_path) if tex_exists else null
			cell_sprites[i].texture = tex
			cell_sprites[i].visible = (tex != null)
			if tex == null:
				print(">>> [Debug] 精灵图加载失败: %s (职业=%d, 等级=%d, 文件存在=%s)" % [sprite_path, ch.job, ch.level, tex_exists])

			cell_labels[i].text = "%s\nLv.%d\n%d/%d" % [
				ch.get_job_name(), ch.level, ch.hp, ch.max_hp
			]
		else:
			cell_rects[i].color = empty_color
			cell_labels[i].text = ""
			cell_sprites[i].texture = null
			cell_sprites[i].visible = false


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
	if is_instance_valid(get_node_or_null("/root/SaveSystem")):
		SaveSystem.unlock_encyclopedia(ch.job, ch.level)
	_refresh_board_display()
	# Tutorial: advance after spawn (step 0 = first spawn, step 1 = second spawn/merge)
	_try_advance_tutorial(0)
	_try_advance_tutorial(1)


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
	# Tutorial: advance on end turn (step 4)
	_try_advance_tutorial(4)
	print(">>> [GameBoard] 结束回合, 进入战斗阶段")
	GameManager.enter_battle_phase()
	get_tree().change_scene_to_file("res://scenes/battle_scene.tscn")


func _on_back_pressed() -> void:
	print(">>> [GameBoard] 返回主菜单")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_shop_pressed() -> void:
	print(">>> [GameBoard] 打开商店")
	get_tree().change_scene_to_file("res://scenes/shop_scene.tscn")


func _on_encyclopedia_pressed() -> void:
	print(">>> [GameBoard] 打开图鉴")
	# Tutorial: advance after opening encyclopedia (step 3)
	_try_advance_tutorial(3)
	get_tree().change_scene_to_file("res://scenes/encyclopedia_scene.tscn")


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
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 让点击穿透到slot
		slot.add_child(bg)

		# 标签显示道具名
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.clip_text = true
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 让点击穿透到slot
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


# ---- 道具详情弹窗 ----

func _show_item_detail(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= GameManager.items.size():
		return

	# 隐藏其他弹窗
	_hide_item_detail()

	# 创建详情弹窗
	_create_item_detail_popup(slot_index)
	item_detail_popup_slot = slot_index
	item_detail_visible = true


func _hide_item_detail() -> void:
	if item_detail_popup != null:
		item_detail_popup.queue_free()
		item_detail_popup = null
	if item_detail_backdrop != null:
		item_detail_backdrop.queue_free()
		item_detail_backdrop = null
	item_detail_popup_slot = -1
	item_detail_visible = false
	_end_target_selection()


func _create_item_detail_popup(slot_index: int) -> void:
	var item: DataModels.ItemData = GameManager.items[slot_index]

	# 背景遮罩
	item_detail_backdrop = ColorRect.new()
	item_detail_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_detail_backdrop.color = Color(0.0, 0.0, 0.0, 0.4)
	item_detail_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	item_detail_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(item_detail_backdrop)
	item_detail_backdrop.name = "ItemDetailBackdrop"

	# 详情面板
	item_detail_popup = PanelContainer.new()
	item_detail_popup.set_anchors_preset(Control.PRESET_CENTER)
	item_detail_popup.custom_minimum_size = Vector2(260, 160)
	item_detail_popup.offset_left = -130
	item_detail_popup.offset_top = -80
	item_detail_popup.offset_right = 130
	item_detail_popup.offset_bottom = 80
	item_detail_popup.z_index = 100
	add_child(item_detail_popup)

	# 面板样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.22, 0.98)
	style.border_color = Color(0.6, 0.5, 0.3, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	item_detail_popup.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	item_detail_popup.add_child(vbox)
	vbox.add_theme_constant_override("separation", 10)

	# 道具名称
	var name_lbl := Label.new()
	name_lbl.text = item.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	vbox.add_child(name_lbl)

	# 道具描述
	var desc_lbl := Label.new()
	desc_lbl.text = item.description
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size.y = 50
	vbox.add_child(desc_lbl)

	# 目标提示
	var target_lbl := Label.new()
	var needs_target: bool = _item_needs_target(item.id)
	if needs_target:
		target_lbl.text = LocalizationSystem.get_text("items.target_required")
		target_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	else:
		target_lbl.text = LocalizationSystem.get_text("items.no_target")
		target_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	target_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(target_lbl)

	# 按钮行
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.custom_minimum_size.y = 36
	vbox.add_child(btn_row)

	# 使用按钮
	var use_btn := Button.new()
	use_btn.text = LocalizationSystem.get_text("items.use")
	use_btn.custom_minimum_size = Vector2(90, 32)
	use_btn.pressed.connect(_on_item_use_clicked.bind(slot_index))
	btn_row.add_child(use_btn)

	# 丢弃按钮
	var discard_btn := Button.new()
	discard_btn.text = LocalizationSystem.get_text("items.discard")
	discard_btn.custom_minimum_size = Vector2(90, 32)
	discard_btn.pressed.connect(_on_item_discard_clicked.bind(slot_index))
	btn_row.add_child(discard_btn)

	# 关闭按钮
	var close_btn := Button.new()
	close_btn.text = LocalizationSystem.get_text("items.close")
	close_btn.custom_minimum_size = Vector2(90, 32)
	close_btn.pressed.connect(_hide_item_detail)
	btn_row.add_child(close_btn)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_hide_item_detail()


func _on_item_use_clicked(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= GameManager.items.size():
		_hide_item_detail()
		return

	var item: DataModels.ItemData = GameManager.items[slot_index]
	var needs_target: bool = _item_needs_target(item.id)

	if needs_target:
		# 需要目标: 进入目标选择模式
		_hide_item_detail()
		_start_target_selection(slot_index)
	else:
		# 直接使用
		_use_item_direct(slot_index)


func _on_item_discard_clicked(slot_index: int) -> void:
	_discard_item(slot_index)
	_hide_item_detail()


func _discard_item(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= GameManager.items.size():
		return
	GameManager.remove_item(slot_index)
	_refresh_item_slots()
	print(">>> [GameBoard] 丢弃道具: %d" % slot_index)


func _use_item_direct(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= GameManager.items.size():
		return

	var item: DataModels.ItemData = GameManager.items[slot_index]
	var success: bool = ItemDatabase.use_consumable(item, -1)
	if success:
		GameManager.remove_item(slot_index)
		_refresh_item_slots()
		_refresh_board_display()
		print(">>> [GameBoard] 使用道具: %s" % item.name)
	else:
		print(">>> [GameBoard] 使用道具失败: %s" % item.name)
	# 无论成功失败，都隐藏详情弹窗
	_hide_item_detail()


func _use_item_on_target(target_index: int) -> void:
	var slot_index: int = target_select_item_slot
	if slot_index < 0 or slot_index >= GameManager.items.size():
		_end_target_selection()
		return

	var item: DataModels.ItemData = GameManager.items[slot_index]
	var success: bool = ItemDatabase.use_consumable(item, target_index)
	if success:
		GameManager.remove_item(slot_index)
		_refresh_item_slots()
		_refresh_board_display()
		print(">>> [GameBoard] 对格 %d 使用道具: %s" % [target_index, item.name])
	else:
		print(">>> [GameBoard] 使用道具失败: %s" % item.name)
	# 无论成功失败，都结束目标选择
	_end_target_selection()


func _item_needs_target(item_id: int) -> bool:
	# 需要指定目标的道具
	match item_id:
		1, 2, 3, 11, 13, 14, 15, 16:
			return true
	return false


# ---- 目标选择模式 ----

func _start_target_selection(item_slot: int) -> void:
	is_selecting_target = true
	target_select_item_slot = item_slot
	_show_target_cursor()


func _end_target_selection() -> void:
	is_selecting_target = false
	target_select_item_slot = -1
	_hide_target_cursor()


func _show_target_cursor() -> void:
	if target_cursor == null:
		target_cursor = Control.new()
		target_cursor.name = "TargetCursor"
		target_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var cursor_bg := ColorRect.new()
		cursor_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		cursor_bg.color = Color(1.0, 0.8, 0.0, 0.15)
		target_cursor.add_child(cursor_bg)

		var cursor_lbl := Label.new()
		cursor_lbl.text = LocalizationSystem.get_text("items.select_target")
		cursor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cursor_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cursor_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		cursor_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		cursor_lbl.add_theme_font_size_override("font_size", 14)
		target_cursor.add_child(cursor_lbl)

	add_child(target_cursor)
	target_cursor.set_anchors_preset(Control.PRESET_FULL_RECT)


func _hide_target_cursor() -> void:
	if target_cursor != null:
		target_cursor.queue_free()
		target_cursor = null


func _on_item_slot_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_show_item_detail(slot_index)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_discard_item(slot_index)


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
	if item_panel == null:
		return
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
	# 注: language_changed 信号会触发 _on_localization_changed


func _on_localization_changed(lang: String) -> void:
	_update_language_button_text()
	_update_settings_texts()
	_refresh_relic_panel()
	_update_resource_labels()
	_refresh_game_board_texts()
	_refresh_dorm_panel()
	_refresh_item_slots()
	_refresh_item_panel()
	# 如果道具详情弹窗打开，关闭它（下次打开时会用新语言创建）
	if item_detail_visible:
		_hide_item_detail()
	print(">>> [GameBoard] 语言切换为: %s" % lang)


func _update_language_button_text() -> void:
	if LocalizationSystem.current_lang == "en":
		language_button.text = "EN"
	else:
		language_button.text = "中文"


func _refresh_game_board_texts() -> void:
	# 更新底部按钮文本
	spawn_warrior.text = LocalizationSystem.get_text("game_board.spawn_warrior")
	spawn_mage.text = LocalizationSystem.get_text("game_board.spawn_mage")
	spawn_priest.text = LocalizationSystem.get_text("game_board.spawn_priest")
	end_turn_button.text = LocalizationSystem.get_text("game_board.end_turn")
	back_button.text = LocalizationSystem.get_text("game_board.back")
	dorm_button.text = LocalizationSystem.get_text("game_board.dorm")
	shop_button.text = LocalizationSystem.get_text("game_board.shop")
	encyclopedia_button.text = LocalizationSystem.get_text("game_board.encyclopedia")


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


# ---- 教学系统辅助 (任务 7.1) ----

func _try_advance_tutorial(expected_step: int) -> void:
	# Tutorial advancement is handled by tutorial_instance
	# This method kept for compatibility with old tutorial overlay
	pass
