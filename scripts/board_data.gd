extends RefCounted
class_name BoardData

## 棋盘数据层
## 管理 6x6 棋盘和宿舍的角色存储与操作

# 预加载依赖类
const DataModels = preload("res://scripts/data_models.gd")

const GRID_SIZE := 6
const BOARD_SLOTS := 36  # 6x6

# ---- 信号 (通过 GameManager 中转, 这里用回调) ----

# ---- 数据存储 ----
var board: Array = []           # 长度36, 每个元素为 CharacterData 或 null
var dormitory: Array = []       # 宿舍, 动态长度

# ---- 初始化 ----

func _init() -> void:
	clear_board()


func clear_board() -> void:
	board.clear()
	board.resize(BOARD_SLOTS)
	for i in range(BOARD_SLOTS):
		board[i] = null
	dormitory.clear()
	print(">>> [BoardData] 棋盘和宿舍已清空")


# ---- 坐标转换 ----

## 二维坐标转一维索引
static func pos_to_index(pos: Vector2i) -> int:
	return pos.y * GRID_SIZE + pos.x


## 一维索引转二维坐标
static func index_to_pos(index: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(index % GRID_SIZE, index / GRID_SIZE)


## 检查坐标是否在棋盘范围内
static func is_valid_pos(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_SIZE and pos.y >= 0 and pos.y < GRID_SIZE


# ---- 棋盘操作 ----

## 获取指定位置的角色
func get_character_at(pos: Vector2i) -> DataModels.CharacterData:
	if not is_valid_pos(pos):
		return null
	return board[pos_to_index(pos)]


## 获取指定索引的角色
func get_character_at_index(index: int) -> DataModels.CharacterData:
	if index < 0 or index >= BOARD_SLOTS:
		return null
	return board[index]


## 放置角色到棋盘指定位置, 成功返回 true
func place_character(ch: DataModels.CharacterData, pos: Vector2i) -> bool:
	if not is_valid_pos(pos):
		print(">>> [BoardData] 放置失败: 坐标越界 (%d, %d)" % [pos.x, pos.y])
		return false
	var index: int = pos_to_index(pos)
	if board[index] != null:
		print(">>> [BoardData] 放置失败: 位置已被占用 (%d, %d)" % [pos.x, pos.y])
		return false
	board[index] = ch
	ch.position = pos
	return true


## 放置角色到第一个空位, 成功返回位置, 失败返回 (-1,-1)
func place_character_first_empty(ch: DataModels.CharacterData) -> Vector2i:
	for i in range(BOARD_SLOTS):
		if board[i] == null:
			var pos: Vector2i = index_to_pos(i)
			board[i] = ch
			ch.position = pos
			return pos
	print(">>> [BoardData] 放置失败: 棋盘已满")
	return Vector2i(-1, -1)


## 从棋盘移除角色
func remove_character(pos: Vector2i) -> DataModels.CharacterData:
	if not is_valid_pos(pos):
		return null
	var index: int = pos_to_index(pos)
	var ch: DataModels.CharacterData = board[index]
	if ch == null:
		return null
	board[index] = null
	ch.position = Vector2i(-1, -1)
	return ch


## 交换棋盘上两个位置的角色
func swap_positions(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	if not is_valid_pos(pos_a) or not is_valid_pos(pos_b):
		return false
	if pos_a == pos_b:
		return false
	var idx_a: int = pos_to_index(pos_a)
	var idx_b: int = pos_to_index(pos_b)
	var ch_a: DataModels.CharacterData = board[idx_a]
	var ch_b: DataModels.CharacterData = board[idx_b]
	board[idx_a] = ch_b
	board[idx_b] = ch_a
	if ch_a != null:
		ch_a.position = pos_b
	if ch_b != null:
		ch_b.position = pos_a
	return true


# ---- 宿舍操作 ----

## 将角色存入宿舍
func store_to_dormitory(ch: DataModels.CharacterData) -> void:
	ch.position = Vector2i(-1, -1)
	dormitory.append(ch)
	print(">>> [BoardData] 角色存入宿舍: %s Lv.%d" % [ch.get_job_name(), ch.level])


## 从宿舍取出角色 (按索引)
func take_from_dormitory(index: int) -> DataModels.CharacterData:
	if index < 0 or index >= dormitory.size():
		return null
	var ch: DataModels.CharacterData = dormitory[index]
	dormitory.remove_at(index)
	return ch


## 棋盘角色移入宿舍
func board_to_dormitory(pos: Vector2i) -> bool:
	var ch: DataModels.CharacterData = remove_character(pos)
	if ch == null:
		return false
	store_to_dormitory(ch)
	return true


## 宿舍角色移入棋盘指定位置
func dormitory_to_board(dorm_index: int, board_pos: Vector2i) -> bool:
	if not is_valid_pos(board_pos):
		return false
	var brd_index: int = pos_to_index(board_pos)
	if board[brd_index] != null:
		return false
	var ch: DataModels.CharacterData = take_from_dormitory(dorm_index)
	if ch == null:
		return false
	board[brd_index] = ch
	ch.position = board_pos
	return true


# ---- 查询 ----

## 获取棋盘上所有存活角色
func get_alive_characters() -> Array:
	var result: Array = []
	for i in range(BOARD_SLOTS):
		if board[i] != null and board[i].is_alive():
			result.append(board[i])
	return result


## 获取棋盘上所有角色 (含死亡)
func get_all_board_characters() -> Array:
	var result: Array = []
	for i in range(BOARD_SLOTS):
		if board[i] != null:
			result.append(board[i])
	return result


## 获取空位数量
func get_empty_count() -> int:
	var count: int = 0
	for i in range(BOARD_SLOTS):
		if board[i] == null:
			count += 1
	return count


## 棋盘是否已满
func is_board_full() -> bool:
	return get_empty_count() == 0


## 获取指定行的角色 (用于战斗: 前排优先)
func get_characters_in_row(row: int) -> Array:
	var result: Array = []
	if row < 0 or row >= GRID_SIZE:
		return result
	for col in range(GRID_SIZE):
		var index: int = row * GRID_SIZE + col
		if board[index] != null and board[index].is_alive():
			result.append(board[index])
	return result


## 获取前排 (第一个有存活角色的行)
func get_front_row_characters() -> Array:
	for row in range(GRID_SIZE):
		var chars: Array = get_characters_in_row(row)
		if chars.size() > 0:
			return chars
	return []


## 全员满血恢复 (战斗胜利后)
func heal_all() -> void:
	for i in range(BOARD_SLOTS):
		if board[i] != null:
			board[i].full_heal()
	for ch in dormitory:
		ch.full_heal()
	print(">>> [BoardData] 全员满血恢复")
