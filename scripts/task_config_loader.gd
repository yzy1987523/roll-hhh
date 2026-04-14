extends RefCounted
class_name TaskConfigLoader

## 局内任务配置加载器 (TaskConfig.json)

const TASK_CONFIG_PATH := "res://config/TaskConfig.json"

# 局内任务配置数据
var tasks: Array = []
var _tasks_by_id: Dictionary = {}  # id -> task data
var _loaded: bool = false

## 加载配置
func load_config() -> bool:
	if _loaded:
		return true

	var file := FileAccess.open(TASK_CONFIG_PATH, FileAccess.READ)
	if file == null:
		print(">>> [TaskConfigLoader] 加载失败: %s" % FileAccess.get_open_error())
		return false

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		print(">>> [TaskConfigLoader] JSON解析失败")
		return false

	var data: Dictionary = json.data
	if data.is_empty():
		print(">>> [TaskConfigLoader] 配置数据为空")
		return false

	tasks = data.get("tasks", [])

	# 构建ID索引
	_tasks_by_id.clear()
	for task in tasks:
		var id: int = task.get("id", 0)
		if id > 0:
			_tasks_by_id[id] = task

	_loaded = true
	# print(">>> [TaskConfigLoader] 局内任务配置加载成功: %d个任务" % tasks.size())
	return true


## 根据ID获取任务配置
func get_task(task_id: int) -> Dictionary:
	if not _loaded:
		load_config()
	return _tasks_by_id.get(task_id, {})


## 获取所有任务配置
func get_all_tasks() -> Array:
	if not _loaded:
		load_config()
	return tasks


## 获取指定解锁等级的任务
func get_tasks_by_unlock_level(level: int) -> Array:
	if not _loaded:
		load_config()
	var result: Array = []
	for task in tasks:
		if task.get("unlockLevel", 1) <= level:
			result.append(task)
	return result


## 获取链式任务的下一个任务ID
func get_next_task_id(task_id: int) -> int:
	var task: Dictionary = get_task(task_id)
	return task.get("nextTaskId", -1)


## 检查任务是否需要指定物品
func task_needs_item(task_id: int, item_id: int) -> bool:
	var task: Dictionary = get_task(task_id)
	var need_items: Array = task.get("needItems", [])
	return item_id in need_items
