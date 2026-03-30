extends Control

## 战斗阶段场景
## 任务 3.3: 战斗UI + 任务 3.5: 胜负结算

# ---- 节点引用 ----
@onready var turn_label: Label = $MainLayout/TopBar/TurnLabel
@onready var enemy_name: Label = $MainLayout/EnemyInfo/EnemyName
@onready var enemy_hp_bar: ProgressBar = $MainLayout/EnemyInfo/EnemyHpBar
@onready var enemy_hp_label: Label = $MainLayout/EnemyInfo/EnemyHpLabel
@onready var grid_container: GridContainer = $MainLayout/BoardCenter/GridContainer
@onready var log_label: RichTextLabel = $MainLayout/LogScroll/LogLabel
@onready var play_button: Button = $MainLayout/BottomBar/PlayButton
@onready var skip_button: Button = $MainLayout/BottomBar/SkipButton
@onready var result_label: Label = $MainLayout/BottomBar/ResultLabel
@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_title: Label = $ResultPanel/ResultVBox/ResultTitle
@onready var reward_label: Label = $ResultPanel/ResultVBox/RewardLabel
@onready var continue_button: Button = $ResultPanel/ResultVBox/ContinueButton

# ---- 常量 ----
const GRID_SIZE := 6
const CELL_SIZE := 60
const TURN_DELAY := 0.5  # 播放模式每回合间隔(秒)

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
var is_playing: bool = false
var battle_finished: bool = false

# ---- 奖励常量 ----
const GOLD_REWARD_NORMAL := 30
const GOLD_REWARD_ELITE := 60
const GOLD_REWARD_BOSS := 100


func _ready() -> void:
	_connect_signals()
	_setup_board_display()
	_start_battle()
	print(">>> [BattleScene] 战斗场景已加载")


func _connect_signals() -> void:
	play_button.pressed.connect(_on_play_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	continue_button.pressed.connect(_on_continue_pressed)


# ---- 棋盘显示 (只读, 不可交互) ----

func _setup_board_display() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	cell_rects.clear()
	cell_labels.clear()
	grid_container.columns = GRID_SIZE

	for i in range(GRID_SIZE * GRID_SIZE):
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)

		var bg := ColorRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
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
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 10)
		cell.add_child(lbl)

		grid_container.add_child(cell)
		cell_rects.append(bg)
		cell_labels.append(lbl)


# ---- 战斗初始化 ----

func _start_battle() -> void:
	engine = BattleEngine.new()
	engine.on_log = _on_battle_log
	engine.setup(GameManager.board_data, GameManager.current_round, GameManager.cycle_count)

	_update_enemy_display()
	_refresh_board_display()
	log_label.text = ""
	result_panel.visible = false
	battle_finished = false


# ---- 播放/跳过 ----

func _on_play_pressed() -> void:
	if battle_finished or is_playing:
		return
	is_playing = true
	play_button.disabled = true
	_play_turns()


func _play_turns() -> void:
	if not is_playing or battle_finished:
		return

	var result: int = engine.execute_turn()
	_update_enemy_display()
	_refresh_board_display()
	turn_label.text = LocalizationSystem.get_text("battle.turn", {"value": GameManager.battle_turn})

	if result != BattleEngine.RESULT_ONGOING:
		_on_battle_end(result)
		return

	# 延迟后执行下一回合
	get_tree().create_timer(TURN_DELAY).timeout.connect(_play_turns)


func _on_skip_pressed() -> void:
	if battle_finished:
		return
	is_playing = false
	play_button.disabled = true
	skip_button.disabled = true

	var result: int = engine.run_full_battle()
	_update_enemy_display()
	_refresh_board_display()
	turn_label.text = LocalizationSystem.get_text("battle.turn", {"value": GameManager.battle_turn})
	_on_battle_end(result)


# ---- 战斗结束与结算 (任务 3.5) ----

func _on_battle_end(result: int) -> void:
	battle_finished = true
	is_playing = false
	play_button.disabled = true
	skip_button.disabled = true

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
	var enemy_type: int = GameManager.get_current_enemy_type()
	match enemy_type:
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
	GameManager.add_item(random_item)
	reward_text += "\n" + LocalizationSystem.get_text("battle.item_reward", {"name": random_item.name})

	# 精英/BOSS额外掉落遗物
	if enemy_type >= 1:
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
	enemy_name.text = "%s [%s]" % [e.name, e.get_type_name()]
	enemy_hp_bar.max_value = e.max_hp
	enemy_hp_bar.value = e.hp
	enemy_hp_label.text = "HP: %d/%d" % [e.hp, e.max_hp]


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
			else:
				cell_rects[i].color = COLOR_DEAD
				cell_labels[i].text = "%s\n%s" % [ch.get_job_name(), LocalizationSystem.get_text("battle.dead")]
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


func _on_battle_log(msg: String) -> void:
	log_label.text += msg + "\n"
