extends Control

## 战斗阶段场景
## 任务 3.3: 战斗UI + 任务 3.5: 胜负结算

# ---- 节点引用 ----
@onready var turn_label: Label = $MainLayout/BattleInfoBar/TurnCenter/TurnLabel
@onready var grid_container: GridContainer = $MainLayout/BoardCenter/GridContainer
@onready var log_label: RichTextLabel = $MainLayout/LogScroll/LogLabel
@onready var play_button: Button = $MainLayout/ControlBar/PlayButton
@onready var skip_button: Button = $MainLayout/ControlBar/SkipButton
@onready var result_label: Label = $BottomBar/ResultLabel
@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_title: Label = $ResultPanel/ResultVBox/ResultTitle
@onready var reward_label: Label = $ResultPanel/ResultVBox/RewardLabel
@onready var continue_button: Button = $ResultPanel/ResultVBox/ContinueButton
@onready var pause_button: Button = $MainLayout/ControlBar/PauseButton
@onready var speed_1x: Button = $MainLayout/ControlBar/Speed1x
@onready var speed_2x: Button = $MainLayout/ControlBar/Speed2x
@onready var speed_3x: Button = $MainLayout/ControlBar/Speed3x
@onready var pause_hint: Label = $MainLayout/ControlBar/PauseHint

# ---- Enemy Panel 节点 ----
@onready var enemy_name: Label = $MainLayout/BattleInfoBar/EnemyPanel/EnemyTitle/EnemyName
@onready var enemy_type: Label = $MainLayout/BattleInfoBar/EnemyPanel/EnemyTitle/EnemyType
@onready var enemy_atk: Label = $MainLayout/BattleInfoBar/EnemyPanel/EnemyStats/EnemyAtk
@onready var enemy_def: Label = $MainLayout/BattleInfoBar/EnemyPanel/EnemyStats/EnemyDef
@onready var enemy_hp_bar: ProgressBar = $MainLayout/BattleInfoBar/EnemyPanel/EnemyHpBar
@onready var enemy_hp_label: Label = $MainLayout/BattleInfoBar/EnemyPanel/EnemyHpLabel

# ---- Player Panel 节点 ----
@onready var player_name: Label = $MainLayout/BattleInfoBar/PlayerPanel/PlayerTitle/PlayerName
@onready var player_level: Label = $MainLayout/BattleInfoBar/PlayerPanel/PlayerTitle/PlayerLevel
@onready var player_atk: Label = $MainLayout/BattleInfoBar/PlayerPanel/PlayerStats/PlayerAtk
@onready var player_def: Label = $MainLayout/BattleInfoBar/PlayerPanel/PlayerStats/PlayerDef
@onready var player_hp_bar: ProgressBar = $MainLayout/BattleInfoBar/PlayerPanel/PlayerHpBar
@onready var player_hp_label: Label = $MainLayout/BattleInfoBar/PlayerPanel/PlayerHpLabel

# ---- ItemBar 节点 ----
@onready var item_slot0: PanelContainer = $MainLayout/BottomPanel/ItemBar/ItemSlots/ItemSlot0
@onready var item_slot1: PanelContainer = $MainLayout/BottomPanel/ItemBar/ItemSlots/ItemSlot1
@onready var item_slot2: PanelContainer = $MainLayout/BottomPanel/ItemBar/ItemSlots/ItemSlot2
@onready var item_slot3: PanelContainer = $MainLayout/BottomPanel/ItemBar/ItemSlots/ItemSlot3
@onready var item_slot4: PanelContainer = $MainLayout/BottomPanel/ItemBar/ItemSlots/ItemSlot4
@onready var item_slot5: PanelContainer = $MainLayout/BottomPanel/ItemBar/ItemSlots/ItemSlot5

# ---- RelicBar 节点 ----
@onready var relic_label: Label = $MainLayout/BattleInfoBar/TurnCenter/RelicLabel
@onready var relic_button: Button = $MainLayout/BottomPanel/RelicBar/RelicHeader/RelicButton
@onready var relic_list: HFlowContainer = $MainLayout/BottomPanel/RelicBar/RelicPanel/RelicList

# ---- 常量 ----
const GRID_SIZE := 6
const CELL_SIZE := 144
const CHAR_SIZE := 140
const BASE_TURN_DELAY := 0.5  # 播放模式每回合间隔(秒)

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
var item_detail_popup: Control = null
var item_detail_backdrop: Control = null
var item_detail_popup_slot: int = -1
var item_detail_visible: bool = false


func _ready() -> void:
	_connect_signals()
	_setup_board_display()
	_setup_bullet_container()
	_start_battle()
	_start_tutorial()
	print(">>> [BattleScene] 战斗场景已加载")


func _setup_bullet_container() -> void:
	# 创建子弹容器节点
	bullet_container = Node2D.new()
	bullet_container.name = "BulletContainer"
	add_child(bullet_container)

	# 初始化子弹对象池
	bullet_pool = BulletPool.new(bullet_container, 30)
	print(">>> [BattleScene] 子弹对象池已初始化")


func _start_tutorial() -> void:
	# 只有在第一回合且未完成教程时显示
	if GameManager.current_round == 1 and not GameManager.tutorial_completed:
		battle_tutorial_instance = preload("res://scripts/battle_tutorial_system.gd").new()
		add_child(battle_tutorial_instance)


# ---- 道具栏 & 遗物栏初始化 ----

func _setup_item_slots() -> void:
	var slots := [item_slot0, item_slot1, item_slot2, item_slot3, item_slot4, item_slot5]
	for i in range(GameManager.MAX_ITEM_SLOTS):
		var slot: PanelContainer = slots[i]
		# 清除旧内容
		for child in slot.get_children():
			child.queue_free()
		# 背景
		var bg := ColorRect.new()
		bg.set_anchors_preset(Control.PRESET_CENTER)
		bg.color = Color("#1A2A3A")
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(bg)
		# 图标/标签
		var lbl := Label.new()
		lbl.set_anchors_preset(Control.PRESET_CENTER)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 18)
		slot.add_child(lbl)

	_refresh_item_slots()


func _refresh_item_slots() -> void:
	var items: Array = GameManager.items
	var slots := [item_slot0, item_slot1, item_slot2, item_slot3, item_slot4, item_slot5]
	for i in range(GameManager.MAX_ITEM_SLOTS):
		var slot: PanelContainer = slots[i]
		var lbl: Label = slot.get_node_or_null(Label_path_from_index(slot, 1))  # 第二个子节点是Label
		if lbl == null:
			continue
		if i < items.size():
			var item: DataModels.ItemData = items[i]
			lbl.text = item.name
			lbl.modulate = Color.WHITE
		else:
			lbl.text = ""
			lbl.modulate = Color(0.3, 0.3, 0.3)


func _refresh_relic_display() -> void:
	var relics: Array = GameManager.relics
	relic_button.text = LocalizationSystem.get_text("battle.relics_count", {"count": relics.size()})
	# 清除旧显示
	for child in relic_list.get_children():
		child.queue_free()
	# 显示遗物图标
	for relic in relics:
		var lbl := Label.new()
		lbl.text = relic.name
		lbl.modulate = Color(1.0, 0.8, 0.4)
		lbl.add_theme_font_size_override("font_size", 20)
		relic_list.add_child(lbl)


func Label_path_from_index(slot: PanelContainer, index: int) -> NodePath:
	# 辅助: 获取slot第index个子节点的Label(如果有)
	if index < slot.get_child_count():
		var child = slot.get_child(index)
		if child is Label:
			return child.get_path()
	return NodePath()


# ---- 道具详情弹窗 ----

func _show_item_detail(slot_index: int) -> void:
	var items: Array = GameManager.items
	if slot_index < 0 or slot_index >= items.size():
		return

	_hide_item_detail()

	var item: DataModels.ItemData = items[slot_index]
	item_detail_popup_slot = slot_index
	item_detail_visible = true

	# 黑色遮罩
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	item_detail_backdrop = backdrop

	# 详情面板
	var popup_bg := ColorRect.new()
	popup_bg.set_anchors_preset(Control.PRESET_CENTER)
	popup_bg.offset_left = -120
	popup_bg.offset_top = -100
	popup_bg.offset_right = 120
	popup_bg.offset_bottom = 100
	popup_bg.color = Color("#2A3A5A")
	add_child(popup_bg)
	item_detail_popup = popup_bg

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	popup_bg.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = item.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 32)
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.custom_minimum_size = Vector2(200, 60)
	vbox.add_child(desc_lbl)

	var use_btn := Button.new()
	use_btn.text = LocalizationSystem.get_text("items.use")
	use_btn.pressed.connect(_on_item_use_pressed.bind(slot_index))
	vbox.add_child(use_btn)

	var discard_btn := Button.new()
	discard_btn.text = LocalizationSystem.get_text("items.discard")
	discard_btn.pressed.connect(_on_item_discard_pressed.bind(slot_index))
	vbox.add_child(discard_btn)

	var close_btn := Button.new()
	close_btn.text = LocalizationSystem.get_text("items.close")
	close_btn.pressed.connect(_hide_item_detail)
	vbox.add_child(close_btn)


func _hide_item_detail() -> void:
	item_detail_visible = false
	item_detail_popup_slot = -1
	if item_detail_popup != null:
		item_detail_popup.queue_free()
		item_detail_popup = null
	if item_detail_backdrop != null:
		item_detail_backdrop.queue_free()
		item_detail_backdrop = null


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_hide_item_detail()


func _on_item_use_pressed(slot_index: int) -> void:
	var items: Array = GameManager.items
	if slot_index < 0 or slot_index >= items.size():
		_hide_item_detail()
		return

	var item: DataModels.ItemData = items[slot_index]

	# 需要目标的道具
	if item.id in [1, 2, 3, 11, 13, 14, 15, 16]:
		# 战斗场景暂不支持目标选择，提示并关闭
		_hide_item_detail()
		return

	# 即时使用
	var success := ItemDatabase.use_consumable(item)
	if success:
		GameManager.remove_item(slot_index)
		_refresh_item_slots()
	_hide_item_detail()


func _on_item_discard_pressed(slot_index: int) -> void:
	GameManager.remove_item(slot_index)
	_refresh_item_slots()
	_hide_item_detail()


func _connect_signals() -> void:
	play_button.pressed.connect(_on_play_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	speed_1x.pressed.connect(_on_speed_1x_pressed)
	speed_2x.pressed.connect(_on_speed_2x_pressed)
	speed_3x.pressed.connect(_on_speed_3x_pressed)
	# 道具槽点击
	item_slot0.gui_input.connect(_on_item_slot_input.bind(0))
	item_slot1.gui_input.connect(_on_item_slot_input.bind(1))
	item_slot2.gui_input.connect(_on_item_slot_input.bind(2))
	item_slot3.gui_input.connect(_on_item_slot_input.bind(3))
	item_slot4.gui_input.connect(_on_item_slot_input.bind(4))
	item_slot5.gui_input.connect(_on_item_slot_input.bind(5))
	# 语言切换信号
	LocalizationSystem.language_changed.connect(_on_localization_changed)


func _on_item_slot_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_show_item_detail(slot_index)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# 右键快速丢弃
			var items: Array = GameManager.items
			if slot_index < items.size():
				GameManager.remove_item(slot_index)
				_refresh_item_slots()


func _on_speed_2x_pressed() -> void:
	battle_speed = 2.0
	speed_1x.button_pressed = false
	speed_2x.button_pressed = true
	speed_3x.button_pressed = false


func _on_speed_3x_pressed() -> void:
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

func _setup_board_display() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	cell_rects.clear()
	cell_labels.clear()
	cell_sprites.clear()
	grid_container.columns = GRID_SIZE

	for i in range(GRID_SIZE * GRID_SIZE):
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)

		var bg := ColorRect.new()
		bg.set_anchors_preset(Control.PRESET_CENTER)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		@warning_ignore("integer_division")
		var row := i / GRID_SIZE
		var col := i % GRID_SIZE
		var is_even := (row + col) % 2 == 0
		bg.color = COLOR_EMPTY_EVEN if is_even else COLOR_EMPTY_ODD
		cell.add_child(bg)

		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_preset(Control.PRESET_CENTER)
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

		grid_container.add_child(cell)
		cell_rects.append(bg)
		cell_labels.append(lbl)
		cell_sprites.append(sprite)


# ---- 战斗初始化 ----

func _start_battle() -> void:
	engine = BattleEngine.new()
	engine.on_log = _on_battle_log
	engine.setup(GameManager.board_data, GameManager.current_round, GameManager.cycle_count)

	_update_enemy_display()
	_update_player_display()
	_refresh_board_display()
	log_label.text = ""
	result_panel.visible = false
	battle_finished = false
	is_paused = false
	battle_speed = 1.0
	relic_label.text = LocalizationSystem.get_text("battle.relics")
	pause_button.text = LocalizationSystem.get_text("battle.pause")
	pause_button.button_pressed = false
	pause_button.disabled = false
	speed_1x.button_pressed = true
	speed_2x.button_pressed = false
	speed_3x.button_pressed = false
	pause_hint.text = ""

	# 初始化道具栏和遗物栏
	_setup_item_slots()
	_refresh_relic_display()


func _on_localization_changed(lang: String) -> void:
	# 更新战斗界面文本
	relic_label.text = LocalizationSystem.get_text("battle.relics")
	if not is_paused:
		pause_button.text = LocalizationSystem.get_text("battle.pause")
	else:
		pause_button.text = LocalizationSystem.get_text("battle.resume")
	skip_button.text = LocalizationSystem.get_text("battle.skip")
	speed_1x.text = LocalizationSystem.get_text("battle.speed_1x")
	speed_2x.text = LocalizationSystem.get_text("battle.speed_2x")
	speed_3x.text = LocalizationSystem.get_text("battle.speed_3x")
	turn_label.text = LocalizationSystem.get_text("battle.turn", {"value": GameManager.battle_turn})
	# 更新遗物栏
	_refresh_relic_display()
	# 更新道具栏（如果详情弹窗打开则关闭）
	if item_detail_visible:
		_hide_item_detail()
	_refresh_item_slots()
	# 更新敌人和玩家信息
	_update_enemy_display()
	_update_player_display()
	# 更新结果面板
	if battle_finished:
		_update_result_panel_texts()
	print(">>> [BattleScene] 语言切换为: %s" % lang)


func _update_result_panel_texts() -> void:
	result_title.text = LocalizationSystem.get_text("battle.victory_title")
	continue_button.text = LocalizationSystem.get_text("battle.continue")


# ---- 播放/跳过 ----

func _on_play_pressed() -> void:
	if battle_finished:
		return
	if is_paused:
		return
	if is_playing:
		return
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
	is_playing = false
	play_button.disabled = true
	skip_button.disabled = true
	pending_timer = null  # 引用清除即可，timer无法cancel

	var result: int = engine.run_full_battle()
	_update_enemy_display()
	_update_player_display()
	_refresh_board_display()
	turn_label.text = LocalizationSystem.get_text("battle.turn", {"value": GameManager.battle_turn})
	_on_battle_end(result)


# ---- 暂停/调速 ----

func _on_pause_pressed() -> void:
	if battle_finished:
		return
	is_paused = !is_paused
	pause_button.text = LocalizationSystem.get_text("battle.resume") if is_paused else LocalizationSystem.get_text("battle.pause")
	pause_hint.text = LocalizationSystem.get_text("battle.battle_paused") if is_paused else ""
	if is_paused:
		# 暂停时只需清除pending_timer引用，无需cancel
		pending_timer = null
	else:
		# 恢复时继续播放
		if is_playing:
			_play_turns()


# ---- 战斗结束与结算 (任务 3.5) ----

func _on_battle_end(result: int) -> void:
	battle_finished = true
	is_playing = false
	is_paused = false
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

	# 显示奖励面板
	result_title.text = LocalizationSystem.get_text("battle.victory_title")
	reward_label.text = reward_text
	result_panel.visible = true

	print(">>> [BattleScene] 胜利! 奖励 %d 金币" % gold_reward)


func _handle_defeat() -> void:
	result_label.text = LocalizationSystem.get_text("battle.defeat")
	result_title.text = LocalizationSystem.get_text("battle.defeat_title")
	reward_label.text = LocalizationSystem.get_text("battle.survived_rounds", {"value": GameManager.current_round})
	result_panel.visible = true
	# 提交排行榜分数
	SaveSystem.submit_leaderboard_score(GameManager.cycle_count)
	GameManager.enter_game_over()
	print(">>> [BattleScene] 战败!")


func _handle_draw() -> void:
	result_label.text = LocalizationSystem.get_text("battle.draw")
	result_title.text = LocalizationSystem.get_text("battle.draw_title")
	reward_label.text = LocalizationSystem.get_text("battle.no_reward_draw")
	result_panel.visible = true
	GameManager.advance_round()
	print(">>> [BattleScene] 平局!")


func _on_continue_pressed() -> void:
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
	enemy_atk.text = "ATK: %d" % e.attack
	enemy_def.text = "DEF: %d" % e.defense
	enemy_hp_bar.max_value = e.max_hp
	enemy_hp_bar.value = e.hp
	enemy_hp_label.text = "HP: %d/%d" % [e.hp, e.max_hp]


func _update_player_display() -> void:
	var bd: BoardData = GameManager.board_data
	# 获取总属性（所有存活角色的合计）
	var total_atk: int = 0
	var total_def: int = 0
	var total_hp: int = 0
	var total_max_hp: int = 0
	var alive_count: int = 0

	for i in range(BoardData.BOARD_SLOTS):
		var ch: DataModels.CharacterData = bd.get_character_at_index(i)
		if ch != null and ch.is_alive():
			total_atk += ch.attack
			total_def += ch.defense
			total_hp += ch.hp
			total_max_hp += ch.max_hp
			alive_count += 1

	if alive_count > 0:
		player_name.text = "Team"
		player_level.text = "x%d" % alive_count
		player_atk.text = "ATK: %d" % total_atk
		player_def.text = "DEF: %d" % total_def
		player_hp_bar.max_value = total_max_hp
		player_hp_bar.value = total_hp
		player_hp_label.text = "HP: %d/%d" % [total_hp, total_max_hp]
	else:
		player_name.text = "Team"
		player_level.text = "x0"
		player_atk.text = "ATK: 0"
		player_def.text = "DEF: 0"
		player_hp_bar.max_value = 1
		player_hp_bar.value = 0
		player_hp_label.text = "HP: 0/0"


func _refresh_board_display() -> void:
	var bd: BoardData = GameManager.board_data
	for i in range(BoardData.BOARD_SLOTS):
		var ch: DataModels.CharacterData = bd.get_character_at_index(i)
		if ch != null:
			if ch.is_alive():
				cell_rects[i].color = _get_job_color(ch.job)
				cell_labels[i].text = "%s\nLv.%d\n%d/%d" % [
					ch.get_job_name(), ch.level, ch.hp, ch.max_hp
				]
				# 加载精灵图
				var sprite_folder: String = ch.get_sprite_folder()
				var sprite_name: String = ch.get_sprite_path(1, 1)
				var sprite_path: String = "res://art/sprites/chars/" + sprite_folder + "/" + sprite_name + ".png"
				var tex := load(sprite_path) if ResourceLoader.exists(sprite_path) else null
				cell_sprites[i].texture = tex
				cell_sprites[i].visible = (tex != null)
			else:
				cell_rects[i].color = COLOR_DEAD
				cell_labels[i].text = "%s\n%s" % [ch.get_job_name(), LocalizationSystem.get_text("battle.dead")]
				cell_sprites[i].texture = null
				cell_sprites[i].visible = false
		else:
			@warning_ignore("integer_division")
			var row := i / GRID_SIZE
			var col := i % GRID_SIZE
			var is_even := (row + col) % 2 == 0
			cell_rects[i].color = COLOR_EMPTY_EVEN if is_even else COLOR_EMPTY_ODD
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


func _on_battle_log(msg: String) -> void:
	log_label.text += msg + "\n"


# ============================================
# 子弹与动画系统
# ============================================

## 获取敌方面板的世界位置（用于计算子弹目标）
func _get_enemy_position() -> Vector2:
	var enemy_panel: Control = get_node_or_null("MainLayout/BattleInfoBar/EnemyPanel")
	if enemy_panel:
		var rect: Rect2 = enemy_panel.get_global_rect()
		return rect.position + rect.size * 0.5
	# 默认位置：屏幕顶部中央
	return get_viewport().get_visible_rect().size * 0.5 + Vector2(0, -100)


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
			# 对敌方造成伤害
			if engine.enemy != null and engine.enemy.is_alive():
				engine.enemy.take_damage(damage)
				_log_attack_result(engine.enemy.name, damage, engine.enemy.hp)
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
		if not ch.is_alive() or not engine.enemy.is_alive():
			continue

		# 获取角色在棋盘上的位置
		var cell_idx: int = ch.get_board_index()
		if cell_idx < 0:
			continue

		# 计算伤害
		var damage: int = maxi(ch.attack - engine.enemy.defense, 1)
		# 法师穿透
		var base_job: int = ch.get_base_job()
		if base_job == DataModels.Job.MAGE and ch.skill_level > 0:
			damage += ch.skill_level  # 穿透伤害
		# 遗物23: 穿透+1
		if ItemDatabase.has_relic(23, GameManager.relics):
			damage += 1

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

		# 等待动画Phase 1完成后发射子弹
		await get_tree().create_timer(0.1).timeout

		# 发射子弹
		_fire_bullet(BULLET_TYPE_ATTACK, damage, source_pos, enemy_pos, -1, bullet_job, bullet_tier)

	# 2. 等待所有子弹命中
	await get_tree().create_timer(0.5).timeout

	# 3. 更新显示
	_update_enemy_display()
	_refresh_board_display()

	current_phase = BattlePhase.IDLE


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
	for row in range(GRID_SIZE):  # 从前排开始
		for col in range(GRID_SIZE):
			var index: int = row * GRID_SIZE + col
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
		var col: int = cols[i]
		var target_ch: DataModels.CharacterData = col_to_target[col]
		var target_idx: int = target_ch.get_board_index()
		var target_pos: Vector2 = _get_cell_position(target_idx)

		# 计算伤害
		var damage: int = maxi(engine.enemy.attack - target_ch.defense, 1)

		# 发射子弹
		_fire_bullet(BULLET_TYPE_ENEMY, damage, enemy_pos, target_pos, target_idx, enemy_job, enemy_tier)

	# 等待子弹命中
	await get_tree().create_timer(0.6).timeout

	# 更新显示
	_update_player_display()
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

	# 检查敌方是否阵亡
	if engine.enemy != null and not engine.enemy.is_alive():
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
	turn_label.text = LocalizationSystem.get_text("battle.turn", {"value": GameManager.battle_turn})
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
