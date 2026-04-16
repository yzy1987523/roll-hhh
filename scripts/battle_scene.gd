extends Control
class_name BattleScene

## 战斗阶段场景
## 任务 3.3: 战斗UI + 任务 3.5: 胜负结算

# ---- 节点引用 ----
@onready var grid_container: GridContainer = $MainLayout/BoardCenter/GridContainer
@onready var log_label: RichTextLabel = $MainLayout/LogScroll/LogLabel
@onready var play_button: Button = $MainLayout/ControlBarMargin/ControlBar/PlayButton
@onready var skip_button: Button = $MainLayout/ControlBarMargin/ControlBar/SkipButton
@onready var result_label: Label = $BottomBar/ResultLabel
@onready var pause_button: Button = $MainLayout/ControlBarMargin/ControlBar/PauseButton
@onready var speed_1x: Button = $MainLayout/ControlBarMargin/ControlBar/Speed1x
@onready var speed_2x: Button = $MainLayout/ControlBarMargin/ControlBar/Speed2x
@onready var speed_3x: Button = $MainLayout/ControlBarMargin/ControlBar/Speed3x
@onready var pause_hint: Label = $MainLayout/PauseHintBar/PauseHint

# ---- Turn & Relic Area 节点 ----
@onready var turn_label: Label = $MainLayout/TurnContainer/TurnBox/TurnLabel
@onready var relic_panel: PanelContainer = $MainLayout/RelicBar/RelicPanel
@onready var relic_scroll: ScrollContainer = $MainLayout/RelicBar/RelicPanel/ScrollContainer
@onready var relic_list: HBoxContainer = $MainLayout/RelicBar/RelicPanel/ScrollContainer/RelicList
@onready var relic_prev_button: Button = $MainLayout/RelicBar/PrevButton
@onready var relic_next_button: Button = $MainLayout/RelicBar/NextButton

# ---- Enemy Area 节点 ----
@onready var enemy_sprite_rect: TextureRect = $MainLayout/EnemyArea/EnemySpriteRect
@onready var enemy_name: Label = $MainLayout/EnemyArea/EnemyInfoPanel/EnemyTitle/EnemyName
@onready var enemy_type: Label = $MainLayout/EnemyArea/EnemyInfoPanel/EnemyTitle/EnemyType
@onready var enemy_atk: Label = $MainLayout/EnemyArea/EnemyInfoPanel/EnemyStats/EnemyAtk
@onready var enemy_def: Label = $MainLayout/EnemyArea/EnemyInfoPanel/EnemyStats/EnemyDef
@onready var enemy_hp_bar: ProgressBar = $MainLayout/EnemyArea/EnemyInfoPanel/EnemyHpBar
@onready var enemy_hp_label: Label = $MainLayout/EnemyArea/EnemyInfoPanel/EnemyHpLabel
@onready var skill_name_label: Label = $MainLayout/EnemyArea/EnemyInfoPanel/SkillSection/SkillName
@onready var skill_desc_label: Label = $MainLayout/EnemyArea/EnemyInfoPanel/SkillSection/SkillDesc

# ---- ItemBar 节点 ----
@onready var item_slot0: PanelContainer = $MainLayout/ControlBarMargin/ControlBar/ItemSlot0
@onready var item_slot1: PanelContainer = $MainLayout/ControlBarMargin/ControlBar/ItemSlot1
@onready var item_slot2: PanelContainer = $MainLayout/ControlBarMargin/ControlBar/ItemSlot2

# ---- 常量 ----
const GRID_COLS := 7
const GRID_ROWS := 9
const CELL_SIZE := 144
const CHAR_SIZE := 140
const BASE_TURN_DELAY := 0.5  # 播放模式每回合间隔(秒)

# ---- 格子背景纹理 ----
const CELL_BG_TEXTURE := preload("res://art/sprites/UI/items/smallItem/cell_0.png")

# ---- 死亡效果Shader ----
const DEATH_SHADER := preload("res://shaders/dissolve_death.gdshader")

# ---- 颜色 ----
const COLOR_EMPTY_EVEN := Color("#2A3A5A")
const COLOR_EMPTY_ODD := Color("#1A2A4A")
const COLOR_WARRIOR := Color("#D94040")
const COLOR_MAGE := Color("#6040D9")
const COLOR_PRIEST := Color("#40B040")
const COLOR_DEAD := Color("#333333")

# ---- 状态 ----
var engine: BattleEngine = null
var cell_rects: Array = []
var cell_labels: Array = []
var cell_sprites: Array = []
var is_playing: bool = false
var battle_finished: bool = false
var is_paused: bool = false
var battle_speed: float = 1.0  # 1.0, 2.0, 3.0
var pending_timer: SceneTreeTimer = null

# ---- 角色存活状态追踪（用于检测死亡） ----
var prev_alive_status: Array = []  # 存储上一帧每个格子角色是否存活
var death_animation_playing: Array = []  # 存储每个格子是否正在播放死亡动画

# ---- 静态暂停状态（供子弹访问） ----
static var _static_is_paused: bool = false


## 获取战斗暂停状态（供子弹等外部访问）
static func is_battle_paused() -> bool:
	return _static_is_paused

# ---- 子弹系统 ----
var bullet_container: Node = null
var bullet_pool: BulletPool = null
var active_bullets: Array = []
var bullet_callback: Callable = Callable()  # 子弹命中后的回调
var bullet_script: GDScript = preload("res://scripts/battle_bullet.gd")

# ---- 子弹类型常量 ----
const BULLET_TYPE_ATTACK: int = 0
const BULLET_TYPE_HEAL: int = 1
const BULLET_TYPE_BLESS: int = 2
const BULLET_TYPE_ENEMY: int = 3

# ---- 回合状态（用于异步战斗） ----
enum BattlePhase { IDLE, PLAYER_ATTACK, ENEMY_ATTACK, ANIMATING }
var current_phase: int = BattlePhase.IDLE

# ---- 奖励常量 ----
const GOLD_REWARD_NORMAL := 30
const GOLD_REWARD_ELITE := 60
const GOLD_REWARD_BOSS := 100

# ---- 教程系统 ----
var battle_tutorial_instance: Control = null

# ---- 道具详情弹窗 ----
var item_detail_popup_slot: int = -1
var item_detail_visible: bool = false


func _ready() -> void:
	_connect_signals()
	_setup_board_display()
	_setup_bullet_container()
	_start_battle()
	_start_tutorial()
	print(">>> [BattleScene] 战斗场景已加载")


## 设置按钮透明背景样式（用于图标按钮）
func _set_button_transparent_style(button: Button) -> void:
	var transparent_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", transparent_style)
	button.add_theme_stylebox_override("hover", transparent_style)
	button.add_theme_stylebox_override("pressed", transparent_style)
	button.add_theme_stylebox_override("disabled", transparent_style)


func _setup_bullet_container() -> void:
	# 创建子弹容器节点
	bullet_container = Node2D.new()
	bullet_container.name = "BulletContainer"
	add_child(bullet_container)

	# 初始化子弹对象池
	bullet_pool = BulletPool.new(bullet_container, 30)
	print(">>> [BattleScene] 子弹对象池已初始化")


func _start_tutorial() -> void:
	# 教程已禁用
	pass


# ---- 道具栏 & 遗物栏初始化 ----

func _setup_item_slots() -> void:
	var slots := [item_slot0, item_slot1, item_slot2]
	for i in range(GameManager.MAX_ITEM_SLOTS):
		var slot: PanelContainer = slots[i]
		# 移除PanelContainer的默认样式
		var transparent_style := StyleBoxEmpty.new()
		slot.add_theme_stylebox_override("panel", transparent_style)
		
		# 清除旧内容
		for child in slot.get_children():
			child.queue_free()
		# 背景纹理（使用cell_0.png）
		var bg := TextureRect.new()
		bg.name = "Background"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.texture = CELL_BG_TEXTURE
		bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg.modulate = Color(0.8, 0.8, 0.8, 0.9)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(bg)
		
		# 居中容器（用于道具图片）
		var center := CenterContainer.new()
		center.name = "CenterContainer"
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(center)
		
		# 道具图片
		var icon := TextureRect.new()
		icon.name = "ItemIcon"
		icon.custom_minimum_size = Vector2(100, 100)
		icon.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false  # 初始隐藏
		center.add_child(icon)

	_refresh_item_slots()


func _refresh_item_slots() -> void:
	var items: Array = GameManager.items
	var slots := [item_slot0, item_slot1, item_slot2]
	for i in range(GameManager.MAX_ITEM_SLOTS):
		var slot: PanelContainer = slots[i]
		var bg: TextureRect = slot.get_node_or_null("Background")
		var icon: TextureRect = slot.get_node_or_null("CenterContainer/ItemIcon")
		
		if i < items.size():
			var item: DataModels.ItemData = items[i]
			# 显示道具图片
			if icon:
				var tex := _get_item_texture(item)
				icon.texture = tex
				icon.visible = (tex != null)
			# 背景不透明
			if bg:
				bg.modulate = Color(0.8, 0.8, 0.8, 0.9)
		else:
			# 空格子：隐藏道具图片
			if icon:
				icon.visible = false
			if bg:
				bg.modulate = Color(0.8, 0.8, 0.8, 0.9)


## 获取道具图片
func _get_item_texture(item: DataModels.ItemData) -> Texture2D:
	# 道具: ID 1-22
	var path := "res://art/sprites/UI/items/item/item_%03d.png" % item.id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


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

	# 更新翻页按钮状态
	await get_tree().process_frame
	var need_scroll: bool = relic_list.size.x > relic_scroll.size.x
	relic_prev_button.disabled = not need_scroll
	relic_next_button.disabled = not need_scroll
	relic_prev_button.modulate = Color(1, 1, 1, 0.3) if not need_scroll else Color.WHITE
	relic_next_button.modulate = Color(1, 1, 1, 0.3) if not need_scroll else Color.WHITE


func _on_relic_prev_pressed() -> void:
	SoundSystem.play_button_click()
	var scroll_width: int = int(relic_scroll.size.x)
	relic_scroll.scroll_horizontal -= scroll_width


func _on_relic_next_pressed() -> void:
	SoundSystem.play_button_click()
	var scroll_width: int = int(relic_scroll.size.x)
	relic_scroll.scroll_horizontal += scroll_width


# ---- 道具详情弹窗 ----

func _show_item_detail(slot_index: int) -> void:
	var items: Array = GameManager.items
	if slot_index < 0 or slot_index >= items.size():
		return

	var item: DataModels.ItemData = items[slot_index]
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
		func(): _on_item_use_pressed(slot_index),  # 确认回调
		func(): _hide_item_detail()  # 关闭回调
	)


func _hide_item_detail() -> void:
	item_detail_visible = false
	item_detail_popup_slot = -1
	if PopupSystem.is_open():
		PopupSystem.hide()


func _on_item_use_pressed(slot_index: int) -> void:
	# 先关闭弹窗
	_hide_item_detail()

	var items: Array = GameManager.items
	if slot_index < 0 or slot_index >= items.size():
		return

	var item: DataModels.ItemData = items[slot_index]

	# 需要目标的道具：进入目标选择模式
	if item.id in [1, 2, 3, 11, 13, 14, 15, 16]:
		_start_target_selection(slot_index)
		return

	# 即时使用
	var result := ItemDatabase.use_consumable(item)
	if result.success:
		GameManager.remove_item(slot_index)
		_refresh_item_slots()
		_refresh_board_display()  # 刷新棋盘显示
	else:
		# 延迟显示提示，避免被弹窗遮挡
		await get_tree().create_timer(0.15).timeout
		TipManager.show_tip(LocalizationSystem.get_text("items.cannot_use"), 2.0)


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


func _on_cell_gui_input(event: InputEvent, cell_index: int) -> void:
	# 目标选择模式：点击角色使用道具
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


func _use_item_on_target(target_index: int) -> void:
	var slot_index: int = target_select_item_slot
	if slot_index < 0 or slot_index >= GameManager.items.size():
		_end_target_selection()
		return

	var item: DataModels.ItemData = GameManager.items[slot_index]
	var result: Dictionary = ItemDatabase.use_consumable(item, target_index)
	var success: bool = result.get("success", false)

	print(">>> [BattleScene] 使用道具 %s (目标: %d), result: %s" % [item.name, target_index, result])

	if success:
		GameManager.remove_item(slot_index)
		_refresh_item_slots()
		_refresh_board_display()
		# 显示成功提示
		TipManager.show_tip(LocalizationSystem.get_text("items.use_success", {"name": item.name}), 1.5)
	else:
		# 显示失败提示
		await get_tree().create_timer(0.15).timeout
		TipManager.show_tip(LocalizationSystem.get_text("items.cannot_use"), 2.0)
	# 无论成功失败，都结束目标选择
	_end_target_selection()


func _on_item_discard_pressed(slot_index: int) -> void:
	# 先关闭弹窗
	_hide_item_detail()
	GameManager.remove_item(slot_index)
	_refresh_item_slots()


func _connect_signals() -> void:
	play_button.pressed.connect(_on_play_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	speed_1x.pressed.connect(_on_speed_1x_pressed)
	speed_2x.pressed.connect(_on_speed_2x_pressed)
	speed_3x.pressed.connect(_on_speed_3x_pressed)
	# 道具槽点击
	item_slot0.gui_input.connect(_on_item_slot_input.bind(0))
	item_slot1.gui_input.connect(_on_item_slot_input.bind(1))
	item_slot2.gui_input.connect(_on_item_slot_input.bind(2))
	# 遗物栏翻页
	relic_prev_button.pressed.connect(_on_relic_prev_pressed)
	relic_next_button.pressed.connect(_on_relic_next_pressed)
	# 语言切换信号
	LocalizationSystem.language_changed.connect(_on_localization_changed)

	# 为播放、跳过、暂停按钮添加悬停和按下效果
	_setup_control_button_feedback(play_button)
	_setup_control_button_feedback(skip_button)
	_setup_control_button_feedback(pause_button)


## 为控制按钮添加悬停和按下视觉反馈
func _setup_control_button_feedback(btn: Button) -> void:
	btn.mouse_entered.connect(_on_control_button_hover.bind(btn, true))
	btn.mouse_exited.connect(_on_control_button_hover.bind(btn, false))
	btn.button_down.connect(_on_control_button_press.bind(btn, true))
	btn.button_up.connect(_on_control_button_press.bind(btn, false))


func _on_control_button_hover(btn: Button, is_hovering: bool) -> void:
	if is_hovering:
		btn.modulate = Color(0.9, 0.9, 0.9, 1.0)
	else:
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _on_control_button_press(btn: Button, is_pressed: bool) -> void:
	if is_pressed:
		btn.modulate = Color(0.75, 0.75, 0.75, 1.0)
	else:
		btn.modulate = Color(0.9, 0.9, 0.9, 1.0)


func _on_item_slot_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			SoundSystem.play_button_click()
			_show_item_detail(slot_index)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# 右键快速丢弃
			var items: Array = GameManager.items
			if slot_index < items.size():
				GameManager.remove_item(slot_index)
				_refresh_item_slots()


func _on_speed_2x_pressed() -> void:
	SoundSystem.play_button_click()
	battle_speed = 2.0
	speed_1x.button_pressed = false
	speed_2x.button_pressed = true
	speed_3x.button_pressed = false


func _on_speed_3x_pressed() -> void:
	SoundSystem.play_button_click()
	battle_speed = 3.0
	speed_1x.button_pressed = false
	speed_2x.button_pressed = false
	speed_3x.button_pressed = true


func _on_speed_1x_pressed() -> void:
	battle_speed = 1.0
	speed_1x.button_pressed = true
	speed_2x.button_pressed = false
	speed_3x.button_pressed = false


# ---- 棋盘显示 (只读, 不可交互) ----

# ---- 目标选择指针 ----
var is_selecting_target: bool = false
var target_select_item_slot: int = -1


func _setup_board_display() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	cell_rects.clear()
	cell_labels.clear()
	cell_sprites.clear()
	prev_alive_status.clear()
	grid_container.columns = GRID_COLS

	for i in range(GRID_COLS * GRID_ROWS):
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		cell.mouse_filter = Control.MOUSE_FILTER_PASS

		# 格子背景纹理
		var bg := TextureRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.texture = CELL_BG_TEXTURE
		bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# 交替灰度和透明度
		@warning_ignore("integer_division")
		var row := i / GRID_COLS
		var col := i % GRID_COLS
		var is_even := (row + col) % 2 == 0
		bg.modulate = Color(0.5, 0.5, 0.5, 0.9) if is_even else Color(0.8, 0.8, 0.8, 0.7)
		cell.add_child(bg)

		var lbl := Label.new()
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 20)
		cell.add_child(lbl)

		# 精灵图
		var sprite := TextureRect.new()
		sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.custom_minimum_size = Vector2(CHAR_SIZE, CHAR_SIZE)
		sprite.position = Vector2(0, 0)
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.visible = false
		cell.add_child(sprite)

		# 点击事件
		cell.gui_input.connect(_on_cell_gui_input.bind(i))

		grid_container.add_child(cell)
		cell_rects.append(bg)
		cell_labels.append(lbl)
		cell_sprites.append(sprite)
		prev_alive_status.append(false)  # 初始化存活状态
		death_animation_playing.append(false)  # 初始化死亡动画状态


# ---- 战斗初始化 ----

func _start_battle() -> void:
	engine = BattleEngine.new()
	engine.on_log = _on_battle_log
	engine.setup(GameManager.board_data, GameManager.current_round, GameManager.cycle_count)

	_update_enemy_display()
	_refresh_board_display()
	log_label.text = ""
	battle_finished = false
	is_paused = false
	battle_speed = 1.0
	
	# 隐藏播放按钮，使用暂停按钮作为播放/暂停切换
	play_button.visible = false
	
	# 隐藏速度按钮
	speed_1x.visible = false
	speed_2x.visible = false
	speed_3x.visible = false
	
	# 初始化暂停按钮状态（显示播放图标，隐藏文字）
	# 初始状态：显示播放图标（点击开始战斗）
	pause_button.text = ""
	pause_button.icon = preload("res://art/sprites/UI/items/smallItem/play.png")
	pause_button.button_pressed = false
	pause_button.disabled = false
	# 设置透明背景
	_set_button_transparent_style(pause_button)
	
	# 初始化暂停提示字体大小（放大到2.5倍）
	pause_hint.add_theme_font_size_override("font_size", 40)
	
	# 初始化跳过按钮（使用图标，不显示文字）
	skip_button.text = ""
	_set_button_transparent_style(skip_button)
	
	speed_1x.button_pressed = true
	speed_2x.button_pressed = false
	speed_3x.button_pressed = false
	pause_hint.text = ""

	# 更新回合数显示
	turn_label.text = str(GameManager.battle_turn)

	# 初始化道具栏和遗物栏
	_setup_item_slots()
	_refresh_relic_panel()


func _on_localization_changed(lang: String) -> void:
	# 更新战斗界面文本
	# 暂停按钮不显示文字，只更新图标
	# 播放中显示暂停图标，暂停或未开始显示播放图标
	if is_playing and not is_paused:
		pause_button.text = ""
		pause_button.icon = preload("res://art/sprites/UI/items/smallItem/pause.png")
	else:
		pause_button.text = ""
		pause_button.icon = preload("res://art/sprites/UI/items/smallItem/play.png")
	# 跳过按钮不显示文字，只使用图标
	skip_button.text = ""
	speed_1x.text = LocalizationSystem.get_text("battle.speed_1x")
	speed_2x.text = LocalizationSystem.get_text("battle.speed_2x")
	speed_3x.text = LocalizationSystem.get_text("battle.speed_3x")
	turn_label.text = str(GameManager.battle_turn)
	# 更新遗物栏
	_refresh_relic_panel()
	# 更新道具栏（如果详情弹窗打开则关闭）
	if item_detail_visible:
		_hide_item_detail()
	_refresh_item_slots()
	# 更新敌人和玩家信息
	_update_enemy_display()
	print(">>> [BattleScene] 语言切换为: %s" % lang)


# ---- 播放/跳过 ----

func _on_play_pressed() -> void:
	if battle_finished:
		return
	if is_paused:
		return
	if is_playing:
		return
	SoundSystem.play_button_click()
	is_playing = true
	play_button.disabled = true
	_play_turns()


func _play_turns() -> void:
	if not is_playing or battle_finished:
		return

	if is_paused:
		return

	# 使用异步版本进行动画战斗
	_play_turn_async()


func _on_skip_pressed() -> void:
	if battle_finished:
		return
	SoundSystem.play_button_click()
	is_playing = false
	play_button.disabled = true
	skip_button.disabled = true
	pending_timer = null  # 引用清除即可，timer无法cancel

	var result: int = engine.run_full_battle()
	_update_enemy_display()
	_refresh_board_display()
	turn_label.text = str(GameManager.battle_turn)
	_on_battle_end(result)


# ---- 暂停/调速 ----

func _on_pause_pressed() -> void:
	if battle_finished:
		return
	
	# 如果战斗未开始，开始战斗
	if not is_playing:
		SoundSystem.play_button_click()
		is_playing = true
		# 开始播放后显示暂停图标
		pause_button.icon = preload("res://art/sprites/UI/items/smallItem/pause.png")
		pause_button.text = ""
		_play_turns()
		return
	
	SoundSystem.play_button_click()
	# 切换暂停状态
	is_paused = !is_paused
	_static_is_paused = is_paused  # 同步静态变量
	
	# 更新按钮图标（不显示文字）
	if is_paused:
		# 暂停状态：显示播放图标（点击继续）
		pause_button.icon = preload("res://art/sprites/UI/items/smallItem/play.png")
		pause_button.text = ""
		pause_hint.text = LocalizationSystem.get_text("battle.battle_paused")
	else:
		# 播放状态：显示暂停图标（点击暂停）
		pause_button.icon = preload("res://art/sprites/UI/items/smallItem/pause.png")
		pause_button.text = ""
		pause_hint.text = ""
	# 不需要在恢复时调用 _play_turns()
	# 因为 _wait_with_pause() 会自动在暂停时阻塞，恢复后继续


# ---- 战斗结束与结算 (任务 3.5) ----

func _on_battle_end(result: int) -> void:
	battle_finished = true
	is_playing = false
	is_paused = false
	_static_is_paused = false  # 重置静态暂停状态
	play_button.disabled = true
	skip_button.disabled = true
	pause_button.disabled = true
	pause_hint.text = ""

	match result:
		BattleEngine.RESULT_WIN:
			_handle_victory()
		BattleEngine.RESULT_LOSE:
			_handle_defeat()
		BattleEngine.RESULT_DRAW:
			_handle_draw()


func _handle_victory() -> void:
	result_label.text = LocalizationSystem.get_text("battle.victory")

	# 播放胜利音效
	SoundSystem.play_victory()

	# 全员满血恢复
	GameManager.board_data.heal_all()

	# 计算金币奖励
	var gold_reward: int = GOLD_REWARD_NORMAL
	var enemy_category: int = GameManager.get_current_enemy_type()
	match enemy_category:
		1: gold_reward = GOLD_REWARD_ELITE
		2: gold_reward = GOLD_REWARD_BOSS

	# 金币袋遗物 (ID 15): +20%
	if ItemDatabase.has_relic(15, GameManager.relics):
		gold_reward = int(gold_reward * 1.2)

	GameManager.add_gold(gold_reward)

	# 随机道具奖励
	var reward_text: String = LocalizationSystem.get_text("battle.gold_reward", {"value": gold_reward})
	var all_consumables: Array = ItemDatabase.get_all_consumables()
	var random_item: DataModels.ItemData = all_consumables[randi_range(0, all_consumables.size() - 1)]
	if GameManager.add_item(random_item):
		reward_text += "\n" + LocalizationSystem.get_text("battle.item_reward", {"name": random_item.name})
	else:
		reward_text += "\n" + LocalizationSystem.get_text("battle.item_reward_failed")

	# 精英/BOSS额外掉落遗物
	if enemy_category >= 1:
		var available_relics: Array = []
		for r in ItemDatabase.get_all_relics():
			if r.stackable or not ItemDatabase.has_relic(r.id, GameManager.relics):
				available_relics.append(r)
		if available_relics.size() > 0:
			var relic: DataModels.ItemData = available_relics[randi_range(0, available_relics.size() - 1)]
			GameManager.add_relic(relic)
			reward_text += "\n" + LocalizationSystem.get_text("battle.relic_reward", {"name": relic.name})

	GameManager.advance_round()

	# 使用PopupSystem显示结算
	PopupSystem.show(
		LocalizationSystem.get_text("battle.victory_title"),
		reward_text,
		"",
		LocalizationSystem.get_text("battle.continue"),
		"",
		func(): _on_continue_pressed(),
		Callable()
	)

	print(">>> [BattleScene] 胜利! 奖励 %d 金币" % gold_reward)


func _handle_defeat() -> void:
	result_label.text = LocalizationSystem.get_text("battle.defeat")
	
	# 使用PopupSystem显示结算
	PopupSystem.show(
		LocalizationSystem.get_text("battle.defeat_title"),
		LocalizationSystem.get_text("battle.survived_rounds", {"value": GameManager.current_round}),
		"",
		LocalizationSystem.get_text("battle.continue"),
		"",
		func(): _on_continue_pressed(),
		Callable()
	)
	
	# 提交排行榜分数
	SaveSystem.submit_leaderboard_score(GameManager.cycle_count)
	GameManager.enter_game_over()
	print(">>> [BattleScene] 战败!")


func _handle_draw() -> void:
	result_label.text = LocalizationSystem.get_text("battle.draw")
	
	# 使用PopupSystem显示结算
	PopupSystem.show(
		LocalizationSystem.get_text("battle.draw_title"),
		LocalizationSystem.get_text("battle.no_reward_draw"),
		"",
		LocalizationSystem.get_text("battle.continue"),
		"",
		func(): _on_continue_pressed(),
		Callable()
	)
	
	GameManager.advance_round()
	print(">>> [BattleScene] 平局!")


func _on_continue_pressed() -> void:
	SoundSystem.play_button_click()
	if GameManager.phase == GameManager.PHASE_GAME_OVER:
		# 战败: 重置并回主菜单
		GameManager.reset_after_defeat()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		# 胜利/平局: 回归备战
		GameManager.enter_prepare_phase()
		get_tree().change_scene_to_file("res://scenes/game_board.tscn")


# ---- 显示更新 ----

func _update_enemy_display() -> void:
	if engine == null or engine.enemy == null:
		return
	var e: EnemyFactory.EnemyData = engine.enemy
	enemy_name.text = e.name
	enemy_type.text = "[%s]" % e.get_type_name()
	
	# 隐藏原来的攻防文字标签（现在使用图标叠加显示）
	enemy_atk.visible = false
	enemy_def.visible = false
	
	# 更新血条
	enemy_hp_bar.max_value = e.max_hp
	enemy_hp_bar.value = e.hp
	enemy_hp_bar.show_percentage = false

	# 设置血条样式
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	enemy_hp_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.9, 0.2, 0.2)  # 红色
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	enemy_hp_bar.add_theme_stylebox_override("fill", fill_style)

	# 血条长度：根据血量计算，范围100-600
	var hp_bar_width: int = clampi(int(e.max_hp * 2), 100, 600)
	enemy_hp_bar.custom_minimum_size = Vector2(hp_bar_width, 24)
	
	# 更新血条上的血量文字
	_update_enemy_hp_label(e, hp_bar_width)

	# 加载敌人精灵图
	_load_enemy_sprite(e)


## 更新敌人血条上的血量文字
func _update_enemy_hp_label(e: EnemyFactory.EnemyData, hp_bar_width: int) -> void:
	# 将enemy_hp_label移动到血条上（如果还没移动）
	if enemy_hp_label.get_parent() != enemy_hp_bar:
		enemy_hp_label.get_parent().remove_child(enemy_hp_label)
		enemy_hp_bar.add_child(enemy_hp_label)

	# 更新血条值
	enemy_hp_bar.value = e.hp

	# 设置样式
	enemy_hp_label.name = "HpText"
	enemy_hp_label.text = "%d/%d" % [e.hp, e.max_hp]
	enemy_hp_label.custom_minimum_size = Vector2(hp_bar_width, 24)
	enemy_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enemy_hp_label.add_theme_font_size_override("font_size", 32)
	enemy_hp_label.add_theme_color_override("font_color", Color.WHITE)
	enemy_hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	enemy_hp_label.add_theme_constant_override("outline_size", 3)
	enemy_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_hp_label.visible = true
	
	# 更新敌人精灵图上的攻防图标
	_update_enemy_sprite_ui(e)

	# 显示特技信息
	_update_skill_display(e)


# ---- 敌人图片缓存 ----
var _cached_enemy_id: int = -1
var _cached_enemy_texture: Texture = null

# ---- 预定义的敌人图片列表（避免Web上DirAccess目录访问受限问题）----
# NORMAL: enemy_id 1-14 → enemy_001-014
const _NORMAL_ENEMY_SPRITES := [
	"res://art/sprites/UI/items/enemy/normal/enemy_001.png",
	"res://art/sprites/UI/items/enemy/normal/enemy_002.png",
	"res://art/sprites/UI/items/enemy/normal/enemy_003.png",
	"res://art/sprites/UI/items/enemy/normal/enemy_004.png",
	"res://art/sprites/UI/items/enemy/normal/enemy_005.png",
	"res://art/sprites/UI/items/enemy/normal/enemy_006.png",
	"res://art/sprites/UI/items/enemy/normal/enemy_007.png",
	"res://art/sprites/UI/items/enemy/normal/enemy_008.png",
	"res://art/sprites/UI/items/enemy/normal/enemy_009.png",
	"res://art/sprites/UI/items/enemy/normal/enemy_010.png",
	"res://art/sprites/UI/items/enemy/normal/enemy_011.png",
	"res://art/sprites/UI/items/enemy/normal/enemy_012.png",
	"res://art/sprites/UI/items/enemy/normal/enemy_013.png",
	"res://art/sprites/UI/items/enemy/normal/enemy_014.png",
]
# ELITE: enemy_id 15-18 → enemy_015-018 (4张)
const _ELITE_ENEMY_SPRITES := [
	"res://art/sprites/UI/items/enemy/elite/enemy_015.png",
	"res://art/sprites/UI/items/enemy/elite/enemy_016.png",
	"res://art/sprites/UI/items/enemy/elite/enemy_017.png",
	"res://art/sprites/UI/items/enemy/elite/enemy_018.png",
]
# BOSS: enemy_id 19-20 → enemy_019-020 (2张)
const _BOSS_ENEMY_SPRITES := [
	"res://art/sprites/UI/items/enemy/boss/enemy_019.png",
	"res://art/sprites/UI/items/enemy/boss/enemy_020.png",
]


## 加载敌人精灵图
func _load_enemy_sprite(e: EnemyFactory.EnemyData) -> void:
	var enemy_id: int = e.enemy_id

	# 设置敌人sprite的尺寸限制（最大200x200）
	enemy_sprite_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	enemy_sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_sprite_rect.custom_minimum_size = Vector2(200, 200)

	# 如果是同一个敌人，使用缓存的纹理
	if _cached_enemy_id == enemy_id and _cached_enemy_texture != null:
		enemy_sprite_rect.texture = _cached_enemy_texture
		return

	# 根据敌人类型选择对应的预定义图片列表
	var sprite_list: Array = _NORMAL_ENEMY_SPRITES
	match e.type:
		EnemyFactory.TYPE_ELITE: sprite_list = _ELITE_ENEMY_SPRITES
		EnemyFactory.TYPE_BOSS: sprite_list = _BOSS_ENEMY_SPRITES

	# 根据敌人ID计算在列表中的索引
	# NORMAL: enemy_id 1-14, 列表有5个
	# ELITE: enemy_id 15-18, 列表有5个
	# BOSS: enemy_id 19-20, 列表有2个
	var index: int = 0
	match e.type:
		EnemyFactory.TYPE_NORMAL: index = (enemy_id - 1) % sprite_list.size()
		EnemyFactory.TYPE_ELITE: index = (enemy_id - 15) % sprite_list.size()
		EnemyFactory.TYPE_BOSS: index = (enemy_id - 19) % sprite_list.size()
		_: index = 0

	# 确保索引有效
	index = clamp(index, 0, sprite_list.size() - 1)
	var sprite_path: String = sprite_list[index]

	# 如果指定图片存在，加载它
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		_cached_enemy_texture = load(sprite_path)
		_cached_enemy_id = enemy_id
		enemy_sprite_rect.texture = _cached_enemy_texture
		return

	# 如果指定ID图片不存在，从列表中随机选择一个
	if sprite_list.size() > 0:
		var random_path: String = sprite_list[randi_range(0, sprite_list.size() - 1)]
		if ResourceLoader.exists(random_path):
			_cached_enemy_texture = load(random_path)
			_cached_enemy_id = enemy_id
			enemy_sprite_rect.texture = _cached_enemy_texture
			return

	# 实在没有图片就设为null
	_cached_enemy_texture = null
	_cached_enemy_id = enemy_id
	enemy_sprite_rect.texture = null
	print(">>> [BattleScene] 警告: 无法加载敌人类型 %d ID=%d 的图片" % [e.type, enemy_id])


## 更新敌人精灵图上的攻防图标
func _update_enemy_sprite_ui(e: EnemyFactory.EnemyData) -> void:
	# 清除旧的UI元素
	var children_to_remove := []
	for j in range(enemy_sprite_rect.get_child_count()):
		var child := enemy_sprite_rect.get_child(j)
		if child.name.begins_with("AtkBox") or child.name.begins_with("DefBox"):
			children_to_remove.append(child)
	for child in children_to_remove:
		child.queue_free()
	
	# 根据sprite实际尺寸计算位置（使用custom_minimum_size，因为纹理加载后size不会立即更新）
	var sprite_size: Vector2 = enemy_sprite_rect.custom_minimum_size
	var icon_size: int = 50  # 图标尺寸

	# 攻击图标+数值（左下角外侧）
	var atk_container := Control.new()
	atk_container.position = Vector2(-5, sprite_size.y - icon_size + 5)
	atk_container.custom_minimum_size = Vector2(icon_size, icon_size)
	atk_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_sprite_rect.add_child(atk_container)
	atk_container.name = "AtkBox"

	var atk_icon := TextureRect.new()
	atk_icon.texture = load("res://art/sprites/UI/items/smallItem/attack.png")
	atk_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	atk_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	atk_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	atk_icon.position = Vector2(0, 0)
	atk_icon.modulate = Color(1, 0.3, 0.3)  # 红色
	atk_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atk_container.add_child(atk_icon)

	var atk_label := Label.new()
	atk_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	atk_label.text = "%d" % e.attack
	atk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atk_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	atk_label.add_theme_font_size_override("font_size", 32)
	atk_label.add_theme_color_override("font_color", Color.WHITE)
	atk_label.add_theme_color_override("font_outline_color", Color.BLACK)
	atk_label.add_theme_constant_override("outline_size", 3)
	atk_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atk_container.add_child(atk_label)

	# 防御图标+数值（右下角外侧）
	var def_container := Control.new()
	def_container.position = Vector2(sprite_size.x -10, sprite_size.y - icon_size + 5)
	def_container.custom_minimum_size = Vector2(icon_size, icon_size)
	def_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_sprite_rect.add_child(def_container)
	def_container.name = "DefBox"

	var def_icon := TextureRect.new()
	def_icon.texture = load("res://art/sprites/UI/items/smallItem/defend.png")
	def_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	def_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	def_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	def_icon.position = Vector2(0, 0)
	def_icon.modulate = Color(0.3, 0.5, 1)  # 蓝色
	def_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	def_container.add_child(def_icon)

	var def_label := Label.new()
	def_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	def_label.text = "%d" % e.defense
	def_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	def_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	def_label.add_theme_font_size_override("font_size", 32)
	def_label.add_theme_color_override("font_color", Color.WHITE)
	def_label.add_theme_color_override("font_outline_color", Color.BLACK)
	def_label.add_theme_constant_override("outline_size", 3)
	def_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	def_container.add_child(def_label)


## 更新特技显示
func _update_skill_display(e: EnemyFactory.EnemyData) -> void:
	var skill_id: int = e.skill_id
	if skill_id == 0:
		# 普通敌人没有特技，隐藏文字
		skill_name_label.visible = false
		skill_desc_label.visible = false
		return
	
	# 有特技时显示文字
	skill_name_label.visible = true
	skill_desc_label.visible = true

	# 获取特技名称和描述
	var skill_info: Dictionary = _get_skill_info(skill_id)
	skill_name_label.text = skill_info.get("name", "Skill %d" % skill_id)
	skill_desc_label.text = skill_info.get("description", "")


## 获取特技信息
func _get_skill_info(skill_id: int) -> Dictionary:
	# 特技ID范围: 2001-2008 精英, 3001-3008 BOSS
	var skill_name: String = ""
	var skill_desc: String = ""

	match skill_id:
		2001:
			skill_name = LocalizationSystem.get_text("skill.2001_name")
			skill_desc = LocalizationSystem.get_text("skill.2001_desc")
		2002:
			skill_name = LocalizationSystem.get_text("skill.2002_name")
			skill_desc = LocalizationSystem.get_text("skill.2002_desc")
		2003:
			skill_name = LocalizationSystem.get_text("skill.2003_name")
			skill_desc = LocalizationSystem.get_text("skill.2003_desc")
		2004:
			skill_name = LocalizationSystem.get_text("skill.2004_name")
			skill_desc = LocalizationSystem.get_text("skill.2004_desc")
		2005:
			skill_name = LocalizationSystem.get_text("skill.2005_name")
			skill_desc = LocalizationSystem.get_text("skill.2005_desc")
		2006:
			skill_name = LocalizationSystem.get_text("skill.2006_name")
			skill_desc = LocalizationSystem.get_text("skill.2006_desc")
		2007:
			skill_name = LocalizationSystem.get_text("skill.2007_name")
			skill_desc = LocalizationSystem.get_text("skill.2007_desc")
		2008:
			skill_name = LocalizationSystem.get_text("skill.2008_name")
			skill_desc = LocalizationSystem.get_text("skill.2008_desc")
		3001:
			skill_name = LocalizationSystem.get_text("skill.3001_name")
			skill_desc = LocalizationSystem.get_text("skill.3001_desc")
		3002:
			skill_name = LocalizationSystem.get_text("skill.3002_name")
			skill_desc = LocalizationSystem.get_text("skill.3002_desc")
		3003:
			skill_name = LocalizationSystem.get_text("skill.3003_name")
			skill_desc = LocalizationSystem.get_text("skill.3003_desc")
		3004:
			skill_name = LocalizationSystem.get_text("skill.3004_name")
			skill_desc = LocalizationSystem.get_text("skill.3004_desc")
		3005:
			skill_name = LocalizationSystem.get_text("skill.3005_name")
			skill_desc = LocalizationSystem.get_text("skill.3005_desc")
		3006:
			skill_name = LocalizationSystem.get_text("skill.3006_name")
			skill_desc = LocalizationSystem.get_text("skill.3006_desc")
		3007:
			skill_name = LocalizationSystem.get_text("skill.3007_name")
			skill_desc = LocalizationSystem.get_text("skill.3007_desc")
		3008:
			skill_name = LocalizationSystem.get_text("skill.3008_name")
			skill_desc = LocalizationSystem.get_text("skill.3008_desc")
		_:
			skill_name = LocalizationSystem.get_text("enemy.no_skill")
			skill_desc = ""

	return {"name": skill_name, "description": skill_desc}


func _refresh_board_display() -> void:
	var bd: BoardData = GameManager.board_data
	for i in range(BoardData.BOARD_SLOTS):
		var ch: DataModels.CharacterData = bd.get_character_at_index(i)
		var cell: Control = grid_container.get_child(i)
		if ch != null:
			if ch.is_alive():
				# 检测是否从死亡复活（一般不会发生）
				prev_alive_status[i] = true

				# 角色格子：不设置背景颜色，保持默认交替灰度
				@warning_ignore("integer_division")
				var row := i / GRID_COLS
				var col := i % GRID_COLS
				var is_even := (row + col) % 2 == 0
				cell_rects[i].modulate = Color(0.5, 0.5, 0.5, 0.9) if is_even else Color(0.8, 0.8, 0.8, 0.7)

				# 加载精灵图
				var sprite_folder: String = ch.get_sprite_folder()
				var sprite_name: String = ch.get_sprite_path(1, 1)
				var sprite_path: String = "res://art/sprites/chars/" + sprite_folder + "/" + sprite_name + ".png"
				var tex := load(sprite_path) if ResourceLoader.exists(sprite_path) else null
				cell_sprites[i].texture = tex
				cell_sprites[i].visible = (tex != null)

				# 重置材质（移除死亡shader）
				cell_sprites[i].material = null

				# 更新格子内的UI元素
				_update_cell_ui(cell, ch)
			else:
				# 检测是否刚死亡（之前存活，现在死亡）
				var just_died: bool = prev_alive_status[i]
				prev_alive_status[i] = false
				
				# 如果正在播放死亡动画，跳过处理
				if death_animation_playing[i]:
					continue
				
				if just_died:
					# 播放死亡动画
					_play_death_animation(i)
				else:
					# 已经是死亡状态，灰暗显示
					cell_rects[i].modulate = Color(COLOR_DEAD, 0.9)
					cell_labels[i].text = LocalizationSystem.get_text("battle.dead")
					cell_sprites[i].texture = null
					cell_sprites[i].visible = false
					_clear_cell_ui(cell)
		else:
			# 空格子：恢复交替灰度
			prev_alive_status[i] = false
			@warning_ignore("integer_division")
			var row := i / GRID_COLS
			var col := i % GRID_COLS
			var is_even := (row + col) % 2 == 0
			cell_rects[i].modulate = Color(0.5, 0.5, 0.5, 0.9) if is_even else Color(0.8, 0.8, 0.8, 0.7)
			cell_labels[i].text = ""
			cell_sprites[i].texture = null
			cell_sprites[i].visible = false
			_clear_cell_ui(cell)


## 播放死亡动画（从上至下渐隐）
func _play_death_animation(cell_index: int) -> void:
	print(">>> [_play_death_animation] 开始播放死亡动画, 格子索引: %d" % cell_index)
	
	if cell_index < 0 or cell_index >= cell_sprites.size():
		print(">>> [_play_death_animation] 错误: 格子索引越界 %d" % cell_index)
		return

	var sprite: TextureRect = cell_sprites[cell_index]
	if sprite == null or not is_instance_valid(sprite):
		print(">>> [_play_death_animation] 错误: sprite无效")
		return
	
	# 标记正在播放死亡动画
	death_animation_playing[cell_index] = true

	# 清除UI元素
	var cell: Control = grid_container.get_child(cell_index)
	print(">>> [_play_death_animation] 调用 _clear_cell_ui")
	_clear_cell_ui(cell)

	# 应用死亡shader
	var mat := ShaderMaterial.new()
	mat.shader = DEATH_SHADER
	mat.set_shader_parameter("dissolve_amount", 0.0)
	mat.set_shader_parameter("fade_color", Color(0.5, 0.5, 0.5, 1.0))
	sprite.material = mat

	# 创建tween动画
	var tween := create_tween()
	tween.tween_method(_set_dissolve_amount.bind(mat), 0.0, 1.2, 0.6)

	# 动画结束后隐藏sprite
	tween.tween_callback(_on_death_animation_finished.bind(cell_index, sprite, mat))


## 设置溶解参数（用于tween回调）
func _set_dissolve_amount(value: float, mat: ShaderMaterial) -> void:
	if is_instance_valid(mat):
		mat.set_shader_parameter("dissolve_amount", value)


## 死亡动画完成回调
func _on_death_animation_finished(cell_index: int, sprite: TextureRect, mat: ShaderMaterial) -> void:
	print(">>> [_on_death_animation_finished] 死亡动画完成, 格子索引: %d" % cell_index)
	
	# 清除死亡动画标记
	if cell_index >= 0 and cell_index < death_animation_playing.size():
		death_animation_playing[cell_index] = false
	
	if is_instance_valid(sprite):
		sprite.visible = false
		sprite.texture = null
	if is_instance_valid(mat):
		mat.shader = null
	# 再次确保清除UI元素
	if cell_index >= 0 and cell_index < grid_container.get_child_count():
		var cell: Control = grid_container.get_child(cell_index)
		print(">>> [_on_death_animation_finished] 再次调用 _clear_cell_ui")
		_clear_cell_ui(cell)
	# 设置格子为死亡状态
	if cell_index >= 0 and cell_index < cell_rects.size():
		cell_rects[cell_index].modulate = Color(COLOR_DEAD, 0.9)
		cell_labels[cell_index].text = LocalizationSystem.get_text("battle.dead")
		print(">>> [_on_death_animation_finished] 格子 %d 已设为死亡状态" % cell_index)


## 更新格子内的UI元素（血条、攻击、防御）
func _update_cell_ui(cell: Control, ch: DataModels.CharacterData) -> void:
	var cell_index: int = cell.get_index()
	print(">>> [_update_cell_ui] 格子 %d, 角色: %s, HP: %d/%d, ATK: %d, DEF: %d" % [cell_index, ch.get_job_name(), ch.hp, ch.max_hp, ch.attack, ch.defense])
	
	# 清除旧的UI元素（保留bg、lbl、sprite）
	var children_to_remove := []
	for j in range(cell.get_child_count()):
		var child := cell.get_child(j)
		if child.name.begins_with("HpBar") or child.name.begins_with("HpLabel") or child.name.begins_with("AtkBox") or child.name.begins_with("DefBox"):
			children_to_remove.append(child)
	print(">>> [_update_cell_ui] 格子 %d 需要清除的旧UI元素数量: %d" % [cell_index, children_to_remove.size()])
	for child in children_to_remove:
		child.queue_free()

	# 隐藏旧的标签（不显示名字和等级）
	var lbl: Label = cell_labels[cell.get_index()]
	if lbl:
		lbl.text = ""

	# 血条容器（底部，宽度=格子宽度-40，左右边距各20）
	var hp_container := Control.new()
	hp_container.custom_minimum_size = Vector2(CELL_SIZE - 40, 20)
	hp_container.position = Vector2(20, CELL_SIZE - 25)
	hp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 不设置z_index，保持在格子层级内
	cell.add_child(hp_container)
	hp_container.name = "HpBar"

	# 血条背景
	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(CELL_SIZE - 40, 16)
	hp_bar.max_value = ch.max_hp
	hp_bar.value = ch.hp
	hp_bar.show_percentage = false
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 设置血条样式为红色
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	hp_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.9, 0.2, 0.2)  # 红色
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	
	hp_container.add_child(hp_bar)

	# 血量文字叠加在血条上
	var hp_label := Label.new()
	hp_label.size = Vector2(CELL_SIZE - 40, 16)
	hp_label.text = "%d/%d" % [ch.hp, ch.max_hp]
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 24)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hp_label.add_theme_constant_override("outline_size", 2)
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_container.add_child(hp_label)
	hp_label.name = "HpLabel"

	# 攻击图标+数值（左上角，数值叠加在图标上，尺寸为0.7倍）
	var atk_container := Control.new()
	atk_container.position = Vector2(4, 4)
	atk_container.custom_minimum_size = Vector2(39, 39)
	atk_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(atk_container)
	atk_container.name = "AtkBox"
	
	var atk_icon := TextureRect.new()
	atk_icon.texture = load("res://art/sprites/UI/items/smallItem/attack.png")
	atk_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	atk_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	atk_icon.custom_minimum_size = Vector2(39, 39)
	atk_icon.position = Vector2(0, 0)
	atk_icon.modulate = Color(1, 0.3, 0.3)  # 红色
	atk_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atk_container.add_child(atk_icon)
	
	var atk_label := Label.new()
	atk_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	atk_label.text = "%d" % ch.attack
	atk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atk_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	atk_label.add_theme_font_size_override("font_size", 25)
	atk_label.add_theme_color_override("font_color", Color.WHITE)
	atk_label.add_theme_color_override("font_outline_color", Color.BLACK)
	atk_label.add_theme_constant_override("outline_size", 2)
	atk_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atk_container.add_child(atk_label)

	# 防御图标+数值（右上角，数值叠加在图标上，尺寸为0.7倍）
	var def_container := Control.new()
	def_container.position = Vector2(CELL_SIZE - 43, 4)
	def_container.custom_minimum_size = Vector2(39, 39)
	def_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(def_container)
	def_container.name = "DefBox"
	
	var def_icon := TextureRect.new()
	def_icon.texture = load("res://art/sprites/UI/items/smallItem/defend.png")
	def_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	def_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	def_icon.custom_minimum_size = Vector2(39, 39)
	def_icon.position = Vector2(0, 0)
	def_icon.modulate = Color(0.3, 0.5, 1)  # 蓝色
	def_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	def_container.add_child(def_icon)
	
	var def_label := Label.new()
	def_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	def_label.text = "%d" % ch.defense
	def_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	def_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	def_label.add_theme_font_size_override("font_size", 25)
	def_label.add_theme_color_override("font_color", Color.WHITE)
	def_label.add_theme_color_override("font_outline_color", Color.BLACK)
	def_label.add_theme_constant_override("outline_size", 2)
	def_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	def_container.add_child(def_label)


## 清除格子内的UI元素
func _clear_cell_ui(cell: Control) -> void:
	var cell_index: int = cell.get_index()
	
	# 打印所有子节点的 name 属性（转为字符串）
	print(">>> [_clear_cell_ui] 格子 %d 子节点数量: %d" % [cell_index, cell.get_child_count()])
	for j in range(cell.get_child_count()):
		var child := cell.get_child(j)
		print("  [%d] 类型: %s, 名字: '%s'" % [j, child.get_class(), str(child.name)])
	
	var children_to_remove := []
	for j in range(cell.get_child_count()):
		var child := cell.get_child(j)
		var child_name: String = str(child.name)
		# 使用更通用的匹配：名字以这些前缀开头
		if child_name.begins_with("HpBar") or child_name.begins_with("HpLabel") or child_name.begins_with("AtkBox") or child_name.begins_with("DefBox"):
			children_to_remove.append(child)
	
	print(">>> [_clear_cell_ui] 格子 %d 清除UI元素, 数量: %d" % [cell_index, children_to_remove.size()])
	
	for child in children_to_remove:
		# 立即隐藏并移除，避免时序问题
		child.visible = false
		child.queue_free()


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


func _on_battle_log(msg: String) -> void:
	log_label.text += msg + "\n"


# ============================================
# 子弹与动画系统
# ============================================

## 获取敌方面板的世界位置（用于计算子弹目标）
func _get_enemy_position() -> Vector2:
	var enemy_sprite: Control = get_node_or_null("MainLayout/EnemyArea/EnemySpriteRect")
	if enemy_sprite:
		var rect: Rect2 = enemy_sprite.get_global_rect()
		return rect.position + rect.size * 0.5
	# 默认位置：屏幕顶部左侧
	return get_viewport().get_visible_rect().size * 0.25 + Vector2(0, 50)


## 获取棋盘格子的世界位置
func _get_cell_position(cell_index: int) -> Vector2:
	if cell_index < 0 or cell_index >= cell_rects.size():
		return Vector2.ZERO
	var cell: Control = cell_rects[cell_index]
	if cell:
		var rect: Rect2 = cell.get_global_rect()
		return rect.position + rect.size * 0.5
	return Vector2.ZERO


## 播放攻击动画（squash & stretch）
func _play_attack_animation(cell_index: int) -> void:
	if cell_index < 0 or cell_index >= cell_sprites.size():
		return
	var sprite: Control = cell_sprites[cell_index]
	if sprite == null or not is_instance_valid(sprite):
		return

	# 设置pivot_offset为中心
	if "pivot_offset" in sprite:
		sprite.pivot_offset = Vector2(CELL_SIZE / 2, CELL_SIZE / 2)

	# 重置
	sprite.scale = Vector2(1.0, 1.0)
	sprite.modulate = Color.WHITE

	# 创建动画序列：x轴1.1 y轴0.9 -> x轴0.9 y轴1.1 -> 恢复
	var tween := create_tween()
	tween.set_parallel(false)

	# Phase 1: x拉长 y压缩
	tween.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.1).from(Vector2(1.0, 1.0))
	# Phase 2: x压缩 y拉长
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.15)
	# Phase 3: 恢复原尺寸
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)


## 我方角色被击中动画（与攻击动画相反：先x压缩y拉长，再x拉长y压缩）
func _play_character_hit_animation(cell_index: int) -> void:
	if cell_index < 0 or cell_index >= cell_sprites.size():
		return
	var sprite: Control = cell_sprites[cell_index]
	if sprite == null or not is_instance_valid(sprite):
		return

	# 设置pivot_offset为中心
	if "pivot_offset" in sprite:
		sprite.pivot_offset = Vector2(CELL_SIZE / 2, CELL_SIZE / 2)

	# 重置
	sprite.scale = Vector2(1.0, 1.0)

	# 创建动画序列：与攻击动画相反
	var tween := create_tween()
	tween.set_parallel(false)

	# Phase 1: x压缩 y拉长
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.1).from(Vector2(1.0, 1.0))
	# Phase 2: x拉长 y压缩
	tween.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.15)
	# Phase 3: 恢复原尺寸
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)


## 敌人被击中动画（squash & stretch，带叠加效果）
var _enemy_hit_offset_x: float = 0.01  # x轴拉长增量
var _enemy_hit_offset_y: float = 0.01   # y轴收缩增量

func _play_enemy_hit_animation() -> void:
	var enemy_sprite: Control = enemy_sprite_rect
	if enemy_sprite == null or not is_instance_valid(enemy_sprite):
		return

	# 设置pivot_offset为中心
	var sprite_size: Vector2 = enemy_sprite.size
	if sprite_size.x > 0 and sprite_size.y > 0:
		enemy_sprite.pivot_offset = sprite_size * 0.5
	else:
		enemy_sprite.pivot_offset = Vector2(100, 100)  # 默认200x200的中心

	# 获取当前scale作为新的基准（叠加效果）
	var base_scale: Vector2 = enemy_sprite.scale
	# 如果当前scale接近(1,1)，说明是初始状态，重置基准
	if absf(base_scale.x - 1.0) < 0.001 and absf(base_scale.y - 1.0) < 0.001:
		base_scale = Vector2(1.0, 1.0)
		_enemy_hit_offset_x = 0.01
		_enemy_hit_offset_y = 0.01

	# 叠加效果：增加偏移量
	_enemy_hit_offset_x += 0.01
	_enemy_hit_offset_y += 0.01

	# 计算新的目标scale
	var target_scale_x: float = base_scale.x + _enemy_hit_offset_x
	var target_scale_y: float = base_scale.y - _enemy_hit_offset_y

	# 创建动画：x拉长到1+offset，y收缩到1-offset，然后恢复
	var tween := create_tween()
	tween.set_parallel(false)

	# Phase 1: x拉长 y收缩
	tween.tween_property(enemy_sprite, "scale", Vector2(target_scale_x, target_scale_y), 0.08).from(base_scale)
	# Phase 2: 恢复原尺寸
	tween.tween_property(enemy_sprite, "scale", Vector2(1.0, 1.0), 0.12)

	# 重置偏移量（动画结束后回归初始累积）
	tween.tween_callback(_reset_enemy_hit_offset)


## 重置敌人被击中动画的偏移量
func _reset_enemy_hit_offset() -> void:
	_enemy_hit_offset_x = 0.01
	_enemy_hit_offset_y = 0.01


## 敌人发射子弹动效（与我方角色被击中动画一致：x压缩y拉长 -> x拉长y压缩 -> 恢复）
func _play_enemy_shoot_animation() -> void:
	var enemy_sprite: Control = enemy_sprite_rect
	if enemy_sprite == null or not is_instance_valid(enemy_sprite):
		return

	# 设置pivot_offset为中心
	var sprite_size: Vector2 = enemy_sprite.size
	if sprite_size.x > 0 and sprite_size.y > 0:
		enemy_sprite.pivot_offset = sprite_size * 0.5
	else:
		enemy_sprite.pivot_offset = Vector2(100, 100)  # 默认200x200的中心

	# 重置
	enemy_sprite.scale = Vector2(1.0, 1.0)

	# 创建动画序列：与角色被击中动画一致
	var tween := create_tween()
	tween.set_parallel(false)

	# Phase 1: x压缩 y拉长
	tween.tween_property(enemy_sprite, "scale", Vector2(0.9, 1.1), 0.08).from(Vector2(1.0, 1.0))
	# Phase 2: x拉长 y压缩
	tween.tween_property(enemy_sprite, "scale", Vector2(1.1, 0.9), 0.1)
	# Phase 3: 恢复原尺寸
	tween.tween_property(enemy_sprite, "scale", Vector2(1.0, 1.0), 0.08)


## 发射子弹（从源头到目标）
## @param bullet_type: 子弹类型 (ATTACK/HEAL/BLESS/ENEMY)
## @param damage: 伤害值
## @param source_pos: 起始位置
## @param target_pos: 目标位置
## @param target_idx: 目标棋盘索引
## @param job: 职业 (0=战士, 1=法师, 2=牧师, 3=敌人)
## @param tier: 等级 (1=原职/普通, 2=转职/精英, 3=高阶/Boss)
func _fire_bullet(bullet_type: int, damage: int, source_pos: Vector2, target_pos: Vector2, target_idx: int = -1, job: int = 0, tier: int = 1) -> void:
	var bullet = bullet_pool.get_bullet()

	bullet.setup(bullet_type, damage, target_idx, source_pos, target_pos, job, tier)

	# 连接信号（确保不重复连接）
	if not bullet.bullet_hit.is_connected(_on_bullet_hit):
		bullet.bullet_hit.connect(_on_bullet_hit)
	var finished_callable: Callable = _on_bullet_finished.bind(bullet)
	if not bullet.bullet_finished.is_connected(finished_callable):
		bullet.bullet_finished.connect(finished_callable)


## 子弹命中回调
func _on_bullet_hit(target_idx: int, damage: int, bullet_type: int) -> void:
	# 安全检查：确保战斗还在进行
	if engine == null:
		return

	match bullet_type:
		BULLET_TYPE_ATTACK:
			# 播放命中音效
			SoundSystem.play_bullet_hit()
			# 对敌方造成伤害
			if engine.enemy != null and engine.enemy.is_alive():
				engine.enemy.take_damage(damage)
				_log_attack_result(engine.enemy.name, damage, engine.enemy.hp)
				# 立即更新敌人血量显示（如果血条宽度未设置，使用默认120）
				var hp_bar_w: int = int(enemy_hp_bar.custom_minimum_size.x)
				if hp_bar_w <= 0:
					hp_bar_w = 120
				_update_enemy_hp_label(engine.enemy, hp_bar_w)
				# 敌人被击中动画
				_play_enemy_hit_animation()
				# 检查敌人是否死亡
				if not engine.enemy.is_alive():
					# 敌人死亡，不等子弹完成，直接弹出结算
					_handle_enemy_death()
					return
			else:
				# 敌人已死亡，忽略此次命中
				return
		BULLET_TYPE_HEAL:
			# 治疗我方角色
			if target_idx < 0 or target_idx >= BoardData.BOARD_SLOTS:
				return
			var bd: BoardData = GameManager.board_data
			if bd == null:
				return
			var ch: DataModels.CharacterData = bd.get_character_at_index(target_idx)
			if ch == null or not ch.is_alive():
				return
			# 治疗
			ch.heal(damage)
			if engine and engine.on_log:
				var msg: String = "[%s] 受到治疗 %d, 当前 HP: %d/%d" % [ch.get_job_name(), damage, ch.hp, ch.max_hp]
				engine.on_log.call(msg)
		BULLET_TYPE_ENEMY:
			# 对我方角色造成伤害
			if target_idx < 0 or target_idx >= BoardData.BOARD_SLOTS:
				return
			var bd: BoardData = GameManager.board_data
			if bd == null:
				return
			var ch: DataModels.CharacterData = bd.get_character_at_index(target_idx)
			if ch == null or not ch.is_alive():
				return
			# 检查格挡
			var base_job: int = ch.get_base_job()
			if base_job == DataModels.Job.WARRIOR and ch.skill_level > 0:
				if GameManager.battle_turn % 3 == 0:
					_log_attack_result(ch.get_job_name(), 0, ch.hp)
					return  # 格挡
			ch.take_damage(damage)
			_log_attack_result(ch.get_job_name(), damage, ch.hp)
			# 我方角色被击中动画（与攻击动画相反：先x压缩y拉长，再x拉长y压缩）
			_play_character_hit_animation(target_idx)
			# 检查角色是否死亡
			if not ch.is_alive():
				_play_death_animation(target_idx)
		_:
			# 未知的子弹类型，忽略
			print(">>> [BattleScene] 未知子弹类型: %d" % bullet_type)


func _log_attack_result(target_name: String, damage: int, remaining_hp: int) -> void:
	if engine and engine.on_log:
		var msg: String = "[%s] 受到伤害 %d, 剩余 HP: %d" % [target_name, damage, remaining_hp]
		engine.on_log.call(msg)


## 子弹完成回调
func _on_bullet_finished(bullet: CharacterBody2D) -> void:
	bullet_pool.return_bullet(bullet)


## 等待所有子弹完成
func _wait_for_bullets() -> void:
	while bullet_pool.get_active_count() > 0:
		await get_tree().create_timer(0.05).timeout


## 暂停感知的等待函数
## 等待指定时间，但在暂停时会阻塞
func _wait_with_pause(seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		if is_paused:
			# 暂停时阻塞，等待恢复
			while is_paused:
				await get_tree().create_timer(0.05).timeout
		else:
			var wait_time: float = minf(0.05, seconds - elapsed)
			await get_tree().create_timer(wait_time).timeout
			elapsed += wait_time


## 我方攻击阶段：播放动画并发射子弹
func _execute_player_attack_phase() -> void:
	if engine == null:
		return

	current_phase = BattlePhase.PLAYER_ATTACK
	var bd: BoardData = GameManager.board_data
	var enemy_pos: Vector2 = _get_enemy_position()

	# 获取所有存活角色
	var alive_chars: Array = bd.get_alive_characters()
	if alive_chars.size() == 0:
		current_phase = BattlePhase.IDLE
		return

	# 1. 播放攻击动画并发射子弹
	for ch in alive_chars:
		if not ch.is_alive():
			continue

		# 暂停检查：在发射前等待恢复
		while is_paused:
			await get_tree().create_timer(0.05).timeout

		# 获取角色在棋盘上的位置
		var cell_idx: int = ch.get_board_index()
		if cell_idx < 0:
			continue

		var base_job: int = ch.get_base_job()
		
		# 计算子弹职业和等级
		# job: 0=战士, 1=法师, 2=牧师
		# tier: 1=原职(1-3级), 2=转职(4-6级), 3=高阶(7+级)
		var bullet_job: int = base_job
		var bullet_tier: int = 1
		if ch.level >= 7:
			bullet_tier = 3
		elif ch.level >= 4:
			bullet_tier = 2

		# 获取角色sprite位置
		var source_pos: Vector2 = _get_cell_position(cell_idx)

		# 播放攻击动画
		_play_attack_animation(cell_idx)

		# 等待动画Phase 1完成后发射子弹（暂停感知）
		await _wait_with_pause(0.1)

		# 牧师系（牧师、暗牧师、圣骑士）：发射治疗子弹到需要治疗的队友
		if base_job == DataModels.Job.PRIEST or ch.job == JobAdvanced.JOB_PALADIN:
			var heal_target: DataModels.CharacterData = _find_heal_target(ch, alive_chars)
			if heal_target != null:
				var target_pos: Vector2 = _get_cell_position(heal_target.get_board_index())
				var heal_amount: int = ch.attack  # 治疗量 = 攻击力
				_fire_bullet(BULLET_TYPE_HEAL, heal_amount, source_pos, target_pos, heal_target.get_board_index(), bullet_job, bullet_tier)
			continue
		
		# 其他职业：检查敌人是否存活
		if engine.enemy == null or not engine.enemy.is_alive():
			continue

		# 计算伤害
		var damage: int = maxi(ch.attack - engine.enemy.defense, 1)
		# 法师穿透
		if base_job == DataModels.Job.MAGE and ch.skill_level > 0:
			damage += ch.skill_level  # 穿透伤害
		# 遗物23: 穿透+1
		if ItemDatabase.has_relic(23, GameManager.relics):
			damage += 1

		# 发射攻击子弹到敌人
		_fire_bullet(BULLET_TYPE_ATTACK, damage, source_pos, enemy_pos, -1, bullet_job, bullet_tier)
		# 播放攻击音效
		SoundSystem.play_attack_fire()

	# 2. 等待所有子弹命中（暂停感知）
	await _wait_with_pause(0.5)

	# 3. 更新显示
	_update_enemy_display()
	_refresh_board_display()

	current_phase = BattlePhase.IDLE


## 找到需要治疗的目标（优先治疗自己，然后治疗受伤最重的队友）
func _find_heal_target(healer: DataModels.CharacterData, alive_chars: Array) -> DataModels.CharacterData:
	# 如果自己受伤，优先治疗自己
	if healer.hp < healer.max_hp:
		return healer
	
	# 找受伤最重的队友
	var most_wounded: DataModels.CharacterData = null
	var lowest_hp_ratio: float = 1.0
	
	for ch in alive_chars:
		if ch == healer:
			continue
		if not ch.is_alive():
			continue
		var hp_ratio: float = float(ch.hp) / float(ch.max_hp)
		if hp_ratio < lowest_hp_ratio:
			lowest_hp_ratio = hp_ratio
			most_wounded = ch
	
	# 只有受伤的队友才治疗
	if most_wounded != null and most_wounded.hp < most_wounded.max_hp:
		return most_wounded
	
	return null


## 敌方攻击阶段：播放动画并发射子弹
func _execute_enemy_attack_phase() -> void:
	if engine == null or engine.enemy == null or not engine.enemy.is_alive():
		current_phase = BattlePhase.IDLE
		return

	current_phase = BattlePhase.ENEMY_ATTACK
	var bd: BoardData = GameManager.board_data
	var enemy_pos: Vector2 = _get_enemy_position()

	# 构建列到角色的映射（每列取最前面的存活角色）
	# 从row 0开始找，每列只要有存活角色就发射子弹
	var col_to_target: Dictionary = {}
	for row in range(GRID_ROWS):  # 从前排开始
		for col in range(GRID_COLS):
			var index: int = row * GRID_COLS + col
			var ch: DataModels.CharacterData = bd.get_character_at_index(index)
			if ch != null and ch.is_alive() and not col_to_target.has(col):
				col_to_target[col] = ch

	if col_to_target.size() == 0:
		current_phase = BattlePhase.IDLE
		return

	# 敌方最多发射6发子弹
	var bullet_count: int = mini(col_to_target.size(), 6)
	var cols: Array = col_to_target.keys()
	cols.sort()  # 从左到右

	# 发射子弹到各列
	# 敌方子弹参数: job=3(敌人), tier根据type
	var enemy_job: int = 3  # ENEMY
	var enemy_tier: int = 1  # 默认 normal
	match engine.enemy.type:
		EnemyFactory.TYPE_ELITE: enemy_tier = 2
		EnemyFactory.TYPE_BOSS: enemy_tier = 3

	for i in range(bullet_count):
		# 暂停检查：在发射前等待恢复
		while is_paused:
			await get_tree().create_timer(0.05).timeout

		var col: int = cols[i]
		var target_ch: DataModels.CharacterData = col_to_target[col]
		var target_idx: int = target_ch.get_board_index()
		var target_pos: Vector2 = _get_cell_position(target_idx)

		# 计算伤害
		var damage: int = maxi(engine.enemy.attack - target_ch.defense, 1)

		# 敌人发射子弹动效（与我方角色被击中动画一致：x压缩y拉长 -> x拉长y压缩）
		_play_enemy_shoot_animation()

		# 发射子弹
		_fire_bullet(BULLET_TYPE_ENEMY, damage, enemy_pos, target_pos, target_idx, enemy_job, enemy_tier)

	# 等待子弹命中（暂停感知）
	await _wait_with_pause(0.6)

	# 更新显示
	_refresh_board_display()

	current_phase = BattlePhase.IDLE


## 异步回合执行（替换原来的同步execute_turn）
func _play_turn_async() -> void:
	if not is_playing or battle_finished:
		return
	if is_paused:
		return

	# 回合开始
	GameManager.advance_battle_turn()
	var turn: int = GameManager.battle_turn
	_log(LocalizationSystem.get_text("battle_log.turn") % turn)

	# 触发回合开始buffs
	_trigger_round_start_buffs()

	# 我方攻击阶段
	await _execute_player_attack_phase()

	# 检查敌方是否阵亡（如果子弹命中已经触发结算，battle_finished会是true，不会重复触发）
	if not battle_finished and engine.enemy != null and not engine.enemy.is_alive():
		_handle_enemy_death()
		return

	# 敌方攻击阶段
	await _execute_enemy_attack_phase()

	# 检查我方是否全灭
	_refresh_alive_list()
	if engine.allies.size() == 0:
		_on_battle_end(BattleEngine.RESULT_LOSE)
		return

	# 检查回合超时
	if GameManager.is_battle_timeout():
		_on_battle_end(BattleEngine.RESULT_DRAW)
		return

	# 进入下一回合
	turn_label.text = str(GameManager.battle_turn)
	var delay: float = BASE_TURN_DELAY / battle_speed
	pending_timer = get_tree().create_timer(delay)
	pending_timer.timeout.connect(_play_turn_async)


func _log(msg: String) -> void:
	if engine and engine.on_log:
		engine.on_log.call(msg)


func _trigger_round_start_buffs() -> void:
	if engine:
		engine._trigger_round_start_buffs()


func _refresh_alive_list() -> void:
	if engine:
		engine.allies = GameManager.board_data.get_alive_characters()


func _handle_enemy_death() -> void:
	if engine.on_log:
		engine.on_log.call(LocalizationSystem.get_text("battle_log.enemy_dead"))
	_on_battle_end(BattleEngine.RESULT_WIN)
