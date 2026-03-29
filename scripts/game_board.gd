extends Control

## 备战阶段主界面
## 任务 2.1: UI 布局 + 任务 2.2: 角色生成

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
const COLOR_WARRIOR := Color("#D94040")    # 红色 - 战士
const COLOR_MAGE := Color("#6040D9")       # 紫色 - 法师
const COLOR_PRIEST := Color("#40B040")     # 绿色 - 牧师

# ---- 棋盘格子引用 ----
var cell_rects: Array = []    # ColorRect 数组
var cell_labels: Array = []   # Label 数组 (显示角色信息)


func _ready() -> void:
	_connect_signals()
	_setup_board_ui()
	_update_resource_labels()
	print(">>> [GameBoard] 备战阶段界面已加载")


# ---- 信号连接 ----

func _connect_signals() -> void:
	# 按钮
	spawn_warrior.pressed.connect(_on_spawn_pressed.bind(DataModels.Job.WARRIOR))
	spawn_mage.pressed.connect(_on_spawn_pressed.bind(DataModels.Job.MAGE))
	spawn_priest.pressed.connect(_on_spawn_pressed.bind(DataModels.Job.PRIEST))
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	back_button.pressed.connect(_on_back_pressed)
	# GameManager 信号
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.energy_changed.connect(_on_energy_changed)
	GameManager.round_changed.connect(_on_round_changed)


# ---- 棋盘 UI 构建 ----

func _setup_board_ui() -> void:
	# 清空旧格子
	for child in grid_container.get_children():
		child.queue_free()
	cell_rects.clear()
	cell_labels.clear()

	grid_container.columns = GRID_SIZE

	for i in range(GRID_SIZE * GRID_SIZE):
		# 格子容器
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

		grid_container.add_child(cell)
		cell_rects.append(bg)
		cell_labels.append(lbl)

	# 同步数据到 UI
	_refresh_board_display()
	print(">>> [GameBoard] %dx%d 棋盘格已生成" % [GRID_SIZE, GRID_SIZE])


# ---- 棋盘显示刷新 ----

func _refresh_board_display() -> void:
	var bd: BoardData = GameManager.board_data
	for i in range(BoardData.BOARD_SLOTS):
		var ch: DataModels.CharacterData = bd.get_character_at_index(i)
		if ch != null:
			# 显示角色
			cell_rects[i].color = _get_job_color(ch.job)
			cell_labels[i].text = "%s\nLv.%d\n%d/%d" % [
				ch.get_job_name(), ch.level, ch.hp, ch.max_hp
			]
		else:
			# 空格子
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
	# 检查能量
	if not GameManager.spend_energy(1):
		print(">>> [GameBoard] 生成失败: 能量不足")
		return

	# 检查棋盘是否已满
	if GameManager.board_data.is_board_full():
		# 退还能量
		GameManager.restore_energy(1)
		print(">>> [GameBoard] 生成失败: 棋盘已满")
		return

	# 创建角色 (随机1-3级)
	var level: int = randi_range(1, 3)
	var ch: DataModels.CharacterData = CharacterFactory.create_character(job, level)

	# 放入棋盘空位
	var pos: Vector2i = GameManager.board_data.place_character_first_empty(ch)
	if pos == Vector2i(-1, -1):
		GameManager.restore_energy(1)
		print(">>> [GameBoard] 生成失败: 无法放置")
		return

	print(">>> [GameBoard] 生成 %s Lv.%d 于 (%d, %d)" % [ch.get_job_name(), ch.level, pos.x, pos.y])
	_refresh_board_display()


# ---- 按钮回调 ----

func _on_end_turn_pressed() -> void:
	print(">>> [GameBoard] 结束回合, 进入战斗阶段")
	GameManager.enter_battle_phase()
	# TODO: 切换到战斗场景 (任务 3.3)


func _on_back_pressed() -> void:
	print(">>> [GameBoard] 返回主菜单")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
