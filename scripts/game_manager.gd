extends Node

## 游戏状态管理器 (Autoload 单例)
## 管理全局游戏状态、阶段流转、资源数据

# ---- 信号 ----
signal phase_changed(new_phase: String)
signal gold_changed(new_gold: int)
signal energy_changed(new_energy: int)
signal round_changed(new_round: int)

# ---- 游戏阶段常量 ----
const PHASE_PREPARE := "prepare"
const PHASE_BATTLE := "battle"
const PHASE_SHOP := "shop"
const PHASE_GAME_OVER := "game_over"

# ---- 默认数值 ----
const DEFAULT_MAX_ENERGY := 36
const DEFAULT_GOLD := 0
const DEFAULT_ROUND := 1
const MAX_BATTLE_TURNS := 999

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

# ---- 棋盘数据 ----
var board_data: BoardData = BoardData.new()

# ---- 背包数据 ----
var items: Array = []         # 道具背包 Array of ItemData
var relics: Array = []        # 遗物栏 Array of ItemData
signal items_changed()
signal relics_changed()


## 添加道具到背包
func add_item(item: DataModels.ItemData) -> void:
	items.append(item)
	items_changed.emit()
	print(">>> [GameManager] 获得道具: %s" % item.name)


## 移除道具
func remove_item(index: int) -> void:
	if index >= 0 and index < items.size():
		var item: DataModels.ItemData = items[index]
		items.remove_at(index)
		items_changed.emit()
		print(">>> [GameManager] 移除道具: %s" % item.name)


## 添加遗物
func add_relic(relic: DataModels.ItemData) -> void:
	# 唯一性检查 (战绩徽章可叠加)
	if not relic.stackable:
		for r in relics:
			if r.id == relic.id:
				print(">>> [GameManager] 遗物已拥有: %s" % relic.name)
				return
	relics.append(relic)
	relics_changed.emit()
	print(">>> [GameManager] 获得遗物: %s" % relic.name)

# ---- 生命周期 ----

func _ready() -> void:
	print(">>> [GameManager] 游戏状态管理器已加载")
	_reset_to_defaults()


# ---- 阶段流转 ----

## 进入备战阶段
func enter_prepare_phase() -> void:
	phase = PHASE_PREPARE
	battle_turn = 0
	phase_changed.emit(phase)
	print(">>> [GameManager] 进入备战阶段, 回合: %d" % current_round)


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
	gold_changed.emit(gold)
	energy_changed.emit(energy)
	round_changed.emit(current_round)
	phase_changed.emit(phase)
	items_changed.emit()
	relics_changed.emit()
	print(">>> [GameManager] 战败重置 (图鉴保留)")


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
