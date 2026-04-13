extends RefCounted
class_name BuildConfigLoader

## 建造配置加载器 (BuildConfig.json)

const BUILD_CONFIG_PATH := "res://config/BuildConfig.json"

# 建造配置数据
var builds: Array = []
var _builds_by_id: Dictionary = {}  # id -> build data
var _loaded: bool = false

## 加载配置
func load_config() -> bool:
	if _loaded:
		return true

	var file := FileAccess.open(BUILD_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error(">>> [BuildConfigLoader] 加载失败: %s" % FileAccess.get_open_error())
		return false

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		push_error(">>> [BuildConfigLoader] JSON解析失败")
		return false

	var data: Dictionary = json.data
	if data.is_empty():
		push_error(">>> [BuildConfigLoader] 配置数据为空")
		return false

	builds = data.get("builds", [])

	# 构建ID索引
	_builds_by_id.clear()
	for build in builds:
		var id: int = build.get("id", 0)
		if id > 0:
			_builds_by_id[id] = build

	_loaded = true
	print(">>> [BuildConfigLoader] 建造配置加载成功: %d个建造" % builds.size())
	return true


## 根据ID获取建造配置
func get_build(id: int) -> Dictionary:
	if not _loaded:
		load_config()
	return _builds_by_id.get(id, {})


## 获取所有已解锁的建造ID列表
func get_unlocked_builds(player_level: int) -> Array:
	if not _loaded:
		load_config()
	var result: Array = []
	for build in builds:
		if build.get("unlockLevel", 999) <= player_level:
			result.append(build.get("id", 0))
	return result
