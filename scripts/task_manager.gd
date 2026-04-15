extends Node

## 任务系统管理器
## 管理局内任务链和局外成就系统

# ---- 预加载 ----
const TCL = preload("res://scripts/task_config_loader.gd")
const DM = preload("res://scripts/data_models.gd")

# ---- 信号 ----
## 局内任务完成信号
signal task_completed(task_id: int, reward: Dictionary)
## 局外成就完成信号
signal achievement_completed(task_id: int, reward_exp: int)
## 任务进度更新信号 (局内任务检查时)
signal task_progress_updated(current_task_id: int, progress: float)
## 成就进度更新信号
signal achievement_progress_updated(task_id: int, progress: float)
## 任务物品信息更新信号（用于刷新任务物品图标显示）
signal task_items_updated(task_items_info: Dictionary)

# ---- 局内任务配置加载器 ----
var _task_loader: TaskConfigLoader = TaskConfigLoader.new()

# ---- 局内任务状态 ----
## 当前进行中的任务ID (0=无任务)
var _current_task_id: int = 0
## 已完成的局内任务ID集合
var _completed_task_ids: Array = []

# ---- 局外任务配置 ----
const OUT_TASK_CONFIG_PATH := "res://config/OutTaskConfig.json"
var _out_tasks: Array = []
var _out_tasks_by_id: Dictionary = {}
var _out_tasks_loaded: bool = false

# ---- 局外成就状态 ----
## 已完成的成就ID集合
var _completed_achievement_ids: Array = []

# ---- 建造清单完成状态 ----
## 已完成的建造ID集合
var _completed_build_ids: Array = []

# ---- 统计数据 (用于局外成就) ----
## 统计类型常量
const STAT_MERGE_COUNT := "mergeCount"           # 合成次数
const STAT_MERGE_TASK_COUNT := "mergeTaskCount"  # 局内合成任务完成次数
const STAT_DINOSAUR_COUNT := "dinosaurCount"     # 拥有恐龙数量
const STAT_LAND_COUNT := "landCount"             # 已解锁地块数量
const STAT_FEED_COUNT := "feedCount"             # 喂食次数
const STAT_HATCH_COUNT := "hatchCount"           # 孵化次数

var _statistics: Dictionary = {
	STAT_MERGE_COUNT: 0,
	STAT_MERGE_TASK_COUNT: 0,
	STAT_DINOSAUR_COUNT: 0,
	STAT_LAND_COUNT: 0,
	STAT_FEED_COUNT: 0,
	STAT_HATCH_COUNT: 0,
}

# ---- 星星数量 (局内任务奖励) ----
var stars: int = 0
signal stars_changed(new_stars: int)

# ---- 经验值 ----
var exp: int = 0
signal exp_changed(new_exp: int)

# ---- 玩家等级 (局内任务解锁用) ----
var player_level: int = 1
signal level_up(new_level: int)

## 获取星星数量
func get_stars() -> int:
	return stars

## 获取玩家等级
func get_level() -> int:
	return player_level

## 获取已完成的建造ID列表
func get_completed_build_ids() -> Array:
	return _completed_build_ids

## 添加一个已完成的建造ID
func add_completed_build_id(build_id: int) -> void:
	if not _completed_build_ids.has(float(build_id)):
		_completed_build_ids.append(float(build_id))

## 保存已完成的建造ID列表
func save_completed_build_ids(ids: Array) -> void:
	_completed_build_ids = ids

# ---- 初始化 ----

func _ready() -> void:
	_load_configs()
	advance_task_chain()  # 初始化任务链
	# 监听背包物品变化，刷新任务进度显示
	GameManager.backpack_items_changed.connect(_on_backpack_items_changed)
	# 监听棋盘物品变化，刷新任务进度显示
	GameManager.board_items_changed.connect(_on_backpack_items_changed)
	print(">>> [TaskManager] 任务系统管理器已加载")


func _on_backpack_items_changed() -> void:
	# 背包物品变化时，刷新任务进度显示和物品图标
	if _current_task_id > 0:
		task_progress_updated.emit(_current_task_id, get_current_task_progress())
		task_items_updated.emit(get_task_items_info())


func _load_configs() -> void:
	# 加载局内任务配置
	_task_loader.load_config()
	# 加载局外任务配置
	_load_out_task_config()


func _load_out_task_config() -> void:
	if _out_tasks_loaded:
		return

	var file := FileAccess.open(OUT_TASK_CONFIG_PATH, FileAccess.READ)
	if file == null:
		print(">>> [TaskManager] 局外任务配置加载失败: %s" % FileAccess.get_open_error())
		return

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		print(">>> [TaskManager] 局外任务配置JSON解析失败")
		return

	var data: Dictionary = json.data
	if data.is_empty():
		print(">>> [TaskManager] 局外任务配置数据为空")
		return

	_out_tasks = data.get("tasks", [])
	_out_tasks_by_id.clear()
	for task in _out_tasks:
		var id: int = task.get("id", 0)
		if id > 0:
			_out_tasks_by_id[id] = task

	_out_tasks_loaded = true
	# print(">>> [TaskManager] 局外任务配置加载成功: %d个成就" % _out_tasks.size())


# ==========================================
# 局内任务系统
# ==========================================

## 获取当前局内任务ID
func get_current_task_id() -> int:
	return _current_task_id


## 获取当前局内任务配置
func get_current_task() -> Dictionary:
	if _current_task_id <= 0:
		return {}
	return _task_loader.get_task(_current_task_id)


## 获取当前任务的完成进度 (0.0 - 1.0)
## 根据棋盘和背包中的物品计算实际进度
func get_current_task_progress() -> float:
	if _current_task_id <= 0:
		return 0.0
	var task: Dictionary = get_current_task()
	if task.is_empty():
		return 0.0

	var need_items: Array = task.get("needItems", [])
	if need_items.is_empty():
		return 1.0

	# 统计需求
	var need_counts: Dictionary = {}
	for need_id in need_items:
		var id_int: int = int(need_id)
		need_counts[id_int] = need_counts.get(id_int, 0) + 1

	# 统计可用数量
	var board_data: BoardData = GameManager.board_data
	var backpack: Array = GameManager.get_backpack_items()
	var available_counts: Dictionary = {}

	# 遍历棋盘（跳过LOCKED和DUSTY）
	for i in range(BoardData.BOARD_SLOTS):
		var state: int = board_data.get_grid_state(i)
		if state == BoardData.GridState.LOCKED or state == BoardData.GridState.DUSTY:
			continue
		var item: DataModels.BoardItemData = board_data.get_item_at_index(i)
		if item == null:
			continue
		var id_int: int = int(item.id)
		available_counts[id_int] = available_counts.get(id_int, 0) + 1

	# 遍历背包
	for item in backpack:
		if item == null:
			continue
		var id_int: int = int(item.id)
		available_counts[id_int] = available_counts.get(id_int, 0) + 1

	# 计算满足的需求数量
	var satisfied_count: int = 0
	var total_need: int = need_items.size()
	for need_id in need_counts.keys():
		var have: int = available_counts.get(need_id, 0)
		var need: int = need_counts[need_id]
		satisfied_count += mini(have, need)

	return clampf(float(satisfied_count) / float(total_need), 0.0, 1.0)


## 检查物品是否满足当前任务需求
## 返回匹配的任务物品数量
func check_task_item(item_id: int) -> int:
	if _current_task_id <= 0:
		return 0
	var task: Dictionary = get_current_task()
	if task.is_empty():
		return 0
	var need_items: Array = task.get("needItems", [])
	if item_id in need_items:
		return 1
	return 0


## 获取当前任务的物品需求ID列表
func get_current_task_need_ids() -> Array[int]:
	var task: Dictionary = get_current_task()
	if task.is_empty():
		return []
	var need_items: Array = task.get("needItems", [])
	var result: Array[int] = []
	for need_id in need_items:
		result.append(int(need_id))
	return result


## 获取所有可提交的任务物品信息（棋盘+背包）
## 返回 {"board": [{index, id, pos}, ...], "backpack": [{index, id}, ...]}
## 跳过LOCKED和DUSTY状态的格子
func get_task_items_info() -> Dictionary:
	var result := {"board": [], "backpack": []}
	if _current_task_id <= 0:
		return result

	var task: Dictionary = get_current_task()
	if task.is_empty():
		return result

	var need_items: Array = task.get("needItems", [])
	if need_items.is_empty():
		return result

	# 统计需求
	var need_counts: Dictionary = {}
	for need_id in need_items:
		var id_int: int = int(need_id)
		need_counts[id_int] = need_counts.get(id_int, 0) + 1

	var board_data: BoardData = GameManager.board_data
	var backpack: Array = GameManager.get_backpack_items()

	# 遍历棋盘，收集可用物品（跳过LOCKED和DUSTY）
	for i in range(BoardData.BOARD_SLOTS):
		var state: int = board_data.get_grid_state(i)
		if state == BoardData.GridState.LOCKED or state == BoardData.GridState.DUSTY:
			continue
		var item: DataModels.BoardItemData = board_data.get_item_at_index(i)
		if item == null:
			continue
		var id_int: int = int(item.id)
		if need_counts.get(id_int, 0) > 0:
			var pos: Vector2i = BoardData.index_to_pos(i)
			result["board"].append({"index": i, "id": id_int, "pos": pos, "sprite_path": item.get_sprite_path()})
			need_counts[id_int] -= 1

	# 遍历背包，收集可用物品
	for i in range(backpack.size()):
		var item: DataModels.BoardItemData = backpack[i]
		if item == null:
			continue
		var id_int: int = int(item.id)
		if need_counts.get(id_int, 0) > 0:
			result["backpack"].append({"index": i, "id": id_int, "sprite_path": item.get_sprite_path()})
			need_counts[id_int] -= 1

	return result


## 尝试完成当前局内任务 (物品提交时调用)
## 返回是否成功完成
func try_complete_task(submitted_item_ids: Array[int]) -> bool:
	if _current_task_id <= 0:
		return false
	var task: Dictionary = get_current_task()
	if task.is_empty():
		return false

	# 检查是否满足任务物品需求
	var need_items: Array = task.get("needItems", [])
	var satisfied: bool = true
	for need_id in need_items:
		if need_id not in submitted_item_ids:
			satisfied = false
			break

	if not satisfied:
		return false

	# 消耗物品并完成任务
	var consumed: bool = _consume_task_items(need_items)
	if not consumed:
		return false

	_complete_task(task)
	return true


## 检查并消耗任务物品
## 从棋盘和背包中查找所需物品，跳过LOCKED和DUSTY状态的格子
## 消耗成功后从棋盘/背包中移除对应物品
## 返回是否成功消耗所有物品
func _consume_task_items(need_items: Array) -> bool:
	var board_data: BoardData = GameManager.board_data
	var backpack: Array = GameManager.get_backpack_items()

	# 统计需求
	var need_counts: Dictionary = {}
	for need_id in need_items:
		var id_int: int = int(need_id)
		need_counts[id_int] = need_counts.get(id_int, 0) + 1

	# 追踪需要从各来源移除的数量
	var board_to_remove: Array = []  # [{index, id}, ...]
	var backpack_to_remove: Array = []  # [index, ...]

	# 遍历棋盘，收集可用物品（跳过LOCKED和DUSTY）
	for i in range(BoardData.BOARD_SLOTS):
		var state: int = board_data.get_grid_state(i)
		if state == BoardData.GridState.LOCKED or state == BoardData.GridState.DUSTY:
			continue
		var item: DataModels.BoardItemData = board_data.get_item_at_index(i)
		if item == null:
			continue
		var id_int: int = int(item.id)
		if need_counts.get(id_int, 0) > 0:
			board_to_remove.append({"index": i, "id": id_int})
			need_counts[id_int] -= 1

	# 遍历背包，收集可用物品
	for i in range(backpack.size()):
		var item: DataModels.BoardItemData = backpack[i]
		if item == null:
			continue
		var id_int: int = int(item.id)
		if need_counts.get(id_int, 0) > 0:
			backpack_to_remove.append(i)
			need_counts[id_int] -= 1

	# 检查是否满足所有需求
	for count in need_counts.values():
		if count > 0:
			print(">>> [TaskManager] 物品不足，无法提交任务")
			return false

	# 执行移除
	# 先移除棋盘物品（按索引降序，避免移除后索引变化）
	board_to_remove.sort_custom(func(a, b): return a["index"] > b["index"])
	for remove_data in board_to_remove:
		var pos: Vector2i = BoardData.index_to_pos(remove_data["index"])
		board_data.remove_item(pos)
		print(">>> [TaskManager] 消耗棋盘物品: index=%d, id=%d" % [remove_data["index"], remove_data["id"]])
	# 移除完成后通知UI刷新
	if not board_to_remove.is_empty():
		GameManager.board_items_changed.emit()

	# 再移除背包物品（按索引降序）
	backpack_to_remove.sort()
	backpack_to_remove.reverse()
	for remove_idx in backpack_to_remove:
		GameManager.remove_from_backpack(remove_idx)
		print(">>> [TaskManager] 消耗背包物品: index=%d" % remove_idx)

	return true


## 直接完成任务并发放奖励
func _complete_task(task: Dictionary) -> void:
	var task_id: int = task.get("id", 0)
	var reward: Dictionary = task.get("reward", {})

	# 发放奖励
	var coin_reward: int = reward.get("coin", 0)
	var star_reward: int = reward.get("star", 0)
	var exp_reward: int = reward.get("exp", 0)
	var items_reward: Array = reward.get("items", [])

	if coin_reward > 0:
		GameManager.add_gold(coin_reward)
	if star_reward > 0:
		add_stars(star_reward)
	if exp_reward > 0:
		add_exp(exp_reward)

	# 发放物品奖励到道具栏
	for item_id in items_reward:
		var board_item: DataModels.BoardItemData = ItemManager.get_item(item_id)
		if board_item != null:
			GameManager.add_item(_create_item_data_from_board_item(board_item))

	# 标记完成
	_completed_task_ids.append(task_id)

	# 推进到下一个任务
	var next_id: int = task.get("nextTaskId", -1)
	_current_task_id = next_id if next_id > 0 else 0

	print(">>> [TaskManager] 局内任务完成: id=%d, 奖励: coin=%d, star=%d, exp=%d, items=%s" % [
		task_id, coin_reward, star_reward, exp_reward, items_reward
	])

	task_completed.emit(task_id, reward)
	task_items_updated.emit(get_task_items_info())


## 设置当前局内任务 (用于存档恢复或GM)
func set_current_task(task_id: int) -> void:
	_current_task_id = task_id


## 推进局内任务链到下一个可解锁的任务
func advance_task_chain() -> void:
	# 跳过已完成的任务，找到下一个未完成的
	var all_tasks: Array = _task_loader.get_all_tasks()
	print(">>> [TaskManager] advance_task_chain: 共%d个任务, player_level=%d, completed=%s" % [all_tasks.size(), player_level, _completed_task_ids])
	for task in all_tasks:
		var tid: int = task.get("id", 0)
		if tid <= 0:
			continue
		if tid in _completed_task_ids:
			print(">>> [TaskManager] 跳过已完成任务: id=%d" % tid)
			continue
		var unlock_level: int = task.get("unlockLevel", 1)
		if unlock_level > player_level:
			print(">>> [TaskManager] 跳过等级不足任务: id=%d, unlockLevel=%d > playerLevel=%d" % [tid, unlock_level, player_level])
			continue
		_current_task_id = tid
		print(">>> [TaskManager] 局内任务推进: id=%d, name=%s" % [tid, task.get("name", "")])
		task_items_updated.emit(get_task_items_info())
		return
	_current_task_id = 0
	print(">>> [TaskManager] 没有可接取的任务")
	task_items_updated.emit(get_task_items_info())


## 获取所有局内任务
func get_all_in_tasks() -> Array:
	return _task_loader.get_all_tasks()


## 获取已完成局内任务列表
func get_completed_in_task_ids() -> Array[int]:
	return _completed_task_ids


## 检查指定物品是否可用于当前任务
func can_use_for_task(item_id: int) -> bool:
	return check_task_item(item_id) > 0


# ==========================================
# 局外成就系统
# ==========================================

## 获取所有局外成就配置
func get_all_out_tasks() -> Array:
	if not _out_tasks_loaded:
		_load_out_task_config()
	return _out_tasks


## 获取成就配置
func get_out_task(task_id: int) -> Dictionary:
	if not _out_tasks_loaded:
		_load_out_task_config()
	return _out_tasks_by_id.get(task_id, {})


## 获取成就进度 (0.0 - 1.0)
func get_achievement_progress(task_id: int) -> float:
	if task_id in _completed_achievement_ids:
		return 1.0
	var task: Dictionary = get_out_task(task_id)
	if task.is_empty():
		return 0.0
	var stat_type: String = task.get("type", "")
	var target: int = task.get("target", 1)
	var current: int = _statistics.get(stat_type, 0)
	return clampf(float(current) / float(target), 0.0, 1.0)


## 获取已完成成就列表
func get_completed_achievement_ids() -> Array:
	return _completed_achievement_ids


## 增加统计数据并检查成就完成情况
## @param stat_type String 统计类型 (STAT_* 常量)
## @param amount int 增加量 (默认为1)
func add_statistic(stat_type: String, amount: int = 1) -> void:
	if not _statistics.has(stat_type):
		print(">>> [TaskManager] 未知统计类型: %s" % stat_type)
		return

	var old_val: int = _statistics[stat_type]
	_statistics[stat_type] = old_val + amount
	print(">>> [TaskManager] 统计数据更新: %s = %d -> %d" % [stat_type, old_val, _statistics[stat_type]])

	# 检查成就完成
	_check_achievements_by_type(stat_type)


## 设置统计数据 (用于存档恢复)
func set_statistic(stat_type: String, value: int) -> void:
	if _statistics.has(stat_type):
		_statistics[stat_type] = value


## 获取统计数据
func get_statistic(stat_type: String) -> int:
	return _statistics.get(stat_type, 0)


func _check_achievements_by_type(stat_type: String) -> void:
	if not _out_tasks_loaded:
		return

	for task in _out_tasks:
		var task_id: int = task.get("id", 0)
		if task_id in _completed_achievement_ids:
			continue
		if task.get("type", "") != stat_type:
			continue

		var unlock_level: int = task.get("unlockLevel", 1)
		if unlock_level > player_level:
			continue

		var target: int = task.get("target", 1)
		var current: int = _statistics.get(stat_type, 0)

		if current >= target:
			_complete_achievement(task)


func _complete_achievement(task: Dictionary) -> void:
	var task_id: int = task.get("id", 0)
	var exp_reward: int = task.get("expReward", 0)

	_completed_achievement_ids.append(task_id)

	if exp_reward > 0:
		add_exp(exp_reward)

	print(">>> [TaskManager] 成就完成: id=%d, name=%s, exp奖励=%d" % [
		task_id, task.get("name", ""), exp_reward
	])

	achievement_completed.emit(task_id, exp_reward)


# ==========================================
# 奖励系统
# ==========================================

func add_stars(amount: int) -> void:
	if amount <= 0:
		return
	stars += amount
	stars_changed.emit(stars)
	print(">>> [TaskManager] 获得星星: +%d, 当前: %d" % [amount, stars])


func add_exp(amount: int) -> void:
	if amount <= 0:
		return
	exp += amount
	exp_changed.emit(exp)
	print(">>> [TaskManager] 获得经验: +%d, 当前: %d" % [amount, exp])
	_check_level_up()


func _check_level_up() -> void:
	# 简单的等级计算: 每100exp升一级
	@warning_ignore("integer_division")
	var new_level: int = 1 + (exp / 100)
	if new_level > player_level:
		player_level = new_level
		level_up.emit(player_level)
		print(">>> [TaskManager] 玩家升级: level=%d" % player_level)
		# 升级后刷新可接取的局内/局外任务
		advance_task_chain()


# ==========================================
# 存档 / 恢复
# ==========================================

## 构建任务系统存档数据
func build_save_data() -> Dictionary:
	return {
		"currentTaskId": _current_task_id,
		"completedTaskIds": _completed_task_ids,
		"completedAchievementIds": _completed_achievement_ids,
		"completedBuildIds": _completed_build_ids,
		"statistics": _statistics.duplicate(true),
		"stars": stars,
		"exp": exp,
		"playerLevel": player_level,
	}


## 从存档数据恢复任务状态
func load_from_save_data(data: Dictionary) -> void:
	_current_task_id = data.get("currentTaskId", 0)
	_completed_task_ids = data.get("completedTaskIds", [])
	_completed_achievement_ids = data.get("completedAchievementIds", [])
	_completed_build_ids = data.get("completedBuildIds", [])

	var saved_stats: Dictionary = data.get("statistics", {})
	for key in _statistics:
		_statistics[key] = saved_stats.get(key, 0)

	stars = data.get("stars", 0)
	exp = data.get("exp", 0)
	player_level = data.get("playerLevel", 1)

	print(">>> [TaskManager] 任务状态已恢复: currentTask=%d, stars=%d, exp=%d, level=%d" % [
		_current_task_id, stars, exp, player_level
	])


# ==========================================
# 辅助方法
# ==========================================

## 从BoardItemData创建ItemData (用于道具栏)
func _create_item_data_from_board_item(board_item: DataModels.BoardItemData) -> DataModels.ItemData:
	var item := DataModels.ItemData.new()
	item.id = board_item.id
	item.type = DataModels.ItemType.CONSUMABLE
	item.name = board_item.name
	item.description = ""
	item.stackable = false
	item.stack_count = 1
	item.price = 0
	return item


## 检查指定棋子ID是否匹配当前任务需求
## 返回匹配数量
func match_task_requirements(board_item_ids: Array[int]) -> int:
	if _current_task_id <= 0:
		return 0
	var task: Dictionary = get_current_task()
	if task.is_empty():
		return 0
	var need_items: Array = task.get("needItems", [])
	var matched: int = 0
	for need_id in need_items:
		if need_id in board_item_ids:
			matched += 1
	return matched


## 获取局内任务描述 (本地化key)
func get_task_desc(task_id: int) -> String:
	var task: Dictionary = _task_loader.get_task(task_id)
	return task.get("content", "")
