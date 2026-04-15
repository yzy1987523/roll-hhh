extends RefCounted
class_name BoardData

## 棋盘数据层
## 管理 6x6 棋盘和宿舍的角色存储与操作

# 预加载依赖类
const DataModels = preload("res://scripts/data_models.gd")

const GRID_COLS := 7
const GRID_ROWS := 9
const BOARD_SLOTS := 63  # 7x9

# ---- 信号 (通过 GameManager 中转, 这里用回调) ----

# ---- 格子状态枚举 ----
enum GridState {
	LOCKED = 1,    # 锁定（未解锁）
	DUSTY = 2,     # 半锁定（可清理解锁）
	OCCUPIED = 3,  # 已被物品占用
	EMPTY = 4,     # 空置（已解锁）
}

# ---- 数据存储 ----
var board: Array = []           # 长度63, 每个元素为 BoardItemData 或 null (物品)
var dormitory: Array = []       # 宿舍, 动态长度, 存储 BoardItemData
var marked_for_removal: Array = []  # 标记移出的物品索引列表
var _grid_states: Array = []    # 格子状态数组, 长度63

# ---- 宿舍容量 ----
const DORM_CAPACITY := 16  # 4x4 宿舍容量

# ---- 初始化 ----

func _init() -> void:
	clear_board()


func clear_board() -> void:
	board.clear()
	board.resize(BOARD_SLOTS)
	for i in range(BOARD_SLOTS):
		board[i] = null
	_grid_states.clear()
	_grid_states.resize(BOARD_SLOTS)
	for i in range(BOARD_SLOTS):
		_grid_states[i] = GridState.LOCKED
	dormitory.clear()


# ---- 坐标转换 ----

## 二维坐标转一维索引
static func pos_to_index(pos: Vector2i) -> int:
	return pos.y * GRID_COLS + pos.x


## 一维索引转二维坐标
static func index_to_pos(index: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(index % GRID_COLS, index / GRID_COLS)


## 检查坐标是否在棋盘范围内
static func is_valid_pos(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_COLS and pos.y >= 0 and pos.y < GRID_ROWS


# ---- 棋盘操作 ----

## 获取指定位置的物品
func get_item_at(pos: Vector2i) -> DataModels.BoardItemData:
	if not is_valid_pos(pos):
		return null
	return board[pos_to_index(pos)]


## 获取指定索引的物品
func get_item_at_index(index: int) -> DataModels.BoardItemData:
	if index < 0 or index >= BOARD_SLOTS:
		return null
	return board[index]


## 获取物品在棋盘上的索引
func get_item_index(item: DataModels.BoardItemData) -> int:
	if item == null:
		return -1
	for i in range(BOARD_SLOTS):
		if board[i] == item:
			return i
	return -1


## 放置物品到棋盘指定位置, 成功返回 true
func place_item(item: DataModels.BoardItemData, pos: Vector2i) -> bool:
	if not is_valid_pos(pos):
		return false
	var index: int = pos_to_index(pos)
	if board[index] != null:
		return false
	board[index] = item
	return true


## 放置物品到第一个空位, 成功返回位置, 失败返回 (-1,-1)
func place_item_first_empty(item: DataModels.BoardItemData) -> Vector2i:
	for i in range(BOARD_SLOTS):
		if board[i] == null:
			board[i] = item
			return index_to_pos(i)
	return Vector2i(-1, -1)


## 从棋盘移除物品
func remove_item(pos: Vector2i) -> DataModels.BoardItemData:
	if not is_valid_pos(pos):
		return null
	var index: int = pos_to_index(pos)
	var item: DataModels.BoardItemData = board[index]
	if item == null:
		return null
	board[index] = null
	return item


## 交换棋盘上两个位置的物品
func swap_items(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	if not is_valid_pos(pos_a) or not is_valid_pos(pos_b):
		return false
	if pos_a == pos_b:
		return false
	var idx_a: int = pos_to_index(pos_a)
	var idx_b: int = pos_to_index(pos_b)
	var item_a: DataModels.BoardItemData = board[idx_a]
	var item_b: DataModels.BoardItemData = board[idx_b]
	board[idx_a] = item_b
	board[idx_b] = item_a
	return true


# ---- 宿舍操作 ----

## 将物品存入宿舍
func store_to_dormitory(item: DataModels.BoardItemData) -> void:
	dormitory.append(item)


## 从宿舍取出物品 (按索引)
func take_from_dormitory(index: int) -> DataModels.BoardItemData:
	if index < 0 or index >= dormitory.size():
		return null
	var item: DataModels.BoardItemData = dormitory[index]
	dormitory.remove_at(index)
	return item


## 棋盘物品移入宿舍
func board_to_dormitory(pos: Vector2i) -> bool:
	var item: DataModels.BoardItemData = remove_item(pos)
	if item == null:
		return false
	store_to_dormitory(item)
	return true


## ---- 标记移出功能 ----

## 标记物品待移出
func mark_for_removal(dorm_index: int) -> void:
	if dorm_index >= 0 and dorm_index < dormitory.size():
		if not marked_for_removal.has(dorm_index):
			marked_for_removal.append(dorm_index)


## 取消标记
func unmark_for_removal(dorm_index: int) -> void:
	marked_for_removal.erase(dorm_index)


## 检查是否已标记
func is_marked_for_removal(dorm_index: int) -> bool:
	return marked_for_removal.has(dorm_index)


## 获取空棋盘格子数量
func get_empty_board_count() -> int:
	return get_empty_count()


## 检查是否可以移出标记的物品
func can_remove_marked() -> bool:
	return get_empty_board_count() >= marked_for_removal.size()


## 执行移出所有标记的物品到棋盘
## 返回成功移出的物品数据数组，每个元素包含 {item, board_index}
func execute_removal() -> Array:
	var result: Array = []

	if not can_remove_marked():
		return result

	# 按索引降序排序，避免移除时索引变化
	marked_for_removal.sort()
	marked_for_removal.reverse()

	for idx in marked_for_removal:
		var item: DataModels.BoardItemData = take_from_dormitory(idx)
		if item != null:
			var pos: Vector2i = place_item_first_empty(item)
			if pos != Vector2i(-1, -1):
				var board_index: int = pos_to_index(pos)
				result.append({"item": item, "board_index": board_index})
			else:
				# 放置失败，放回宿舍
				store_to_dormitory(item)

	marked_for_removal.clear()
	return result


## 获取宿舍空位数量
func get_empty_dorm_count() -> int:
	return DORM_CAPACITY - dormitory.size()


## 检查宿舍是否已满
func is_dorm_full() -> bool:
	return dormitory.size() >= DORM_CAPACITY


## 宿舍物品移入棋盘指定位置
func dormitory_to_board(dorm_index: int, board_pos: Vector2i) -> bool:
	if not is_valid_pos(board_pos):
		return false
	var brd_index: int = pos_to_index(board_pos)
	if board[brd_index] != null:
		return false
	var item: DataModels.BoardItemData = take_from_dormitory(dorm_index)
	if item == null:
		return false
	board[brd_index] = item
	return true


# ---- 查询 ----

## 获取棋盘上所有物品
func get_all_board_items() -> Array:
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


## 获取指定行的所有物品
func get_items_in_row(row: int) -> Array:
	var result: Array = []
	if row < 0 or row >= GRID_ROWS:
		return result
	for col in range(GRID_COLS):
		var index: int = row * GRID_COLS + col
		if board[index] != null:
			result.append(board[index])
	return result


## 获取棋盘上指定合成链的所有物品
func get_items_by_merge_chain(chain_id: int) -> Array:
	var result: Array = []
	for i in range(BOARD_SLOTS):
		var item: DataModels.BoardItemData = board[i]
		if item != null and item.get_merge_chain() == chain_id:
			result.append(item)
	return result


## 检查两个物品是否可以合成
func can_merge_items(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	var item_a: DataModels.BoardItemData = get_item_at(pos_a)
	var item_b: DataModels.BoardItemData = get_item_at(pos_b)
	if item_a == null or item_b == null:
		return false
	# 相同合成链、相同ID可合成
	return item_a.id == item_b.id and item_a.can_merge()


# ---- 格子状态管理 ----

## 获取格子状态
func get_grid_state(index: int) -> int:
	if index < 0 or index >= BOARD_SLOTS:
		return GridState.LOCKED
	return _grid_states[index]


## 设置格子状态
func set_grid_state(index: int, state: int) -> void:
	if index < 0 or index >= BOARD_SLOTS:
		return
	_grid_states[index] = state


## 获取格子状态的二维坐标版本
func get_grid_state_at(pos: Vector2i) -> int:
	if not is_valid_pos(pos):
		return GridState.LOCKED
	return get_grid_state(pos_to_index(pos))


## 设置格子状态的二维坐标版本
func set_grid_state_at(pos: Vector2i, state: int) -> void:
	if not is_valid_pos(pos):
		return
	set_grid_state(pos_to_index(pos), state)


## 检查格子是否可以交互（可点击、可拖拽）
func can_interact(index: int) -> bool:
	var state: int = get_grid_state(index)
	# LOCKED 不可交互，DUSTY 可点击（但不能拖拽），EMPTY/OCCUPIED 完全可交互
	return state == GridState.EMPTY or state == GridState.OCCUPIED or state == GridState.DUSTY


## 获取相邻格子的索引（上下左右）
func get_adjacent_indices(index: int) -> Array:
	var pos: Vector2i = index_to_pos(index)
	var adjacents: Array = []
	# 上
	if pos.y > 0:
		adjacents.append(pos_to_index(Vector2i(pos.x, pos.y - 1)))
	# 下
	if pos.y < GRID_ROWS - 1:
		adjacents.append(pos_to_index(Vector2i(pos.x, pos.y + 1)))
	# 左
	if pos.x > 0:
		adjacents.append(pos_to_index(Vector2i(pos.x - 1, pos.y)))
	# 右
	if pos.x < GRID_COLS - 1:
		adjacents.append(pos_to_index(Vector2i(pos.x + 1, pos.y)))
	return adjacents


## 触发合成时，锁定格子变灰尘状态
## 合成位置周围的 LOCKED 格子切换为 DUSTY
func trigger_merge_unlock(merge_index: int) -> void:
	var adjacents: Array = get_adjacent_indices(merge_index)
	for adj_idx in adjacents:
		if get_grid_state(adj_idx) == GridState.LOCKED:
			set_grid_state(adj_idx, GridState.DUSTY)


## 灰尘状态被合成时切换为 OCCUPIED
func dust_to_occupied(index: int) -> void:
	if get_grid_state(index) == GridState.DUSTY:
		set_grid_state(index, GridState.OCCUPIED)


## 初始化格子状态（从 MapConfig 加载）
## MapConfig: rows=7(9列Lua行数), cols=9(每行的Lua列数)
## map[lua_row][lua_col] = Lua第(lua_row+1)行第(lua_col+1)列
## pos_to_index(x, y) 中 x=col(0-6), y=row(0-8)
## x=lua_row(0-6), y=lua_col(0-8)
func init_grid_states_from_config(config: MapConfigLoader) -> void:
	var state_counts := {1: 0, 2: 0, 3: 0, 4: 0}  # 统计各状态数量
	for lua_row in range(config.rows):  # Lua 行范围 0-6
		for lua_col in range(config.cols):  # Lua 列范围 0-8
			# lua_row -> x(col), lua_col -> y(row)
			var index: int = pos_to_index(Vector2i(lua_row, lua_col))
			var state: int = config.get_grid_state(lua_row, lua_col)
			set_grid_state(index, state)
			state_counts[state] += 1
			if state == 2 or state == 3:  # DUSTY or OCCUPIED
				print(">>> [BoardData] Lua[%d][%d] -> index=%d, state=%d (OCCUPIED=%d, DUSTY=%d)" % [lua_row, lua_col, index, state, GridState.OCCUPIED, GridState.DUSTY])
