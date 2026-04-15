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
signal diamond_changed(new_diamond: int)
signal round_changed(new_round: int)
@warning_ignore("unused_signal")
signal character_merged(merged_level: int)  # 角色合成信号

# ---- 游戏阶段常量 ----
const PHASE_PREPARE := "prepare"
const PHASE_BATTLE := "battle"
const PHASE_SHOP := "shop"
const PHASE_GAME_OVER := "game_over"

# ---- 默认数值 ----
const DEFAULT_MAX_ENERGY := 100
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
var diamond: int = 100  # 钻石数量
var battle_turn: int = 0
var current_round: int = DEFAULT_ROUND
var cycle_count: int = 0  # 完整循环次数 (每9轮+1)
var shop_last_refresh_round: int = -1  # 商店上次刷新的回合数
var shop_items_data: Array = []  # 商店商品数据 [{"id": int, "is_relic": bool, "sold": bool}, ...]

# ---- 能量购买 ----
var _energy_purchase_cost: int = 5  # 当前购买能量花费的钻石
var _last_energy_reset_day: int = 0  # 上次重置能量购买费用的日期（天数）

# ---- 体力恢复 ----
const ENERGY_RECOVERY_INTERVAL: float = 120.0  # 每120秒（2分钟）恢复1点体力
var last_energy_update_time: float = 0.0  # 上次更新体力的真实时间戳

# ---- 教程状态 ----
var tutorial_completed: bool = true  # 新手教程是否已完成 (已屏蔽)

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

# ---- 棋盘数据 ----
var board_data: BoardData = BoardData.new()

# ---- 背包数据 ----
var items: Array = []         # 道具背包 Array of ItemData
var relics: Array = []        # 遗物栏 Array of ItemData
var out_items: Array[int] = []  # 局外道具（背包ID 99由SaveSystem在新游戏时添加）
var backpack_items: Array = []  # 背包中的棋盘物品 Array of BoardItemData
signal items_changed()
signal relics_changed()
signal out_items_changed()
signal backpack_items_changed()
signal board_items_changed()  # 棋盘物品变化信号（放置/移除物品时）


## 添加道具到背包
## 返回是否添加成功（栏位已满时返回false）
func add_item(item: DataModels.ItemData) -> bool:
	if items.size() >= MAX_ITEM_SLOTS:
		return false
	items.append(item)
	items_changed.emit()
	_auto_save()
	return true


## 移除道具
func remove_item(index: int) -> void:
	if index >= 0 and index < items.size():
		var item: DM.ItemData = items[index]
		items.remove_at(index)
		items_changed.emit()


## 添加局外道具
func add_out_item(item_id: int) -> void:
	out_items.append(item_id)
	out_items_changed.emit()


## 移除局外道具
func remove_out_item(item_id: int) -> void:
	var idx: int = out_items.find(item_id)
	if idx >= 0:
		out_items.remove_at(idx)
		out_items_changed.emit()


## 获取局外道具列表
func get_out_items() -> Array[int]:
	return out_items


## 添加物品到背包（棋盘物品）
func add_to_backpack(board_item: DM.BoardItemData) -> bool:
	backpack_items.append(board_item)
	backpack_items_changed.emit()
	return true


## 从背包移除物品
func remove_from_backpack(index: int) -> void:
	if index >= 0 and index < backpack_items.size():
		var item: DM.BoardItemData = backpack_items[index]
		backpack_items.remove_at(index)
		backpack_items_changed.emit()


## 获取背包物品列表
func get_backpack_items() -> Array:
	return backpack_items


## 添加遗物
func add_relic(relic: DM.ItemData) -> void:
	# 唯一性检查 (战绩徽章可叠加)
	if not relic.stackable:
		for r in relics:
			if r.id == relic.id:
				return
	relics.append(relic)
	relics_changed.emit()
	# 刷新所有角色的遗物加成
	CharacterFactory.refresh_all_characters_relics()
	_auto_save()

# ---- 生命周期 ----

func _ready() -> void:
	_load_tutorial_state()
	_reset_to_defaults()
	last_energy_update_time = Time.get_unix_time_from_system()
	_initialized = true


func _process(_delta: float) -> void:
	if not _initialized:
		return
	_update_energy_recovery()


## 根据真实时间恢复体力
func _update_energy_recovery() -> void:
	if energy >= max_energy:
		last_energy_update_time = Time.get_unix_time_from_system()
		return
	var current_time: float = Time.get_unix_time_from_system()
	var elapsed: float = current_time - last_energy_update_time
	if elapsed >= ENERGY_RECOVERY_INTERVAL:
		var recovered: int = int(elapsed / ENERGY_RECOVERY_INTERVAL)
		var old_energy: int = energy
		energy = mini(energy + recovered, max_energy)
		last_energy_update_time = current_time - fmod(elapsed, ENERGY_RECOVERY_INTERVAL)
		if energy != old_energy:
			energy_changed.emit(energy)


## 应用离线期间的体力恢复（存档加载时调用）
func apply_offline_energy_recovery() -> void:
	if energy >= max_energy:
		last_energy_update_time = Time.get_unix_time_from_system()
		return
	var current_time: float = Time.get_unix_time_from_system()
	var elapsed: float = current_time - last_energy_update_time
	if elapsed >= ENERGY_RECOVERY_INTERVAL:
		var recovered: int = int(elapsed / ENERGY_RECOVERY_INTERVAL)
		energy = mini(energy + recovered, max_energy)
		last_energy_update_time = current_time - fmod(elapsed, ENERGY_RECOVERY_INTERVAL)
		energy_changed.emit(energy)


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
	
	phase_changed.emit(phase)
	_auto_save()


## 进入战斗阶段
func enter_battle_phase() -> void:
	phase = PHASE_BATTLE
	battle_turn = 0
	phase_changed.emit(phase)


## 进入商店阶段
func enter_shop_phase() -> void:
	phase = PHASE_SHOP
	phase_changed.emit(phase)


## 进入游戏结束
func enter_game_over() -> void:
	phase = PHASE_GAME_OVER
	phase_changed.emit(phase)


# ---- 回合推进 ----

## 战斗胜利后推进回合
func advance_round() -> void:
	current_round += 1
	# 检查是否完成一个9轮循环
	if (current_round - 1) % ENEMY_CYCLE.size() == 0:
		cycle_count += 1
	round_changed.emit(current_round)
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
		return false
	energy -= amount
	energy_changed.emit(energy)
	return true


## 恢复能量
func restore_energy(amount: int) -> void:
	if amount <= 0:
		return
	energy = mini(energy + amount, max_energy)
	if energy >= max_energy:
		last_energy_update_time = Time.get_unix_time_from_system()
	energy_changed.emit(energy)


## 重置能量为满
func reset_energy() -> void:
	energy = max_energy
	last_energy_update_time = Time.get_unix_time_from_system()
	energy_changed.emit(energy)


## 检查并重置能量购买费用（每天零点重置）
func check_energy_purchase_cost_reset() -> void:
	var today: int = int(Time.get_unix_time_from_system() / 86400.0)  # 天数
	if today > _last_energy_reset_day:
		_energy_purchase_cost = 5
		_last_energy_reset_day = today


## 获取当前能量购买费用
func get_energy_purchase_cost() -> int:
	check_energy_purchase_cost_reset()
	return _energy_purchase_cost


## 购买能量（花费钻石）
## 返回是否购买成功
func purchase_energy() -> bool:
	check_energy_purchase_cost_reset()
	if diamond < _energy_purchase_cost:
		return false
	if energy >= max_energy:
		return false
	if not spend_diamond(_energy_purchase_cost):
		return false
	var cost_paid: int = _energy_purchase_cost
	restore_energy(100)
	# 花费翻倍
	_energy_purchase_cost *= 2
	return true


## 消耗金币, 成功返回 true
func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return false
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


## 增加金币（收集金币堆时调用）
func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)


## 消耗钻石，成功返回true
func spend_diamond(amount: int) -> bool:
	if amount <= 0:
		return false
	if diamond < amount:
		return false
	diamond -= amount
	diamond_changed.emit(diamond)
	return true


## 增加钻石
func add_diamond(amount: int) -> void:
	if amount <= 0:
		return
	diamond += amount
	diamond_changed.emit(diamond)


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
	gold_changed.emit(gold)
	energy_changed.emit(energy)
	round_changed.emit(current_round)
	phase_changed.emit(phase)
	items_changed.emit()
	relics_changed.emit()
	if _initialized and is_instance_valid(get_node_or_null("/root/SaveSystem")):
		SaveSystem.clear_game_save()
		SaveSystem.init_board_from_config()  # 从MapConfig重新初始化


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
	spawn_initial_characters()


## 生成初始角色：战士、牧师、法师
## 注意：当前版本棋盘使用物品，由SaveSystem从MapConfig初始化
func spawn_initial_characters() -> void:
	pass


## 自动存档辅助 (仅在初始化完成且SaveSystem可用时调用)
func _auto_save() -> void:
	if _initialized and is_instance_valid(get_node_or_null("/root/SaveSystem")):
		SaveSystem.save_game()
