extends Node

## 存档系统
## 任务 6.1: LocalStorage 自动存档

# 信号
signal save_cleared  # 清空存档后发出，用于通知 UI 刷新

# 预加载依赖类 (Autoload 需要显式预加载)
const BD = preload("res://scripts/board_data.gd")
const DM = preload("res://scripts/data_models.gd")
const CF = preload("res://scripts/character_factory.gd")
const MCL = preload("res://scripts/map_config_loader.gd")
const ICL = preload("res://scripts/item_config_loader.gd")
const IM = preload("res://scripts/item_manager.gd")

const SAVE_KEY := "roll_hhh_save"
const ENCYCLOPEDIA_KEY := "roll_hhh_encyclopedia"
const TUTORIAL_KEY := "roll_hhh_tutorial_done"

## 图鉴数据 (永久保留)
var encyclopedia: Dictionary = {}  # key: "job_level" string, value: true

func _ready() -> void:
	load_encyclopedia()
	# Try to load game save
	var save_data: Dictionary = _load_from_storage(SAVE_KEY)
	if save_data.size() > 0:
		_apply_save(save_data)
	else:
		_init_board_from_map_config()


## 保存游戏状态
func save_game() -> void:
	var data: Dictionary = _build_save_data()
	_write_to_storage(SAVE_KEY, data)
	save_encyclopedia()


## 清除游戏存档 (战败后调用, 保留图鉴)
func clear_game_save() -> void:
	_remove_from_storage(SAVE_KEY)
	save_encyclopedia()
	# 重新从 MapConfig 初始化棋盘
	_init_board_from_map_config()
	# 发出信号通知 UI 刷新
	save_cleared.emit()


## 解锁图鉴条目
func unlock_encyclopedia(job: int, level: int) -> void:
	var key: String = "%d_%d" % [job, level]
	if not encyclopedia.has(key):
		encyclopedia[key] = true


## 检查图鉴是否解锁
func is_encyclopedia_unlocked(job: int, level: int) -> bool:
	return encyclopedia.has("%d_%d" % [job, level])


## 保存图鉴
func save_encyclopedia() -> void:
	_write_to_storage(ENCYCLOPEDIA_KEY, encyclopedia)


## 加载图鉴
func load_encyclopedia() -> void:
	var data: Dictionary = _load_from_storage(ENCYCLOPEDIA_KEY)
	if data.size() > 0:
		encyclopedia = data


## 检查新手教学是否已完成
func is_tutorial_done() -> bool:
	var raw: String = ""
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("localStorage.getItem('%s')" % TUTORIAL_KEY)
		if result != null and result is String and result != "null":
			raw = result
	else:
		var file := FileAccess.open("user://%s.json" % TUTORIAL_KEY, FileAccess.READ)
		if file:
			raw = file.get_as_text()
			file.close()
	return raw == "true"


## 公开初始化方法 - 供 GameManager 调用 (清空存档后重新初始化)
func init_board_from_config() -> void:
	_init_board_from_map_config()


## 从 MapConfig 初始化棋盘布局
func _init_board_from_map_config() -> void:
	var map_loader := MCL.new()
	if not map_loader.load_config():
		return

	GameManager.board_data.clear_board()

	# 初始化局外道具
	GameManager.out_items.clear()

	# 清空背包
	GameManager.backpack_items.clear()

	# 初始化所有格子状态（从 MapConfig）
	GameManager.board_data.init_grid_states_from_config(map_loader)

	var cells: Array = map_loader.get_initial_cells()

	for cell in cells:
		var row: int = cell.get("row", 0)
		var col: int = cell.get("col", 0)
		var item_id: int = cell.get("item_id", 0)
		var state: int = cell.get("state", MCL.GridState.LOCKED)

		if item_id == 0:
			continue

		# 使用ItemManager获取物品数据并复制一份
		var board_item: DataModels.BoardItemData = ItemManager.get_item(item_id)
		if board_item == null:
			continue

		# 复制物品数据(因为ItemManager的缓存是共享的)
		var item: DataModels.BoardItemData = board_item.duplicate()
		# 交换坐标：col=lua_col(0-8)->row, row=lua_row(0-6)->col
		var pos := Vector2i(row, col)

		# 放置到棋盘（格子状态已在 init_grid_states_from_config 中设置）
		GameManager.board_data.place_item(item, pos)
		# 如果是生成器，注册到 ProducerManager（Autoload单例）
		var board_index: int = pos.y * BD.GRID_COLS + pos.x
		if IM.new().is_producer(item.id):
			get_node("/root/ProducerManager").register_producer(board_index, item.id)


## 根据物品ID获取职业 (临时实现，需要根据实际ID规则调整)
func _get_job_from_item_id(item_id: int) -> int:
	# 物品ID第3-4位表示职业链
	# 01=化石/龙蛋, 02=宝箱/龙蛋, 03=骨头/食肉龙蛋, 04=装备/仪器
	# 05=水生/水龙蛋, 06=地图/物资, 07=文物/飞龙蛋
	var chain := (item_id / 10000) % 100
	match chain:
		1: return 0  # 战士相关
		2: return 0  # 战士相关
		3: return 0  # 战士相关
		4: return 1  # 法师相关
		5: return 1  # 法师相关
		6: return 2  # 牧师相关
		7: return 2  # 牧师相关
		_: return 0


## 标记新手教学已完成
func mark_tutorial_done() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("localStorage.setItem('%s', 'true')" % TUTORIAL_KEY)
	else:
		var file := FileAccess.open("user://%s.json" % TUTORIAL_KEY, FileAccess.WRITE)
		if file:
			file.store_string("true")
			file.close()


# ---- 构建存档数据 ----

func _build_save_data() -> Dictionary:
	var data: Dictionary = {}
	# 游戏状态
	data["phase"] = GameManager.phase
	data["gold"] = GameManager.gold
	data["energy"] = GameManager.energy
	data["max_energy"] = GameManager.max_energy
	data["current_round"] = GameManager.current_round
	data["cycle_count"] = GameManager.cycle_count
	data["battle_turn"] = GameManager.battle_turn
	data["shop_last_refresh_round"] = GameManager.shop_last_refresh_round
	data["shop_items_data"] = GameManager.shop_items_data

	# 体力恢复时间
	data["last_energy_update_time"] = GameManager.last_energy_update_time

	# 生成器状态
	var producers_data: Array = []
	var pm = get_node_or_null("/root/ProducerManager")
	if pm != null:
		for board_index in pm.get_all_producers():
			var state = pm.get_producer_state(board_index)
			if state != null:
				producers_data.append({
					"board_index": board_index,
					"current_count": state.current_count,
					"cooldown_remaining": state.cooldown_remaining,
					"last_recovery_time": state.last_recovery_time
				})
	data["producers"] = producers_data

	# 棋盘物品
	var board_items: Array = []
	for i in range(BD.BOARD_SLOTS):
		var item: DataModels.BoardItemData = GameManager.board_data.board[i]
		if item != null:
			var d: Dictionary = item.to_dict()
			d["board_index"] = i
			board_items.append(d)
	data["board"] = board_items

	# 棋盘格子状态
	var grid_states: Array = []
	for i in range(BD.BOARD_SLOTS):
		grid_states.append(GameManager.board_data.get_grid_state(i))
	data["grid_states"] = grid_states

	# 宿舍物品
	var dorm_items: Array = []
	for item in GameManager.board_data.dormitory:
		dorm_items.append(item.to_dict())
	data["dormitory"] = dorm_items

	# 道具
	var items_data: Array = []
	for item in GameManager.items:
		items_data.append(item.to_dict())
	data["items"] = items_data

	# 遗物
	var relics_data: Array = []
	for relic in GameManager.relics:
		relics_data.append(relic.to_dict())
	data["relics"] = relics_data

	# 局外道具
	data["out_items"] = GameManager.out_items.duplicate()

	# 背包物品
	var backpack_data: Array = []
	for item in GameManager.backpack_items:
		backpack_data.append(item.to_dict())
	data["backpack_items"] = backpack_data

	# 任务系统状态
	var tm = get_node_or_null("/root/TaskManager")
	if tm != null:
		data["taskSystem"] = tm.build_save_data()

	return data


# ---- 应用存档数据 ----

func _apply_save(data: Dictionary) -> void:
	# 游戏状态
	GameManager.phase = data.get("phase", GameManager.PHASE_PREPARE)
	GameManager.gold = data.get("gold", 0)
	GameManager.energy = data.get("energy", GameManager.DEFAULT_MAX_ENERGY)
	GameManager.max_energy = data.get("max_energy", GameManager.DEFAULT_MAX_ENERGY)
	GameManager.current_round = data.get("current_round", 1)
	GameManager.cycle_count = data.get("cycle_count", 0)
	GameManager.battle_turn = data.get("battle_turn", 0)
	GameManager.shop_last_refresh_round = data.get("shop_last_refresh_round", -1)
	GameManager.shop_items_data = data.get("shop_items_data", [])

	# 恢复体力时间和离线恢复
	GameManager.last_energy_update_time = data.get("last_energy_update_time", Time.get_unix_time_from_system())
	GameManager.apply_offline_energy_recovery()

	# 清空棋盘再填充
	GameManager.board_data.clear_board()

	# 恢复棋盘物品
	var board_items: Array = data.get("board", [])
	for idata in board_items:
		var item := DM.BoardItemData.from_dict(idata)
		var idx: int = idata.get("board_index", -1)
		if idx >= 0 and idx < BD.BOARD_SLOTS:
			GameManager.board_data.board[idx] = item
			# 如果是生成器，注册到 ProducerManager
			if item != null and IM.new().is_producer(item.id):
				get_node("/root/ProducerManager").register_producer(idx, item.id)

	# 恢复棋盘格子状态
	var grid_states: Array = data.get("grid_states", [])
	if grid_states.size() == BD.BOARD_SLOTS:
		for i in range(BD.BOARD_SLOTS):
			GameManager.board_data.set_grid_state(i, grid_states[i])
	else:
		# 兼容：没有存档的旧存档，从 MapConfig 初始化
		_init_board_from_map_config()

	# 恢复生成器状态（库存和冷却）
	var producers_data: Array = data.get("producers", [])
	var pm = get_node_or_null("/root/ProducerManager")
	if pm != null:
		for pdata in producers_data:
			var board_index: int = pdata.get("board_index", -1)
			if board_index >= 0:
				pm.restore_producer_state(
					board_index,
					pdata.get("current_count", 0),
					pdata.get("cooldown_remaining", 0.0),
					pdata.get("last_recovery_time", 0.0)
				)

	# 恢复宿舍物品
	GameManager.board_data.dormitory.clear()
	var dorm_items: Array = data.get("dormitory", [])
	for idata in dorm_items:
		var item := DM.BoardItemData.from_dict(idata)
		GameManager.board_data.dormitory.append(item)

	# 恢复道具
	GameManager.items.clear()
	var items_data: Array = data.get("items", [])
	for idata in items_data:
		var item := DM.ItemData.from_dict(idata)
		GameManager.items.append(item)

	# 恢复遗物
	GameManager.relics.clear()
	var relics_data: Array = data.get("relics", [])
	for rd in relics_data:
		var item := DM.ItemData.from_dict(rd)
		GameManager.relics.append(item)

	# 恢复局外道具
	GameManager.out_items.clear()
	var out_items_data: Array = data.get("out_items", [])
	for oid in out_items_data:
		GameManager.out_items.append(oid)

	# 恢复背包物品
	GameManager.backpack_items.clear()
	var backpack_data: Array = data.get("backpack_items", [])
	for idata in backpack_data:
		var item := DM.BoardItemData.from_dict(idata)
		GameManager.backpack_items.append(item)

	# 恢复任务系统状态
	var tm = get_node_or_null("/root/TaskManager")
	if tm != null:
		var task_data: Dictionary = data.get("taskSystem", {})
		if not task_data.is_empty():
			tm.load_from_save_data(task_data)

	# 发射信号更新UI
	GameManager.gold_changed.emit(GameManager.gold)
	GameManager.energy_changed.emit(GameManager.energy)
	GameManager.round_changed.emit(GameManager.current_round)
	GameManager.items_changed.emit()
	GameManager.relics_changed.emit()


# ---- LocalStorage 底层操作 ----

func _write_to_storage(key: String, data) -> void:
	var json_str: String = JSON.stringify(data)
	if OS.has_feature("web"):
		var js_code: String = "localStorage.setItem('%s', '%s')" % [key, json_str.replace("\\", "\\\\").replace("'", "\\'")]
		JavaScriptBridge.eval(js_code)
	else:
		# 非web环境: 文件存档
		var file := FileAccess.open("user://%s.json" % key, FileAccess.WRITE)
		if file:
			file.store_string(json_str)
			file.close()


func _load_from_storage(key: String) -> Dictionary:
	var json_str: String = ""
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("localStorage.getItem('%s')" % key)
		if result != null and result is String and result != "null" and result != "":
			json_str = result
	else:
		var file := FileAccess.open("user://%s.json" % key, FileAccess.READ)
		if file:
			json_str = file.get_as_text()
			file.close()

	if json_str == "":
		return {}

	var json := JSON.new()
	var err := json.parse(json_str)
	if err != OK:
		return {}

	var parsed_data = json.data
	if parsed_data is Dictionary:
		return parsed_data
	return {}


## 提交排行榜分数
func submit_leaderboard_score(score: int) -> void:
	var player_data: Dictionary = _load_player_data()
	var leaderboard: Array = _load_leaderboard_data()

	var player_id: String = player_data.get("id", "")
	var player_name: String = player_data.get("name", "")

	if player_id == "":
		player_id = "Guest_%d" % randi_range(10000, 99999)
		player_name = player_id
		_write_to_storage("roll_hhh_player_id", {"id": player_id, "name": player_name})

	# Update or add entry
	var found: bool = false
	for entry in leaderboard:
		if entry is Dictionary and entry.get("id", "") == player_id:
			if score > entry.get("score", 0):
				entry["score"] = score
				entry["name"] = player_name
			found = true
			break

	if not found:
		leaderboard.append({"id": player_id, "name": player_name, "score": score})

	leaderboard.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))
	if leaderboard.size() > 50:
		leaderboard.resize(50)

	var json_str: String = JSON.stringify(leaderboard)
	if OS.has_feature("web"):
		var escaped: String = json_str.replace("\\", "\\\\").replace("'", "\\'")
		JavaScriptBridge.eval("localStorage.setItem('roll_hhh_leaderboard', '%s')" % escaped)
	else:
		var file := FileAccess.open("user://roll_hhh_leaderboard.json", FileAccess.WRITE)
		if file:
			file.store_string(json_str)
			file.close()



func _load_player_data() -> Dictionary:
	var data: Dictionary = {}
	var raw: String = ""
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("localStorage.getItem('roll_hhh_player_id')")
		if result != null and result is String and result != "null":
			raw = result
	else:
		var file := FileAccess.open("user://roll_hhh_player_id.json", FileAccess.READ)
		if file:
			raw = file.get_as_text()
			file.close()

	if raw != "":
		var json := JSON.new()
		if json.parse(raw) == OK and json.data is Dictionary:
			data = json.data
	return data


func _load_leaderboard_data() -> Array:
	var raw: String = ""
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("localStorage.getItem('roll_hhh_leaderboard')")
		if result != null and result is String and result != "null":
			raw = result
	else:
		var file := FileAccess.open("user://roll_hhh_leaderboard.json", FileAccess.READ)
		if file:
			raw = file.get_as_text()
			file.close()

	if raw != "":
		var json := JSON.new()
		if json.parse(raw) == OK and json.data is Array:
			return json.data
	return []


func _remove_from_storage(key: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("localStorage.removeItem('%s')" % key)
	else:
		var path: String = "user://%s.json" % key
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
