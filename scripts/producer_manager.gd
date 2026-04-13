extends Node

## 生产器时间管理器 (Autoload 单例)
## 统一管理所有生成器的库存恢复和冷却时间
## 使用 BatchUpdate 优化方式批量处理

const ICL = preload("res://scripts/item_config_loader.gd")
const DM = preload("res://scripts/data_models.gd")

# ---- 配置 ----
const BATCH_UPDATE_INTERVAL: float = 0.1  # 批量更新间隔（秒）
const RECOVERY_BATCH_SIZE: int = 1  # 每次恢复1个库存

# ---- 生成器状态数据类 ----
class ProducerState:
	var board_index: int = -1      # 棋盘索引
	var item_id: int = 0            # 物品配置ID
	var current_count: int = 0      # 当前库存
	var max_count: int = 0          # 最大库存
	var recovery_time: float = 0.0  # 恢复1个库存所需时间（秒）
	var cooldown_time: float = 0.0  # 冷却时间（秒）
	var cooldown_remaining: float = 0.0  # 剩余冷却时间（秒）
	var last_recovery_time: float = 0.0  # 上次恢复库存的时间（秒，绝对时间）

	func _to_string() -> String:
		return "ProducerState(board=%d, id=%d, count=%d/%d, cd=%.1f)" % [board_index, item_id, current_count, max_count, cooldown_remaining]

# ---- 状态存储 ----
var _producers: Dictionary = {}  # board_index -> ProducerState
var _last_batch_time: float = 0.0
var _config_loader: ItemConfigLoader = ItemConfigLoader.new()

# ---- 信号 ----
signal stock_changed(board_index: int, current_count: int, max_count: int)
signal cooldown_started(board_index: int, cooldown_duration: float)
signal cooldown_finished(board_index: int)
signal producer_registered(board_index: int, state: ProducerState)
signal producer_unregistered(board_index: int)

func _ready() -> void:
	_config_loader.load_config()
	print(">>> [ProducerManager] 生成器时间管理器已初始化")


func _process(delta: float) -> void:
	_last_batch_time += delta
	if _last_batch_time >= BATCH_UPDATE_INTERVAL:
		_last_batch_time -= BATCH_UPDATE_INTERVAL
		_batch_update(BATCH_UPDATE_INTERVAL)


# ---- 批量更新 ----
func _batch_update(delta: float) -> void:
	if _producers.is_empty():
		return

	var states_to_update: Array = []
	for board_index in _producers:
		states_to_update.append(_producers[board_index])

	for state in states_to_update:
		_update_single_producer(state, delta * RECOVERY_BATCH_SIZE)


# ---- 更新单个生成器 ----
func _update_single_producer(state: ProducerState, delta: float) -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0

	# 处理冷却时间（使用 delta 递减）
	if state.cooldown_remaining > 0:
		state.cooldown_remaining -= delta
		if state.cooldown_remaining <= 0:
			state.cooldown_remaining = 0.0
			cooldown_finished.emit(state.board_index)
			# 冷却结束时不重置 last_recovery_time，恢复继续

	# 处理库存恢复（库存没满就执行，冷却期间也执行）
	# recovery_time: 每恢复1个库存需要的时间（秒）
	# 库存耗尽后开始恢复计时，每 recovery_time 秒恢复1个
	if state.current_count < state.max_count:
		var elapsed: float = current_time - state.last_recovery_time
		var recovered: int = int(elapsed / state.recovery_time)
		if recovered > 0:
			state.current_count = mini(state.current_count + recovered, state.max_count)
			# 更新时间点（余数用于下次计算）
			state.last_recovery_time = current_time - (elapsed - float(recovered) * state.recovery_time)
			stock_changed.emit(state.board_index, state.current_count, state.max_count)


# ---- 注册生成器 ----
func register_producer(board_index: int, item_id: int) -> bool:
	# 检查是否已经是生成器
	if _producers.has(board_index):
		print(">>> [ProducerManager] 警告: 位置 %d 已是生成器" % board_index)
		return false

	# 获取物品配置
	var cfg: Dictionary = _config_loader.get_item(item_id)
	if cfg.is_empty():
		print(">>> [ProducerManager] 注册失败: 找不到物品配置 id=%d" % item_id)
		return false

	var item_type: String = cfg.get("type", "")
	if item_type != "production" and item_type != "maxproduction":
		print(">>> [ProducerManager] 注册失败: 物品 %d 不是生成器类型 (type=%s)" % [item_id, item_type])
		return false

	var state := ProducerState.new()
	state.board_index = board_index
	state.item_id = item_id
	state.max_count = cfg.get("maxCount", 20)
	state.current_count = state.max_count  # 初始满库存
	state.recovery_time = cfg.get("recovery_time", 60.0)
	state.cooldown_time = cfg.get("cooldown_time", 120.0)
	state.cooldown_remaining = 0.0
	state.last_recovery_time = Time.get_ticks_msec() / 1000.0

	_producers[board_index] = state
	producer_registered.emit(board_index, state)
	print(">>> [ProducerManager] 注册生成器: board=%d, item=%d, maxCount=%d, recovery=%.1fs, cooldown=%.1fs" % [board_index, item_id, state.max_count, state.recovery_time, state.cooldown_time])
	return true


# ---- 注销生成器 ----
func unregister_producer(board_index: int) -> bool:
	if not _producers.has(board_index):
		return false
	_producers.erase(board_index)
	producer_unregistered.emit(board_index)
	print(">>> [ProducerManager] 注销生成器: board=%d" % board_index)
	return true


# ---- 移动生成器到新位置 ----
func move_producer(from_index: int, to_index: int) -> bool:
	if not _producers.has(from_index):
		return false
	if _producers.has(to_index):
		print(">>> [ProducerManager] 移动失败: 目标位置 %d 已是生成器" % to_index)
		return false

	var state: ProducerState = _producers[from_index]
	_producers.erase(from_index)
	state.board_index = to_index
	_producers[to_index] = state
	producer_unregistered.emit(from_index)
	producer_registered.emit(to_index, state)
	print(">>> [ProducerManager] 移动生成器: %d -> %d" % [from_index, to_index])
	return true


# ---- 交换两个生成器的位置 ----
func swap_producer(index_a: int, index_b: int) -> bool:
	if not _producers.has(index_a) or not _producers.has(index_b):
		return false

	var state_a: ProducerState = _producers[index_a]
	var state_b: ProducerState = _producers[index_b]
	_producers.erase(index_a)
	_producers.erase(index_b)
	state_a.board_index = index_b
	state_b.board_index = index_a
	_producers[index_b] = state_a
	_producers[index_a] = state_b
	producer_unregistered.emit(index_a)
	producer_unregistered.emit(index_b)
	producer_registered.emit(index_a, state_b)
	producer_registered.emit(index_b, state_a)
	print(">>> [ProducerManager] 交换生成器: %d <-> %d" % [index_a, index_b])
	return true


# ---- 消耗库存 ----
func consume_stock(board_index: int) -> bool:
	if not _producers.has(board_index):
		return false

	var state: ProducerState = _producers[board_index]
	if state.current_count <= 0:
		# 进入冷却
		state.cooldown_remaining = state.cooldown_time
		cooldown_started.emit(board_index, state.cooldown_time)
		print(">>> [ProducerManager] 库存耗尽，进入冷却: board=%d, cooldown=%.1fs" % [board_index, state.cooldown_time])
		return false

	state.current_count -= 1
	stock_changed.emit(board_index, state.current_count, state.max_count)

	if state.current_count <= 0:
		state.cooldown_remaining = state.cooldown_time
		cooldown_started.emit(board_index, state.cooldown_time)
		print(">>> [ProducerManager] 库存耗尽，进入冷却: board=%d, cooldown=%.1fs" % [board_index, state.cooldown_time])

	return true


# ---- 获取当前库存 ----
func get_stock(board_index: int) -> int:
	if not _producers.has(board_index):
		return 0
	return _producers[board_index].current_count


# ---- 获取最大库存 ----
func get_max_stock(board_index: int) -> int:
	if not _producers.has(board_index):
		return 0
	return _producers[board_index].max_count


# ---- 是否在冷却中 ----
func is_in_cooldown(board_index: int) -> bool:
	if not _producers.has(board_index):
		return false
	return _producers[board_index].cooldown_remaining > 0


# ---- 获取剩余冷却时间 ----
func get_cooldown_remaining(board_index: int) -> float:
	if not _producers.has(board_index):
		return 0.0
	return _producers[board_index].cooldown_remaining


# ---- 获取冷却总时间 ----
func get_cooldown_total(board_index: int) -> float:
	if not _producers.has(board_index):
		return 0.0
	return _producers[board_index].cooldown_time


# ---- 是否是生成器 ----
func is_producer(board_index: int) -> bool:
	return _producers.has(board_index)


# ---- 获取生成器状态 ----
func get_producer_state(board_index: int) -> ProducerState:
	return _producers.get(board_index, null)


# ---- 获取所有生成器 ----
func get_all_producers() -> Dictionary:
	return _producers.duplicate()


# ---- 检查是否可以生产 ----
func can_produce(board_index: int) -> bool:
	if not _producers.has(board_index):
		return false
	var state: ProducerState = _producers[board_index]
	return state.cooldown_remaining <= 0 and state.current_count > 0
