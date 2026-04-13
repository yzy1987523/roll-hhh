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
	print(">>> [ItemManager] 物品管理器已初始化")


## 加载所有物品配置
func _load_items() -> void:
	if not _config_loader.load_config():
		print(">>> [ItemManager] 物品配置加载失败")
		return

	all_items.clear()
	_item_cache.clear()

	for item_data in _config_loader.items:
		var id: int = item_data.get("id", 0)
		if id == 0:
			continue
		var board_item: DM.BoardItemData = DM.BoardItemData.from_config(item_data)
		all_items.append(board_item)
		_item_cache[id] = board_item

	print(">>> [ItemManager] 已加载 %d 个物品配置" % all_items.size())


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
		print(">>> [ItemManager] 合成失败: 物品不可合成")
		return null
	if item_a.id != item_b.id:
		print(">>> [ItemManager] 合成失败: 物品ID不同 (%d vs %d)" % [item_a.id, item_b.id])
		return null

	# 获取合成后的物品ID
	var next_id: int = item_a.get_next_item_id()
	if next_id == 0:
		print(">>> [ItemManager] 合成失败: 没有可合成的物品")
		return null

	# 获取合成后的物品数据
	var merged_item: DM.BoardItemData = get_item(next_id)
	if merged_item == null:
		print(">>> [ItemManager] 合成失败: 找不到合成后的物品 ID=%d" % next_id)
		return null

	# 复制一份用于棋盘存储
	var result: DM.BoardItemData = merged_item.duplicate()
	print(">>> [ItemManager] 合成成功: %d + %d → %d (Lv.%d)" % [item_a.id, item_b.id, next_id, result.level])
	return result


## 检查物品是否为生产器
func is_producer(item_id: int) -> bool:
	var cfg: Dictionary = _config_loader.get_item(item_id)
	if cfg.is_empty():
		return false
	var item_type: String = cfg.get("type", "")
	return item_type == "production" or item_type == "maxproduction"


## 检查物品是否为背包
func is_backpack(item_id: int) -> bool:
	# 背包物品ID为99
	return item_id == 99


## 生产物品
## 点击生成器后，根据概率随机产出物品
## board_index: 棋盘索引，用于库存和冷却管理，-1表示不管理库存
func produce_item(item_id: int, board_index: int = -1) -> DM.BoardItemData:
	# 如果提供了 board_index，尝试消耗库存
	if board_index >= 0 and ProducerManager.is_producer(board_index):
		if not ProducerManager.can_produce(board_index):
			print(">>> [ItemManager] 生产失败: 生成器正在冷却或库存为空 board=%d" % board_index)
			return null
		ProducerManager.consume_stock(board_index)

	var produced_id: int = _config_loader.roll_production_item(item_id)
	if produced_id == 0:
		print(">>> [ItemManager] 生产失败: 找不到产出物品 item_id=%d" % item_id)
		return null

	var produced: DM.BoardItemData = get_item(produced_id)
	if produced == null:
		print(">>> [ItemManager] 生产失败: 找不到产出物品配置 id=%d" % produced_id)
		return null

	var result: DM.BoardItemData = produced.duplicate()
	print(">>> [ItemManager] 生产成功: %d → %d (%s Lv.%d)" % [item_id, produced_id, result.name, result.level])
	return result
