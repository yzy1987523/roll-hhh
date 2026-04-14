extends RefCounted
class_name MapConfigLoader

## MapConfig 配置加载器

const MAP_CONFIG_PATH := "res://config/MapConfig.json"

# 格子状态枚举
enum GridState {
	LOCKED = 1,
	DUSTY = 2,
	OCCUPIED = 3,
	EMPTY = 4,
}

# 配置数据
var grid_state: Dictionary = {}
var rows: int = 9
var cols: int = 7
var map: Array = []

# 是否已加载
var _loaded: bool = false

## 加载配置
func load_config() -> bool:
	if _loaded:
		return true

	var file := FileAccess.open(MAP_CONFIG_PATH, FileAccess.READ)
	if file == null:
		print(">>> [MapConfigLoader] 加载失败: %s" % FileAccess.get_open_error())
		return false

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		print(">>> [MapConfigLoader] JSON 解析失败")
		return false

	var data: Dictionary = json.data
	if data.is_empty():
		print(">>> [MapConfigLoader] 配置数据为空")
		return false

	grid_state = data.get("gridState", {})
	rows = data.get("rows", 9)
	cols = data.get("cols", 7)
	map = data.get("map", [])

	_loaded = true
	# print(">>> [MapConfigLoader] 配置加载成功: rows=%d, cols=%d, map.size()=%d" % [rows, cols, map.size()])
	# 验证：打印第3行第5列的数据
	# if map.size() > 2 and (map[2] as Array).size() > 4:
	# 	var cell: Dictionary = map[2][4]
	# 	print(">>> [MapConfigLoader] map[2][4]=%s" % [cell])
	return true


## 获取格子状态
func get_grid_state(row: int, col: int) -> int:
	if not _loaded:
		load_config()
	if row < 0 or row >= rows or col < 0 or col >= cols:
		return GridState.LOCKED
	var row_data: Array = map[row] if row < map.size() else []
	var cell: Dictionary = row_data[col] if col < row_data.size() else {}
	var state: int = cell.get("state", GridState.LOCKED)
	return state


## 获取格子物品ID
func get_cell_id(row: int, col: int) -> int:
	if not _loaded:
		load_config()
	if row < 0 or row >= rows or col < 0 or col >= cols:
		return 0
	var row_data: Array = map[row] if row < map.size() else []
	var cell: Dictionary = row_data[col] if col < row_data.size() else {}
	return cell.get("id", 0)


## 根据物品ID获取等级
func get_item_level(item_id: int) -> int:
	# 物品ID格式: 01XXXXXX -> 从中提取等级
	# 例如 01010101 -> level 1
	# 01010102 -> level 2
	return item_id % 10 if item_id > 0 else 1


## 获取所有需要初始化的格子 (所有有物品ID的格子)
func get_initial_cells() -> Array:
	if not _loaded:
		load_config()

	var cells: Array = []
	for row in range(rows):
		if row >= map.size():
			continue
		var row_data: Array = map[row]
		for col in range(cols):
			if col >= row_data.size():
				continue
			var cell: Dictionary = row_data[col]
			var state: int = cell.get("state", GridState.LOCKED)
			var item_id: int = cell.get("id", 0)
			# 初始化所有有物品ID的格子
			if item_id > 0:
				cells.append({
					"row": row,
					"col": col,
					"state": state,
					"item_id": item_id
				})
	return cells
