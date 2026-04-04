extends Control

## 备战阶段主界面
## 任务 2.1-2.5: UI + 生成 + 拖拽 + 合成 + 献祭

# ---- 资源预加载 ----
const CELL_BG_TEXTURE := preload("res://art/sprites/UI/items/smallItem/cell_0.png")
const CELL_SELECT_TEXTURE := preload("res://art/sprites/UI/items/smallItem/cell_1.png")

# 选中效果序列帧 (fx01)
var SELECT_FRAMES: Array[Texture2D] = []

# ---- 节点引用 ----
@onready var gold_label: Label = $MainLayout/TopBar/GoldContainer/GoldLabel
@onready var energy_label: Label = $MainLayout/BottomBar/SpawnRow/EnergyContainer/EnergyLabel
@onready var round_label: Label = $MainLayout/TopBar/RoundContainer/RoundLabel
# ---- 节点引用 ----
@onready var settings_button: Button = $MainLayout/TopBar/SettingsButton
@onready var relic_panel: PanelContainer = $MainLayout/RelicBar/RelicPanel
@onready var relic_scroll: ScrollContainer = $MainLayout/RelicBar/RelicPanel/ScrollContainer
@onready var relic_list: HBoxContainer = $MainLayout/RelicBar/RelicPanel/ScrollContainer/RelicList
@onready var relic_prev_button: Button = $MainLayout/RelicBar/PrevButton
@onready var relic_next_button: Button = $MainLayout/RelicBar/NextButton

@onready var grid_container: GridContainer = $MainLayout/BoardCenter/GridContainer
@onready var board_sprite: Sprite2D = $BoardSprite
@onready var spawn_warrior: TextureButton = $MainLayout/BottomBar/SpawnRow/SpawnButtons/SpawnWarrior
@onready var spawn_mage: TextureButton = $MainLayout/BottomBar/SpawnRow/SpawnButtons/SpawnMage
@onready var spawn_priest: TextureButton = $MainLayout/BottomBar/SpawnRow/SpawnButtons/SpawnPriest
@onready var end_turn_button: Button = $MainLayout/DetailActionBar/EndTurnButton
@onready var item_bar: HBoxContainer = $MainLayout/MiddleBar/ItemBar
@onready var dorm_button: TextureButton = $MainLayout/MiddleBar/DormButton
@onready var shop_button: TextureButton = $MainLayout/MiddleBar/ShopButton
@onready var encyclopedia_button: TextureButton = $MainLayout/MiddleBar/EncyclopediaButton

# ---- 详情面板节点 ----
@onready var detail_panel: PanelContainer = $MainLayout/DetailActionBar/DetailPanel
@onready var name_label: Label = $MainLayout/DetailActionBar/DetailPanel/VBox/NameLabel
@onready var detail_label: Label = $MainLayout/DetailActionBar/DetailPanel/VBox/DetailLabel
@onready var hint_label: Label = $MainLayout/DetailActionBar/DetailPanel/VBox/BottomRow/HintLabel
@onready var sacrifice_button: Button = $MainLayout/DetailActionBar/DetailPanel/VBox/BottomRow/SacrificeButton

# ---- 设置面板节点 ----
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var settings_vbox: VBoxContainer = $SettingsPanel/SettingsVBox
@onready var settings_title: Label = $SettingsPanel/SettingsVBox/SettingsTitle
@onready var language_button: Button = $SettingsPanel/SettingsVBox/LanguageRow/LanguageButton
@onready var language_label: Label = $SettingsPanel/SettingsVBox/LanguageRow/LanguageLabel
@onready var volume_slider: HSlider = $SettingsPanel/SettingsVBox/VolumeRow/VolumeSlider
@onready var volume_label: Label = $SettingsPanel/SettingsVBox/VolumeRow/VolumeLabel
@onready var reset_tutorial_button: Button = $SettingsPanel/SettingsVBox/ResetTutorialButton
@onready var clear_save_button: Button = $SettingsPanel/SettingsVBox/ClearSaveButton
@onready var close_settings_button: Button = $SettingsPanel/SettingsVBox/CloseButton
@onready var reset_confirm_label: Label = $SettingsPanel/ResetConfirmLabel

# ---- 常量 ----
const GRID_SIZE := 6
const CELL_SIZE := 144
const CHAR_SIZE := 140

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
var cell_select_frames: Array = []  # TextureRect 选中框（静态边框）
var cell_highlight_effects: Array = []  # TextureRect 高亮效果（序列帧动画）

# ---- 选中状态 (任务 2.3 拖拽) ----
var selected_index: int = -1   # 当前选中的棋盘格索引, -1=无选中
var _select_tween: Tween = null  # 选中动画tween
var _highlight_frame_index: int = 0  # 当前高亮动画帧索引

# ---- 拖拽状态 ----
var is_dragging: bool = false   # 是否正在拖拽
var drag_index: int = -1        # 拖拽源的格子索引
var drag_preview: Control = null # 拖拽预览节点
var hover_index: int = -1       # 当前悬停的格子索引
var is_hovering_dorm: bool = false  # 是否悬停在宿舍按钮上
var _drag_start_pos: Vector2 = Vector2.ZERO  # 按下时的鼠标位置
var _press_cell_index: int = -1  # 按下的格子索引
var _is_awaiting_drag: bool = false  # 是否等待拖拽判断
const DRAG_THRESHOLD: float = 5.0  # 开始拖拽的移动阈值（像素）
var merge_targets: Array = []   # 可合成的目标格子列表

# ---- 生成动画锁 ----
var is_spawning: bool = false   # 是否正在播放生成动画

# ---- 教学系统 ----
var tutorial_overlay = null

# ---- 宿舍面板 ----
var dorm_panel: PanelContainer = null
var dorm_visible: bool = false
var dorm_backdrop: ColorRect = null  # 宿舍遮罩

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
	print(">>> [GameBoard] _ready 开始")
	# 加载选中效果序列帧
	_load_select_frames()
	_connect_signals()
	_setup_board_ui()
	_setup_dorm_panel()
	_setup_item_slots()
	_setup_character_detail_panel()
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


## 加载选中效果序列帧
func _load_select_frames() -> void:
	SELECT_FRAMES.clear()
	for i in range(16):
		var frame_path := "res://art/effects/fx01/FX1_%02d.png" % i
		if ResourceLoader.exists(frame_path):
			var tex := load(frame_path) as Texture2D
			SELECT_FRAMES.append(tex)
			if i == 0:
				print(">>> [Debug] 加载选中效果序列帧: %s" % frame_path)
	print(">>> [Debug] 加载了 %d 帧选中效果" % SELECT_FRAMES.size())


# ---- 信号连接 ----

func _connect_signals() -> void:
	spawn_warrior.pressed.connect(_on_spawn_pressed.bind(DataModels.Job.WARRIOR))
	spawn_mage.pressed.connect(_on_spawn_pressed.bind(DataModels.Job.MAGE))
	spawn_priest.pressed.connect(_on_spawn_pressed.bind(DataModels.Job.PRIEST))
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	sacrifice_button.pressed.connect(_on_sacrifice_button_pressed)
	dorm_button.pressed.connect(_on_dorm_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	encyclopedia_button.pressed.connect(_on_encyclopedia_pressed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.energy_changed.connect(_on_energy_changed)
	GameManager.round_changed.connect(_on_round_changed)
	GameManager.relics_changed.connect(_on_relics_changed)
	relic_prev_button.pressed.connect(_on_relic_prev_pressed)
	relic_next_button.pressed.connect(_on_relic_next_pressed)
	# 设置面板信号
	language_button.pressed.connect(_on_language_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	reset_tutorial_button.pressed.connect(_on_reset_tutorial_pressed)
	clear_save_button.pressed.connect(_on_clear_save_pressed)
	close_settings_button.pressed.connect(_on_close_settings)
	# 语言切换信号
	LocalizationSystem.language_changed.connect(_on_localization_changed)
	
	# 设置按钮状态反馈
	_setup_button_feedbacks()


## 为所有TextureButton添加hover和press视觉反馈
func _setup_button_feedbacks() -> void:
	var texture_buttons: Array[TextureButton] = [
		spawn_warrior, spawn_mage, spawn_priest,
		dorm_button, shop_button, encyclopedia_button
	]
	for btn in texture_buttons:
		btn.mouse_entered.connect(_on_button_mouse_entered.bind(btn))
		btn.mouse_exited.connect(_on_button_mouse_exited.bind(btn))
		btn.button_down.connect(_on_button_down.bind(btn))
		btn.button_up.connect(_on_button_up.bind(btn))
	
	# 为献祭按钮添加反馈
	sacrifice_button.mouse_entered.connect(_on_button_mouse_entered.bind(sacrifice_button))
	sacrifice_button.mouse_exited.connect(_on_button_mouse_exited.bind(sacrifice_button))
	sacrifice_button.button_down.connect(_on_button_down.bind(sacrifice_button))
	sacrifice_button.button_up.connect(_on_button_up.bind(sacrifice_button))


func _on_button_mouse_entered(btn: BaseButton) -> void:
	btn.modulate = Color(0.9, 0.9, 0.9)


func _on_button_mouse_exited(btn: BaseButton) -> void:
	btn.modulate = Color.WHITE


func _on_button_down(btn: BaseButton) -> void:
	btn.modulate = Color(0.8, 0.8, 0.8)


func _on_button_up(btn: BaseButton) -> void:
	btn.modulate = Color(0.9, 0.9, 0.9) if btn.get_global_rect().has_point(btn.get_viewport().get_mouse_position()) else Color.WHITE


# ---- 棋盘 UI 构建 ----

func _setup_board_ui() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	cell_rects.clear()
	cell_labels.clear()
	cell_panels.clear()
	cell_sprites.clear()
	cell_select_frames.clear()
	cell_highlight_effects.clear()

	grid_container.columns = GRID_SIZE

	for i in range(GRID_SIZE * GRID_SIZE):
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		cell.mouse_filter = Control.MOUSE_FILTER_PASS

		# 格子背景（交替灰度0.5/0.8，透明度0.9/0.7）
		var bg := TextureRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.texture = CELL_BG_TEXTURE
		bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg.modulate = Color(0.5, 0.5, 0.5, 0.9) if (i / GRID_SIZE + i % GRID_SIZE) % 2 == 0 else Color(0.8, 0.8, 0.8, 0.7)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.z_index = 0  # 最底层
		cell.add_child(bg)
		cell_rects.append(bg)

		# 选中框（静态边框，初始隐藏）
		var select_frame := TextureRect.new()
		select_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		select_frame.texture = CELL_SELECT_TEXTURE
		select_frame.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		select_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		select_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		select_frame.visible = false
		select_frame.z_index = 1  # 在格子底之上
		cell.add_child(select_frame)
		cell_select_frames.append(select_frame)
		
		# 高亮效果（序列帧动画，初始隐藏）
		var highlight_effect := TextureRect.new()
		highlight_effect.set_anchors_preset(Control.PRESET_FULL_RECT)
		highlight_effect.texture = null
		highlight_effect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		highlight_effect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		highlight_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		highlight_effect.visible = false
		highlight_effect.scale = Vector2(2.6, 2.6)  # 放大2.6倍
		highlight_effect.pivot_offset = Vector2(CELL_SIZE / 2, CELL_SIZE / 2)  # 以中心为缩放原点
		highlight_effect.z_index = 2  # 在选中框之上
		cell.add_child(highlight_effect)
		cell_highlight_effects.append(highlight_effect)
		
		if i == 0:
			print(">>> [Debug] 选中框纹理: %s" % CELL_SELECT_TEXTURE)

		# 角色精灵图（覆盖整个格子）
		var sprite := TextureRect.new()
		sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.custom_minimum_size = Vector2(CHAR_SIZE, CHAR_SIZE)
		sprite.position = Vector2(0, 0)
		sprite.pivot_offset = Vector2(CELL_SIZE / 2, CELL_SIZE / 2)  # 以中央为缩放中心
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.visible = false
		sprite.z_index = 5  # 正常角色层级，在动画之上
		cell.add_child(sprite)

		# 角色信息标签（隐藏）
		var lbl := Label.new()
		lbl.set_anchors_preset(Control.PRESET_CENTER)
		lbl.anchor_top = 0.6  # 从60%高度开始
		lbl.anchor_bottom = 1.0
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.visible = false  # 隐藏角色文字
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


# ---- 角色详情面板 ----

func _setup_character_detail_panel() -> void:
	# 使用场景中已有的 detail_panel 和 detail_label 节点
	_update_character_detail_panel()


func _update_character_detail_panel() -> void:
	if selected_index >= 0:
		var bd: BoardData = GameManager.board_data
		var ch: DataModels.CharacterData = bd.get_character_at_index(selected_index)
		if ch != null:
			# 显示角色信息
			name_label.text = ch.get_job_name()
			detail_label.text = "Lv.%d  HP: %d/%d  ATK: %d  DEF: %d" % [
				ch.level, ch.hp, ch.max_hp, ch.attack, ch.defense
			]
			var energy := GameManager.calc_sacrifice_energy(ch.level)
			sacrifice_button.text = "献祭\n获得 %d 能量" % energy
			sacrifice_button.visible = true
			return
	
	# 无选中或角色已不存在
	name_label.text = ""
	detail_label.text = LocalizationSystem.get_text("game_board.click_to_view_detail", {})
	sacrifice_button.visible = false


func _on_sacrifice_button_pressed() -> void:
	if selected_index >= 0:
		_sacrifice_character(selected_index)


# ---- 宿舍面板 ----
var _dorm_sort_order: Array = []  # 排序后的宿舍索引

func _setup_dorm_panel() -> void:
	# 遮罩层（先创建，放在最底层）
	dorm_backdrop = ColorRect.new()
	dorm_backdrop.color = Color(0, 0, 0, 0.5)
	dorm_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	dorm_backdrop.visible = false
	dorm_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	dorm_backdrop.gui_input.connect(_on_dorm_backdrop_clicked)
	dorm_backdrop.z_index = 50  # 设置层级
	add_child(dorm_backdrop)
	
	dorm_panel = PanelContainer.new()
	dorm_panel.visible = false
	dorm_panel.set_anchors_preset(Control.PRESET_CENTER)
	dorm_panel.z_index = 51  # 确保在遮罩之上，在角色之上
	# 宿舍尺寸：4列 * 140 + 3间隔 * 10 + padding
	dorm_panel.custom_minimum_size = Vector2(4 * 140 + 3 * 10 + 40, 4 * 140 + 3 * 10 + 100)
	dorm_panel.offset_left = -(dorm_panel.custom_minimum_size.x / 2)
	dorm_panel.offset_top = -(dorm_panel.custom_minimum_size.y / 2)
	dorm_panel.offset_right = dorm_panel.custom_minimum_size.x / 2
	dorm_panel.offset_bottom = dorm_panel.custom_minimum_size.y / 2
	
	# 使用panel.png作为背景
	var panel_texture := preload("res://art/sprites/UI/panels/panel.png")
	var bg := TextureRect.new()
	bg.texture = panel_texture
	bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dorm_panel.add_child(bg)
	
	add_child(dorm_panel)


func _refresh_dorm_panel() -> void:
	# 清空旧内容
	for child in dorm_panel.get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	dorm_panel.add_child(vbox)

	# 标题行
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)
	
	var title := Label.new()
	title.text = LocalizationSystem.get_text("game_board.dorm_title", {"count": GameManager.board_data.dormitory.size(), "max": BoardData.DORM_CAPACITY})
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	
	# 关闭按钮（右上角）
	var close_btn := TextureButton.new()
	close_btn.texture_normal = load("res://art/sprites/UI/items/smallItem/close.png")
	close_btn.custom_minimum_size = Vector2(80, 80)
	close_btn.pressed.connect(_on_dorm_close)
	title_row.add_child(close_btn)

	# 4x4 网格
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)

	# 获取排序后的宿舍索引（按等级从高到低）
	_dorm_sort_order.clear()
	var dorm_data: Array = []
	for i in range(GameManager.board_data.dormitory.size()):
		var ch: DataModels.CharacterData = GameManager.board_data.dormitory[i]
		dorm_data.append({"index": i, "level": ch.level, "job": ch.job})
	
	# 排序：等级高的在前
	dorm_data.sort_custom(func(a, b): 
		if a["level"] != b["level"]:
			return a["level"] > b["level"]  # 等级降序
		return a["job"] < b["job"]  # 同等级按职业ID排序
	)
	
	for data in dorm_data:
		_dorm_sort_order.append(data["index"])

	# 创建格子
	for i in range(BoardData.DORM_CAPACITY):
		var cell := _create_dorm_cell(i)
		grid.add_child(cell)


func _create_dorm_cell(index: int) -> Control:
	# 使用 PanelContainer 作为格子容器
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(140, 140)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 背景层（cell_0）
	var bg := TextureRect.new()
	bg.texture = load("res://art/sprites/UI/items/smallItem/cell_0.png")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(bg)
	
	# 选择框叠加层（cell_1）- 初始隐藏
	var overlay := TextureRect.new()
	overlay.name = "Overlay"
	overlay.texture = load("res://art/sprites/UI/items/smallItem/cell_1.png")
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	container.add_child(overlay)
	
	# 判断是否有角色
	var is_occupied := index < _dorm_sort_order.size()
	if is_occupied:
		var dorm_idx: int = _dorm_sort_order[index]
		var ch: DataModels.CharacterData = GameManager.board_data.dormitory[dorm_idx]
		var is_marked: bool = GameManager.board_data.is_marked_for_removal(dorm_idx)
		
		# 角色居中容器
		var center := CenterContainer.new()
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.add_child(center)
		
		# 角色精灵（使用 TextureRect 便于控制尺寸和居中）
		var sprite := TextureRect.new()
		sprite.texture = _load_character_sprite(ch)
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.custom_minimum_size = Vector2(100, 100)  # 比格子小40像素
		center.add_child(sprite)
		
		# 等级标签
		var lv_label := Label.new()
		lv_label.text = "Lv.%d" % ch.level
		lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		lv_label.add_theme_font_size_override("font_size", 14)
		lv_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
		center.add_child(lv_label)
		
		# 标记高亮 - 叠加层显示
		if is_marked:
			overlay.visible = true
		
		# 点击事件
		container.gui_input.connect(_on_dorm_cell_input.bind(dorm_idx))
	
	return container


func _on_dorm_cell_clicked(dorm_index: int) -> void:
	_show_dorm_character_popup(dorm_index)


func _load_character_sprite(ch: DataModels.CharacterData) -> Texture2D:
	# 根据角色职业和等级加载 sprite
	var folder := ch.get_sprite_folder()
	var sprite_name := ch.get_sprite_path(1, 1)  # 待机动画第1帧
	var path := "res://art/sprites/chars/%s/%s.png" % [folder, sprite_name]
	var tex: Texture2D = load(path)
	if tex == null:
		# 回退到战士默认图
		tex = load("res://art/sprites/chars/char_01/char_010101.png")
	return tex


func _get_dorm_job_color(job_id: int) -> Color:
	match job_id:
		0: return Color(0.85, 0.25, 0.25)  # 战士 - 红色
		1: return Color(0.4, 0.25, 0.85)  # 法师 - 紫色
		2: return Color(0.25, 0.7, 0.25)  # 牧师 - 绿色
		10: return Color(0.9, 0.3, 0.1)  # 狂战士 - 深红
		11: return Color(0.5, 0.5, 0.6)  # 骑士 - 银灰
		20: return Color(0.3, 0.8, 0.9)  # 冰法 - 冰蓝
		21: return Color(0.9, 0.4, 0.1)  # 火法 - 橙红
		30: return Color(0.4, 0.2, 0.5)  # 暗牧 - 暗紫
		31: return Color(0.9, 0.85, 0.5)  # 圣骑士 - 金色
		_: return Color(0.5, 0.5, 0.5)


func _on_dorm_cell_input(event: InputEvent, dorm_index: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_show_dorm_character_popup(dorm_index)


func _show_dorm_character_popup(dorm_index: int) -> void:
	var ch: DataModels.CharacterData = GameManager.board_data.dormitory[dorm_index]
	var content := "等级: %d\n血量: %d/%d\n攻击: %d\n防御: %d" % [
		ch.level, ch.hp, ch.max_hp, ch.attack, ch.defense
	]
	
	var is_marked: bool = GameManager.board_data.is_marked_for_removal(dorm_index)
	var btn_text := "标记移出" if not is_marked else "取消标记"
	
	PopupSystem.show(
		"%s Lv.%d" % [ch.get_job_name(), ch.level],
		content,
		"是否移出角色到棋盘？",
		btn_text,
		"关闭",
		Callable(self, "_on_dorm_popup_confirm").bind(dorm_index),
		Callable(self, "_on_dorm_popup_close")
	)


func _on_dorm_popup_confirm(dorm_index: int) -> void:
	var bd: BoardData = GameManager.board_data
	var is_marked: bool = bd.is_marked_for_removal(dorm_index)
	
	if is_marked:
		bd.unmark_for_removal(dorm_index)
	else:
		# 检查棋盘是否有空间
		if bd.get_empty_board_count() <= bd.marked_for_removal.size():
			TipManager.show_tip("棋盘格已满，无法移出")
			return
		bd.marked_for_removal.append(dorm_index)
	
	_refresh_dorm_panel()


func _on_dorm_popup_close() -> void:
	pass  # 关闭弹窗不做额外操作


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

	# 鼠标按下: 记录按下状态
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# 按下左键：记录位置，等待拖拽判断
				_drag_start_pos = mb.global_position
				_press_cell_index = cell_index
				_is_awaiting_drag = true
				if ch != null:
					# 有角色 → 先选中
					if cell_index != selected_index:
						_set_selected(cell_index)
			else:
				# 释放左键
				if is_dragging:
					# 正在拖拽 → 结束拖拽
					_end_drag(cell_index)
				elif _is_awaiting_drag and _press_cell_index == cell_index:
					# 没有拖拽超过阈值，且在同一个格子抬起 → 执行选中/点击效果
					if ch != null:
						# 有角色 → 显示详情（已选中）
						_update_character_detail_panel()
					else:
						# 空格子 → 移动选中角色到此处
						if selected_index >= 0:
							_handle_cell_action(cell_index)
				# 重置按下状态
				_is_awaiting_drag = false
				_press_cell_index = -1

	# 鼠标移动: 判断是否开始拖拽
	elif event is InputEventMouseMotion:
		if _is_awaiting_drag and not is_dragging:
			# 检查移动距离是否超过阈值
			var drag_dist: float = (event.global_position - _drag_start_pos).length()
			if drag_dist > DRAG_THRESHOLD:
				# 超过阈值，开始拖拽
				if _press_cell_index >= 0:
					var bd_check: BoardData = GameManager.board_data
					var ch_check: DataModels.CharacterData = bd_check.get_character_at_index(_press_cell_index)
					if ch_check != null:
						_start_drag(_press_cell_index, _drag_start_pos)
				_is_awaiting_drag = false
		elif is_dragging:
			# 正在拖拽，更新预览位置
			_update_drag_preview(event.global_position)

	# 右键: 献祭 (任务 2.5)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if ch != null:
				_sacrifice_character(cell_index)


## 设置选中状态
func _set_selected(cell_index: int) -> void:
	selected_index = cell_index
	_refresh_board_display()
	_update_character_detail_panel()


func _handle_cell_action(target_index: int) -> void:
	var bd: BoardData = GameManager.board_data
	var source_ch: DataModels.CharacterData = bd.get_character_at_index(selected_index)
	var target_ch: DataModels.CharacterData = bd.get_character_at_index(target_index)

	if source_ch == null:
		selected_index = -1
		_refresh_board_display()
		_update_character_detail_panel()
		return

	if target_ch == null:
		# 目标为空: 直接移动，无需动画
		_do_swap_or_move(selected_index, target_index)
		# 移动后角色在新位置，保持选中
		selected_index = target_index
		_refresh_board_display()
		_update_character_detail_panel()
		_try_advance_tutorial(2)
	elif target_ch.job == source_ch.job and target_ch.level == source_ch.level:
		# 同职业同等级: 合成 (任务 2.4)
		_merge_at(selected_index, target_index)
		# 合成后清空拖拽状态，防止高亮动画重新显示
		merge_targets.clear()
		hover_index = -1
		# 合成后目标位置的角色保持选中
		selected_index = target_index
		_refresh_board_display()
		_update_character_detail_panel()
	else:
		# 不同角色: 尝试找最近空格移动被换角色，没有空格才交换
		var nearest_empty: int = _find_nearest_empty_cell(target_index)
		if nearest_empty >= 0:
			# 有空格: 被换角色移动到空格，源角色移动到目标位置
			_play_displace_to_empty_animation(selected_index, target_index, nearest_empty)
		else:
			# 没空格: 交换位置
			_play_swap_animation(selected_index, target_index)
		# 操作后目标位置保持选中
		selected_index = target_index
		_refresh_board_display()
		_update_character_detail_panel()


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
		_update_character_detail_panel()
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
		_update_character_detail_panel()
		_try_advance_tutorial(2)
		return
	b_end_pos = a_pos.global_position

	# 角色B现在在src_index，先设置到B原来的位置（起点）
	var b_sprite: Control = cell_sprites[src_index]
	if b_sprite == null or not is_instance_valid(b_sprite):
		selected_index = -1
		_update_character_detail_panel()
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

	# 角色到达目标后播放"落地"动效：缩小到0.95再还原（丝滑）
	_play_land_animation(src_index)

	selected_index = -1
	_try_advance_tutorial(2)


## 查找最近空格（排除指定单元格）
func _find_nearest_empty_cell(exclude_index: int) -> int:
	var bd: BoardData = GameManager.board_data
	var tgt_pos: Vector2i = BoardData.index_to_pos(exclude_index)

	var nearest: int = -1
	var nearest_dist: float = INF

	for i in range(BoardData.BOARD_SLOTS):
		if i == exclude_index:
			continue
		if bd.get_character_at_index(i) == null:
			var dist: float = (BoardData.index_to_pos(i) - tgt_pos).length()
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = i

	return nearest


## 被换角色移动到空格动画
func _play_displace_to_empty_animation(src_index: int, tgt_index: int, empty_index: int) -> void:
	# 隐藏拖拽预览
	if drag_preview != null:
		drag_preview.queue_free()
		drag_preview = null

	# 数据层: src -> tgt, tgt -> empty
	_do_swap_and_displace(src_index, tgt_index, empty_index)

	# 刷新显示
	_refresh_board_display()


## 执行交换并移动到空格（数据层）
func _do_swap_and_displace(src_index: int, tgt_index: int, empty_index: int) -> void:
	var bd: BoardData = GameManager.board_data
	var src_ch: DataModels.CharacterData = bd.get_character_at_index(src_index)
	var tgt_ch: DataModels.CharacterData = bd.get_character_at_index(tgt_index)

	if src_ch == null or tgt_ch == null:
		return

	# tgt角色移动到empty
	var tgt_pos: Vector2i = BoardData.index_to_pos(tgt_index)
	var empty_pos: Vector2i = BoardData.index_to_pos(empty_index)
	bd.swap_positions(tgt_pos, empty_pos)

	# src角色移动到tgt
	var src_pos: Vector2i = BoardData.index_to_pos(src_index)
	bd.swap_positions(src_pos, tgt_pos)

	print(">>> [GameBoard] 置换: 格%d→格%d, 格%d→格%d(空格)" % [tgt_index, empty_index, src_index, tgt_index])


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


## 落地动效：缩小到0.95再丝滑还原
func _play_land_animation(cell_index: int) -> void:
	if cell_index < 0 or cell_index >= cell_sprites.size():
		return
	var sprite: Control = cell_sprites[cell_index]
	if sprite == null or not is_instance_valid(sprite):
		return

	# 重置scale（防止残留）
	sprite.scale = Vector2(1.0, 1.0)

	# 使用弹性缓动：1.0 → 0.95 → 1.0
	var tween := create_tween()
	tween.set_parallel(false)
	# 从当前(1.0)缩小到0.95，再弹回1.0
	tween.tween_property(sprite, "scale", Vector2(0.91, 0.91), 0.01)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.6)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


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
	_update_character_detail_panel()
	# Tutorial: advance after sacrifice (step 3 = details/sacrifice/encyclopedia)
	_try_advance_tutorial(3)


# ---- 拖拽系统 (任务 2.3) ----

func _start_drag(cell_index: int, mouse_pos: Vector2) -> void:
	is_dragging = true
	drag_index = cell_index
	selected_index = cell_index

	# 创建拖拽预览（添加到场景树根节点以确保最上层显示）
	drag_preview = _create_drag_preview(cell_index)
	get_tree().root.add_child(drag_preview)
	drag_preview.global_position = mouse_pos - Vector2(CELL_SIZE / 2, CELL_SIZE / 2)

	# 隐藏原始格子
	cell_panels[cell_index].modulate.a = 0.3

	# 提升拖拽角色的层级到最高
	cell_sprites[cell_index].z_index = 20

	# 找到所有可合成的目标格子
	_find_merge_targets(cell_index)

	# 显示所有可合成目标的高亮动画（透明度0.5）
	_update_merge_highlights()

	print(">>> [GameBoard] 开始拖拽格 %d，可合成目标: %s" % [cell_index, merge_targets])


func _create_drag_preview(cell_index: int, with_outline: bool = false) -> Control:
	var bd: BoardData = GameManager.board_data
	var ch: DataModels.CharacterData = bd.get_character_at_index(cell_index)

	# 根节点只用于定位，不显示背景
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 让事件穿透到下层
	preview.z_index = 100  # 最上层
	preview.z_as_relative = false  # 使用全局z_index

	# 精灵图
	var sprite_folder: String = ch.get_sprite_folder()
	var sprite_name: String = ch.get_sprite_path(1, 1)
	var sprite_path: String = "res://art/sprites/chars/" + sprite_folder + "/" + sprite_name + ".png"
	var tex := load(sprite_path) if ResourceLoader.exists(sprite_path) else null
	if tex:
		var sprite := TextureRect.new()
		sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.texture = tex
		sprite.custom_minimum_size = Vector2(CHAR_SIZE, CHAR_SIZE)
		sprite.z_index = 0  # 相对于preview的层级

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

	# 更新高亮效果（拖拽悬停在可合成目标上时显示）
	_update_merge_highlights()

	# 临时高亮目标格子 & 更新拖拽预览Outline
	var is_over_mergeable: bool = false
	if hover_index >= 0 and hover_index != drag_index:
		var bd: BoardData = GameManager.board_data
		var target_ch: DataModels.CharacterData = bd.get_character_at_index(hover_index)
		var sel_ch: DataModels.CharacterData = bd.get_character_at_index(drag_index)

		if target_ch == null:
			# 移动到空格子
			# cell_rects[hover_index].color = COLOR_SELECTED
			pass
		elif target_ch.job == sel_ch.job and target_ch.level == sel_ch.level:
			# 可合成
			# cell_rects[hover_index].color = COLOR_MERGE_HINT
			is_over_mergeable = true
		else:
			# 交换
			# cell_rects[hover_index].color = Color("#888888")
			pass

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

	# 恢复原始格子透明度和层级
	if drag_index >= 0 and drag_index < cell_panels.size():
		cell_panels[drag_index].modulate.a = 1.0
		cell_sprites[drag_index].z_index = 5  # 恢复正常层级

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
		merge_targets.clear()
		return

	# 执行放置操作: 使用悬停的格子作为目标
	if hover_index >= 0 and hover_index != drag_index:
		selected_index = drag_index
		_handle_cell_action(hover_index)
	elif hover_index == drag_index or hover_index < 0:
		# 释放到原格子或无效区域: 取消选中
		selected_index = -1
		_refresh_board_display()
		_update_character_detail_panel()

	is_dragging = false
	drag_index = -1
	hover_index = -1
	is_hovering_dorm = false
	merge_targets.clear()
	# 隐藏所有高亮效果
	_update_merge_highlights()
	# 恢复宿舍按钮颜色
	dorm_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	print(">>> [GameBoard] 结束拖拽")


# ---- 棋盘显示刷新 ----

func _refresh_board_display() -> void:
	var bd: BoardData = GameManager.board_data

	# 只在非拖拽状态下停止高亮动画和隐藏高亮
	if not is_dragging:
		if _select_tween and _select_tween.is_valid():
			_select_tween.kill()
			_select_tween = null

		for i in range(BoardData.BOARD_SLOTS):
			cell_highlight_effects[i].visible = false

	for i in range(BoardData.BOARD_SLOTS):
		# 更新选中框显示（静态边框）
		var is_selected: bool = (i == selected_index)
		cell_select_frames[i].visible = is_selected

		var ch: DataModels.CharacterData = bd.get_character_at_index(i)
		if ch != null:
			# 角色格子：背景保持空格子颜色
			# 屏蔽颜色变化: cell_rects[i].color = empty_color

			# 加载角色精灵图
			var sprite_folder: String = ch.get_sprite_folder()
			var sprite_name: String = ch.get_sprite_path(1, 1)  # 待机动画第1帧
			var sprite_path: String = "res://art/sprites/chars/" + sprite_folder + "/" + sprite_name + ".png"
			var tex_exists: bool = ResourceLoader.exists(sprite_path)
			var tex := load(sprite_path) if tex_exists else null
			cell_sprites[i].texture = tex
			cell_sprites[i].visible = (tex != null)
			if tex == null:
				print(">>> [Debug] 精灵图加载失败: %s (职业=%d, 等级=%d, 文件存在=%s)" % [sprite_path, ch.job, ch.level, tex_exists])

			cell_labels[i].text = "%s\nLv.%d\n%d/%d" % [
				ch.get_job_name(), ch.level, ch.hp, ch.max_hp
			]
		else:
			# 屏蔽所有格子颜色变化
			# cell_rects[i].color = empty_color
			cell_labels[i].text = ""
			cell_sprites[i].texture = null
			cell_sprites[i].visible = false

	# 更新高亮效果（拖拽时动态显示）
	_update_merge_highlights()


## 更新可合成高亮效果（拖拽时显示）
func _update_merge_highlights() -> void:
	# 如果不在拖拽状态，隐藏所有高亮
	if not is_dragging:
		for i in range(BoardData.BOARD_SLOTS):
			cell_highlight_effects[i].visible = false
		return

	# 显示所有可合成目标的高亮，透明度0.5，白色
	for target_index in merge_targets:
		cell_highlight_effects[target_index].visible = true
		cell_highlight_effects[target_index].texture = SELECT_FRAMES[_highlight_frame_index] if not SELECT_FRAMES.is_empty() else null
		cell_highlight_effects[target_index].modulate = Color(1, 1, 1, 0.5)

	# 如果悬停在某个可合成目标上，该目标透明度改为1，颜色偏红
	if hover_index >= 0 and merge_targets.has(hover_index):
		cell_highlight_effects[hover_index].modulate = Color(1, 0.6, 0.6, 1.0)

	# 隐藏不在目标列表中的高亮
	for i in range(BoardData.BOARD_SLOTS):
		if not merge_targets.has(i):
			cell_highlight_effects[i].visible = false

	# 启动动画（如果未运行）
	if not merge_targets.is_empty() and not SELECT_FRAMES.is_empty():
		_start_highlight_animation()


## 查找拖拽角色可合成的目标格子
func _find_merge_targets(drag_source_index: int) -> void:
	merge_targets.clear()
	var bd: BoardData = GameManager.board_data
	var source_ch: DataModels.CharacterData = bd.get_character_at_index(drag_source_index)

	if source_ch == null:
		return

	# 遍历所有格子，找到相同职业、相同等级的角色
	for i in range(BoardData.BOARD_SLOTS):
		if i == drag_source_index:
			continue

		var target_ch: DataModels.CharacterData = bd.get_character_at_index(i)
		if target_ch != null and target_ch.job == source_ch.job and target_ch.level == source_ch.level:
			merge_targets.append(i)

	print(">>> [Debug] 可合成目标格子: %s" % merge_targets)


## 查找可合成的格子
func _find_merge_candidates() -> Array:
	var bd: BoardData = GameManager.board_data
	var candidates: Array = []

	for i in range(BoardData.BOARD_SLOTS):
		var ch: DataModels.CharacterData = bd.get_character_at_index(i)
		if ch == null:
			continue

		# 检查相邻格子是否有相同角色
		var neighbors := _get_neighbors(i)
		for neighbor_index in neighbors:
			var neighbor_ch: DataModels.CharacterData = bd.get_character_at_index(neighbor_index)
			if neighbor_ch != null and neighbor_ch.job == ch.job and neighbor_ch.level == ch.level:
				# 找到可合成的格子
				if not candidates.has(i):
					candidates.append(i)
				if not candidates.has(neighbor_index):
					candidates.append(neighbor_index)

	return candidates


## 获取相邻格子索引
func _get_neighbors(index: int) -> Array:
	var neighbors: Array = []
	var pos := BoardData.index_to_pos(index)
	var x := pos.x
	var y := pos.y

	# 上
	if y > 0:
		neighbors.append(BoardData.pos_to_index(Vector2i(x, y - 1)))
	# 下
	if y < BoardData.GRID_SIZE - 1:
		neighbors.append(BoardData.pos_to_index(Vector2i(x, y + 1)))
	# 左
	if x > 0:
		neighbors.append(BoardData.pos_to_index(Vector2i(x - 1, y)))
	# 右
	if x < BoardData.GRID_SIZE - 1:
		neighbors.append(BoardData.pos_to_index(Vector2i(x + 1, y)))

	return neighbors


## 启动高亮序列帧动画（持续运行，独立于格子列表）
func _start_highlight_animation() -> void:
	if SELECT_FRAMES.is_empty():
		print(">>> [Warning] 序列帧纹理未加载！")
		return

	# 如果动画已经在运行，不重复创建
	if _select_tween and _select_tween.is_valid():
		return

	print(">>> [Debug] 启动高亮动画（持续运行模式）")

	# 创建序列帧动画：循环切换帧索引
	_select_tween = create_tween()
	_select_tween.set_loops()

	# 每帧显示 0.05 秒，循环播放
	for i in range(SELECT_FRAMES.size()):
		_select_tween.tween_callback(_advance_highlight_frame)
		_select_tween.tween_interval(0.05)


## 推进高亮帧并更新所有可见的高亮效果
func _advance_highlight_frame() -> void:
	_highlight_frame_index = (_highlight_frame_index + 1) % SELECT_FRAMES.size()

	# 更新所有可见高亮效果的纹理
	var frame_texture: Texture2D = SELECT_FRAMES[_highlight_frame_index]
	for i in range(BoardData.BOARD_SLOTS):
		if cell_highlight_effects[i].visible:
			cell_highlight_effects[i].texture = frame_texture


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
	# 动画进行中，禁用连续点击
	if is_spawning:
		return
	
	# 检查棋盘是否已满
	if GameManager.board_data.is_board_full():
		print(">>> [GameBoard] 生成失败: 棋盘已满")
		TipManager.show_tip("棋盘格已满")
		return

	if not GameManager.spend_energy(1):
		print(">>> [GameBoard] 生成失败: 能量不足")
		TipManager.show_tip("能量不足")
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

	# 获取生成按钮位置和目标格子位置
	var spawn_btn: BaseButton
	match job:
		DataModels.Job.WARRIOR: spawn_btn = spawn_warrior
		DataModels.Job.MAGE: spawn_btn = spawn_mage
		DataModels.Job.PRIEST: spawn_btn = spawn_priest
		_: spawn_btn = spawn_warrior

	var start_pos: Vector2 = spawn_btn.global_position + Vector2(spawn_btn.size.x / 2, spawn_btn.size.y / 2)
	var target_index: int = pos.y * GRID_SIZE + pos.x
	var target_cell: Control = cell_panels[target_index]
	var end_pos: Vector2 = target_cell.global_position + Vector2(CELL_SIZE / 2, CELL_SIZE / 2)

	# 播放生成动画
	_play_spawn_animation(ch, start_pos, end_pos, target_index)

	# Tutorial: advance after spawn (step 0 = first spawn, step 1 = second spawn/merge)
	_try_advance_tutorial(0)


## 生成动画：从按钮位置飞到目标格子
func _play_spawn_animation(ch: DataModels.CharacterData, start_pos: Vector2, end_pos: Vector2, target_index: int) -> void:
	is_spawning = true

	# 先给目标格子添加"即将放置"标记（边框闪烁）
	_play_spawn_cell_hint(target_index)

	# 创建独立的动画精灵（添加到根节点，不受格子约束）
	var anim_sprite := TextureRect.new()
	anim_sprite.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	anim_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	anim_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	anim_sprite.z_index = 100

	# 加载精灵图
	var sprite_folder: String = ch.get_sprite_folder()
	var sprite_name: String = ch.get_sprite_path(1, 1)
	var sprite_path: String = "res://art/sprites/chars/" + sprite_folder + "/" + sprite_name + ".png"
	if ResourceLoader.exists(sprite_path):
		anim_sprite.texture = load(sprite_path)

	add_child(anim_sprite)

	# 使用世界坐标设置初始位置（让精灵中央对准目标）
	anim_sprite.global_position = start_pos - Vector2(CELL_SIZE / 2, CELL_SIZE / 2)
	anim_sprite.scale = Vector2(0.5, 0.5)

	# 动画：从小到大、从按钮位置飞到目标格子（终点也是左上角对齐）
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(anim_sprite, "global_position", end_pos - Vector2(CELL_SIZE / 2, CELL_SIZE / 2), 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(anim_sprite, "scale", Vector2(1.0, 1.0), 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tween.finished

	# 清理动画精灵
	anim_sprite.queue_free()

	# 清理目标格子标记
	_clear_spawn_cell_hint(target_index)

	# 刷新棋盘显示（此时才显示角色）
	_refresh_board_display()

	# 角色到达目标后播放"落地"动效：缩小到0.95再还原（丝滑）
	_play_land_animation(target_index)

	_try_advance_tutorial(1)

	is_spawning = false


## 生成前格子闪烁提示
var _spawn_hint_panel: PanelContainer = null
var _spawn_hint_tween: Tween = null

func _play_spawn_cell_hint(target_index: int) -> void:
	if target_index < 0 or target_index >= cell_panels.size():
		return
	var cell: Control = cell_panels[target_index]
	if cell == null:
		return

	# 创建高亮面板
	_spawn_hint_panel = PanelContainer.new()
	_spawn_hint_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spawn_hint_panel.z_index = 50

	# 创建边框样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(1.0, 0.85, 0.0, 0.8)  # 金色边框
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	_spawn_hint_panel.add_theme_stylebox_override("panel", style)

	cell.add_child(_spawn_hint_panel)

	# 边框闪烁动画
	_spawn_hint_tween = create_tween()
	_spawn_hint_tween.set_parallel(true)
	_spawn_hint_tween.tween_property(_spawn_hint_panel, "modulate:a", 0.4, 0.2)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).from(1.0)
	_spawn_hint_tween.tween_property(_spawn_hint_panel, "modulate:a", 1.0, 0.2)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_spawn_hint_tween.set_loops(3)  # 闪烁3次


func _clear_spawn_cell_hint(_target_index: int) -> void:
	if _spawn_hint_tween != null and _spawn_hint_tween.is_valid():
		_spawn_hint_tween.kill()
		_spawn_hint_tween = null
	if _spawn_hint_panel != null and is_instance_valid(_spawn_hint_panel):
		_spawn_hint_panel.queue_free()
		_spawn_hint_panel = null


# ---- 宿舍操作 ----

func _on_dorm_pressed() -> void:
	dorm_visible = !dorm_visible
	dorm_panel.visible = dorm_visible
	dorm_backdrop.visible = dorm_visible
	if dorm_visible:
		_refresh_dorm_panel()


func _on_dorm_take_pressed(dorm_index: int) -> void:
	if GameManager.board_data.is_board_full():
		print(">>> [GameBoard] 取出失败: 棋盘已满")
		TipManager.show_tip("棋盘格已满")
		return
	var ch: DataModels.CharacterData = GameManager.board_data.take_from_dormitory(dorm_index)
	if ch == null:
		return
	var pos: Vector2i = GameManager.board_data.place_character_first_empty(ch)
	print(">>> [GameBoard] 从宿舍取出 %s Lv.%d 到 (%d,%d)" % [ch.get_job_name(), ch.level, pos.x, pos.y])
	_refresh_dorm_panel()
	_refresh_board_display()


func _on_dorm_backdrop_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_on_dorm_close()


func _on_dorm_close() -> void:
	var bd: BoardData = GameManager.board_data
	
	# 执行所有标记移出的角色
	if bd.marked_for_removal.size() > 0:
		if not bd.can_remove_marked():
			TipManager.show_tip("棋盘格已满，无法移出")
			bd.marked_for_removal.clear()
			_hide_dorm_ui()
		else:
			# 获取宿舍按钮中心位置作为动画起点（必须在隐藏面板之前获取）
			var dorm_pos: Vector2 = dorm_button.global_position + Vector2(dorm_button.size.x / 2, dorm_button.size.y / 2)
			
			# 执行数据操作，获取每个角色被放置到的棋盘索引
			var moved_data: Array = bd.execute_removal()
			
			if moved_data.size() > 0:
				TipManager.show_tip("已移出 %d 个角色到棋盘" % moved_data.size())
				# 先隐藏宿舍UI
				_hide_dorm_ui()
				# 播放动画
				_play_dorm_to_board_animation(moved_data, dorm_pos)
				return
	
	_hide_dorm_ui()


func _hide_dorm_ui() -> void:
	dorm_visible = false
	dorm_panel.visible = false
	dorm_backdrop.visible = false


func _play_dorm_to_board_animation(moved_data: Array, start_pos: Vector2) -> void:
	# 先刷新棋盘显示，加载角色的 texture
	_refresh_board_display()
	
	# 隐藏目标格子上的角色显示（等动画结束再显示）
	var hidden_indices: Array = []
	for data in moved_data:
		var board_idx: int = data["board_index"]
		if board_idx >= 0 and board_idx < cell_sprites.size():
			hidden_indices.append(board_idx)
			cell_sprites[board_idx].visible = false
	
	# 为每个角色播放从宿舍飞到棋盘的动画
	for data in moved_data:
		var ch: DataModels.CharacterData = data["char"]
		var board_idx: int = data["board_index"]
		
		if board_idx < 0 or board_idx >= cell_panels.size():
			continue
		
		var target_cell: Control = cell_panels[board_idx]
		var end_pos: Vector2 = target_cell.global_position + Vector2(CELL_SIZE / 2, CELL_SIZE / 2)
		
		# 创建动画精灵
		var anim_sprite := TextureRect.new()
		anim_sprite.custom_minimum_size = Vector2(CHAR_SIZE, CHAR_SIZE)
		anim_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		anim_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		anim_sprite.z_index = 200
		
		# 加载精灵图
		var sprite_folder: String = ch.get_sprite_folder()
		var sprite_name: String = ch.get_sprite_path(1, 1)
		var sprite_path: String = "res://art/sprites/chars/" + sprite_folder + "/" + sprite_name + ".png"
		if ResourceLoader.exists(sprite_path):
			anim_sprite.texture = load(sprite_path)
		
		add_child(anim_sprite)
		anim_sprite.global_position = start_pos - Vector2(CELL_SIZE / 2, CELL_SIZE / 2)
		anim_sprite.scale = Vector2(0.8, 0.8)
		
		# 飞行动画
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(anim_sprite, "global_position", end_pos - Vector2(CELL_SIZE / 2, CELL_SIZE / 2), 0.4)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(anim_sprite, "scale", Vector2(1.0, 1.0), 0.4)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		# 动画结束后恢复格子显示并播放落地动画
		tween.finished.connect(func():
			anim_sprite.queue_free()
			cell_sprites[board_idx].visible = true
			_play_land_animation(board_idx)
		)


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
	
	# 重置拖拽状态，确保高亮被隐藏
	is_dragging = false
	drag_index = -1
	merge_targets.clear()
	
	selected_index = -1
	_refresh_board_display()
	_update_character_detail_panel()


# ---- 遗物栏操作（常驻显示）----

func _refresh_relic_panel() -> void:
	# 清空旧内容
	for child in relic_list.get_children():
		child.queue_free()
	
	# 显示所有遗物
	for i in range(GameManager.relics.size()):
		var relic: DataModels.ItemData = GameManager.relics[i]
		var relic_item: Button = Button.new()
		relic_item.custom_minimum_size = Vector2(80, 60)
		relic_item.tooltip_text = "%s\n%s" % [relic.name, relic.description]
		relic_item.pressed.connect(_on_relic_pressed.bind(relic))
		
		var vbox := VBoxContainer.new()
		relic_item.add_child(vbox)

		var name_lbl := Label.new()
		name_lbl.text = relic.name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 20)
		vbox.add_child(name_lbl)

		var count_lbl := Label.new()
		count_lbl.text = LocalizationSystem.get_text("game_board.relic_count", {"count": relic.stack_count})
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.add_theme_font_size_override("font_size", 18)
		vbox.add_child(count_lbl)

		relic_list.add_child(relic_item)
	
	# 更新翻页按钮状态：遗物未满时半透明禁用
	await get_tree().process_frame  # 等待布局更新
	var need_scroll: bool = relic_list.size.x > relic_scroll.size.x
	relic_prev_button.disabled = not need_scroll
	relic_next_button.disabled = not need_scroll
	relic_prev_button.modulate = Color(1, 1, 1, 0.3) if not need_scroll else Color.WHITE
	relic_next_button.modulate = Color(1, 1, 1, 0.3) if not need_scroll else Color.WHITE


func _on_relic_pressed(relic: DataModels.ItemData) -> void:
	# 按下时显示详细信息（触屏支持）
	print(">>> [GameBoard] 遗物详情: %s - %s" % [relic.name, relic.description])


func _on_relic_prev_pressed() -> void:
	# 滚动到上一页
	var scroll_width: int = int(relic_scroll.size.x)
	relic_scroll.scroll_horizontal -= scroll_width


func _on_relic_next_pressed() -> void:
	# 滚动到下一页
	var scroll_width: int = int(relic_scroll.size.x)
	relic_scroll.scroll_horizontal += scroll_width


func _on_relics_changed() -> void:
	print(">>> [GameBoard] 遗物改变，刷新遗物面板，当前遗物数量: %d" % GameManager.relics.size())
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
				_update_character_detail_panel()


# ---- 按钮回调 ----

func _on_end_turn_pressed() -> void:
	selected_index = -1
	_update_character_detail_panel()
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
	# 使用弹窗方式打开商店（不切换场景）
	var shop_scene := preload("res://scenes/shop_scene.tscn").instantiate()
	add_child(shop_scene)


func _on_encyclopedia_pressed() -> void:
	print(">>> [GameBoard] 打开图鉴")
	_try_advance_tutorial(3)
	var encyclopedia := preload("res://scenes/encyclopedia_scene.tscn").instantiate()
	add_child(encyclopedia)


func _on_item_pressed() -> void:
	# 道具栏弹窗 (备用)
	_show_item_panel()


# ---- 道具栏格子 (3个固定格子) ----

func _setup_item_slots() -> void:
	item_slot_nodes.clear()
	item_slot_labels.clear()
	item_slot_overlays.clear()

	# 加载格子背景纹理
	var cell_texture := preload("res://art/sprites/UI/items/smallItem/cell_0.png")

	for i in range(ITEM_SLOT_COUNT):
		var slot: Control = item_bar.get_child(i)
		item_slot_nodes.append(slot)
		
		# 移除PanelContainer的默认样式（如果有）
		if slot is PanelContainer:
			var transparent_style := StyleBoxEmpty.new()
			slot.add_theme_stylebox_override("panel", transparent_style)

		# 清除旧内容
		for child in slot.get_children():
			child.queue_free()

		# 背景纹理（使用cell_0.png）
		var bg := TextureRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.texture = cell_texture
		bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg.modulate = Color(0.8, 0.8, 0.8, 0.9)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 让点击穿透到slot
		slot.add_child(bg)

		# 标签显示道具名
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_preset(Control.PRESET_CENTER)
		lbl.add_theme_font_size_override("font_size", 16)
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
	name_lbl.add_theme_font_size_override("font_size", 32)
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
		cursor_bg.set_anchors_preset(Control.PRESET_CENTER)
		cursor_bg.color = Color(1.0, 0.8, 0.0, 0.15)
		target_cursor.add_child(cursor_bg)

		var cursor_lbl := Label.new()
		cursor_lbl.text = LocalizationSystem.get_text("items.select_target")
		cursor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cursor_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cursor_lbl.set_anchors_preset(Control.PRESET_CENTER)
		cursor_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		cursor_lbl.add_theme_font_size_override("font_size", 28)
		target_cursor.add_child(cursor_lbl)

	add_child(target_cursor)
	target_cursor.set_anchors_preset(Control.PRESET_CENTER)


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
	item_panel.z_index = 50  # 设置层级，确保在角色之上
	
	# 添加 panel.png 背景
	var panel_texture := preload("res://art/sprites/UI/panels/panel.png")
	var bg := TextureRect.new()
	bg.texture = panel_texture
	bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_panel.add_child(bg)
	
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
	# 添加 panel.png 背景（如果还没有）
	if settings_panel.get_child_count() == 0 or not settings_panel.get_child(0).name == "PanelBg":
		var panel_texture := preload("res://art/sprites/UI/panels/panel.png")
		var bg := TextureRect.new()
		bg.name = "PanelBg"
		bg.texture = panel_texture
		bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		settings_panel.add_child(bg)
		settings_panel.move_child(bg, 0)  # 移到最底层
	
	# 设置层级，确保在角色之上
	settings_panel.z_index = 50
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
	clear_save_button.text = LocalizationSystem.get_text("settings.clear_save")
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
	dorm_button.text = LocalizationSystem.get_text("game_board.dorm")
	shop_button.text = LocalizationSystem.get_text("game_board.shop")
	encyclopedia_button.text = LocalizationSystem.get_text("game_board.encyclopedia")


func _on_volume_changed(value: float) -> void:
	_save_volume(value)


func _on_reset_tutorial_pressed() -> void:
	GameManager.reset_tutorial()
	_reset_confirm_label_visible(true, "settings.reset_confirm")


func _on_clear_save_pressed() -> void:
	# 清空存档（保留图鉴）
	SaveSystem.clear_game_save()
	# 重置游戏状态
	GameManager.reset_game()
	# 刷新UI
	_refresh_board_display()
	_on_gold_changed(GameManager.gold)
	_on_energy_changed(GameManager.energy)
	_on_round_changed(GameManager.current_round)
	# 显示提示
	_reset_confirm_label_visible(true, "settings.clear_save_confirm")
	print(">>> [GameBoard] 存档已清空")


func _reset_confirm_label_visible(visible: bool, text_key: String = "") -> void:
	reset_confirm_label.visible = visible
	if visible and text_key != "":
		reset_confirm_label.text = LocalizationSystem.get_text(text_key)


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
