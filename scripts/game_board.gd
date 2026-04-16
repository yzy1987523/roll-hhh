extends Control

## 备战阶段主界面
## 任务 2.1-2.5: UI + 生成 + 拖拽 + 合成 + 献祭

# ---- 资源预加载 ----
const CELL_BG_TEXTURE := preload("res://art/sprites/UI/items/smallItem/cell_0.png")
const CELL_SELECT_TEXTURE := preload("res://art/sprites/UI/items/smallItem/cell_1.png")
# 金币图标（用于出售按钮）
const JINBI_ICON := preload("res://art/sprites/UI/icon/jinbi.png")
const ENERGY_ICON := preload("res://art/sprites/UI/items/smallItem/engery.png")
# 体力图标（用于消耗体力球粒子特效）
const POWER_ICON := preload("res://art/sprites/UI/icon/power.png")
# 锁定状态纹理（运行时加载）
var CELL_LOCKED_EVEN_TEXTURE: Texture2D
var CELL_LOCKED_ODD_TEXTURE: Texture2D
var CELL_DUSTY_TEXTURE: Texture2D

# 宿舍场景
const DormScene = preload("res://scenes/dorm_scene.tscn")
# 背包场景
const BackpackScene = preload("res://scenes/backpack_scene.tscn")

# 选中效果序列帧 (fx01)
var SELECT_FRAMES: Array[Texture2D] = []

# 生成器特效序列帧 (fx02)
var PRODUCER_FRAMES: Array[Texture2D] = []
var _producer_fx_frame: int = 0
var _producer_fx_accum: float = 0.0  # 时间累加器

# 飘字系统：跟踪上次资源值用于计算变化量
var _last_gold: int = 0
var _last_energy: int = 0
var _last_diamond: int = 0

# ---- 节点引用 ----
# ---- 节点引用 ----
@onready var settings_button: Button = $MainLayout/TopBar/SettingsButton
var relic_panel: PanelContainer
var relic_scroll: ScrollContainer
var relic_list: HBoxContainer
var relic_prev_button: Button
var relic_next_button: Button

@onready var grid_container: GridContainer = $MainLayout/BoardCenter/GridContainer
var spawn_warrior: TextureButton
var spawn_mage: TextureButton
var spawn_priest: TextureButton
var end_turn_button: TextureButton
@onready var build_button: TextureButton = $MainLayout/DetailActionBar/BuildButton
var item_bar: HBoxContainer
var dorm_button: TextureButton
var shop_button: TextureButton
var encyclopedia_button: TextureButton
var bottom_hud_container: Control

# ---- 资源显示节点 (TopBar/ResourceDisplay) ----
@onready var energy_label: Label = $MainLayout/TopBar/ResourceDisplay/EnergyContainer/EnergyRow/EnergyLabel
@onready var energy_timer: Label = $MainLayout/TopBar/ResourceDisplay/EnergyContainer/EnergyTimer
@onready var energy_buy_btn: Button = $MainLayout/TopBar/ResourceDisplay/EnergyContainer/EnergyBuyBtn
@onready var gold_label: Label = $MainLayout/TopBar/ResourceDisplay/GoldContainer/GoldRow/GoldLabel
@onready var gold_buy_btn: Button = $MainLayout/TopBar/ResourceDisplay/GoldContainer/GoldBuyBtn
@onready var diamond_label: Label = $MainLayout/TopBar/ResourceDisplay/DiamondContainer/DiamondRow/DiamondLabel
@onready var diamond_buy_btn: Button = $MainLayout/TopBar/ResourceDisplay/DiamondContainer/DiamondBuyBtn

# ---- 详情面板节点 ----
@onready var detail_panel: PanelContainer = $MainLayout/DetailActionBar/DetailPanel
@onready var name_label: Label = $MainLayout/DetailActionBar/DetailPanel/MainHBox/LeftContent/NameLabel
@onready var detail_label: Label = $MainLayout/DetailActionBar/DetailPanel/MainHBox/LeftContent/DetailLabel
@onready var hint_label: Label = $MainLayout/DetailActionBar/DetailPanel/MainHBox/LeftContent/HintLabel
@onready var sacrifice_button: TextureButton = $MainLayout/DetailActionBar/DetailPanel/MainHBox/SacrificeButton
@onready var sacrifice_icon: TextureRect = $MainLayout/DetailActionBar/DetailPanel/MainHBox/SacrificeButton/VBoxContainer/HBoxContainer/EnergyIcon
@onready var sacrifice_label: Label = $MainLayout/DetailActionBar/DetailPanel/MainHBox/SacrificeButton/VBoxContainer/HBoxContainer/Label

# ---- 冷却加速按钮（动态创建） ----
var _speedup_btn: TextureButton = null
var _speedup_label: Label = null
var _speedup_cost_label: Label = null
var _speedup_timer: Timer = null

# ---- 设置面板节点 ----
@onready var settings_backdrop: ColorRect = $SettingsBackdrop
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var settings_vbox: VBoxContainer = $SettingsPanel/SettingsMargin/SettingsVBox
@onready var settings_title: Label = $SettingsPanel/SettingsMargin/SettingsVBox/TitleBarMargin/TitleBar/SettingsTitle
@onready var language_button: Button = $SettingsPanel/SettingsMargin/SettingsVBox/LanguageButton2

@onready var reset_tutorial_button: Button = $SettingsPanel/SettingsMargin/SettingsVBox/ResetTutorialButton
@onready var clear_save_button: Button = $SettingsPanel/SettingsMargin/SettingsVBox/ClearSaveButton
@onready var close_settings_button: TextureButton = $SettingsPanel/SettingsMargin/SettingsVBox/TitleBarMargin/TitleBar/CloseButton

# ---- 常量 ----
const GRID_COLS := 7
const GRID_ROWS := 9
const CELL_SIZE := 133
const CHAR_SIZE := 129

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
var cell_panels: Array = []    # PanelContainer 格子容器
var cell_sprites: Array = []   # TextureRect 角色精灵图
var cell_containers: Array = []  # Control 容器（包裹sprite）
var cell_select_frames: Array = []  # TextureRect 选中框（静态边框）
var cell_highlight_effects: Array = []  # TextureRect 高亮效果（序列帧动画）
var cell_state_overlays: Array = []  # TextureRect 状态叠加层（锁定/灰尘）
var cell_producer_fx: Array = []  # TextureRect 生成器特效 fx02（作为物品sprite的子级）
var cell_task_icons: Array = []  # TextureRect 任务物品图标（左下角标记）
var cell_cooldown_timers: Array = []  # TextureProgressBar 冷却倒计时（右上角）
var cell_cooldown_bgs: Array = []  # TextureRect 冷却倒计时背景层

# ---- 背包面板 ----
var _backpack_scene_instance: Control = null  # 背包场景实例
var _backpack_visible: bool = false  # 背包是否显示

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
var is_hovering_backpack: bool = false  # 是否悬停在背包物品上
var _drag_start_pos: Vector2 = Vector2.ZERO  # 按下时的鼠标位置
var _press_cell_index: int = -1  # 按下的格子索引
var _is_awaiting_drag: bool = false  # 是否等待拖拽判断
const DRAG_THRESHOLD: float = 5.0  # 开始拖拽的移动阈值（像素）
var merge_targets: Array = []   # 可合成的目标格子列表

# ---- 移动动画状态 ----
var moving_cells: Array = []   # 正在移动动画中的格子索引列表

# ---- 教学系统 ----
var tutorial_overlay = null

# ---- 宿舍面板 ----
var dorm_scene_instance: Control = null
var dorm_visible: bool = false

# ---- 道具栏格子 ----
const ITEM_SLOT_COUNT := 3
var item_slot_nodes: Array = []
var item_slot_labels: Array = []
var item_slot_overlays: Array = []
var item_slot_icons: Array = []  # 道具图片

# ---- 道具详情弹窗 ----
var item_detail_popup_slot: int = -1
var item_detail_visible: bool = false

# ---- 目标选择指针 ----
var is_selecting_target: bool = false
var target_select_item_slot: int = -1

# ---- 遗物提示控制 ----
var _relic_tip_showing: bool = false

# ---- Idle 提示系统 ----
var _idle_hint_timer: SceneTreeTimer = null
var _idle_hint_playing: bool = false  # 提示动画是否正在播放
const IDLE_HINT_DELAY: float = 5.0  # 5秒无操作后触发提示

# 呼吸动效相关
var _breathing_timer: SceneTreeTimer = null
var _breathing_indices: Array = []  # 正在呼吸动画的格子索引

# ---- 教程系统 ----
var tutorial_instance: Control = null


func _ready() -> void:
	# 初始化资源跟踪变量
	_last_gold = GameManager.gold
	_last_energy = GameManager.energy
	_last_diamond = GameManager.diamond
	# 获取遗物面板节点（可能不存在于场景中）
	relic_panel = get_node_or_null("MainLayout/RelicBar/RelicPanel")
	relic_scroll = get_node_or_null("MainLayout/RelicBar/RelicPanel/ScrollContainer")
	relic_list = get_node_or_null("MainLayout/RelicBar/RelicPanel/ScrollContainer/RelicList")
	relic_prev_button = get_node_or_null("MainLayout/RelicBar/PrevButton")
	relic_next_button = get_node_or_null("MainLayout/RelicBar/NextButton")
	# 获取已移除的节点（使用 get_node_or_null 避免错误）
	spawn_warrior = get_node_or_null("MainLayout/BottomBarContainer/BottomBar/SpawnRow/SpawnButtons/SpawnWarrior")
	spawn_mage = get_node_or_null("MainLayout/BottomBarContainer/BottomBar/SpawnRow/SpawnButtons/SpawnMage")
	spawn_priest = get_node_or_null("MainLayout/BottomBarContainer/BottomBar/SpawnRow/SpawnButtons/SpawnPriest")
	end_turn_button = get_node_or_null("MainLayout/DetailActionBar/EndTurnButton")
	item_bar = get_node_or_null("MainLayout/MiddleBar/ItemBar")
	dorm_button = get_node_or_null("MainLayout/MiddleBar/DormButton")
	shop_button = get_node_or_null("MainLayout/MiddleBar/ShopButton")
	encyclopedia_button = get_node_or_null("MainLayout/MiddleBar/EncyclopediaButton")
	bottom_hud_container = get_node_or_null("MainLayout/MiddleBar/BottomHUDContainer")
	# 播放备战阶段BGM
	SoundSystem.play_bgm(SoundSystem.BGM_PREPARE)
	# 加载选中效果序列帧
	_load_select_frames()
	# 加载生成器特效序列帧
	_load_producer_fx()
	_connect_signals()
	_connect_producer_signals()
	_setup_board_ui()
	_setup_dorm_panel()
	_setup_item_slots()
	_setup_character_detail_panel()
	_setup_settings_panel()
	pass  # _update_resource_labels 已移除
	_refresh_relic_panel()
	_refresh_item_slots()
	_refresh_game_board_texts()
	_start_tutorial()


func _process(delta: float) -> void:
	_process_producer_fx_animation(delta)
	_process_cooldown_timers()
	if energy_timer != null and energy_timer.visible:
		_update_energy_timer_text()


func _start_tutorial() -> void:
	# 教程已禁用
	pass


## 加载选中效果序列帧
func _load_select_frames() -> void:
	SELECT_FRAMES.clear()
	for i in range(16):
		var frame_path := "res://art/effects/fx01/FX1_%02d.png" % i
		if ResourceLoader.exists(frame_path):
			var tex := load(frame_path) as Texture2D
			SELECT_FRAMES.append(tex)
			# if i == 0:
			# 	print(">>> [Debug] 加载选中效果序列帧: %s" % frame_path)
	# print(">>> [Debug] 加载了 %d 帧选中效果" % SELECT_FRAMES.size())


## 加载生成器特效序列帧 (fx02)
func _load_producer_fx() -> void:
	PRODUCER_FRAMES.clear()
	for i in range(16):
		var frame_path := "res://art/effects/fx02/FX1_%02d.png" % i
		# print(">>> [Debug] 检查 FX2 路径: %s exists=%s" % [frame_path, ResourceLoader.exists(frame_path)])
		if ResourceLoader.exists(frame_path):
			var tex := load(frame_path) as Texture2D
			PRODUCER_FRAMES.append(tex)
			# if i == 0:
			# 	print(">>> [Debug] 加载生成器特效序列帧: %s" % frame_path)
	# print(">>> [Debug] 加载了 %d 帧生成器特效" % PRODUCER_FRAMES.size())


# ---- 信号连接 ----

func _connect_signals() -> void:
	if spawn_warrior:
		spawn_warrior.pressed.connect(_on_spawn_pressed.bind(DataModels.Job.WARRIOR))
	if spawn_mage:
		spawn_mage.pressed.connect(_on_spawn_pressed.bind(DataModels.Job.MAGE))
	if spawn_priest:
		spawn_priest.pressed.connect(_on_spawn_pressed.bind(DataModels.Job.PRIEST))
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	if sacrifice_button:
		sacrifice_button.pressed.connect(_on_sacrifice_button_pressed)
	_init_speedup_button()
	if dorm_button:
		dorm_button.pressed.connect(_on_dorm_pressed)
	if shop_button:
		shop_button.pressed.connect(_on_shop_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	if energy_buy_btn:
		energy_buy_btn.pressed.connect(_on_energy_buy_pressed)
	if gold_buy_btn:
		gold_buy_btn.pressed.connect(_on_gold_buy_pressed)
	if diamond_buy_btn:
		diamond_buy_btn.pressed.connect(_on_diamond_buy_pressed)
	if encyclopedia_button:
		encyclopedia_button.pressed.connect(_on_encyclopedia_pressed)
	if build_button:
		build_button.pressed.connect(_on_build_button_pressed)
	if bottom_hud_container:
		bottom_hud_container.build_list_pressed.connect(_on_build_list_pressed)
		bottom_hud_container.out_item_clicked.connect(_on_out_item_clicked)
		bottom_hud_container.submit_requested.connect(_on_submit_requested)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.energy_changed.connect(_on_energy_changed)
	GameManager.diamond_changed.connect(_on_diamond_changed)
	GameManager.round_changed.connect(_on_round_changed)
	GameManager.relics_changed.connect(_on_relics_changed)
	GameManager.items_changed.connect(_on_items_changed)
	GameManager.board_items_changed.connect(_on_board_items_changed)
	TaskManager.task_items_updated.connect(_on_task_items_updated)
	if relic_prev_button:
		relic_prev_button.pressed.connect(_on_relic_prev_pressed)
	if relic_next_button:
		relic_next_button.pressed.connect(_on_relic_next_pressed)
	# 设置面板信号
	language_button.pressed.connect(_on_language_toggled)
	reset_tutorial_button.pressed.connect(_on_reset_tutorial_pressed)
	clear_save_button.pressed.connect(_on_clear_save_pressed)
	close_settings_button.pressed.connect(_on_close_settings)
	# 语言切换信号
	LocalizationSystem.language_changed.connect(_on_localization_changed)

	# 设置按钮状态反馈
	_setup_button_feedbacks()

	# 初始化资源标签显示
	_on_gold_changed(GameManager.gold)
	_on_energy_changed(GameManager.energy)
	_on_diamond_changed(GameManager.diamond)

	# 启动 idle 提示计时器
	_start_idle_hint_timer()

	# 使用 call_deferred 确保任务面板完全构建后再刷新
	if bottom_hud_container and bottom_hud_container.has_method("refresh_task_display"):
		bottom_hud_container.call_deferred("refresh_task_display")


## 连接生成器相关信号
func _connect_producer_signals() -> void:
	ProducerManager.stock_changed.connect(_on_producer_stock_changed)
	ProducerManager.cooldown_started.connect(_on_producer_cooldown_started)
	ProducerManager.cooldown_finished.connect(_on_producer_cooldown_finished)
	ProducerManager.producer_registered.connect(_on_producer_registered)
	ProducerManager.producer_unregistered.connect(_on_producer_unregistered)
	ProducerManager.auto_produced.connect(_on_auto_produced)
	ProducerManager.stock_depleted.connect(_on_stock_depleted)


## 生成器信号处理
func _on_producer_stock_changed(board_index: int, _new_stock: int) -> void:
	_update_producer_fx_visibility(board_index)


func _on_producer_cooldown_started(board_index: int, _cooldown_duration: float) -> void:
	_hide_producer_fx(board_index)
	_show_cooldown_timer(board_index)


func _on_producer_cooldown_finished(board_index: int) -> void:
	_update_producer_fx_visibility(board_index)
	_hide_cooldown_timer(board_index)


func _on_producer_registered(board_index: int, _state: ProducerManager.ProducerState) -> void:
	_update_producer_fx_visibility(board_index)


func _on_producer_unregistered(board_index: int) -> void:
	_hide_producer_fx(board_index)


## 自动生成器产出回调
func _on_auto_produced(board_index: int, producer_item_id: int) -> void:
	var bd: BoardData = GameManager.board_data
	var produced: DataModels.BoardItemData = ItemManager.produce_item(producer_item_id)
	if produced == null:
		return
	# 找空位
	var empty_index: int = -1
	for i in range(BoardData.BOARD_SLOTS):
		if bd.get_item_at_index(i) == null:
			empty_index = i
			break
	if empty_index < 0:
		return
	# 从生成器位置飞出
	var start_pos: Vector2 = cell_panels[board_index].global_position + Vector2(CELL_SIZE / 2, CELL_SIZE / 2)
	spawn_item(start_pos, produced, empty_index)
	GameManager._auto_save()


## 库存型生成器耗尽回调：替换为depleted_product
func _on_stock_depleted(board_index: int, depleted_product_id: int) -> void:
	var bd: BoardData = GameManager.board_data
	# 注销生成器
	ProducerManager.unregister_producer(board_index)
	# 移除当前物品
	var pos: Vector2i = BoardData.index_to_pos(board_index)
	bd.remove_item(pos)
	# 如果有depleted_product，放置替代品
	if depleted_product_id > 0:
		var new_item: DataModels.BoardItemData = ItemManager.get_item(depleted_product_id)
		if new_item != null:
			bd.place_item(new_item.duplicate(), pos)
	GameManager.board_items_changed.emit()
	_refresh_board_display()
	GameManager._auto_save()


## 更新生成器特效可见性
func _update_producer_fx_visibility(board_index: int) -> void:
	if board_index < 0 or board_index >= BoardData.BOARD_SLOTS:
		return
	if cell_producer_fx.is_empty() or board_index >= cell_producer_fx.size():
		return

	# LOCKED 状态不显示特效
	var grid_state: int = GameManager.board_data.get_grid_state(board_index)
	if grid_state == BoardData.GridState.LOCKED:
		_hide_producer_fx(board_index)
		return

	var item: DataModels.BoardItemData = GameManager.board_data.get_item_at_index(board_index)
	if item == null:
		return

	# 使用 ItemManager 检查是否是生成器
	var is_prod: bool = ItemManager.is_producer(item.id)
	if not is_prod:
		return

	# autoproduction 不显示生产特效（自动生产，无需点击）
	if ItemManager.is_autoproduction(item.id):
		_hide_producer_fx(board_index)
		return

	var can_prod: bool = ProducerManager.can_produce(board_index)
	if can_prod:
		_show_producer_fx(board_index)
	else:
		_hide_producer_fx(board_index)


## 显示生成器特效
func _show_producer_fx(board_index: int) -> void:
	if cell_producer_fx.is_empty() or board_index >= cell_producer_fx.size():
		return
	if not is_instance_valid(cell_producer_fx[board_index]):
		return
	if PRODUCER_FRAMES.is_empty():
		return

	# 只设置可见性，纹理由_process帧动画驱动（不断帧）
	cell_producer_fx[board_index].visible = true
	cell_producer_fx[board_index].modulate = Color(1, 1, 1, 1)


## 隐藏生成器特效
func _hide_producer_fx(board_index: int) -> void:
	if cell_producer_fx.is_empty() or board_index >= cell_producer_fx.size():
		return
	if not is_instance_valid(cell_producer_fx[board_index]):
		return
	cell_producer_fx[board_index].visible = false
	cell_producer_fx[board_index].texture = null


## 启动生成器特效动画
func _start_producer_fx_animation() -> void:
	# 不再需要tween，动画改由_process驱动
	pass


## _process驱动生成器特效帧动画
func _process_producer_fx_animation(delta: float) -> void:
	if PRODUCER_FRAMES.is_empty() or PRODUCER_FRAMES.size() <= 1:
		return

	_producer_fx_accum += delta
	var frame_interval: float = 0.05  # 每帧50ms

	if _producer_fx_accum >= frame_interval:
		_producer_fx_accum = fmod(_producer_fx_accum, frame_interval)
		_producer_fx_frame = (_producer_fx_frame + 1) % PRODUCER_FRAMES.size()
		var frame_tex: Texture2D = PRODUCER_FRAMES[_producer_fx_frame]
		for i in range(BoardData.BOARD_SLOTS):
			if cell_producer_fx.size() > i and is_instance_valid(cell_producer_fx[i]) and cell_producer_fx[i].visible:
				cell_producer_fx[i].texture = frame_tex


## 更新所有冷却倒计时进度
func _process_cooldown_timers() -> void:
	for i in range(BoardData.BOARD_SLOTS):
		if i >= cell_cooldown_timers.size():
			break
		var cd_progress: TextureProgressBar = cell_cooldown_timers[i]
		if not is_instance_valid(cd_progress) or not cd_progress.visible:
			continue
		var total_cd: float = ProducerManager.get_cooldown_total(i)
		var remaining: float = ProducerManager.get_cooldown_remaining(i)
		if total_cd > 0 and remaining > 0:
			cd_progress.value = remaining / total_cd
		else:
			_hide_cooldown_timer(i)


## 显示冷却倒计时
func _show_cooldown_timer(board_index: int) -> void:
	if board_index < 0 or board_index >= cell_cooldown_timers.size():
		return
	var cd_progress: TextureProgressBar = cell_cooldown_timers[board_index]
	var cd_bg: TextureRect = cell_cooldown_bgs[board_index]
	if is_instance_valid(cd_progress):
		cd_progress.visible = true
		cd_progress.value = 1.0
	if is_instance_valid(cd_bg):
		cd_bg.visible = true


## 隐藏冷却倒计时
func _hide_cooldown_timer(board_index: int) -> void:
	if board_index < 0 or board_index >= cell_cooldown_timers.size():
		return
	var cd_progress: TextureProgressBar = cell_cooldown_timers[board_index]
	var cd_bg: TextureRect = cell_cooldown_bgs[board_index]
	if is_instance_valid(cd_progress):
		cd_progress.visible = false
	if is_instance_valid(cd_bg):
		cd_bg.visible = false


## 为所有TextureButton添加hover和press视觉反馈
func _setup_button_feedbacks() -> void:
	var texture_buttons: Array[TextureButton] = [
		spawn_warrior, spawn_mage, spawn_priest,
		dorm_button, shop_button, encyclopedia_button,
		end_turn_button, close_settings_button
	]
	for btn in texture_buttons:
		if is_instance_valid(btn):
			btn.mouse_entered.connect(_on_button_mouse_entered.bind(btn))
			btn.mouse_exited.connect(_on_button_mouse_exited.bind(btn))
			btn.button_down.connect(_on_button_down.bind(btn))
			btn.button_up.connect(_on_button_up.bind(btn))

	# 为献祭按钮添加反馈
	if is_instance_valid(sacrifice_button):
		sacrifice_button.mouse_entered.connect(_on_button_mouse_entered.bind(sacrifice_button))
		sacrifice_button.mouse_exited.connect(_on_button_mouse_exited.bind(sacrifice_button))
		sacrifice_button.button_down.connect(_on_button_down.bind(sacrifice_button))
		sacrifice_button.button_up.connect(_on_button_up.bind(sacrifice_button))


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


# ---- 棋盘 UI 构建 ----

func _setup_board_ui() -> void:
	# 加载锁定状态纹理
	CELL_LOCKED_EVEN_TEXTURE = load("res://art/sprites/UI/icon/cell5.png")
	CELL_LOCKED_ODD_TEXTURE = load("res://art/sprites/UI/icon/cell6.png")
	CELL_DUSTY_TEXTURE = load("res://art/sprites/UI/icon/cell7.png")

	# 清空数组
	cell_rects.clear()
	cell_panels.clear()
	cell_sprites.clear()
	cell_select_frames.clear()
	cell_highlight_effects.clear()
	cell_state_overlays.clear()
	cell_producer_fx.clear()
	cell_task_icons.clear()
	cell_cooldown_timers.clear()
	cell_cooldown_bgs.clear()

	for i in range(GRID_COLS * GRID_ROWS):
		# 获取静态格子节点
		var cell: Control = grid_container.get_node_or_null("cell_%d" % i)
		if cell == null:
			push_error(">>> [GameBoard] 静态格子节点 cell_%d 不存在!" % i)
			continue

		cell_panels.append(cell)

		# 获取静态 bg
		var bg: TextureRect = cell.get_node_or_null("bg")
		if bg:
			cell_rects.append(bg)

		# 动态创建选中框
		var select_frame := TextureRect.new()
		select_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		select_frame.texture = CELL_SELECT_TEXTURE
		select_frame.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		select_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		select_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		select_frame.visible = false
		select_frame.z_index = 1
		cell.add_child(select_frame)
		cell_select_frames.append(select_frame)

		# 动态创建状态叠加层
		var state_overlay := TextureRect.new()
		state_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		state_overlay.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		state_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		state_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		state_overlay.visible = false
		state_overlay.z_index = 6
		cell.add_child(state_overlay)
		cell_state_overlays.append(state_overlay)

		# 动态创建高亮效果
		var highlight_effect := TextureRect.new()
		highlight_effect.set_anchors_preset(Control.PRESET_FULL_RECT)
		highlight_effect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		highlight_effect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		highlight_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		highlight_effect.visible = false
		highlight_effect.scale = Vector2(2.6, 2.6)
		highlight_effect.pivot_offset = Vector2(CELL_SIZE / 2, CELL_SIZE / 2)
		highlight_effect.z_index = 2
		cell.add_child(highlight_effect)
		cell_highlight_effects.append(highlight_effect)

		# 动态创建角色精灵（使用预制体）
		var sprite_container: Control = preload("res://scenes/board_item.tscn").instantiate()
		var sprite: TextureRect
		# 尝试通过路径获取 Sprite 节点（更可靠）
		sprite = sprite_container.get_node_or_null("Sprite")
		# 降级：取第一个子节点
		if sprite == null and sprite_container.get_child_count() > 0:
			var first: Node = sprite_container.get_child(0)
			if first is TextureRect:
				sprite = first
		if sprite == null:
			push_error(">>> [GameBoard] 无法从 board_item.tscn 获取 Sprite 节点")
			sprite_container.queue_free()
			continue
		sprite_container.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		sprite_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite_container.visible = false
		sprite_container.z_index = 5
		cell.add_child(sprite_container)
		cell_sprites.append(sprite)
		cell_containers.append(sprite_container)

		# 动态创建生成器特效
		var producer_fx := TextureRect.new()
		producer_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
		producer_fx.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		producer_fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		producer_fx.custom_minimum_size = Vector2(CHAR_SIZE, CHAR_SIZE)
		producer_fx.pivot_offset = Vector2(CELL_SIZE / 2, CELL_SIZE / 2)
		producer_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		producer_fx.visible = false
		producer_fx.scale = Vector2(3.4, 3.4)
		producer_fx.z_index = 10
		sprite_container.add_child(producer_fx)
		cell_producer_fx.append(producer_fx)

		# 动态创建任务图标
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
		task_icon.visible = false
		task_icon.z_index = 15
		sprite_container.add_child(task_icon)
		cell_task_icons.append(task_icon)

		# 动态创建冷却倒计时（右上角，2层：背景圆 + 前景TextureProgressBar）
		var cd_size: float = 36.0
		# 背景层（灰色半透明圆底）
		var cd_bg := TextureRect.new()
		cd_bg.name = "CooldownBg"
		cd_bg.custom_minimum_size = Vector2(cd_size, cd_size)
		cd_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cd_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cd_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd_bg.anchor_left = 1.0
		cd_bg.anchor_top = 0.0
		cd_bg.anchor_right = 1.0
		cd_bg.anchor_bottom = 0.0
		cd_bg.offset_left = -cd_size - 2.0
		cd_bg.offset_top = 2.0
		cd_bg.offset_right = -2.0
		cd_bg.offset_bottom = cd_size + 2.0
		cd_bg.visible = false
		cd_bg.z_index = 16
		cd_bg.modulate = Color(0.3, 0.3, 0.3, 0.7)
		cell.add_child(cd_bg)
		cell_cooldown_bgs.append(cd_bg)

		# 前景层（TextureProgressBar，360度Filled模式）
		var cd_progress := TextureProgressBar.new()
		cd_progress.name = "CooldownTimer"
		cd_progress.custom_minimum_size = Vector2(cd_size, cd_size)
		cd_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd_progress.anchor_left = 1.0
		cd_progress.anchor_top = 0.0
		cd_progress.anchor_right = 1.0
		cd_progress.anchor_bottom = 0.0
		cd_progress.offset_left = -cd_size - 2.0
		cd_progress.offset_top = 2.0
		cd_progress.offset_right = -2.0
		cd_progress.offset_bottom = cd_size + 2.0
		cd_progress.fill_mode = TextureProgressBar.FILL_CLOCKWISE
		cd_progress.min_value = 0.0
		cd_progress.max_value = 1.0
		cd_progress.value = 1.0
		cd_progress.visible = false
		cd_progress.z_index = 17
		# 使用 bar1 作为进度纹理（白色）
		if ResourceLoader.exists("res://art/sprites/UI/icon/bar1.png"):
			cd_progress.texture_progress = load("res://art/sprites/UI/icon/bar1.png")
		cell.add_child(cd_progress)
		cell_cooldown_timers.append(cd_progress)

		# 点击事件
		if cell.gui_input.is_connected(_on_cell_gui_input):
			cell.gui_input.disconnect(_on_cell_gui_input)
		cell.gui_input.connect(_on_cell_gui_input.bind(i))

	_refresh_board_display()



# ---- 角色详情面板 ----

func _setup_character_detail_panel() -> void:
	# 使用场景中已有的 detail_panel 和 detail_label 节点
	_update_character_detail_panel()


func _setup_settings_panel() -> void:
	# 设置遮罩和面板的层级（使用全局层级）
	settings_backdrop.z_index = 100
	settings_backdrop.z_as_relative = false
	settings_panel.z_index = 101
	settings_panel.z_as_relative = false


func _update_character_detail_panel() -> void:
	# 默认隐藏加速按钮
	_hide_speedup_button()

	if selected_index >= 0:
		var bd: BoardData = GameManager.board_data
		var ch: DataModels.BoardItemData = bd.get_item_at_index(selected_index)
		if ch != null:
			# 显示角色信息
			name_label.text = ch.name
			detail_label.text = "Lv.%d" % ch.level
			hint_label.text = ""

			# 检查是否是冷却中的生成器，显示加速按钮
			if ItemManager.is_producer(ch.id) and ProducerManager.is_in_cooldown(selected_index):
				_show_speedup_button(selected_index)

			# 根据物品类型决定是否显示出售按钮
			if ItemManager.is_sellable(ch.id):
				# 普通物品：显示出售按钮
				sacrifice_button.modulate.a = 1.0
				sacrifice_button.mouse_filter = Control.MOUSE_FILTER_STOP
				# 更新出售价格: 2^(level-1)
				var sell_price: int = ItemManager.get_sell_price(ch.id, ch.level)
				sacrifice_label.text = str(sell_price)
				# 更新按钮文字为"出售" + 金币图标
				var vbox = sacrifice_button.get_node_or_null("VBoxContainer")
				if vbox:
					var label2 = vbox.get_node_or_null("Label2")
					if label2:
						label2.text = "出售"
				# 更换为金币图标
				sacrifice_icon.texture = JINBI_ICON
			else:
				# 非普通物品（生成器/背包/金币堆/体力球）：隐藏出售按钮
				sacrifice_button.modulate.a = 0.0
				sacrifice_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
				# 恢复为能量图标
				sacrifice_icon.texture = ENERGY_ICON
			return

	# 无选中或角色已不存在
	name_label.text = ""
	detail_label.text = LocalizationSystem.get_text("game_board.click_to_view_detail", {})
	hint_label.text = ""
	# 性能优化：使用透明度而非visible，避免HBoxContainer重布局
	sacrifice_button.modulate.a = 0.0
	sacrifice_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


## 初始化冷却加速按钮（动态创建，添加到详情面板）
func _init_speedup_button() -> void:
	var main_hbox = detail_panel.find_child("MainHBox", true, false)
	if main_hbox == null:
		return

	var btn := TextureButton.new()
	btn.name = "SpeedupButton"
	btn.custom_minimum_size = Vector2(100, 80)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.visible = false

	# 加载按钮纹理
	var tex_path := "res://art/sprites/UI/icon/btn.png"
	if ResourceLoader.exists(tex_path):
		btn.texture_normal = load(tex_path)

	# 内部布局: VBox -> [倒计时Label, HBox(钻石图标+费用)]
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var time_label := Label.new()
	time_label.name = "TimeLabel"
	time_label.text = "00:00"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 16)
	time_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(time_label)

	var cost_hbox := HBoxContainer.new()
	cost_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_hbox.add_theme_constant_override("separation", 4)
	cost_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var diamond_icon := TextureRect.new()
	diamond_icon.custom_minimum_size = Vector2(20, 20)
	diamond_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	diamond_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var diamond_tex_path := "res://art/sprites/UI/icon/diamond.png"
	if ResourceLoader.exists(diamond_tex_path):
		diamond_icon.texture = load(diamond_tex_path)
	diamond_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_hbox.add_child(diamond_icon)

	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "1"
	cost_label.add_theme_font_size_override("font_size", 18)
	cost_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0, 1))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_hbox.add_child(cost_label)

	vbox.add_child(cost_hbox)
	btn.add_child(vbox)

	btn.pressed.connect(_on_speedup_pressed)
	main_hbox.add_child(btn)

	_speedup_btn = btn
	_speedup_label = time_label
	_speedup_cost_label = cost_label

	# 创建更新Timer（每0.5秒刷新一次倒计时显示）
	var timer := Timer.new()
	timer.name = "SpeedupTimer"
	timer.wait_time = 0.5
	timer.one_shot = false
	timer.autostart = false
	timer.timeout.connect(_on_speedup_timer_tick)
	add_child(timer)
	_speedup_timer = timer


## 显示加速按钮
func _show_speedup_button(board_index: int) -> void:
	if _speedup_btn == null:
		return
	_speedup_btn.visible = true
	_speedup_btn.set_meta("board_index", board_index)
	_update_speedup_display(board_index)
	if _speedup_timer:
		_speedup_timer.start()


## 隐藏加速按钮
func _hide_speedup_button() -> void:
	if _speedup_btn != null:
		_speedup_btn.visible = false
	if _speedup_timer != null:
		_speedup_timer.stop()


## 更新加速按钮显示（倒计时+费用）
func _update_speedup_display(board_index: int) -> void:
	var remaining: float = ProducerManager.get_cooldown_remaining(board_index)
	if remaining <= 0:
		_hide_speedup_button()
		_update_producer_fx_visibility(board_index)
		return

	# 格式化倒计时 mm:ss
	var mins: int = int(remaining) / 60
	var secs: int = int(remaining) % 60
	if _speedup_label:
		_speedup_label.text = "%02d:%02d" % [mins, secs]

	# 费用: max(1, remaining/600)
	var cost: int = ProducerManager.get_skip_cooldown_cost(board_index)
	if _speedup_cost_label:
		_speedup_cost_label.text = str(cost)


## Timer回调：定期刷新加速按钮显示
func _on_speedup_timer_tick() -> void:
	if _speedup_btn == null or not _speedup_btn.visible:
		return
	var board_index: int = _speedup_btn.get_meta("board_index", -1)
	if board_index < 0:
		return
	_update_speedup_display(board_index)


## 加速按钮点击
func _on_speedup_pressed() -> void:
	if _speedup_btn == null:
		return
	var board_index: int = _speedup_btn.get_meta("board_index", -1)
	if board_index < 0:
		return

	var cost: int = ProducerManager.get_skip_cooldown_cost(board_index)
	if GameManager.diamond < cost:
		TipManager.show_tip(LocalizationSystem.get_text("game_board.not_enough_diamond"))
		return

	# 扣除钻石
	GameManager.diamond -= cost
	GameManager.diamond_changed.emit(GameManager.diamond)

	# 跳过冷却
	ProducerManager.skip_cooldown(board_index)

	# 播放点击动效
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_speedup_btn, "scale", Vector2(1.1, 1.1), 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_speedup_btn, "scale", Vector2(1.0, 1.0), 0.1)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(0.1)

	# 刷新显示
	_hide_speedup_button()
	_update_producer_fx_visibility(board_index)
	_update_character_detail_panel()
	GameManager._auto_save()


func _on_sacrifice_button_pressed() -> void:
	if selected_index >= 0:
		SoundSystem.play_button_click()
		_sell_selected_item(selected_index)


# ---- 宿舍面板 ----
func _setup_dorm_panel() -> void:
	# 实例化宿舍场景
	dorm_scene_instance = DormScene.instantiate()
	dorm_scene_instance.visible = false
	add_child(dorm_scene_instance)
	
	# 连接信号
	dorm_scene_instance.close_requested.connect(_on_dorm_close)


func _refresh_dorm_panel() -> void:
	if dorm_scene_instance:
		dorm_scene_instance.refresh(GameManager.board_data.dormitory)


# ---- 棋盘格拖拽处理 (任务 2.3 拖拽/选中) ----

func _on_cell_gui_input(event: InputEvent, cell_index: int) -> void:
	# 重置 idle 提示计时器
	_reset_idle_hint_timer()

	# 检查格子状态 - LOCKED 状态不可交互
	var bd: BoardData = GameManager.board_data
	if not bd.can_interact(cell_index):
		return

	var ch: DataModels.BoardItemData = bd.get_item_at_index(cell_index)

	# 目标选择模式: 点击角色使用道具
	if is_selecting_target and event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if ch != null:
				_use_item_on_target(cell_index)
				return
			else:
				# 点击空格子取消选择
				_end_target_selection()
				return

	# 鼠标按下: 记录按下状态
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# 按下左键：记录位置，等待拖拽判断
				_drag_start_pos = mb.global_position
				_press_cell_index = cell_index
				_is_awaiting_drag = true
			else:
				# 释放左键
				if is_dragging:
					# 正在拖拽 → 结束拖拽
					_end_drag(cell_index)
				elif _is_awaiting_drag and _press_cell_index == cell_index:
					# 没有拖拽超过阈值，且在同一个格子抬起 → 执行选中/点击效果
					if ch != null:
						# 检查是否已经是选中状态
						if cell_index == selected_index:
							# 已经是选中状态 → 触发点击效果（如生成器生成）
							if ItemManager.is_producer(ch.id):
								_try_produce_item(cell_index)
							elif ItemManager.is_backpack(ch.id):
								_open_backpack_ui()
							elif ItemManager.is_coinpile(ch.id):
								# 金币堆：移动到金币栏，增加金币
								_collect_coinpile(cell_index)
							elif ItemManager.is_energy(ch.id):
								# 体力球：点击消耗，增加体力
								_collect_energy_ball(cell_index)
							else:
								_update_character_detail_panel()
						else:
							# 不是选中状态 → 先选中
							_set_selected(cell_index)
					else:
						# 空格子 → 取消选中
						if selected_index >= 0:
							selected_index = -1
							_refresh_board_display()
							_update_character_detail_panel()
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
					var ch_check: DataModels.BoardItemData = bd_check.get_item_at_index(_press_cell_index)
					# DUSTY 状态不能拖拽
					if ch_check != null and bd_check.get_grid_state(_press_cell_index) != BoardData.GridState.DUSTY:
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
	var source_ch: DataModels.BoardItemData = bd.get_item_at_index(selected_index)
	var target_ch: DataModels.BoardItemData = bd.get_item_at_index(target_index)

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
		_update_producer_fx_visibility(target_index)
		_try_advance_tutorial(2)
	elif target_ch.get_merge_chain() == source_ch.get_merge_chain() and target_ch.level == source_ch.level:
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
			# 有空格: 被换角色移动到空格（带动画），源角色直接到目标位置
			_play_displace_to_empty_animation(selected_index, target_index, nearest_empty)
		else:
			# 没空格: 交换位置（无动画）
			_play_swap_animation(selected_index, target_index)


## 交换角色：被交换的角色有飞行动画，拖拽的角色直接落下
func _play_swap_animation(src_index: int, tgt_index: int) -> void:
	# 隐藏拖拽预览
	if drag_preview != null:
		drag_preview.queue_free()
		drag_preview = null

	# 获取被交换角色的数据（动画前先获取）
	var bd: BoardData = GameManager.board_data
	var tgt_ch: DataModels.BoardItemData = bd.get_item_at_index(tgt_index)

	# 数据层交换
	_do_swap_or_move(src_index, tgt_index)

	# 标记 src_index 为移动中（被交换角色要飞到那里）
	moving_cells.append(src_index)
	_refresh_board_display()

	# 被交换角色的飞行动画（从 tgt_index 飞到 src_index）
	if tgt_ch != null:
		var start_cell: Control = cell_panels[tgt_index]
		var end_cell: Control = cell_panels[src_index]
		var start_world: Vector2 = start_cell.global_position + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
		var end_world: Vector2 = end_cell.global_position + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)

		var anim_sprite := _create_flying_sprite(tgt_ch)
		anim_sprite.global_position = start_world - Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
		add_child(anim_sprite)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(anim_sprite, "global_position", end_world - Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0), 0.25)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		tween.finished.connect(func():
			anim_sprite.queue_free()
			moving_cells.erase(src_index)
			_refresh_board_display()
			_refresh_producer_fx_all()
			_play_land_animation(src_index)
		, CONNECT_ONE_SHOT)

	# 更新选中状态
	selected_index = tgt_index
	_update_character_detail_panel()
	_try_advance_tutorial(2)


## 创建飞行动画精灵的辅助函数（参考 _create_drag_preview 的方式）
func _create_flying_sprite(ch: DataModels.BoardItemData) -> Control:
	var anim_sprite := Control.new()
	anim_sprite.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	anim_sprite.z_index = 10
	anim_sprite.z_as_relative = false
	anim_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sprite := TextureRect.new()
	sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.custom_minimum_size = Vector2(CHAR_SIZE, CHAR_SIZE)
	sprite.z_index = 0
	var sprite_path: String = ch.get_sprite_path()
	if ResourceLoader.exists(sprite_path):
		sprite.texture = load(sprite_path)

	anim_sprite.add_child(sprite)
	return anim_sprite


## 查找最近空格（排除指定单元格）
func _find_nearest_empty_cell(exclude_index: int) -> int:
	var bd: BoardData = GameManager.board_data
	var tgt_pos: Vector2i = BoardData.index_to_pos(exclude_index)

	var nearest: int = -1
	var nearest_dist: float = INF

	for i in range(BoardData.BOARD_SLOTS):
		if i == exclude_index:
			continue
		if bd.get_item_at_index(i) == null:
			var dist: float = (BoardData.index_to_pos(i) - tgt_pos).length()
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = i

	return nearest


## 检查棋盘是否有空位
func has_empty_slot() -> bool:
	var bd: BoardData = GameManager.board_data
	for i in range(BoardData.BOARD_SLOTS):
		if bd.get_item_at_index(i) == null:
			return true
	return false


## 颤动动效（合成时的动效）：0.8 -> 1.1 -> 1.0 + 白色闪烁
func play_shake_animation(obj: Control) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	obj.scale = Vector2(1.0, 1.0)
	obj.modulate = Color.WHITE

	var tween := create_tween()
	tween.set_parallel(false)
	tween.tween_property(obj, "scale", Vector2(0.8, 0.8), 0.1).from(Vector2(1.0, 1.0))
	tween.tween_property(obj, "scale", Vector2(1.1, 1.1), 0.15)
	tween.tween_property(obj, "scale", Vector2(1.0, 1.0), 0.15)

	var tween2 := create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(obj, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.05)
	tween2.tween_property(obj, "modulate", Color(1.0, 1.0, 0.5, 1.0), 0.1)
	tween2.tween_property(obj, "modulate", Color.WHITE, 0.25)


## 生成物品：从起始坐标飞向目标位置，到达后播放一次颤动动效
## 返回是否生成成功（棋盘满时返回false）
## 注意：直接使用传入的 item 对象（应为独立的副本），不再重复查询缓存
func spawn_item(start_pos: Vector2, item: DataModels.BoardItemData, target_index: int) -> bool:
	var bd: BoardData = GameManager.board_data
	if target_index < 0 or target_index >= BoardData.BOARD_SLOTS:
		return false
	if bd.get_item_at_index(target_index) != null:
		return false

	if item == null:
		return false

	# 标记目标格子为移动中
	moving_cells.append(target_index)
	_refresh_board_display()

	# 获取物品纹理以确定原始尺寸
	var sprite_path: String = item.get_sprite_path()
	var item_tex: Texture2D = null
	if ResourceLoader.exists(sprite_path):
		item_tex = load(sprite_path)
	var item_size: Vector2 = item_tex.get_size() if item_tex else Vector2(CHAR_SIZE, CHAR_SIZE)

	# 创建飞行动画精灵（使用board_item预制体）
	var anim_container: Control = preload("res://scenes/board_item.tscn").instantiate()
	anim_container.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	anim_container.z_index = 10
	anim_container.z_as_relative = false
	anim_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 获取Sprite节点并设置纹理
	var sprite: TextureRect = anim_container.get_node_or_null("Sprite")
	if sprite == null and anim_container.get_child_count() > 0:
		var first: Node = anim_container.get_child(0)
		if first is TextureRect:
			sprite = first
	if sprite != null:
		sprite.custom_minimum_size = item_size
		if item_tex != null:
			sprite.texture = item_tex

	add_child(anim_container)
	anim_container.global_position = start_pos - Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)

	# 目标格子中心世界坐标
	var target_cell: Control = cell_panels[target_index]
	var end_pos: Vector2 = target_cell.global_position + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)

	# 在 tween 创建前就复制 item（避免闭包引用问题）
	var captured_item: DataModels.BoardItemData = item.duplicate()

	# 位移动画
	var tween := create_tween()
	tween.tween_property(anim_container, "global_position", end_pos - Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0), 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func():
		anim_container.queue_free()
		moving_cells.erase(target_index)
		# 放置物品到目标格子
		var tgt_pos: Vector2i = BoardData.index_to_pos(target_index)
		bd.place_item(captured_item, tgt_pos)
		bd.set_grid_state(target_index, BoardData.GridState.OCCUPIED)
		GameManager.board_items_changed.emit()
		_refresh_board_display()
		# 落地后播放颤动动效
		if target_index < cell_sprites.size() and cell_sprites[target_index] != null:
			play_shake_animation(cell_sprites[target_index])
	, CONNECT_ONE_SHOT)

	return true


## 被换角色移动到空格：被挤开角色有飞行动画
func _play_displace_to_empty_animation(src_index: int, tgt_index: int, empty_index: int) -> void:
	# 隐藏拖拽预览
	if drag_preview != null:
		drag_preview.queue_free()
		drag_preview = null

	# 获取被挤开角色的数据（动画前先获取）
	var bd: BoardData = GameManager.board_data
	var displaced_ch: DataModels.BoardItemData = bd.get_item_at_index(tgt_index)

	# 数据层: src -> tgt, tgt -> empty
	_do_swap_and_displace(src_index, tgt_index, empty_index)

	# 标记 empty 格子为移动中（被挤开角色的目标位置）
	moving_cells.append(empty_index)
	_refresh_board_display()

	# 被挤开的角色需要有飞行动画
	if displaced_ch != null:
		var start_cell: Control = cell_panels[tgt_index]
		var end_cell: Control = cell_panels[empty_index]
		var start_world: Vector2 = start_cell.global_position + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
		var end_world: Vector2 = end_cell.global_position + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)

		var anim_sprite := _create_flying_sprite(displaced_ch)
		anim_sprite.global_position = start_world - Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
		add_child(anim_sprite)

		# 飞行动画（0.25秒，平滑过渡）
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(anim_sprite, "global_position", end_world - Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0), 0.25)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# 动画结束后清理
		tween.finished.connect(func():
			anim_sprite.queue_free()
			moving_cells.erase(empty_index)
			_refresh_board_display()
			_play_land_animation(empty_index)
		, CONNECT_ONE_SHOT)

	# 更新选中状态（src 角色已在 tgt_index）
	selected_index = tgt_index
	_update_character_detail_panel()
	_try_advance_tutorial(2)


## 执行交换并移动到空格（数据层）
func _do_swap_and_displace(src_index: int, tgt_index: int, empty_index: int) -> void:
	var bd: BoardData = GameManager.board_data
	var src_ch: DataModels.BoardItemData = bd.get_item_at_index(src_index)
	var tgt_ch: DataModels.BoardItemData = bd.get_item_at_index(tgt_index)

	if src_ch == null or tgt_ch == null:
		return

	# tgt角色移动到empty
	var tgt_pos: Vector2i = BoardData.index_to_pos(tgt_index)
	var empty_pos: Vector2i = BoardData.index_to_pos(empty_index)
	bd.swap_items(tgt_pos, empty_pos)

	# src角色移动到tgt
	var src_pos: Vector2i = BoardData.index_to_pos(src_index)
	bd.swap_items(src_pos, tgt_pos)



## 执行实际的交换或移动（数据层）
func _do_swap_or_move(src_index: int, tgt_index: int) -> void:
	var bd: BoardData = GameManager.board_data
	var source_ch: DataModels.BoardItemData = bd.get_item_at_index(src_index)

	if source_ch == null:
		return

	var target_ch: DataModels.BoardItemData = bd.get_item_at_index(tgt_index)

	if target_ch == null:
		# 移动
		var src_pos: Vector2i = BoardData.index_to_pos(src_index)
		var tgt_pos: Vector2i = BoardData.index_to_pos(tgt_index)
		bd.swap_items(src_pos, tgt_pos)
		# 更新ProducerManager注册
		if ProducerManager.is_producer(src_index):
			ProducerManager.move_producer(src_index, tgt_index)
	else:
		# 交换 - 目标格子是Locked或DUSTY状态则不能交换
		var tgt_state: int = bd.get_grid_state(tgt_index)
		if tgt_state == BoardData.GridState.LOCKED or tgt_state == BoardData.GridState.DUSTY:
			return
		var src_pos: Vector2i = BoardData.index_to_pos(src_index)
		var tgt_pos: Vector2i = BoardData.index_to_pos(tgt_index)
		bd.swap_items(src_pos, tgt_pos)
		# 更新ProducerManager注册
		var src_is_prod: bool = ProducerManager.is_producer(src_index)
		var tgt_is_prod: bool = ProducerManager.is_producer(tgt_index)
		if src_is_prod and tgt_is_prod:
			ProducerManager.swap_producer(src_index, tgt_index)
		elif src_is_prod:
			ProducerManager.move_producer(src_index, tgt_index)
		elif tgt_is_prod:
			ProducerManager.move_producer(tgt_index, src_index)


# ---- 角色合成 (任务 2.4) ----

func _merge_at(src_index: int, tgt_index: int) -> void:
	var bd: BoardData = GameManager.board_data
	var src_item: DataModels.BoardItemData = bd.get_item_at_index(src_index)
	var tgt_item: DataModels.BoardItemData = bd.get_item_at_index(tgt_index)

	# DUSTY 状态被合成时 → 切换为 OCCUPIED
	bd.dust_to_occupied(tgt_index)

	var merged: DataModels.BoardItemData = ItemManager.merge_items(src_item, tgt_item)
	if merged == null:
		return

	# 播放合成音效
	SoundSystem.play_merge()

	# 移除两个原物品
	bd.remove_item(BoardData.index_to_pos(src_index))
	bd.remove_item(BoardData.index_to_pos(tgt_index))

	# 放置新物品到目标位置
	var tgt_pos: Vector2i = BoardData.index_to_pos(tgt_index)
	bd.place_item(merged, tgt_pos)
	GameManager.board_items_changed.emit()

	# 合成后目标位置变为 OCCUPIED
	bd.set_grid_state(tgt_index, BoardData.GridState.OCCUPIED)

	# 合成位置上下左右的 LOCKED 格子 → 切换为 DUSTY
	bd.trigger_merge_unlock(tgt_index)


	# 刷新棋盘显示
	_refresh_board_display()

	# 播放合成动画: 0.8 -> 1.1 -> 1.0
	_play_merge_animation(tgt_index)

	# 合成后有概率生成金币：概率 = merged.level * 10%，上限100%
	_try_spawn_coin_on_merge(merged, tgt_index)


## 合成后概率生成金币
## 概率 = merged.level * 10%，金币从合成处弹出，飞向最近空格
func _try_spawn_coin_on_merge(merged: DataModels.BoardItemData, merge_index: int) -> void:
	var bd: BoardData = GameManager.board_data

	# 找最近空格（排除合成位置）
	var empty_index: int = _find_nearest_empty_cell(merge_index)
	if empty_index < 0:
		return  # 没有空格

	# 计算概率：Lv.1=10%, Lv.6=60%, Lv.10=100%
	var probability: float = clampf(merged.level * 0.1, 0.0, 1.0)
	if randf() > probability:
		return  # 概率未命中

	# 总是生成1级金币堆
	var coin_level: int = 1
	# 金币堆ID: 3020101-3020106 对应等级1-6
	var coin_id: int = 3020100 + coin_level

	# 获取起始位置并使用 spawn_item 生成金币
	var start_cell: Control = cell_panels[merge_index]
	var start_world: Vector2 = start_cell.global_position + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	var coin_item: DataModels.BoardItemData = ItemManager.get_item(coin_id)
	if coin_item == null:
		return
	spawn_item(start_world, coin_item, empty_index)


## 收集金币堆：粒子特效，增加金币
func _collect_coinpile(cell_index: int) -> void:
	var bd: BoardData = GameManager.board_data
	var coin_item: DataModels.BoardItemData = bd.get_item_at_index(cell_index)
	if coin_item == null:
		return

	# 计算金币价值 f(n) = round(2.5^(n-1))
	var coin_value: int = ItemManager.get_coinpile_value(coin_item.level)

	# 获取位置用于粒子特效
	var start_cell: Control = cell_panels[cell_index]
	var start_pos: Vector2 = start_cell.global_position + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	# 动态获取金币栏位置（参考经验特效的获取方式）
	var coin_bar_pos: Vector2 = _get_gold_bar_position()

	# 隐藏金币堆sprite
	cell_sprites[cell_index].visible = false
	cell_containers[cell_index].visible = false

	# 播放金币粒子特效（粒子数量根据金币堆等级调整）
	var particle_count := mini(maxi(coin_item.level, 1), 10)
	_play_coin_particle_effect(start_pos, coin_bar_pos, particle_count)

	# 从棋盘移除金币
	bd.remove_item(BoardData.index_to_pos(cell_index))
	GameManager.board_items_changed.emit()

	# 增加金币
	GameManager.add_gold(coin_value)

	# 取消选中
	selected_index = -1
	_update_character_detail_panel()


## 体力球：点击消耗，增加体力，播放粒子飞向体力条
func _collect_energy_ball(cell_index: int) -> void:
	var bd: BoardData = GameManager.board_data
	var energy_item: DataModels.BoardItemData = bd.get_item_at_index(cell_index)
	if energy_item == null:
		return

	# 计算体力值
	var energy_value: int = ItemManager.get_energy_value(energy_item.id, energy_item.level)
	if energy_value <= 0:
		energy_value = 1

	# 获取位置用于粒子特效
	var start_cell: Control = cell_panels[cell_index]
	var start_pos: Vector2 = start_cell.global_position + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	var energy_bar_pos: Vector2 = _get_energy_bar_position()

	# 隐藏体力球sprite
	cell_sprites[cell_index].visible = false
	cell_containers[cell_index].visible = false

	# 播放体力粒子特效（绿色能量球飞向体力条，粒子数量根据体力值调整）
	var energy_particle_count := mini(maxi(energy_value, 1), 10)
	_play_energy_particle_effect(start_pos, energy_bar_pos, energy_particle_count)

	# 从棋盘移除体力球
	bd.remove_item(BoardData.index_to_pos(cell_index))
	GameManager.board_items_changed.emit()

	# 增加体力
	GameManager.restore_energy(energy_value)

	# 取消选中
	selected_index = -1
	_update_character_detail_panel()
	_refresh_board_display()
	GameManager._auto_save()


## 体力粒子特效：爆炸散开 + 收束飞向体力条（参考经验粒子特效）
func _play_energy_particle_effect(start_pos: Vector2, end_pos: Vector2, particle_count: int = 8) -> void:
	var particle_container := Node2D.new()
	particle_container.z_index = 15
	add_child(particle_container)
	particle_container.global_position = start_pos

	var particles: Array[Sprite2D] = []

	# Phase 1: 爆炸散开 (0.3s)
	for i in range(particle_count):
		var particle := Sprite2D.new()
		particle.texture = POWER_ICON
		particle.scale = Vector2(0.4, 0.4)
		particle.modulate = Color(1, 1, 1, 0.9)
		particle_container.add_child(particle)
		particle.global_position = start_pos
		particles.append(particle)

		var angle: float = TAU * float(i) / float(particle_count) + randf_range(-0.2, 0.2)
		var scatter_dist: float = randf_range(25, 50)
		var scatter_pos: Vector2 = start_pos + Vector2(cos(angle), sin(angle)) * scatter_dist

		var scatter_tween := create_tween()
		scatter_tween.tween_property(particle, "global_position", scatter_pos, 0.3)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		scatter_tween.parallel().tween_property(particle, "scale", Vector2(0.6, 0.6), 0.3)

	# Phase 2: 收束飞向体力条 (0.4s)
	await get_tree().create_timer(0.3).timeout
	for particle in particles:
		if not is_instance_valid(particle):
			continue
		var fly_tween := create_tween()
		var random_offset := Vector2(randf_range(-10, 10), randf_range(-10, 10))
		fly_tween.tween_property(particle, "global_position", end_pos + random_offset, 0.4)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly_tween.parallel().tween_property(particle, "scale", Vector2(0.3, 0.3), 0.4)
		fly_tween.tween_property(particle, "modulate:a", 0.0, 0.1)

	# 清理
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(particle_container):
		particle_container.queue_free()


## 金币粒子特效：爆炸散开 + 收束飞向金币栏（参考经验粒子特效）
func _play_coin_particle_effect(start_pos: Vector2, end_pos: Vector2, particle_count: int = 10) -> void:
	var particle_container := Node2D.new()
	particle_container.z_index = 15
	add_child(particle_container)
	particle_container.global_position = start_pos

	var particles: Array[Sprite2D] = []

	# Phase 1: 爆炸散开 (0.3s)
	for i in range(particle_count):
		var particle := Sprite2D.new()
		particle.texture = JINBI_ICON
		particle.scale = Vector2(0.5, 0.5)
		particle.modulate = Color(1, 1, 1, 0.9)
		particle_container.add_child(particle)
		particle.global_position = start_pos
		particles.append(particle)

		var angle: float = TAU * float(i) / float(particle_count) + randf_range(-0.2, 0.2)
		var scatter_dist: float = randf_range(25, 50)
		var scatter_pos: Vector2 = start_pos + Vector2(cos(angle), sin(angle)) * scatter_dist

		var scatter_tween := create_tween()
		scatter_tween.tween_property(particle, "global_position", scatter_pos, 0.3)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		scatter_tween.parallel().tween_property(particle, "scale", Vector2(0.7, 0.7), 0.3)

	# Phase 2: 收束飞向金币栏 (0.4s)
	await get_tree().create_timer(0.3).timeout
	for particle in particles:
		if not is_instance_valid(particle):
			continue
		var fly_tween := create_tween()
		var random_offset := Vector2(randf_range(-10, 10), randf_range(-10, 10))
		fly_tween.tween_property(particle, "global_position", end_pos + random_offset, 0.4)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly_tween.parallel().tween_property(particle, "scale", Vector2(0.3, 0.3), 0.4)
		fly_tween.tween_property(particle, "modulate:a", 0.0, 0.1)

	# 清理
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(particle_container):
		particle_container.queue_free()


## 获取金币栏图标位置（用于粒子特效终点）
func _get_gold_bar_position() -> Vector2:
	var gold_icon: Node = get_node_or_null("MainLayout/TopBar/ResourceDisplay/GoldContainer/GoldRow/GoldIcon")
	if gold_icon != null:
		var pos: Vector2 = gold_icon.global_position + Vector2(20, 20)
		print(">>> [GameBoard] gold_icon global_position: ", gold_icon.global_position, " -> target: ", pos)
		return pos
	# 回退到 resource_display 的金币区域
	var resource_display: Node = get_node_or_null("MainLayout/TopBar/ResourceDisplay")
	if resource_display != null:
		var pos: Vector2 = resource_display.global_position + Vector2(200, 30)
		print(">>> [GameBoard] resource_display global_position: ", resource_display.global_position, " -> target: ", pos)
		return pos
	print(">>> [GameBoard] gold_bar_position fallback: ", Vector2(300, 50))
	return Vector2(300, 50)  # 最终回退


## 获取体力条图标位置（用于粒子特效终点）
func _get_energy_bar_position() -> Vector2:
	var energy_icon: Node = get_node_or_null("MainLayout/TopBar/ResourceDisplay/EnergyContainer/EnergyRow/EnergyIcon")
	if energy_icon != null:
		return energy_icon.global_position + Vector2(20, 20)  # 图标中心偏移
	# 回退到 resource_display 的体力区域
	var resource_display: Node = get_node_or_null("MainLayout/TopBar/ResourceDisplay")
	if resource_display != null:
		return resource_display.global_position + Vector2(50, 30)
	return Vector2(100, 50)  # 最终回退


## 经验粒子特效：爆炸散开 + 收束飞向等级条位置（与 building_ui 一致）
func _play_exp_particle_effect(start_pos: Vector2, exp_amount: int) -> void:
	# 查找等级条位置（TopBar/ResourceDisplay区域）
	var exp_bar_pos: Vector2 = Vector2(400, 50)  # 默认位置，会动态获取

	var resource_display := get_node_or_null("MainLayout/TopBar/ResourceDisplay")
	if resource_display != null:
		exp_bar_pos = resource_display.global_position + Vector2(100, 30)

	# 创建粒子节点
	var particle_container := Node2D.new()
	particle_container.z_index = 15
	add_child(particle_container)
	particle_container.global_position = start_pos

	# 经验图标
	var EXP_ICON := preload("res://art/sprites/UI/icon/jingyan.png")

	# 粒子数量根据经验值调整（每50点一个粒子，最多10个）
	var particle_count := mini(maxi(exp_amount / 50, 1), 10)
	var particles: Array[Sprite2D] = []

	# Phase 1: 爆炸散开 (0.3s)
	for i in range(particle_count):
		var particle := Sprite2D.new()
		particle.texture = EXP_ICON
		particle.scale = Vector2(0.4, 0.4)
		particle_container.add_child(particle)
		particle.global_position = start_pos
		particles.append(particle)

		var angle: float = TAU * float(i) / float(particle_count) + randf_range(-0.2, 0.2)
		var scatter_dist: float = randf_range(25, 50)
		var scatter_pos: Vector2 = start_pos + Vector2(cos(angle), sin(angle)) * scatter_dist

		var scatter_tween := create_tween()
		scatter_tween.tween_property(particle, "global_position", scatter_pos, 0.3)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		scatter_tween.parallel().tween_property(particle, "scale", Vector2(0.6, 0.6), 0.3)

	# Phase 2: 收束飞向经验条 (0.4s)
	await get_tree().create_timer(0.3).timeout
	for particle in particles:
		if not is_instance_valid(particle):
			continue
		var fly_tween := create_tween()
		var random_offset := Vector2(randf_range(-10, 10), randf_range(-10, 10))
		fly_tween.tween_property(particle, "global_position", exp_bar_pos + random_offset, 0.4)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly_tween.parallel().tween_property(particle, "scale", Vector2(0.3, 0.3), 0.4)
		fly_tween.tween_property(particle, "modulate:a", 0.0, 0.1)

	# 清理
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(particle_container):
		particle_container.queue_free()


func _play_merge_animation(cell_index: int) -> void:
	if cell_index < 0 or cell_index >= cell_sprites.size():
		return
	var sprite: Control = cell_sprites[cell_index]
	if sprite == null:
		return
	play_shake_animation(sprite)


## 落地动效：缩小到0.95再丝滑还原
func _play_land_animation(cell_index: int) -> void:
	if cell_index < 0 or cell_index >= cell_sprites.size():
		return
	var sprite: Control = cell_sprites[cell_index]
	if sprite == null or not is_instance_valid(sprite):
		return

	# 重置scale（防止残留）
	sprite.scale = Vector2(1.0, 1.0)


## 播放脉冲动画：1 -> 1.15 -> 1（用于生成/合成落地提示）
func _play_pulse_animation(cell_index: int) -> void:
	if cell_index < 0 or cell_index >= cell_sprites.size():
		return
	var sprite: Control = cell_sprites[cell_index]
	if sprite == null or not is_instance_valid(sprite):
		return

	# 先重置scale
	sprite.scale = Vector2(1.0, 1.0)

	# 脉冲动画：1 -> 1.15 -> 1
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.12)


# ---- 生成器生产 (任务 2.X) ----

func _try_produce_item(cell_index: int) -> void:
	var bd: BoardData = GameManager.board_data
	var item: DataModels.BoardItemData = bd.get_item_at_index(cell_index)
	if item == null:
		return

	# autoproduction不需要点击
	if ItemManager.is_autoproduction(item.id):
		return

	# 检查能量是否足够
	if not GameManager.spend_energy(1):
		TipManager.show_tip(LocalizationSystem.get_text("game_board.energy_insufficient"))
		return

	# 尝试生产物品（传入board_index以消耗库存）
	var produced: DataModels.BoardItemData = ItemManager.produce_item(item.id, cell_index)
	if produced == null:
		# 生产失败，返还能量
		GameManager.restore_energy(1)
		return

	# 找到空位放置
	var empty_pos: Vector2i = Vector2i(-1, -1)
	for i in range(BoardData.BOARD_SLOTS):
		if bd.get_item_at_index(i) == null:
			empty_pos = BoardData.index_to_pos(i)
			break

	if empty_pos == Vector2i(-1, -1):
		# 棋盘已满，返还能量
		GameManager.restore_energy(1)
		TipManager.show_tip(LocalizationSystem.get_text("game_board.board_full"))
		return

	# 播放生产成功音效
	SoundSystem.play_merge()

	# 获取起始位置和目标格子索引
	var start_pos: Vector2 = cell_panels[cell_index].global_position + Vector2(CELL_SIZE / 2, CELL_SIZE / 2)
	var target_index: int = BoardData.pos_to_index(empty_pos)

	# 播放产出动画
	if not spawn_item(start_pos, produced, target_index):
		GameManager.restore_energy(1)

	# 每次棋子操作后自动存档
	GameManager._auto_save()


# ---- 献祭 (任务 2.5) ----

func _sacrifice_character(cell_index: int) -> void:
	var bd: BoardData = GameManager.board_data
	var pos: Vector2i = BoardData.index_to_pos(cell_index)
	var ch: DataModels.BoardItemData = bd.get_item_at(pos)
	if ch == null:
		return

	var refund: int = GameManager.calc_sacrifice_energy(ch.level)
	
	# 遗物: 献祭效率 (ID 21) - 增加20%能量返还
	if ItemDatabase.has_relic(21, GameManager.relics):
		var cfg: Dictionary = MechanicsDb.get_relic_effect(21)
		var bonus_ratio: float = cfg.get("bonus_ratio", 0.2)
		refund = int(refund * (1.0 + bonus_ratio))
	
	# 获取位置用于粒子特效（在移除物品前获取）
	var start_cell: Control = cell_panels[cell_index]
	var start_pos: Vector2 = start_cell.global_position + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	var coin_bar_pos: Vector2 = _get_gold_bar_position()

	bd.remove_item(pos)
	GameManager.board_items_changed.emit()
	GameManager.restore_energy(refund)

	# 遗物: 献祭金币 (ID 22) - 献祭时获得金币
	if ItemDatabase.has_relic(22, GameManager.relics):
		var cfg22: Dictionary = MechanicsDb.get_relic_effect(22)
		var gold_bonus: int = cfg22.get("gold_per_sacrifice", 1)
		# 播放金币粒子特效
		_play_coin_particle_effect(start_pos, coin_bar_pos, 5)
		GameManager.add_gold(gold_bonus)

	selected_index = -1
	_refresh_board_display()
	_update_character_detail_panel()
	# Tutorial: advance after sacrifice (step 3 = details/sacrifice/encyclopedia)
	_try_advance_tutorial(3)


## 出售选中的物品，获得金币
func _sell_selected_item(cell_index: int) -> void:
	var bd: BoardData = GameManager.board_data
	var pos: Vector2i = BoardData.index_to_pos(cell_index)
	var ch: DataModels.BoardItemData = bd.get_item_at(pos)
	if ch == null:
		return

	# 检查是否可出售
	if not ItemManager.is_sellable(ch.id):
		return

	# 计算出售价格: 2^(level-1)
	var sell_price: int = ItemManager.get_sell_price(ch.id, ch.level)

	# 获取位置用于粒子特效
	var start_cell: Control = cell_panels[cell_index]
	var start_pos: Vector2 = start_cell.global_position + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	var coin_bar_pos: Vector2 = _get_gold_bar_position()

	# 播放金币粒子特效（粒子数量根据等级调整）
	var particle_count := mini(maxi(ch.level, 1), 10)
	_play_coin_particle_effect(start_pos, coin_bar_pos, particle_count)

	# 获得金币
	GameManager.add_gold(sell_price)

	# 从棋盘移除物品
	bd.remove_item(pos)
	GameManager.board_items_changed.emit()

	selected_index = -1
	_refresh_board_display()
	_update_character_detail_panel()


# ---- 拖拽系统 (任务 2.3) ----

func _start_drag(cell_index: int, _mouse_pos: Vector2) -> void:
	is_dragging = true
	drag_index = cell_index
	selected_index = cell_index

	# 拖拽容器，将容器从原格子移出到根节点
	var container: Control = cell_containers[cell_index]
	var old_parent: Node = container.get_parent()
	old_parent.remove_child(container)
	get_tree().root.add_child(container)
	container.z_index = 50
	container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	container.position = _mouse_pos - Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)

	# 拖拽时隐藏producer_fx（避免闪烁）
	if cell_producer_fx.size() > cell_index and is_instance_valid(cell_producer_fx[cell_index]):
		cell_producer_fx[cell_index].visible = false

	# 隐藏原始格子
	#cell_panels[cell_index].modulate.a = 0.3

	# 找到所有可合成的目标格子
	_find_merge_targets(cell_index)

	# 显示所有可合成目标的高亮动画（透明度0.5）
	_update_merge_highlights()



func _create_drag_preview(cell_index: int, with_outline: bool = false) -> Control:
	var bd: BoardData = GameManager.board_data
	var ch: DataModels.BoardItemData = bd.get_item_at_index(cell_index)

	# 根节点只用于定位，不显示背景
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 让事件穿透到下层
	preview.z_index = 50  # 拖拽层级（低于弹窗遮罩）
	preview.z_as_relative = false  # 使用全局z_index

	# 精灵图：使用BoardItemData的sprite路径
	var sprite_path: String = ch.get_sprite_path()
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
	# 更新拖拽中的物品容器位置（使物品中心对准鼠标）
	if is_dragging and drag_index >= 0:
		cell_containers[drag_index].position = mouse_pos - Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)

	# 高亮悬停的格子
	hover_index = _get_hovered_cell_index(mouse_pos)
	is_hovering_dorm = _is_near_dorm_button(mouse_pos)
	is_hovering_backpack = _is_near_backpack_item(mouse_pos)
	_refresh_board_display()

	# 更新高亮效果（拖拽悬停在可合成目标上时显示）
	_update_merge_highlights()

	# 临时高亮目标格子 & 更新拖拽预览Outline
	var is_over_mergeable: bool = false
	if hover_index >= 0 and hover_index != drag_index:
		var bd: BoardData = GameManager.board_data
		var target_ch: DataModels.BoardItemData = bd.get_item_at_index(hover_index)
		var sel_ch: DataModels.BoardItemData = bd.get_item_at_index(drag_index)

		if target_ch == null:
			# 移动到空格子
			# cell_rects[hover_index].color = COLOR_SELECTED
			pass
		elif target_ch.get_merge_chain() == sel_ch.get_merge_chain() and target_ch.level == sel_ch.level:
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
	var col := int(local_pos.x / (grid_rect.size.x / GRID_COLS))
	var row := int(local_pos.y / (grid_rect.size.y / GRID_ROWS))

	if row < 0 or row >= GRID_ROWS or col < 0 or col >= GRID_COLS:
		return -1

	return row * GRID_COLS + col


func _is_near_backpack_item(mouse_pos: Vector2) -> bool:
	# 检查是否悬停在背包物品上（ID 99）
	var bd: BoardData = GameManager.board_data
	for i in range(BoardData.BOARD_SLOTS):
		var ch: DataModels.BoardItemData = bd.get_item_at_index(i)
		if ch != null and ch.id == 99:  # 背包物品
			var rect: Rect2 = cell_panels[i].get_global_rect()
			if rect.has_point(mouse_pos):
				return true
	return false


func _is_near_dorm_button(mouse_pos: Vector2) -> bool:
	if not is_instance_valid(dorm_button):
		return false
	# 扩展检测区域：宿舍按钮本身 + 周围扩展区域
	var dorm_rect: Rect2 = dorm_button.get_global_rect()
	var expand: int = 50  # 扩展50像素
	dorm_rect.position -= Vector2(expand, expand)
	dorm_rect.size += Vector2(expand * 2, expand * 2)
	return dorm_rect.has_point(mouse_pos)


func _update_dorm_highlight() -> void:
	if not is_instance_valid(dorm_button):
		return
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


## 将拖拽的容器移回原格子
func _move_sprite_back_to_cell(cell_index: int, from_position: Vector2 = Vector2.ZERO) -> void:
	if cell_index < 0 or cell_index >= cell_containers.size():
		return
	var container: Control = cell_containers[cell_index]
	# 从根节点移除
	container.get_parent().remove_child(container)
	# 添加回原格子
	cell_panels[cell_index].add_child(container)
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.position = Vector2.ZERO

	# 如果有起始位置，播放平滑移回动画
	if from_position != Vector2.ZERO:
		# 设置初始位置（动画起点）
		container.position = from_position - cell_panels[cell_index].global_position
		container.scale = Vector2(1, 1)
		# 创建平滑移回动画
		var tween := create_tween()
		tween.tween_property(container, "position", Vector2.ZERO, 0.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		container.scale = Vector2(1, 1)


func _end_drag(_target_index: int) -> void:
	if not is_dragging:
		return

	# 检查目标格子是否是Locked状态，是则返回原格子；Dusty状态只有物品不同时才返回
	if hover_index >= 0 and hover_index != drag_index:
		var bd: BoardData = GameManager.board_data
		var tgt_state: int = bd.get_grid_state(hover_index)
		var should_return: bool = false
		if tgt_state == BoardData.GridState.LOCKED:
			should_return = true
		elif tgt_state == BoardData.GridState.DUSTY:
			# Dusty状态：只有物品不同时才返回原格子（用id判断）
			var src_ch: DataModels.BoardItemData = bd.get_item_at_index(drag_index)
			var tgt_ch: DataModels.BoardItemData = bd.get_item_at_index(hover_index)
			if tgt_ch != null and tgt_ch.id != src_ch.id:
				should_return = true
		if should_return:
			# 目标格子不可用，强制返回原格子
			var sprite: TextureRect = cell_sprites[drag_index]
			var current_pos: Vector2 = sprite.global_position
			_move_sprite_back_to_cell(drag_index, current_pos)
			cell_panels[drag_index].modulate.a = 1.0
			is_dragging = false
			drag_index = -1
			hover_index = -1
			is_hovering_dorm = false
			is_hovering_backpack = false
			selected_index = -1
			merge_targets.clear()
			_update_merge_highlights()
			return

	# 将精灵移回原格子
	if drag_index >= 0 and drag_index < cell_panels.size():
		var sprite: TextureRect = cell_sprites[drag_index]
		var current_pos: Vector2 = sprite.global_position
		_move_sprite_back_to_cell(drag_index, current_pos)
		cell_panels[drag_index].modulate.a = 1.0

	# 检查是否拖放到宿舍
	if is_hovering_dorm:
		_drag_to_dorm()
		# 恢复宿舍按钮颜色
		dorm_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		is_dragging = false
		drag_index = -1
		hover_index = -1
		is_hovering_dorm = false
		is_hovering_backpack = false
		selected_index = -1
		merge_targets.clear()
		return

	# 检查是否拖放到背包物品上
	if is_hovering_backpack:
		_drag_to_backpack()
		is_dragging = false
		drag_index = -1
		hover_index = -1
		is_hovering_backpack = false
		selected_index = -1
		merge_targets.clear()
		return

	# 执行放置操作: 使用悬停的格子作为目标
	if hover_index >= 0 and hover_index != drag_index:
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
	is_hovering_backpack = false
	merge_targets.clear()
	# 隐藏所有高亮效果
	_update_merge_highlights()
	# 拖拽结束后刷新所有producer_fx可见性
	_refresh_producer_fx_all()
	# 恢复宿舍按钮颜色
	dorm_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	# 每次棋子操作后自动存档
	GameManager._auto_save()


# ---- 刷新所有producer_fx可见性 ----
func _refresh_producer_fx_all() -> void:
	for i in range(BoardData.BOARD_SLOTS):
		_update_producer_fx_visibility(i)


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

		# 更新状态叠加层（锁定/灰尘）
		_update_cell_state_overlay(i)

		# 更新生成器特效可见性
		_update_producer_fx_visibility(i)

		# 更新冷却倒计时可见性
		if ProducerManager.is_in_cooldown(i):
			_show_cooldown_timer(i)
		else:
			_hide_cooldown_timer(i)

		# 如果格子正在移动动画中，跳过渲染
		if i in moving_cells:
			if cell_sprites[i] != null:
				cell_sprites[i].visible = false
			if cell_containers[i] != null:
				cell_containers[i].visible = false
			continue

		# 获取格子状态
		var grid_state: int = bd.get_grid_state(i)

		var ch: DataModels.BoardItemData = bd.get_item_at_index(i)
		if ch != null and grid_state != BoardData.GridState.LOCKED and cell_sprites[i] != null:
			# 加载精灵图：使用BoardItemData的sprite路径
			# LOCKED 状态不显示物品图片，DUSTY 仍显示图片但叠加 cell7
			var sprite_path: String = ch.get_sprite_path()
			var tex_exists: bool = ResourceLoader.exists(sprite_path)
			var tex := load(sprite_path) if tex_exists else null
			cell_sprites[i].texture = tex
			var show_item: bool = (tex != null)
			cell_sprites[i].visible = show_item
			if cell_containers[i] != null:
				cell_containers[i].visible = show_item
			# DUSTY 状态：物品显示为 0.7 灰度
			if grid_state == BoardData.GridState.DUSTY:
				cell_sprites[i].modulate = Color(0.7, 0.7, 0.7, 1.0)
			else:
				cell_sprites[i].modulate = Color.WHITE
			if tex == null:
				print(">>> [Debug] 精灵图加载失败: %s" % sprite_path)
		else:
			if cell_sprites[i] != null:
				cell_sprites[i].texture = null
				cell_sprites[i].visible = false
			if cell_containers[i] != null:
				cell_containers[i].visible = false

	# 更新高亮效果（拖拽时动态显示）
	_update_merge_highlights()

	# 更新任务物品图标
	_update_task_icons()


## 更新格子状态叠加层显示
func _update_cell_state_overlay(index: int) -> void:
	var bd: BoardData = GameManager.board_data
	var state: int = bd.get_grid_state(index)
	var overlay: TextureRect = cell_state_overlays[index]

	if state == BoardData.GridState.LOCKED:
		# 锁定状态：根据行列奇偶性交替使用 cell5/cell6
		var pos: Vector2i = BoardData.index_to_pos(index)
		overlay.texture = CELL_LOCKED_EVEN_TEXTURE if (pos.x + pos.y) % 2 == 0 else CELL_LOCKED_ODD_TEXTURE
		overlay.visible = true
	elif state == BoardData.GridState.DUSTY:
		# 灰尘状态：使用 cell7
		overlay.texture = CELL_DUSTY_TEXTURE
		overlay.visible = true
	else:
		# EMPTY 或 OCCUPIED：隐藏叠加层
		overlay.visible = false


## 更新任务物品图标显示
func _update_task_icons() -> void:
	var task_info: Dictionary = TaskManager.get_task_items_info()
	var board_items: Array = task_info.get("board", [])

	# 获取任务栏位置（用于计算距离）
	var task_panel_path := "MainLayout/MiddleBar/BottomHUDContainer/ScrollContainer/ContentHBox/ZoneC"
	var task_panel: Control = get_node_or_null(task_panel_path)
	var task_bar_pos: Vector2 = task_panel.get_global_position() + Vector2(task_panel.size.x / 2, task_panel.size.y / 2) if task_panel else Vector2.ZERO

	# 获取任务需求数量
	var current_task: Dictionary = TaskManager.get_current_task()
	var need_items: Array = current_task.get("needItems", []) if not current_task.is_empty() else []
	# 统计每个物品ID的需求数量
	var need_counts: Dictionary = {}
	for need_id in need_items:
		var id_int: int = int(need_id)
		need_counts[id_int] = need_counts.get(id_int, 0) + 1

	# 按距离排序并选择每个ID最近的物品
	var selected_indices: Array = []
	for need_id in need_counts.keys():
		var need_count: int = need_counts[need_id]
		# 找出所有匹配该ID的物品
		var matching_items: Array = []
		for item_data in board_items:
			if int(item_data["id"]) == need_id:
				matching_items.append(item_data)

		# 按距离排序（近的在前）
		matching_items.sort_custom(func(a, b):
			var pos_a: Vector2i = a["pos"]
			var pos_b: Vector2i = b["pos"]
			var cell_a: Control = cell_panels[pos_a.y * GRID_COLS + pos_a.x] if pos_a.y * GRID_COLS + pos_a.x < cell_panels.size() else null
			var cell_b: Control = cell_panels[pos_b.y * GRID_COLS + pos_b.x] if pos_b.y * GRID_COLS + pos_b.x < cell_panels.size() else null
			if cell_a == null or cell_b == null:
				return false
			var dist_a: float = cell_a.global_position.distance_to(task_bar_pos)
			var dist_b: float = cell_b.global_position.distance_to(task_bar_pos)
			return dist_a < dist_b
		)

		# 只选择最近的need_count个
		for i in range(mini(need_count, matching_items.size())):
			selected_indices.append(matching_items[i]["index"])

	# 更新每个格子的任务图标可见性
	for i in range(BoardData.BOARD_SLOTS):
		if i < cell_task_icons.size() and is_instance_valid(cell_task_icons[i]):
			cell_task_icons[i].visible = selected_indices.has(i)


## 更新可合成高亮效果（拖拽时显示）
func _update_merge_highlights() -> void:
	# 如果不在拖拽状态，隐藏所有高亮
	if not is_dragging:
		for i in range(BoardData.BOARD_SLOTS):
			if is_instance_valid(cell_highlight_effects[i]):
				cell_highlight_effects[i].visible = false
		return

	# 显示所有可合成目标的高亮，透明度0.5，白色（排除LOCKED状态）
	for target_index in merge_targets:
		# 跳过LOCKED状态的格子
		if GameManager.board_data.get_grid_state(target_index) == BoardData.GridState.LOCKED:
			continue
		if is_instance_valid(cell_highlight_effects[target_index]):
			cell_highlight_effects[target_index].visible = true
			cell_highlight_effects[target_index].texture = SELECT_FRAMES[_highlight_frame_index] if not SELECT_FRAMES.is_empty() else null
			cell_highlight_effects[target_index].modulate = Color(1, 1, 1, 0.5)

	# 如果悬停在某个可合成目标上，该目标透明度改为1，颜色偏红（排除LOCKED状态）
	if hover_index >= 0 and merge_targets.has(hover_index) and GameManager.board_data.get_grid_state(hover_index) != BoardData.GridState.LOCKED:
		if is_instance_valid(cell_highlight_effects[hover_index]):
			cell_highlight_effects[hover_index].modulate = Color(1, 0.6, 0.6, 1.0)

	# 隐藏不在目标列表中的高亮
	for i in range(BoardData.BOARD_SLOTS):
		if not merge_targets.has(i) and is_instance_valid(cell_highlight_effects[i]):
			cell_highlight_effects[i].visible = false

	# 启动动画（如果未运行）
	if not merge_targets.is_empty() and not SELECT_FRAMES.is_empty():
		_start_highlight_animation()


## 查找拖拽角色可合成的目标格子
func _find_merge_targets(drag_source_index: int) -> void:
	merge_targets.clear()
	var bd: BoardData = GameManager.board_data
	var source_ch: DataModels.BoardItemData = bd.get_item_at_index(drag_source_index)

	if source_ch == null:
		return

	# 如果物品已达顶级（无法合成），不显示高亮
	if not source_ch.can_merge():
		return

	# 遍历所有格子，找到相同合成链、相同等级的角色
	for i in range(BoardData.BOARD_SLOTS):
		if i == drag_source_index:
			continue

		var target_ch: DataModels.BoardItemData = bd.get_item_at_index(i)
		# 检查 merge_chain (物品链ID) 和 level 都相同才能合成
		if target_ch != null and target_ch.get_merge_chain() == source_ch.get_merge_chain() and target_ch.level == source_ch.level:
			merge_targets.append(i)



## 查找可合成的格子
func _find_merge_candidates() -> Array:
	var bd: BoardData = GameManager.board_data
	var candidates: Array = []

	for i in range(BoardData.BOARD_SLOTS):
		var ch: DataModels.BoardItemData = bd.get_item_at_index(i)
		if ch == null or not ch.can_merge():
			continue

		# 检查相邻格子是否有相同合成链、相同等级的角色
		var neighbors := _get_neighbors(i)
		for neighbor_index in neighbors:
			var neighbor_ch: DataModels.BoardItemData = bd.get_item_at_index(neighbor_index)
			if neighbor_ch != null and neighbor_ch.can_merge() and neighbor_ch.get_merge_chain() == ch.get_merge_chain() and neighbor_ch.level == ch.level:
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
	if y < BoardData.GRID_ROWS - 1:
		neighbors.append(BoardData.pos_to_index(Vector2i(x, y + 1)))
	# 左
	if x > 0:
		neighbors.append(BoardData.pos_to_index(Vector2i(x - 1, y)))
	# 右
	if x < BoardData.GRID_COLS - 1:
		neighbors.append(BoardData.pos_to_index(Vector2i(x + 1, y)))

	return neighbors


## 启动高亮序列帧动画（持续运行，独立于格子列表）
func _start_highlight_animation() -> void:
	if SELECT_FRAMES.is_empty():
		push_warning(">>> [GameBoard] 序列帧纹理未加载！")
		return

	# 如果动画已经在运行，不重复创建
	if _select_tween and _select_tween.is_valid():
		return


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
		if is_instance_valid(cell_highlight_effects[i]) and cell_highlight_effects[i].visible:
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
# 已移除（UI节点不存在）


## 飘字系统：显示资源增减动画
## is_increase: true=增加（向上飘，绿色），false=减少（向下飘，红色）
func _show_float_text(label_node: Label, amount: int, is_increase: bool) -> void:
	var float_label := Label.new()
	float_label.text = "%+d" % amount if is_increase else "%d" % amount
	float_label.z_index = 100  # 确保在最上层

	# 设置飘字样式
	var font_color: Color = Color(0.2, 1.0, 0.2, 1.0) if is_increase else Color(1.0, 0.2, 0.2, 1.0)
	float_label.add_theme_color_override("font_color", font_color)
	float_label.add_theme_font_size_override("font_size", 28)

	# 设置位置：紧贴目标label（先设为相同位置，等添加后再获取正确的global_position）
	float_label.position = label_node.position
	float_label.size = Vector2(100, 40)

	# 添加到场景（必须在获取global_position之前）
	add_child(float_label)

	# 现在可以获取正确的global_position
	var start_pos: Vector2 = float_label.global_position
	var end_offset: Vector2 = Vector2(0, -40) if is_increase else Vector2(0, 40)

	# 创建飘字动画
	var tween := create_tween()
	if is_increase:
		# 增加：向上飘并渐隐
		tween.set_parallel(true)
		tween.tween_property(float_label, "global_position", start_pos + end_offset, 0.8)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(float_label, "modulate:a", 0.0, 0.8)
	else:
		# 减少：从上方来并渐隐
		tween.set_parallel(true)
		float_label.global_position = start_pos + Vector2(0, -20)
		tween.tween_property(float_label, "global_position", start_pos + Vector2(0, 20), 0.6)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(float_label, "modulate:a", 0.0, 0.6)

	tween.finished.connect(func():
		float_label.queue_free()
	, CONNECT_ONE_SHOT)


func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = str(new_gold)


func _on_energy_changed(new_energy: int) -> void:
	energy_label.text = str(new_energy)
	_update_energy_timer_visible(new_energy)


func _update_energy_timer_visible(current_energy: int) -> void:
	# 体力在100以下时显示倒计时（100时不再自动恢复）
	if current_energy >= 100:
		energy_timer.visible = false
	else:
		energy_timer.visible = true
		_update_energy_timer_text()


func _update_energy_timer_text() -> void:
	if energy_timer == null or not energy_timer.visible:
		return
	var current_time: float = Time.get_unix_time_from_system()
	var elapsed: float = current_time - GameManager.last_energy_update_time
	var remaining: float = GameManager.ENERGY_RECOVERY_INTERVAL - elapsed
	if remaining < 0:
		remaining = 0
	var seconds: int = int(remaining)
	@warning_ignore("integer_division")
	var minutes: int = seconds / 60
	seconds = seconds % 60
	energy_timer.text = "%d:%02d" % [minutes, seconds]


func _on_diamond_changed(new_diamond: int) -> void:
	diamond_label.text = str(new_diamond)


func _on_round_changed(_new_round: int) -> void:
	pass  # 回合数已隐藏


func _on_items_changed() -> void:
	_refresh_item_slots()


func _on_board_items_changed() -> void:
	_refresh_board_display()


func _on_task_items_updated(_task_items_info: Dictionary) -> void:
	_update_task_icons()


# ---- 角色生成 (任务 2.2) ----

func _on_spawn_pressed(job: int) -> void:
	# 播放按钮点击音效
	SoundSystem.play_button_click()

	# 检查棋盘是否已满
	if GameManager.board_data.is_board_full():
		TipManager.show_tip(LocalizationSystem.get_text("game_board.board_full"))
		return

	if not GameManager.spend_energy(1):
		TipManager.show_tip(LocalizationSystem.get_text("game_board.energy_insufficient"))
		return

	# 根据职业获取物品链 (0=战士, 1=法师, 2=牧师)
	# 战士链: 1,2,3 → chain_id 前缀 1,2,3
	# 法师链: 4,5 → chain_id 前缀 4,5
	# 牧师链: 6,7 → chain_id 前缀 6,7

	# 获取该职业链的所有可合成物品
	var candidates: Array = []
	match job:
		0:  # 战士
			candidates = ItemManager.get_items_by_chain(1) + ItemManager.get_items_by_chain(2) + ItemManager.get_items_by_chain(3)
		1:  # 法师
			candidates = ItemManager.get_items_by_chain(4) + ItemManager.get_items_by_chain(5)
		2:  # 牧师
			candidates = ItemManager.get_items_by_chain(6) + ItemManager.get_items_by_chain(7)
		_:
			candidates = ItemManager.get_items_by_chain(1)

	if candidates.is_empty():
		# 尝试获取随机物品
		candidates = ItemManager.all_items

	# 过滤出可合成的物品
	var mergeable: Array = []
	for c in candidates:
		if c.can_merge():
			mergeable.append(c)

	var item: DataModels.BoardItemData
	if not mergeable.is_empty():
		item = mergeable[randi_range(0, mergeable.size() - 1)].duplicate()
	else:
		item = candidates[randi_range(0, candidates.size() - 1)].duplicate()

	var pos: Vector2i = GameManager.board_data.place_item_first_empty(item)
	if pos == Vector2i(-1, -1):
		GameManager.restore_energy(1)
		return

	GameManager.board_items_changed.emit()

	# 获取生成按钮位置和目标格子位置
	var spawn_btn: BaseButton
	match job:
		DataModels.Job.WARRIOR: spawn_btn = spawn_warrior
		DataModels.Job.MAGE: spawn_btn = spawn_mage
		DataModels.Job.PRIEST: spawn_btn = spawn_priest
		_: spawn_btn = spawn_warrior

	var start_pos: Vector2 = spawn_btn.global_position + Vector2(spawn_btn.size.x / 2, spawn_btn.size.y / 2)
	var target_index: int = pos.y * GRID_COLS + pos.x
	var target_cell: Control = cell_panels[target_index]
	var end_pos: Vector2 = target_cell.global_position + Vector2(CELL_SIZE / 2, CELL_SIZE / 2)

	# 播放生成动画
	_play_spawn_animation(item, start_pos, end_pos, target_index)

	# Tutorial: advance after spawn (step 0 = first spawn, step 1 = second spawn/merge)
	_try_advance_tutorial(0)


## 生成动画：从按钮位置飞到目标格子（参考 _create_drag_preview 的方式）
func _play_spawn_animation(ch: DataModels.BoardItemData, start_pos: Vector2, end_pos: Vector2, target_index: int) -> void:
	# 标记目标格子为移动中（动画完成前不显示）
	moving_cells.append(target_index)

	# 刷新显示（目标格子不显示角色）
	_refresh_board_display()

	# 获取物品纹理以确定原始尺寸
	var sprite_path: String = ch.get_sprite_path()
	var item_tex: Texture2D = null
	if ResourceLoader.exists(sprite_path):
		item_tex = load(sprite_path)

	# 使用物品原始纹理尺寸（而非CELL_SIZE）
	var item_size: Vector2 = Vector2(CHAR_SIZE, CHAR_SIZE)
	if item_tex != null:
		item_size = item_tex.get_size()

	# 创建动画精灵
	var anim_sprite := Control.new()
	anim_sprite.custom_minimum_size = item_size
	anim_sprite.z_index = 10
	anim_sprite.z_as_relative = false
	anim_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 创建 Sprite 节点
	var sprite := TextureRect.new()
	sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.custom_minimum_size = item_size
	sprite.z_index = 0
	if item_tex != null:
		sprite.texture = item_tex

	anim_sprite.add_child(sprite)
	add_child(anim_sprite)
	anim_sprite.global_position = start_pos - item_size / 2
	# 不再使用scale动画，物品直接以原始尺寸飞行

	# 动画：从按钮位置飞到目标格子
	var tween := create_tween()
	tween.tween_property(anim_sprite, "global_position", end_pos - item_size / 2, 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 动画结束后清理并刷新显示
	tween.finished.connect(func():
		anim_sprite.queue_free()
		moving_cells.erase(target_index)
		_refresh_board_display()
		_play_land_animation(target_index)
	)

	_try_advance_tutorial(1)


# ---- 宿舍操作 ----

func _on_dorm_pressed() -> void:
	SoundSystem.play_button_click()
	dorm_visible = !dorm_visible
	dorm_scene_instance.visible = dorm_visible
	if dorm_visible:
		_refresh_dorm_panel()


func _on_dorm_take_pressed(dorm_index: int) -> void:
	SoundSystem.play_button_click()
	if GameManager.board_data.is_board_full():
		TipManager.show_tip(LocalizationSystem.get_text("game_board.board_full"))
		return
	var item: DataModels.BoardItemData = GameManager.board_data.take_from_dormitory(dorm_index)
	if item == null:
		return
	var pos: Vector2i = GameManager.board_data.place_item_first_empty(item)
	GameManager.board_items_changed.emit()
	_refresh_dorm_panel()
	_refresh_board_display()
	# 每次棋子操作后自动存档
	GameManager._auto_save()


func _on_dorm_backdrop_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_on_dorm_close()


func _on_dorm_close() -> void:
	SoundSystem.play_button_click()
	var bd: BoardData = GameManager.board_data
	
	# 执行所有标记移出的角色
	if bd.marked_for_removal.size() > 0:
		if not bd.can_remove_marked():
			TipManager.show_tip(LocalizationSystem.get_text("game_board.cannot_remove_board_full"))
			bd.marked_for_removal.clear()
			_hide_dorm_ui()
		else:
			# 执行数据操作，获取每个角色被放置到的棋盘索引
			var moved_data: Array = bd.execute_removal()
			# 每次棋子操作后自动存档
			GameManager._auto_save()

			# 获取宿舍按钮中心位置作为动画起点（必须在隐藏面板之前获取）
			var dorm_pos: Vector2 = Vector2.ZERO
			if is_instance_valid(dorm_button):
				dorm_pos = dorm_button.global_position + Vector2(dorm_button.size.x / 2, dorm_button.size.y / 2)

			if moved_data.size() > 0:
				TipManager.show_tip(LocalizationSystem.get_text("game_board.removed_characters", {"count": moved_data.size()}))
				# 先隐藏宿舍UI
				_hide_dorm_ui()
				# 播放动画
				_play_dorm_to_board_animation(moved_data, dorm_pos)
				return
	
	_hide_dorm_ui()


func _hide_dorm_ui() -> void:
	dorm_visible = false
	dorm_scene_instance.visible = false


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
			if cell_containers[board_idx] != null:
				cell_containers[board_idx].visible = false
	
	# 为每个角色播放从宿舍飞到棋盘的动画
	for data in moved_data:
		var ch: DataModels.BoardItemData = data["char"]
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
		anim_sprite.z_index = 15  # 宿舍动画层级（低于弹窗）
		
		# 加载精灵图
		var sprite_path: String = ch.get_sprite_path()
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
			if board_idx >= 0 and board_idx < cell_sprites.size():
				cell_sprites[board_idx].visible = true
				if cell_containers[board_idx] != null:
					cell_containers[board_idx].visible = true
			_play_land_animation(board_idx)
		)


func _drag_to_dorm() -> void:
	if drag_index < 0:
		return
	var bd: BoardData = GameManager.board_data
	var ch: DataModels.BoardItemData = bd.get_item_at_index(drag_index)
	if ch == null:
		return
	var pos: Vector2i = BoardData.index_to_pos(drag_index)
	bd.board_to_dormitory(pos)
	
	# 重置拖拽状态，确保高亮被隐藏
	is_dragging = false
	drag_index = -1
	merge_targets.clear()
	
	selected_index = -1
	_refresh_board_display()
	_update_character_detail_panel()


## 拖拽物品存入背包
func _drag_to_backpack() -> void:
	if drag_index < 0:
		return
	var bd: BoardData = GameManager.board_data
	var ch: DataModels.BoardItemData = bd.get_item_at_index(drag_index)
	if ch == null:
		return

	# 背包物品本身不能存入背包
	if ch.id == 99:
		return

	# 添加到背包
	GameManager.add_to_backpack(ch)

	# 从棋盘移除（直接设置board数组）
	bd.board[drag_index] = null


	# 重置拖拽状态
	is_dragging = false
	drag_index = -1
	merge_targets.clear()
	selected_index = -1
	_refresh_board_display()
	_update_character_detail_panel()




# ---- 遗物栏操作（常驻显示）----

func _refresh_relic_panel() -> void:
	# 如果遗物面板节点不存在则跳过
	if not is_instance_valid(relic_panel) or not is_instance_valid(relic_list):
		return

	# 确保遗物面板可见
	relic_panel.modulate = Color.WHITE

	# 设置遗物列表间隔为10
	relic_list.add_theme_constant_override("separation", 10)

	# 清空旧内容
	for child in relic_list.get_children():
		child.queue_free()
	
	# 显示所有遗物（只显示图片）
	for i in range(GameManager.relics.size()):
		var relic: DataModels.ItemData = GameManager.relics[i]
		var relic_item: Button = Button.new()
		relic_item.custom_minimum_size = Vector2(60, 60)
		# 移除tooltip，使用按住显示
		# relic_item.tooltip_text = "%s\n%s" % [relic.name, relic.description]
		
		# 移除按钮的默认背景（去掉黑底）
		var empty_style := StyleBoxEmpty.new()
		relic_item.add_theme_stylebox_override("normal", empty_style)
		relic_item.add_theme_stylebox_override("hover", empty_style)
		relic_item.add_theme_stylebox_override("pressed", empty_style)
		relic_item.add_theme_stylebox_override("disabled", empty_style)
		
		# 只添加图片
		var texture_rect := TextureRect.new()
		texture_rect.texture = _get_relic_texture(relic)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		relic_item.add_child(texture_rect)

		relic_list.add_child(relic_item)
		
		# 连接事件（在添加到场景树后）
		relic_item.pressed.connect(_on_relic_pressed.bind(relic))
		relic_item.button_down.connect(_on_relic_button_down.bind(relic))
		relic_item.button_up.connect(_on_relic_button_up)
		relic_item.mouse_entered.connect(_on_relic_mouse_entered.bind(relic))
		relic_item.mouse_exited.connect(_on_relic_mouse_exited)
	
	# 更新翻页按钮状态：遗物未满时半透明禁用
	await get_tree().process_frame  # 等待布局更新
	if is_instance_valid(relic_scroll) and is_instance_valid(relic_prev_button) and is_instance_valid(relic_next_button):
		var need_scroll: bool = relic_list.size.x > relic_scroll.size.x
		relic_prev_button.disabled = not need_scroll
		relic_next_button.disabled = not need_scroll
		relic_prev_button.modulate = Color(1, 1, 1, 0.3) if not need_scroll else Color.WHITE
		relic_next_button.modulate = Color(1, 1, 1, 0.3) if not need_scroll else Color.WHITE


# ---- 背包系统 ----

## 打开背包界面
func _open_backpack_ui() -> void:
	if _backpack_visible:
		_close_backpack_ui()
		return

	_backpack_visible = true
	_setup_backpack_panel()
	_refresh_backpack_panel()
	_backpack_scene_instance.visible = true


## 设置背包面板（实例化场景）
func _setup_backpack_panel() -> void:
	if _backpack_scene_instance != null:
		return

	_backpack_scene_instance = BackpackScene.instantiate()
	_backpack_scene_instance.visible = false
	add_child(_backpack_scene_instance)

	# 连接信号
	_backpack_scene_instance.close_requested.connect(_on_backpack_close)
	_backpack_scene_instance.items_taken.connect(_on_backpack_items_taken)


## 刷新背包面板
func _refresh_backpack_panel() -> void:
	if _backpack_scene_instance:
		_backpack_scene_instance.refresh(GameManager.backpack_items)


## 关闭背包界面
func _close_backpack_ui() -> void:
	_backpack_visible = false
	if _backpack_scene_instance != null:
		_backpack_scene_instance.visible = false


func _on_backpack_close() -> void:
	SoundSystem.play_button_click()
	_close_backpack_ui()


## 背包物品移出到棋盘
func _on_backpack_items_taken(marked_indices: Array[int]) -> void:
	if marked_indices.is_empty():
		_close_backpack_ui()
		return

	var bd: BoardData = GameManager.board_data

	# 获取背包物品在棋盘上的位置（用于动画起点）
	var backpack_cell_pos: Vector2 = _get_backpack_cell_center()

	# 收集要移出的物品
	var sorted_indices: Array = marked_indices.duplicate()
	sorted_indices.sort_custom(func(a, b): return a > b)

	# 先收集物品和目标位置，确保都有空位再操作
	var moved_data: Array = []
	var items_to_remove: Array[int] = []

	for idx in sorted_indices:
		if idx >= 0 and idx < GameManager.backpack_items.size():
			var item: DataModels.BoardItemData = GameManager.backpack_items[idx]
			# 找到空棋盘位置
			var empty_idx: int = -1
			for i in range(BoardData.BOARD_SLOTS):
				if bd.get_item_at_index(i) == null:
					empty_idx = i
					break
			if empty_idx >= 0:
				bd.board[empty_idx] = item  # 放置到棋盘
				moved_data.append({"char": item, "board_index": empty_idx})
				items_to_remove.append(idx)
			else:
				# 棋盘已满，物品保留在背包
				pass

	# 清空成功移出的物品（从后往前移除）
	for idx in items_to_remove:
		GameManager.backpack_items.remove_at(idx)

	var moved_count: int = moved_data.size()

	# 先关闭背包UI
	_close_backpack_ui()

	# 播放动画
	if moved_count > 0:
		_play_backpack_to_board_animation(moved_data, backpack_cell_pos)
		TipManager.show_tip("已移出 %d 个物品到棋盘" % moved_count)
		# 每次棋子操作后自动存档
		GameManager._auto_save()


## 获取背包物品在棋盘上的格子中心位置
func _get_backpack_cell_center() -> Vector2:
	var bd: BoardData = GameManager.board_data
	for i in range(BoardData.BOARD_SLOTS):
		var ch: DataModels.BoardItemData = bd.get_item_at_index(i)
		if ch != null and ch.id == 99:  # 背包物品ID
			return cell_panels[i].global_position + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	# 找不到背包格子，使用面板中心
	return _get_backpack_panel_center()


## 获取背包面板中心位置
func _get_backpack_panel_center() -> Vector2:
	if _backpack_scene_instance != null and is_instance_valid(_backpack_scene_instance):
		var panel: Node = _backpack_scene_instance.get_node_or_null("BackpackPanel")
		if panel != null:
			return panel.global_position + Vector2(400, 500)  # 面板大小800x1000
	# 默认返回屏幕中心
	return get_viewport_rect().size / 2


## 播放背包飞到棋盘的动画
func _play_backpack_to_board_animation(moved_data: Array, start_pos: Vector2) -> void:
	# 先刷新棋盘显示，加载物品的 texture
	_refresh_board_display()

	# 隐藏目标格子上的物品显示（等动画结束再显示）
	for data in moved_data:
		var board_idx: int = data["board_index"]
		if board_idx >= 0 and board_idx < cell_sprites.size():
			cell_sprites[board_idx].visible = false
			if cell_containers[board_idx] != null:
				cell_containers[board_idx].visible = false

	# 为每个物品播放从背包飞到棋盘的动画
	for data in moved_data:
		var item: DataModels.BoardItemData = data["char"]
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
		anim_sprite.z_index = 15  # 动画层级（低于弹窗）

		# 加载精灵图
		var sprite_path: String = item.get_sprite_path()
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
			if board_idx >= 0 and board_idx < cell_sprites.size():
				cell_sprites[board_idx].visible = true
				if cell_containers[board_idx] != null:
					cell_containers[board_idx].visible = true
				_play_land_animation(board_idx)
		)


## 获取遗物图片
func _get_relic_texture(relic: DataModels.ItemData) -> Texture2D:
	# 遗物: ID 1-26
	var path := "res://art/sprites/UI/items/relic/relic_%03d.png" % relic.id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	
	# 如果加载失败，返回一个默认颜色纹理
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.4, 0.3, 0.5))
	return ImageTexture.create_from_image(image)


func _on_relic_pressed(relic: DataModels.ItemData) -> void:
	SoundSystem.play_button_click()
	# 点击时显示详细信息（如果提示未显示）
	if not _relic_tip_showing:
		var localized_relic: DataModels.ItemData = ItemDatabase.get_relic_by_id(relic.id)
		if localized_relic:
			TipManager.show_tip("%s\n%s" % [localized_relic.name, localized_relic.description], 2.0)
		else:
			TipManager.show_tip("%s\n%s" % [relic.name, relic.description], 2.0)
		_relic_tip_showing = true
		# 延迟重置标志
		await get_tree().create_timer(2.0).timeout
		_relic_tip_showing = false


func _on_relic_button_down(relic: DataModels.ItemData) -> void:
	# 按住时显示说明（触屏支持）
	if not _relic_tip_showing:
		var localized_relic: DataModels.ItemData = ItemDatabase.get_relic_by_id(relic.id)
		if localized_relic:
			TipManager.show_tip("%s\n%s" % [localized_relic.name, localized_relic.description], 10.0)
		else:
			TipManager.show_tip("%s\n%s" % [relic.name, relic.description], 10.0)
		_relic_tip_showing = true


func _on_relic_button_up() -> void:
	# 松开时隐藏说明（延迟隐藏，避免闪烁）
	await get_tree().create_timer(0.1).timeout
	TipManager.hide_tip()
	_relic_tip_showing = false


func _on_relic_mouse_entered(relic: DataModels.ItemData) -> void:
	# 悬停时显示说明
	if not _relic_tip_showing:
		var localized_relic: DataModels.ItemData = ItemDatabase.get_relic_by_id(relic.id)
		if localized_relic:
			TipManager.show_tip("%s\n%s" % [localized_relic.name, localized_relic.description], 10.0)
		else:
			TipManager.show_tip("%s\n%s" % [relic.name, relic.description], 10.0)
		_relic_tip_showing = true


func _on_relic_mouse_exited() -> void:
	# 移出时隐藏说明
	TipManager.hide_tip()
	_relic_tip_showing = false


func _on_relic_prev_pressed() -> void:
	if not is_instance_valid(relic_scroll):
		return
	SoundSystem.play_button_click()
	# 滚动到上一页
	var scroll_width: int = int(relic_scroll.size.x)
	relic_scroll.scroll_horizontal -= scroll_width


func _on_relic_next_pressed() -> void:
	if not is_instance_valid(relic_scroll):
		return
	SoundSystem.play_button_click()
	# 滚动到下一页
	var scroll_width: int = int(relic_scroll.size.x)
	relic_scroll.scroll_horizontal += scroll_width


func _on_relics_changed() -> void:
	_refresh_relic_panel()


# ---- 棋盘→宿舍 (长按或双击可扩展, 暂用选中+宿舍按钮) ----

func _find_control_at_position(pos: Vector2) -> Control:
	# 从 GridContainer 开始递归查找包含该位置的 Control
	var gc: GridContainer = grid_container
	if gc == null:
		push_warning(">>> [GameBoard] grid_container is null!")
		return null
	# 获取 GridContainer 内的所有 cell
	for child in gc.get_children():
		if child is Control:
			var rect: Rect2 = child.get_global_rect()
			if rect.has_point(pos):
				return child
	return null

func _input(event: InputEvent) -> void:
	# 处理鼠标点击/移动 - 手动路由到正确的格子以解决 gui_input 信号不触发的问题
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		var mouse_pos: Vector2 = event.global_position
		var clicked_cell: Control = _find_control_at_position(mouse_pos)
		if clicked_cell != null:
			var cell_name: String = clicked_cell.name
			if cell_name.begins_with("cell_"):
				var cell_index_str: String = cell_name.substr(5)
				var cell_index: int = cell_index_str.to_int()
				_on_cell_gui_input(event, cell_index)
				return  # 阻止事件继续传播到 GUI 系统
	# 按 D 键将选中角色存入宿舍
	if event is InputEventKey and event.pressed and event.keycode == KEY_D:
		if selected_index >= 0:
			var bd: BoardData = GameManager.board_data
			var ch: DataModels.BoardItemData = bd.get_item_at_index(selected_index)
			if ch != null:
				var pos: Vector2i = BoardData.index_to_pos(selected_index)
				bd.board_to_dormitory(pos)
				selected_index = -1
				_refresh_board_display()
				_update_character_detail_panel()


# ---- 按钮回调 ----

func _on_end_turn_pressed() -> void:
	selected_index = -1
	_update_character_detail_panel()
	# Tutorial: advance on end turn (step 4)
	_try_advance_tutorial(4)
	SoundSystem.play_button_click()
	GameManager.enter_battle_phase()
	get_tree().change_scene_to_file("res://scenes/battle_scene.tscn")


func _on_back_pressed() -> void:
	SoundSystem.play_button_click()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_build_list_pressed() -> void:
	SoundSystem.play_button_click()
	TransitionManager.change_scene_with_transition("res://scenes/building.tscn")


func _on_out_item_clicked(item_id: int) -> void:
	# 获取物品数据
	var item: DataModels.BoardItemData = ItemManager.get_item(item_id)
	if item == null:
		TipManager.show_tip("物品不存在")
		return
	# 查找空棋盘格放置
	var target_index: int = -1
	for i in range(BoardData.BOARD_SLOTS):
		if GameManager.board_data.get_item_at_index(i) == null:
			target_index = i
			break
	if target_index < 0:
		TipManager.show_tip("棋盘已满，无法放置道具")
		return
	# 获取目标格子位置
	var target_pos: Vector2i = BoardData.index_to_pos(target_index)
	var end_pos: Vector2 = grid_container.get_global_position() + Vector2(
		target_pos.x * CELL_SIZE + CELL_SIZE / 2,
		target_pos.y * CELL_SIZE + CELL_SIZE / 2
	)
	# 获取局外道具图标位置
	var items_stack: VBoxContainer = find_child("ItemsStack", true, false)
	if items_stack == null:
		items_stack = get_node_or_null("MainLayout/MiddleBar/BottomHUDContainer/ScrollContainer/ContentHBox/ZoneB/VBoxB/ItemsStack")
	var start_pos: Vector2 = items_stack.get_global_position() + Vector2(30, 30) if items_stack else Vector2(400, 1600)
	# 获取物品纹理以确定原始尺寸
	var item_tex: Texture2D = null
	var sprite_path: String = item.get_sprite_path()
	if ResourceLoader.exists(sprite_path):
		item_tex = load(sprite_path)
	var item_size: Vector2 = item_tex.get_size() if item_tex else Vector2(60, 60)
	# 创建飞行动画精灵
	var anim_sprite := TextureRect.new()
	anim_sprite.custom_minimum_size = item_size
	anim_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	anim_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	anim_sprite.global_position = start_pos - item_size / 2
	anim_sprite.z_index = 10
	if item_tex != null:
		anim_sprite.texture = item_tex
	get_tree().root.add_child(anim_sprite)
	# 从局外道具移除
	GameManager.remove_out_item(item_id)
	# 播放飞行动画
	var tween := create_tween()
	tween.tween_property(anim_sprite, "global_position", end_pos - item_size / 2, 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		anim_sprite.queue_free()
		# 放置物品到棋盘
		GameManager.board_data.place_item(item, target_pos)
		GameManager.board_items_changed.emit()
		_refresh_board_display()
		_play_land_animation(target_index)
	)


## 处理提交请求：隐藏完成按钮 → 物品飞向任务栏 → 任务单缩小消失 → 星星粒子飞向建造清单 → 刷新
func _on_submit_requested() -> void:
	# Step 1: 隐藏完成按钮
	if bottom_hud_container and bottom_hud_container.has_method("hide_submit_button"):
		bottom_hud_container.hide_submit_button()

	# 获取任务物品信息
	var task_info: Dictionary = TaskManager.get_task_items_info()
	var all_board_items: Array = task_info.get("board", [])

	# 只选择显示图标的物品
	var board_items: Array = []
	for item_data in all_board_items:
		var idx: int = item_data["index"]
		if idx < cell_task_icons.size() and is_instance_valid(cell_task_icons[idx]) and cell_task_icons[idx].visible:
			board_items.append(item_data)

	# 获取任务栏位置
	var task_panel_center: Vector2 = bottom_hud_container.get_task_panel_global_center() if bottom_hud_container else Vector2(540, 1600)

	# 如果没有物品，直接进入缩小动画
	if board_items.is_empty():
		_play_task_shrink_animation(task_panel_center)
		return

	# Step 2: 物品飞向任务栏位置
	var total_items: int = board_items.size()
	var completed := [0]

	for item_data in board_items:
		var board_index: int = item_data["index"]
		var cell_panel: Control = cell_panels[board_index]
		var start_pos: Vector2 = cell_panel.get_global_position() + Vector2(CELL_SIZE / 2, CELL_SIZE / 2)

		# 创建飞行精灵
		var anim_sprite := TextureRect.new()
		anim_sprite.custom_minimum_size = Vector2(60, 60)
		anim_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		anim_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		anim_sprite.global_position = start_pos - Vector2(30, 30)
		anim_sprite.z_index = 10
		var sprite_path: String = item_data.get("sprite_path", "")
		if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
			anim_sprite.texture = load(sprite_path)
		get_tree().root.add_child(anim_sprite)

		# 隐藏原物品
		if board_index < cell_sprites.size():
			cell_sprites[board_index].visible = false
			if cell_containers[board_index] != null:
				cell_containers[board_index].visible = false
		if board_index < cell_task_icons.size():
			cell_task_icons[board_index].visible = false

		# 飞行动画
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(anim_sprite, "global_position", task_panel_center - Vector2(30, 30), 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(anim_sprite, "scale", Vector2(0.4, 0.4), 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.finished.connect(func():
			anim_sprite.queue_free()
			completed[0] += 1
			if completed[0] >= total_items:
				# 所有物品到达，开始任务单缩小动画
				_play_task_shrink_animation(task_panel_center)
		)


## 任务单缩小消失动画
func _play_task_shrink_animation(task_panel_center: Vector2) -> void:
	var task_panel_path := "MainLayout/MiddleBar/BottomHUDContainer/ScrollContainer/ContentHBox/ZoneC"
	var task_panel: Control = get_node_or_null(task_panel_path)
	if task_panel == null:
		_finish_task_submission_new()
		return

	task_panel.pivot_offset = task_panel.size / 2

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(task_panel, "scale", Vector2(0.0, 0.0), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(task_panel, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func():
		# 缩小完成，播放星星粒子飞向建造清单
		_play_star_particles_to_build_list(task_panel_center)
	)


## 星星粒子飞向建造清单按钮
func _play_star_particles_to_build_list(start_pos: Vector2) -> void:
	var STAR_ICON: Texture2D = load("res://art/sprites/UI/icon/star.png")
	var end_pos: Vector2 = bottom_hud_container.get_build_list_btn_global_center() if bottom_hud_container else Vector2(100, 1600)

	# 获取当前任务的星星奖励
	var current_task: Dictionary = TaskManager.get_current_task()
	var reward: Dictionary = current_task.get("reward", {})
	var star_reward: int = reward.get("star", 1)

	var particle_count: int = clampi(star_reward, 1, 8)
	var particles_arrived := [0]

	for i in range(particle_count):
		var star := Sprite2D.new()
		star.texture = STAR_ICON
		star.scale = Vector2(0.5, 0.5)
		star.global_position = start_pos

		# 创建CanvasLayer包裹以确保屏幕空间
		var canvas := CanvasLayer.new()
		canvas.layer = 100
		var star_control := TextureRect.new()
		star_control.texture = STAR_ICON
		star_control.custom_minimum_size = Vector2(30, 30)
		star_control.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star_control.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star_control.position = start_pos - Vector2(15, 15)
		star_control.z_index = 200
		star_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(star_control)
		get_tree().root.add_child(canvas)
		star.queue_free()  # 不需要Sprite2D

		# 先散开
		var angle: float = TAU * float(i) / float(particle_count)
		var scatter_pos: Vector2 = start_pos + Vector2(cos(angle), sin(angle)) * randf_range(30, 60) - Vector2(15, 15)

		var scatter_tween := create_tween()
		scatter_tween.tween_property(star_control, "position", scatter_pos, 0.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# 然后飞向目标
		var fly_delay: float = 0.2 + randf_range(0.0, 0.1)
		scatter_tween.tween_property(star_control, "position", end_pos - Vector2(15, 15), 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(fly_delay - 0.2)
		scatter_tween.tween_property(star_control, "modulate:a", 0.0, 0.1)
		scatter_tween.finished.connect(func():
			canvas.queue_free()
			particles_arrived[0] += 1
			if particles_arrived[0] >= particle_count:
				# 所有星星到达，完成任务提交
				_finish_task_submission_new()
		)


## 新版完成提交：实际移除物品，增加星星，恢复任务面板，刷新
func _finish_task_submission_new() -> void:
	# 获取当前任务信息
	var current_task: Dictionary = TaskManager.get_current_task()
	if current_task.is_empty():
		return
	var need_items: Array = current_task.get("needItems", [])
	# 提交任务
	var submitted: Array[int] = []
	for item_id in need_items:
		submitted.append(int(item_id))
	var success: bool = TaskManager.try_complete_task(submitted)
	if success:
		print(">>> [GameBoard] 任务提交成功")
	else:
		print(">>> [GameBoard] 任务提交失败")

	# 恢复任务面板显示
	var task_panel_path := "MainLayout/MiddleBar/BottomHUDContainer/ScrollContainer/ContentHBox/ZoneC"
	var task_panel: Control = get_node_or_null(task_panel_path)
	if task_panel:
		task_panel.scale = Vector2(1.0, 1.0)
		task_panel.modulate = Color.WHITE

	# 刷新棋盘和任务栏
	_refresh_board_display()


func _on_energy_buy_pressed() -> void:
	SoundSystem.play_button_click()
	var cost: int = GameManager.get_energy_purchase_cost()
	var cost_text: String = LocalizationSystem.get_text("game_board.buy_energy_confirm", {"cost": cost})
	PopupSystem.show(
		LocalizationSystem.get_text("game_board.buy_energy_title"),
		cost_text,
		"",  # description
		LocalizationSystem.get_text("common.confirm"),  # confirm_text
		"",  # close_text
		Callable(self, "_do_energy_buy"),  # on_confirm
		Callable(self, "_on_popup_close")  # on_close
	)


func _do_energy_buy() -> void:
	if GameManager.purchase_energy():
		TipManager.show_tip(LocalizationSystem.get_text("game_board.buy_energy_success"))
	else:
		TipManager.show_tip(LocalizationSystem.get_text("game_board.buy_energy_failed"))


func _on_gold_buy_pressed() -> void:
	SoundSystem.play_button_click()
	PopupSystem.show(
		LocalizationSystem.get_text("game_board.gold_buy_title"),
		LocalizationSystem.get_text("game_board.gold_buy_desc"),
		"",  # description
		LocalizationSystem.get_text("game_board.watch_ad"),  # confirm_text
		"",  # close_text
		Callable(self, "_do_gold_buy"),  # on_confirm
		Callable(self, "_on_popup_close")  # on_close
	)


func _do_gold_buy() -> void:
	GameManager.add_gold(1000)
	PopupSystem.hide()


func _on_diamond_buy_pressed() -> void:
	SoundSystem.play_button_click()
	PopupSystem.show(
		LocalizationSystem.get_text("game_board.diamond_buy_title"),
		LocalizationSystem.get_text("game_board.diamond_buy_desc"),
		"",  # description
		LocalizationSystem.get_text("game_board.watch_ad"),  # confirm_text
		"",  # close_text
		Callable(self, "_do_diamond_buy"),  # on_confirm
		Callable(self, "_on_popup_close")  # on_close
	)


func _do_diamond_buy() -> void:
	GameManager.add_diamond(1000)
	PopupSystem.hide()


func _on_popup_close() -> void:
	PopupSystem.hide()


func _on_build_button_pressed() -> void:
	print(">>> [GameBoard] BuildButton pressed!")
	SoundSystem.play_button_click()
	# 播放按钮缩放动画（由子级Icon播放），动画完成后再执行场景切换
	var icon: TextureRect = build_button.find_child("Icon", true, false) if build_button else null
	if icon:
		var tween := create_tween()
		tween.tween_property(icon, "scale", Vector2(1.1, 1.1), 0.15)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.1)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(0.1)
		tween.finished.connect(_on_build_button_animation_complete)
	else:
		# 没有Icon时直接切换
		_on_build_button_animation_complete()


func _on_build_button_animation_complete() -> void:
	# 动画完成后使用挡板过渡切换到Building场景
	TransitionManager.change_scene_with_transition("res://scenes/building.tscn")


func _on_shop_pressed() -> void:
	SoundSystem.play_button_click()
	# 使用弹窗方式打开商店（不切换场景）
	var shop_scene := preload("res://scenes/shop_scene.tscn").instantiate()
	add_child(shop_scene)


func _on_encyclopedia_pressed() -> void:
	SoundSystem.play_button_click()
	_try_advance_tutorial(3)
	var encyclopedia := preload("res://scenes/encyclopedia_scene.tscn").instantiate()
	add_child(encyclopedia)


func _on_item_pressed() -> void:
	SoundSystem.play_button_click()
	# 道具栏弹窗 (备用)
	_show_item_panel()


# ---- 道具栏格子 (3个固定格子) ----

func _setup_item_slots() -> void:
	item_slot_nodes.clear()
	item_slot_labels.clear()
	item_slot_overlays.clear()
	item_slot_icons.clear()

	# 加载格子背景纹理
	var cell_texture := preload("res://art/sprites/UI/items/smallItem/cell_0.png")

	for i in range(ITEM_SLOT_COUNT):
		var slot: Control = item_bar.get_child(i)
		item_slot_nodes.append(slot)
		
		# 清除旧内容
		for child in slot.get_children():
			child.queue_free()

		# 背景纹理（cell_0.png，不透明）
		var bg := TextureRect.new()
		bg.name = "Background"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.custom_minimum_size = Vector2(120, 120)  # 格子尺寸
		bg.texture = cell_texture
		bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH  # 关键：使用FitWidth而非KeepSize
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg.modulate = Color(0.8, 0.8, 0.8, 1.0)  # 不透明
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(bg)

		# 居中容器（用于道具图片）
		var center := CenterContainer.new()
		center.name = "CenterContainer"
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(center)

		# 道具图片（100x100，格子120x120，留10px边距）
		var icon := TextureRect.new()
		icon.name = "ItemIcon"
		icon.custom_minimum_size = Vector2(100, 100)
		icon.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false  # 初始隐藏
		center.add_child(icon)
		item_slot_icons.append(icon)

		# 标签（隐藏，不显示文字）
		var lbl := Label.new()
		lbl.name = "Label"
		lbl.visible = false  # 不显示文字
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(lbl)
		item_slot_labels.append(lbl)

		# 点击事件
		slot.gui_input.connect(_on_item_slot_input.bind(i))


func _refresh_item_slots() -> void:
	for i in range(ITEM_SLOT_COUNT):
		var bg: TextureRect = item_slot_nodes[i].get_node_or_null("Background")
		
		if i < GameManager.items.size():
			var item: DataModels.ItemData = GameManager.items[i]
			
			# 显示道具图片
			var icon: TextureRect = item_slot_icons[i]
			if icon:
				# 获取道具图片纹理
				var tex := _get_item_texture(item)
				icon.texture = tex
				icon.visible = (tex != null)
			else:
				pass

			# 背景不透明
			if bg:
				bg.modulate = Color(0.8, 0.8, 0.8, 1.0)
		else:
			# 空格子：隐藏道具图片，背景不透明
			var icon: TextureRect = item_slot_icons[i]
			if icon:
				icon.visible = false
			if bg:
				bg.modulate = Color(0.8, 0.8, 0.8, 1.0)


## 获取道具图片
func _get_item_texture(item: DataModels.ItemData) -> Texture2D:
	# 道具: ID 1-22
	var path := "res://art/sprites/UI/items/item/item_%03d.png" % item.id
	
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	
	return null


# ---- 道具详情弹窗 ----

func _show_item_detail(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= GameManager.items.size():
		return

	var item: DataModels.ItemData = GameManager.items[slot_index]
	item_detail_popup_slot = slot_index
	item_detail_visible = true

	# 获取本地化的道具信息
	var localized_item: DataModels.ItemData = ItemDatabase.get_consumable_by_id(item.id)
	if localized_item == null:
		localized_item = item

	# 使用PopupSystem显示道具详情
	PopupSystem.show(
		localized_item.name,  # 标题
		localized_item.description,  # 内容
		"",  # 说明
		LocalizationSystem.get_text("items.use"),  # 确认按钮文字
		LocalizationSystem.get_text("items.close"),  # 关闭按钮文字
		func(): _on_item_use_clicked(slot_index),  # 确认回调
		func(): _hide_item_detail()  # 关闭回调
	)


func _hide_item_detail() -> void:
	item_detail_popup_slot = -1
	item_detail_visible = false
	_end_target_selection()
	if PopupSystem.is_open():
		PopupSystem.hide()


func _on_item_use_clicked(slot_index: int) -> void:
	# 先关闭弹窗
	_hide_item_detail()

	if slot_index < 0 or slot_index >= GameManager.items.size():
		return

	var item: DataModels.ItemData = GameManager.items[slot_index]
	var needs_target: bool = _item_needs_target(item.id)

	if needs_target:
		# 需要目标: 进入目标选择模式
		_start_target_selection(slot_index)
	else:
		# 直接使用
		_use_item_direct(slot_index)


func _on_item_discard_clicked(slot_index: int) -> void:
	# 先关闭弹窗
	_hide_item_detail()
	_discard_item(slot_index)


func _discard_item(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= GameManager.items.size():
		return
	GameManager.remove_item(slot_index)
	_refresh_item_slots()


func _use_item_direct(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= GameManager.items.size():
		return

	var item: DataModels.ItemData = GameManager.items[slot_index]
	var result: Dictionary = ItemDatabase.use_consumable(item, -1)
	var success: bool = result.get("success", false)
	var affected_target: int = result.get("target_index", -1)


	if success:
		GameManager.remove_item(slot_index)
		_refresh_item_slots()
		_refresh_board_display()

		# 如果有受影响的目标，播放高亮动效
		if affected_target >= 0:
			_play_item_effect_highlight(affected_target)
	else:
		print(">>> [GameBoard] 使用道具失败: %s" % item.name)
		# 显示失败提示（延迟显示，避免被弹窗遮挡）
		await get_tree().create_timer(0.15).timeout
		TipManager.show_tip(LocalizationSystem.get_text("items.cannot_use_board_full"))


func _use_item_on_target(target_index: int) -> void:
	var slot_index: int = target_select_item_slot
	if slot_index < 0 or slot_index >= GameManager.items.size():
		_end_target_selection()
		return

	var item: DataModels.ItemData = GameManager.items[slot_index]
	var result: Dictionary = ItemDatabase.use_consumable(item, target_index)
	var success: bool = result.get("success", false)
	var affected_target: int = result.get("target_index", -1)


	if success:
		GameManager.remove_item(slot_index)
		_refresh_item_slots()
		_refresh_board_display()

		# 播放高亮动效（使用target_index，如果result中没有affected_target）
		if affected_target < 0:
			affected_target = target_index
		_play_item_effect_highlight(affected_target)
	else:
		print(">>> [GameBoard] 使用道具失败: %s" % item.name)
		# 显示失败提示（延迟显示，避免被弹窗遮挡）
		await get_tree().create_timer(0.15).timeout
		TipManager.show_tip(LocalizationSystem.get_text("items.cannot_use_board_full"))
	# 无论成功失败，都结束目标选择
	_end_target_selection()


## 播放道具使用效果的高亮动效（0.5s红色高亮）
func _play_item_effect_highlight(cell_index: int) -> void:
	
	# 强制结束拖拽状态，避免冲突
	if is_dragging:
		is_dragging = false
		merge_targets.clear()
		_update_merge_highlights()
	
	# 清理所有格子的颜色状态（关键：避免之前的红色状态残留）
	for i in range(BoardData.BOARD_SLOTS):
		# 隐藏高亮效果层
		cell_highlight_effects[i].visible = false
		# 重置精灵颜色为白色
		if cell_sprites[i] and is_instance_valid(cell_sprites[i]):
			cell_sprites[i].modulate = Color.WHITE
		# 重置背景颜色为原始颜色（根据格子位置计算）
		if cell_rects[i] and is_instance_valid(cell_rects[i]):
			var is_even: bool = (i / GRID_COLS + i % GRID_COLS) % 2 == 0
			cell_rects[i].modulate = Color(0.5, 0.5, 0.5, 0.9) if is_even else Color(0.8, 0.8, 0.8, 0.7)
	
	if cell_index < 0 or cell_index >= cell_sprites.size():
		return
	
	var sprite: Control = cell_sprites[cell_index]
	if sprite == null or not is_instance_valid(sprite):
		return
	
	
	# 创建高亮动画：红色闪烁
	var tween := create_tween()
	tween.set_parallel(false)
	
	# 0.25s 红色
	tween.tween_property(sprite, "modulate", Color(2.0, 0.3, 0.3, 1.0), 0.25)
	# 0.25s 恢复白色
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	
	# 同时播放格子背景的红色高亮
	var bg: Control = cell_rects[cell_index]
	if bg and is_instance_valid(bg):
		var bg_tween := create_tween()
		# 计算背景的正常颜色
		var is_even: bool = (cell_index / GRID_COLS + cell_index % GRID_COLS) % 2 == 0
		var normal_bg_color: Color = Color(0.5, 0.5, 0.5, 0.9) if is_even else Color(0.8, 0.8, 0.8, 0.7)
		bg_tween.set_parallel(false)
		bg_tween.tween_property(bg, "modulate", Color(1.5, 0.2, 0.2, 1.0), 0.25)
		bg_tween.tween_property(bg, "modulate", normal_bg_color, 0.25)


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
	# 使用 TipManager 显示提示（持续显示直到手动隐藏）
	TipManager.show_tip(LocalizationSystem.get_text("items.select_target"), 10.0)


func _end_target_selection() -> void:
	is_selecting_target = false
	target_select_item_slot = -1
	# 隐藏 TipManager 提示
	TipManager.hide_tip()


func _on_item_slot_input(event: InputEvent, slot_index: int) -> void:
	_reset_idle_hint_timer()
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
		TipManager.show_tip(LocalizationSystem.get_text("game_board.select_character_first"))
		return

	var item: DataModels.ItemData = GameManager.items[slot_index]
	var result: Dictionary = ItemDatabase.use_consumable(item, selected_index)
	var success: bool = result.get("success", false)
	if success:
		GameManager.remove_item(slot_index)
		_refresh_item_slots()
		_refresh_board_display()
	else:
		TipManager.show_tip(LocalizationSystem.get_text("items.cannot_use"))


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
		var localized_item: DataModels.ItemData = ItemDatabase.get_consumable_by_id(item.id)
		if localized_item == null:
			localized_item = item
		var row := HBoxContainer.new()
		list.add_child(row)

		var info := Label.new()
		info.text = "%s - %s" % [localized_item.name, localized_item.description]
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
	SoundSystem.play_button_click()
	var item: DataModels.ItemData = GameManager.items[item_index]

	# 需要指定目标的道具, 使用选中的格子
	var target_idx: int = selected_index
	var result: Dictionary = ItemDatabase.use_consumable(item, target_idx)
	var success: bool = result.get("success", false)
	if success:
		GameManager.remove_item(item_index)
		_refresh_item_panel()
		_refresh_item_slots()
		_refresh_board_display()
	else:
		TipManager.show_tip(LocalizationSystem.get_text("items.cannot_use"))


# ---- 设置面板 ----

func _on_settings_pressed() -> void:
	_reset_idle_hint_timer()
	SoundSystem.play_button_click()
	_show_settings_panel()


func _show_settings_panel() -> void:
	settings_backdrop.visible = true
	settings_panel.visible = true
	# 连接遮罩点击事件（只连接一次）
	if not settings_backdrop.gui_input.is_connected(_on_settings_backdrop_pressed):
		settings_backdrop.gui_input.connect(_on_settings_backdrop_pressed)
	_update_language_button_text()
	_update_settings_texts()


func _on_settings_backdrop_pressed(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_hide_settings_panel()


func _hide_settings_panel() -> void:
	settings_backdrop.visible = false
	settings_panel.visible = false


func _update_settings_texts() -> void:
	settings_title.text = LocalizationSystem.get_text("settings.title")
	reset_tutorial_button.text = LocalizationSystem.get_text("settings.reset_tutorial")
	clear_save_button.text = LocalizationSystem.get_text("settings.clear_save")


func _on_language_toggled() -> void:
	SoundSystem.play_button_click()
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
	pass  # _update_resource_labels 已移除
	_refresh_game_board_texts()
	_refresh_dorm_panel()
	_refresh_item_slots()
	_refresh_item_panel()
	# 如果道具详情弹窗打开，关闭它（下次打开时会用新语言创建）
	if item_detail_visible:
		_hide_item_detail()


func _update_language_button_text() -> void:
	if LocalizationSystem.current_lang == "en":
		language_button.text = "EN"
	else:
		language_button.text = "中文"


func _refresh_game_board_texts() -> void:
	# 更新底部按钮文本（通过 Label 子节点）
	var warrior_label = spawn_warrior.get_node_or_null("Label") if spawn_warrior else null
	if warrior_label:
		warrior_label.text = LocalizationSystem.get_text("game_board.spawn_warrior")

	var mage_label = spawn_mage.get_node_or_null("Label") if spawn_mage else null
	if mage_label:
		mage_label.text = LocalizationSystem.get_text("game_board.spawn_mage")

	var priest_label = spawn_priest.get_node_or_null("Label") if spawn_priest else null
	if priest_label:
		priest_label.text = LocalizationSystem.get_text("game_board.spawn_priest")

	var end_turn_label = end_turn_button.get_node_or_null("Label") if end_turn_button else null
	if end_turn_label:
		end_turn_label.text = LocalizationSystem.get_text("game_board.end_turn")

	var dorm_label = dorm_button.get_node_or_null("Label") if dorm_button else null
	if dorm_label:
		dorm_label.text = LocalizationSystem.get_text("game_board.dorm")

	var shop_label = shop_button.get_node_or_null("Label") if shop_button else null
	if shop_label:
		shop_label.text = LocalizationSystem.get_text("game_board.shop")

	var encyclopedia_label = encyclopedia_button.get_node_or_null("Label") if encyclopedia_button else null
	if encyclopedia_label:
		encyclopedia_label.text = LocalizationSystem.get_text("game_board.encyclopedia")
	
	# 献祭按钮标题
	var vbox = sacrifice_button.get_node_or_null("VBoxContainer")
	if vbox:
		var label2 = vbox.get_node_or_null("Label2")
		if label2:
			label2.text = LocalizationSystem.get_text("game_board.sacrifice")


func _on_reset_tutorial_pressed() -> void:
	SoundSystem.play_button_click()
	TipManager.show_tip("教程已禁用", 2.0)


func _on_clear_save_pressed() -> void:
	SoundSystem.play_button_click()
	# 清空存档（保留图鉴）- clear_game_save 内部会从 MapConfig 重新初始化棋盘
	SaveSystem.clear_game_save()
	# 刷新UI
	_refresh_board_display()
	_on_gold_changed(GameManager.gold)
	_on_energy_changed(GameManager.energy)
	_on_diamond_changed(GameManager.diamond)
	_on_round_changed(GameManager.current_round)
	# 显示提示
	TipManager.show_tip(LocalizationSystem.get_text("settings.clear_save_confirm"), 2.0)




func _on_close_settings() -> void:
	SoundSystem.play_button_click()
	_hide_settings_panel()


func _load_volume() -> float:
	var config := ConfigFile.new()
	var err := config.load("user://settings.cfg")
	if err == OK:
		return config.get_value("audio", "volume", 1.0)
	return 1.0


# ---- 教学系统辅助 (任务 7.1) ----

func _try_advance_tutorial(expected_step: int) -> void:
	# Tutorial advancement is handled by tutorial_instance
	# This method kept for compatibility with old tutorial overlay
	pass


# ---- Idle 提示系统 ----

## 启动 idle 提示计时器
func _start_idle_hint_timer() -> void:
	_stop_idle_hint_timer()
	_idle_hint_timer = get_tree().create_timer(IDLE_HINT_DELAY, false)
	_idle_hint_timer.timeout.connect(_on_idle_hint_timeout)


## 停止 idle 提示计时器
func _stop_idle_hint_timer() -> void:
	if _idle_hint_timer != null:
		if _idle_hint_timer.timeout.is_connected(_on_idle_hint_timeout):
			_idle_hint_timer.timeout.disconnect(_on_idle_hint_timeout)
		_idle_hint_timer = null


## 重置 idle 提示计时器（玩家操作时调用）
func _reset_idle_hint_timer() -> void:
	if not _idle_hint_playing:
		_stop_breathing_animation()
		_start_idle_hint_timer()


## Idle 计时器到期回调
func _on_idle_hint_timeout() -> void:
	_idle_hint_timer = null
	_play_idle_hint_animation()


## 开启呼吸动效：每隔1.0秒播放一次颤动弹效
func _start_breathing_animation(idx1: int, idx2: int) -> void:
	_stop_breathing_animation()
	_breathing_indices = [idx1, idx2]
	_breathing_timer = get_tree().create_timer(1.0, true)
	_breathing_timer.timeout.connect(_on_breathing_tick)


## 停止呼吸动效
func _stop_breathing_animation() -> void:
	if _breathing_timer != null:
		if _breathing_timer.timeout.is_connected(_on_breathing_tick):
			_breathing_timer.timeout.disconnect(_on_breathing_tick)
		_breathing_timer = null
	_breathing_indices.clear()
	_idle_hint_playing = false


## 呼吸计时器回调
func _on_breathing_tick() -> void:
	_breathing_timer = null
	for idx in _breathing_indices:
		if idx >= 0 and idx < cell_sprites.size() and cell_sprites[idx] != null:
			play_shake_animation(cell_sprites[idx])
	if not _breathing_indices.is_empty():
		_breathing_timer = get_tree().create_timer(1.0, true)
		_breathing_timer.timeout.connect(_on_breathing_tick)


## 播放 idle 提示动画：找到两个相同物品（id一致），播放呼吸动效
func _play_idle_hint_animation() -> void:
	var bd: BoardData = GameManager.board_data
	var found_pair: Array = []  # [idx1, idx2] 真正可合成的物品对

	# 遍历棋盘，找到第一对可合成的物品（相邻 + id一致 + level相同 + 可合成 + 非LOCKED + 非DUSTY）
	for i in range(BoardData.BOARD_SLOTS):
		var ch: DataModels.BoardItemData = bd.get_item_at_index(i)
		if ch == null or not ch.can_merge():
			continue

		# 检查格子状态，非LOCKED且非DUSTY才显示物品
		var grid_state: int = bd.get_grid_state(i)
		if grid_state == BoardData.GridState.LOCKED or grid_state == BoardData.GridState.DUSTY:
			continue

		# 检查 sprite 是否有有效贴图
		if i >= cell_sprites.size() or cell_sprites[i] == null or cell_sprites[i].texture == null:
			continue

		var neighbors := _get_neighbors(i)
		for neighbor_index in neighbors:
			var neighbor_ch: DataModels.BoardItemData = bd.get_item_at_index(neighbor_index)
			var neighbor_state: int = bd.get_grid_state(neighbor_index)
			if neighbor_ch != null and neighbor_ch.can_merge() and neighbor_ch.id == ch.id and neighbor_ch.level == ch.level:
				if neighbor_state != BoardData.GridState.LOCKED and neighbor_state != BoardData.GridState.DUSTY:
					if neighbor_index < cell_sprites.size() and cell_sprites[neighbor_index] != null and cell_sprites[neighbor_index].texture != null:
						found_pair = [i, neighbor_index]
						break
		if found_pair.size() == 2:
			break

	if found_pair.size() < 2:
		_start_idle_hint_timer()
		return

	_idle_hint_playing = true
	_start_breathing_animation(found_pair[0], found_pair[1])
	_start_idle_hint_timer()
