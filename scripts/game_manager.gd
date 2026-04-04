extends Node

## 游戏状态管理器 (Autoload 单例)
## 管理全局游戏状态、阶段流转、资源数据

# 预加载依赖类 (Autoload 需要显式预加载)
const BD = preload("res://scripts/board_data.gd")
const DM = preload("res://scripts/data_models.gd")

# ---- 初始化标志 ----
var _initialized: bool = false

# ---- 信号 ----
signal phase_changed(new_phase: String)
signal gold_changed(new_gold: int)
signal energy_changed(new_energy: int)
signal round_changed(new_round: int)
@warning_ignore("unused_signal")
signal character_merged(merged_level: int)  # 角色合成信号

# ---- 游戏阶段常量 ----
const PHASE_PREPARE := "prepare"
const PHASE_BATTLE := "battle"
const PHASE_SHOP := "shop"
const PHASE_GAME_OVER := "game_over"

# ---- 默认数值 ----
const DEFAULT_MAX_ENERGY := 36
const DEFAULT_GOLD := 200
const DEFAULT_ROUND := 1
const MAX_BATTLE_TURNS := 999
const MAX_ITEM_SLOTS := 3

# ---- 敌人循环节奏 (9轮一循环) ----
# 0=普通, 1=精英, 2=BOSS
const ENEMY_CYCLE := [0, 0, 1, 0, 0, 1, 0, 0, 2]

# ---- 游戏状态 ----
var phase: String = PHASE_PREPARE
var gold: int = DEFAULT_GOLD
var energy: int = DEFAULT_MAX_ENERGY
var max_energy: int = DEFAULT_MAX_ENERGY
var battle_turn: int = 0
var current_round: int = DEFAULT_ROUND
var cycle_count: int = 0  # 完整循环次数 (每9轮+1)
var shop_last_refresh_round: int = -1  # 商店上次刷新的回合数
var shop_items_data: Array = []  # 商店商品数据 [{"id": int, "is_relic": bool, "sold": bool}, ...]

# ---- 教程状态 ----
var tutorial_completed: bool = false  # 新手教程是否已完成

# ---- 属性 ----
var has_tutorial_completed: bool:
	get: return tutorial_completed

func set_tutorial_completed(value: bool) -> void:
	tutorial_completed = value
	# 持久化存储
	if value:
		_save_tutorial_state()

func _save_tutorial_state() -> void:
	# 使用 ConfigFile 持久化
	var config := ConfigFile.new()
	config.set_value("player", "tutorial_completed", true)
	config.save("user://tutorial.cfg")

func _load_tutorial_state() -> void:
	var config := ConfigFile.new()
	var err := config.load("user://tutorial.cfg")
	if err == OK:
		tutorial_completed = config.get_value("player", "tutorial_completed", false)

func reset_tutorial() -> void:
	# 重置教程状态
	tutorial_completed = false
	var config := ConfigFile.new()
	config.set_value("player", "tutorial_completed", false)
	config.save("user://tutorial.cfg")
	print(">>> [GameManager] 教程状态已重置")

# ---- 棋盘数据 ----
var board_data: BoardData = BoardData.new()

# ---- 背包数据 ----
var items: Array = []         # 道具背包 Array of ItemData
var relics: Array = []        # 遗物栏 Array of ItemData
signal items_changed()
signal relics_changed()


## 添加道具到背包
## 返回是否添加成功（栏位已满时返回false）
func add_item(item: DataModels.ItemData) -> bool:
	if items.size() >= MAX_ITEM_SLOTS:
		print(">>> [GameManager] 道具栏已满，无法获取: %s" % item.name)
		return false
	items.append(item)
	items_changed.emit()
	print(">>> [GameManager] 获得道具: %s" % item.name)
	_auto_save()
	return true


## 移除道具
func remove_item(index: int) -> void:
	if index >= 0 and index < items.size():
		var item: DM.ItemData = items[index]
		items.remove_at(index)
		items_changed.emit()
		print(">>> [GameManager] 移除道具: %s" % item.name)


## 添加遗物
func add_relic(relic: DM.ItemData) -> void:
	# 唯一性检查 (战绩徽章可叠加)
	if not relic.stackable:
		for r in relics:
			if r.id == relic.id:
				print(">>> [GameManager] 遗物已拥有: %s" % relic.name)
				return
	relics.append(relic)
	relics_changed.emit()
	print(">>> [GameManager] 获得遗物: %s" % relic.name)
	# 刷新所有角色的遗物加成
	CharacterFactory.refresh_all_characters_relics()
	_auto_save()

# ---- 生命周期 ----

func _ready() -> void:
	print(">>> [GameManager] 游戏状态管理器已加载")
	_load_tutorial_state()
	_reset_to_defaults()
	_initialized = true


# ---- 阶段流转 ----

## 进入备战阶段
func enter_prepare_phase() -> void:
	phase = PHASE_PREPARE
	battle_turn = 0
	reset_energy()
	
	# 遗物: 初始能量加成 (ID 19) - 每轮开始时增加能量
	if ItemDatabase.has_relic(19, GameManager.relics):
		var cfg: Dictionary = MechanicsDb.get_relic_effect(19)
		var bonus: int = cfg.get("bonus", 3)
		restore_energy(bonus)
		print(">>> [GameManager] 初始能量加成 +%d (遗物ID 19)" % bonus)
	
	phase_changed.emit(phase)
	print(">>> [GameManager] 进入备战阶段, 回合: %d" % current_round)
	_auto_save()


## 进入战斗阶段
func enter_battle_phase() -> void:
	phase = PHASE_BATTLE
	battle_turn = 0
	phase_changed.emit(phase)
	print(">>> [GameManager] 进入战斗阶段, 回合: %d" % current_round)


## 进入商店阶段
func enter_shop_phase() -> void:
	phase = PHASE_SHOP
	phase_changed.emit(phase)
	print(">>> [GameManager] 进入商店阶段")


## 进入游戏结束
func enter_game_over() -> void:
	phase = PHASE_GAME_OVER
	phase_changed.emit(phase)
	print(">>> [GameManager] 游戏结束, 存活 %d 回合" % current_round)


# ---- 回合推进 ----

## 战斗胜利后推进回合
func advance_round() -> void:
	current_round += 1
	# 检查是否完成一个9轮循环
	if (current_round - 1) % ENEMY_CYCLE.size() == 0:
		cycle_count += 1
		print(">>> [GameManager] 完成第 %d 个循环" % cycle_count)
	round_changed.emit(current_round)
	print(">>> [GameManager] 推进到回合: %d" % current_round)
	_auto_save()


## 获取当前回合的敌人类型 (0=普通, 1=精英, 2=BOSS)
func get_current_enemy_type() -> int:
	var index: int = (current_round - 1) % ENEMY_CYCLE.size()
	return ENEMY_CYCLE[index]


## 获取当前敌人类型名称
func get_current_enemy_type_name() -> String:
	var enemy_type: int = get_current_enemy_type()
	match enemy_type:
		0: return "普通"
		1: return "精英"
		2: return "BOSS"
		_: return "未知"


# ---- 资源操作 ----

## 消耗能量, 成功返回 true
func spend_energy(amount: int) -> bool:
	if amount <= 0:
		return false
	if energy < amount:
		print(">>> [GameManager] 能量不足: 需要 %d, 当前 %d" % [amount, energy])
		return false
	energy -= amount
	energy_changed.emit(energy)
	return true


## 恢复能量
func restore_energy(amount: int) -> void:
	if amount <= 0:
		return
	energy = mini(energy + amount, max_energy)
	energy_changed.emit(energy)
	print(">>> [GameManager] 恢复能量 %d, 当前: %d/%d" % [amount, energy, max_energy])


## 重置能量为满
func reset_energy() -> void:
	energy = max_energy
	energy_changed.emit(energy)


## 消耗金币, 成功返回 true
func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return false
	if gold < amount:
		print(">>> [GameManager] 金币不足: 需要 %d, 当前 %d" % [amount, gold])
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


## 获得金币
func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)
	print(">>> [GameManager] 获得金币 %d, 当前: %d" % [amount, gold])


# ---- 献祭能量计算 ----

## 献祭角色返还能量 = 2^(level-1)
func calc_sacrifice_energy(level: int) -> int:
	if level < 1:
		return 0
	# 使用位运算: 2^(level-1) = 1 << (level-1)
	return 1 << (level - 1)


# ---- 战斗回合 ----

## 推进战斗回合
func advance_battle_turn() -> void:
	battle_turn += 1


## 检查战斗是否超时 (>=999回合)
func is_battle_timeout() -> bool:
	return battle_turn >= MAX_BATTLE_TURNS


# ---- 重置 ----

## 重置为初始状态 (新游戏)
func reset_game() -> void:
	_reset_to_defaults()
	print(">>> [GameManager] 游戏已重置")


## 战败后重置 (保留图鉴数据, 图鉴由其他系统管理)
func reset_after_defeat() -> void:
	gold = DEFAULT_GOLD
	energy = DEFAULT_MAX_ENERGY
	max_energy = DEFAULT_MAX_ENERGY
	battle_turn = 0
	current_round = DEFAULT_ROUND
	cycle_count = 0
	phase = PHASE_PREPARE
	items.clear()
	relics.clear()
	board_data.clear_board()
	# 生成初始角色：战士、牧师、法师
	_spawn_initial_characters()
	gold_changed.emit(gold)
	energy_changed.emit(energy)
	round_changed.emit(current_round)
	phase_changed.emit(phase)
	items_changed.emit()
	relics_changed.emit()
	print(">>> [GameManager] 战败重置 (图鉴保留)")
	if _initialized and is_instance_valid(get_node_or_null("/root/SaveSystem")):
		SaveSystem.clear_game_save()


func _reset_to_defaults() -> void:
	phase = PHASE_PREPARE
	gold = DEFAULT_GOLD
	energy = DEFAULT_MAX_ENERGY
	max_energy = DEFAULT_MAX_ENERGY
	battle_turn = 0
	current_round = DEFAULT_ROUND
	cycle_count = 0
	items.clear()
	relics.clear()
	board_data.clear_board()
	
	# 生成初始角色：战士、牧师、法师
	_spawn_initial_characters()


## 生成初始角色：战士、牧师、法师
func _spawn_initial_characters() -> void:
	# 预加载CharacterFactory
	const CF = preload("res://scripts/character_factory.gd")
	
	# 创建1级角色
	var warrior = CF.create_character(DataModels.Job.WARRIOR, 1)  # 战士
	var priest = CF.create_character(DataModels.Job.PRIEST, 1)    # 牧师
	var mage = CF.create_character(DataModels.Job.MAGE, 1)        # 法师
	
	# 6x6棋盘布局：
	# 行0: [0] [1] [2] [3] [4] [5]   <- 第一行
	# 行1: [6] [7] [8] [9] [10] [11]  <- 第二行
	# ...
	# 行5: [30] [31] [32] [33] [34] [35]  <- 最后一行
	
	# 放置角色到指定位置
	board_data.place_character(warrior, Vector2i(2, 0))  # 战士：第一行中央偏左
	board_data.place_character(priest, Vector2i(2, 1))   # 牧师：第二行中央偏左
	board_data.place_character(mage, Vector2i(2, 5))     # 法师：最后一行中央偏左
	
	print(">>> [GameManager] 初始角色已生成: 战士(第一行中央), 牧师(第二行中央), 法师(最后一行中央)")


## 自动存档辅助 (仅在初始化完成且SaveSystem可用时调用)
func _auto_save() -> void:
	if _initialized and is_instance_valid(get_node_or_null("/root/SaveSystem")):
		SaveSystem.save_game()
