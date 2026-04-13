extends RefCounted
class_name ItemConfigLoader

## ItemConfig 配置加载器

const ITEM_CONFIG_PATH := "res://config/ItemConfig.json"

# 配置数据
var items: Array = []
var _items_by_id: Dictionary = {}  # id -> item data

# 是否已加载
var _loaded: bool = false

## 加载配置
func load_config() -> bool:
	if _loaded:
		return true

	var file := FileAccess.open(ITEM_CONFIG_PATH, FileAccess.READ)
	if file == null:
		print(">>> [ItemConfigLoader] 加载失败: %s" % FileAccess.get_open_error())
		return false

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		print(">>> [ItemConfigLoader] JSON 解析失败")
		return false

	var data: Dictionary = json.data
	if data.is_empty():
		print(">>> [ItemConfigLoader] 配置数据为空")
		return false

	items = data.get("items", [])

	# 构建ID索引
	_items_by_id.clear()
	for item in items:
		var id: int = item.get("id", 0)
		if id > 0:
			_items_by_id[id] = item

	_loaded = true
	print(">>> [ItemConfigLoader] 配置加载成功: %d 个物品" % items.size())
	return true


## 根据ID获取物品数据
func get_item(item_id: int) -> Dictionary:
	if not _loaded:
		load_config()
	return _items_by_id.get(item_id, {})


## 获取物品sprite名称
func get_sprite(item_id: int) -> String:
	var item: Dictionary = get_item(item_id)
	return item.get("sprite", "")


## 获取物品名称
func get_name(item_id: int) -> String:
	var item: Dictionary = get_item(item_id)
	return item.get("name", "")


## 获取物品等级
func get_level(item_id: int) -> int:
	var item: Dictionary = get_item(item_id)
	return item.get("level", 1)


## 获取物品类型
func get_type(item_id: int) -> String:
	var item: Dictionary = get_item(item_id)
	return item.get("type", "")


## 获取sprite完整路径
func get_sprite_path(item_id: int) -> String:
	var sprite: String = get_sprite(item_id)
	if sprite.is_empty():
		return ""
	return "res://art/sprites/items/%s.png" % sprite


## 获取产出物品列表
func get_production_items(item_id: int) -> Array:
	var item: Dictionary = get_item(item_id)
	return item.get("production_items", [])


## 获取产出概率列表
func get_production_random(item_id: int) -> Array:
	var item: Dictionary = get_item(item_id)
	return item.get("production_random", [])


## 根据概率随机选择产出物品ID
func roll_production_item(item_id: int) -> int:
	var prod_items: Array = get_production_items(item_id)
	var randoms: Array = get_production_random(item_id)
	if prod_items.is_empty() or randoms.is_empty():
		return 0
	if prod_items.size() != randoms.size():
		return prod_items[0] if not prod_items.is_empty() else 0

	# 累加概率并随机
	var total: float = 0.0
	for r in randoms:
		total += r

	var roll: float = randf() * total
	var cumulative: float = 0.0
	for i in range(prod_items.size()):
		cumulative += randoms[i]
		if roll <= cumulative:
			return prod_items[i]
	return prod_items[0]
