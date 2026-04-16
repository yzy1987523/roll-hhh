extends Node

## 棋盘物品管理器 (Autoload 单例)
## 负责从ItemConfig加载物品配置，提供BoardItemData管理

const ICL = preload("res://scripts/item_config_loader.gd")
const DM = preload("res://scripts/data_models.gd")

# ItemConfig加载器实例
var _config_loader: ItemConfigLoader = ItemConfigLoader.new()

# BoardItemData缓存 (id -> BoardItemData)
var _item_cache: Dictionary = {}

# 所有物品列表
var all_items: Array = []  # Array of BoardItemData


func _ready() -> void:
	_load_items()


## 加载所有物品配置
func _load_items() -> void:
	if not _config_loader.load_config():
		return

	all_items.clear()
	_item_cache.clear()

	for item_data in _config_loader.items:
		var id_val = item_data.get("id", 0)
		var id: int = int(id_val) if id_val is String or id_val is int else 0
		if id == 0:
			continue
		var board_item: DM.BoardItemData = DM.BoardItemData.from_config(item_data)
		all_items.append(board_item)
		_item_cache[id] = board_item



## 根据ID获取BoardItemData
func get_item(item_id: int) -> DM.BoardItemData:
	if _item_cache.has(item_id):
		return _item_cache[item_id]

	# 尝试从配置加载器获取
	var cfg: Dictionary = _config_loader.get_item(item_id)
	if not cfg.is_empty():
		var board_item: DM.BoardItemData = DM.BoardItemData.from_config(cfg)
		_item_cache[item_id] = board_item
		return board_item

	return null


## 获取物品sprite完整路径
func get_sprite_path(item_id: int) -> String:
	var board_item: DM.BoardItemData = get_item(item_id)
	if board_item != null:
		return board_item.get_sprite_path()
	return ""


## 获取物品等级
func get_level(item_id: int) -> int:
	var board_item: DM.BoardItemData = get_item(item_id)
	if board_item != null:
		return board_item.level
	return 1


## 获取物品类型 (BoardItemType enum)
func get_item_type(item_id: int) -> int:
	var board_item: DM.BoardItemData = get_item(item_id)
	if board_item != null:
		return board_item.item_type
	return DataModels.BoardItemType.COMPOSITE


## 检查物品是否可合成
func can_merge(item_id: int) -> bool:
	var board_item: DM.BoardItemData = get_item(item_id)
	if board_item != null:
		return board_item.can_merge()
	return false


## 获取合成后的物品ID
func get_next_composite(item_id: int) -> int:
	var board_item: DM.BoardItemData = get_item(item_id)
	if board_item != null:
		return board_item.get_next_item_id()
	return 0


## 获取合成链ID
func get_merge_chain(item_id: int) -> int:
	# 合成链 = item_id / 100
	return item_id / 100


## 根据合成链ID获取该链所有物品
func get_items_by_chain(chain_id: int) -> Array:
	var result: Array = []
	for item in all_items:
		if item.get_merge_chain() == chain_id:
			result.append(item)
	return result


## 根据类型获取物品
func get_items_by_type(item_type: int) -> Array:
	var result: Array = []
	for item in all_items:
		if item.item_type == item_type:
			result.append(item)
	return result


## 获取随机物品 (用于生成)
## item_type: -1表示所有类型
## max_level: 限制最大等级
func get_random_item(item_type: int = -1, max_level: int = 99) -> DM.BoardItemData:
	var candidates: Array = []
	for item in all_items:
		if item.level > max_level:
			continue
		if item_type >= 0 and item.item_type != item_type:
			continue
		candidates.append(item)

	if candidates.is_empty():
		return null

	return candidates[randi_range(0, candidates.size() - 1)]


## 获取随机可合成物品
func get_random_mergeable_item(max_level: int = 9) -> DM.BoardItemData:
	var candidates: Array = []
	for item in all_items:
		if item.can_merge() and item.level < max_level:
			candidates.append(item)

	if candidates.is_empty():
		return null

	return candidates[randi_range(0, candidates.size() - 1)]


## 合成两个物品
## 返回合成后的新物品，失败返回null
func merge_items(item_a: DM.BoardItemData, item_b: DM.BoardItemData) -> DM.BoardItemData:
	# 检查是否可以合成
	if not item_a.can_merge() or not item_b.can_merge():
		return null
	if item_a.id != item_b.id:
		return null

	# 获取合成后的物品ID
	var next_id: int = item_a.get_next_item_id()
	if next_id == 0:
		return null

	# 获取合成后的物品数据
	var merged_item: DM.BoardItemData = get_item(next_id)
	if merged_item == null:
		return null

	# 复制一份用于棋盘存储
	var result: DM.BoardItemData = merged_item.duplicate()
	return result


## 检查物品是否为生产器
func is_producer(item_id: int) -> bool:
	var cfg: Dictionary = _config_loader.get_item(item_id)
	if cfg.is_empty():
		return false
	var item_type: String = cfg.get("type", "")
	return item_type == "production" or item_type == "maxproduction" or item_type == "autoproduction" or item_type == "stockproduction"


## 检查物品是否为自动生产器
func is_autoproduction(item_id: int) -> bool:
	var cfg: Dictionary = _config_loader.get_item(item_id)
	if cfg.is_empty():
		return false
	var item_type: String = cfg.get("type", "")
	return item_type == "autoproduction"


## 检查物品是否为库存生产器
func is_stockproduction(item_id: int) -> bool:
	var cfg: Dictionary = _config_loader.get_item(item_id)
	if cfg.is_empty():
		return false
	var item_type: String = cfg.get("type", "")
	return item_type == "stockproduction"


## 检查物品是否为背包
func is_backpack(item_id: int) -> bool:
	# 背包物品ID为99
	return item_id == 99


## 检查物品是否为金币堆
func is_coinpile(item_id: int) -> bool:
	var cfg: Dictionary = _config_loader.get_item(item_id)
	if cfg.is_empty():
		return false
	var item_type: String = cfg.get("type", "")
	return item_type == "coinpile"


## 获取金币堆的金币价值
## f(n) = round(2.5^(n-1))，n为等级1-6
func get_coinpile_value(level: int) -> int:
	if level < 1:
		return 0
	return int(roundf(pow(2.5, level - 1)))


## 检查物品是否为体力球
func is_energy(item_id: int) -> bool:
	var cfg: Dictionary = _config_loader.get_item(item_id)
	if cfg.is_empty():
		return false
	var item_type: String = cfg.get("type", "")
	return item_type == "energy"


## 获取体力球的体力价值
## 优先读取配置的energy_value字段，未配置则使用公式 round(2^(n-1))
func get_energy_value(item_id: int, level: int) -> int:
	if level < 1:
		return 0
	var cfg: Dictionary = _config_loader.get_item(item_id)
	if not cfg.is_empty():
		var energy_val = cfg.get("energy_value", -1)
		if energy_val is int and energy_val >= 0:
			return energy_val
		if energy_val is float and energy_val >= 0:
			return int(energy_val)
		if energy_val is String and energy_val.is_valid_int():
			return int(energy_val)
	return int(roundf(pow(2, level - 1)))


## 获取物品出售价格
## 普通物品: 2^(level-1)
func get_sell_price(_item_id: int, level: int) -> int:
	if level < 1:
		return 0
	return int(pow(2, level - 1))


## 检查物品是否可出售（普通物品可出售，生成器/背包/金币堆/体力球不可）
func is_sellable(item_id: int) -> bool:
	# 生成器、背包、金币堆、体力球不可出售
	if is_producer(item_id):
		return false
	if is_backpack(item_id):
		return false
	if is_coinpile(item_id):
		return false
	# 检查是否为体力相关物品
	var cfg: Dictionary = _config_loader.get_item(item_id)
	if cfg.is_empty():
		return false
	var item_type: String = cfg.get("type", "")
	if item_type == "energy" or item_type == "energybox":
		return false
	return true


## 生产物品
## 点击生成器后，根据概率随机产出物品
## board_index: 棋盘索引，用于库存和冷却管理，-1表示不管理库存
func produce_item(item_id: int, board_index: int = -1) -> DM.BoardItemData:
	# 如果提供了 board_index，尝试消耗库存
	if board_index >= 0 and ProducerManager.is_producer(board_index):
		if not ProducerManager.can_produce(board_index):
			return null
		ProducerManager.consume_stock(board_index)

	var produced_id: int = _config_loader.roll_production_item(item_id)
	if produced_id == 0:
		return null

	var produced: DM.BoardItemData = get_item(produced_id)
	if produced == null:
		return null

	var result: DM.BoardItemData = produced.duplicate()
	return result
