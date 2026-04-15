extends Node2D

# ================================= 动画配置 =================================
@export var frames: Array[Texture2D] = []
@export var frame_interval: float = 0.4  # 每帧间隔秒数

# ================================= 移动配置 =================================
@export var move_speed: float = 2.0  # 移动速度（格子/秒）
@export var move_interval: float = 1.0  # 移动间隔（秒）

# ================================= 节点引用 =================================
var sprite: Sprite2D
var grid_manager: Node2D

# ================================= 状态变量 =================================
var _current_grid: Vector2i = Vector2i(5, 4)
var _target_grid: Vector2i = Vector2i(5, 4)
var _is_moving: bool = false
var _animation_timer: float = 0.0
var _current_frame: int = 0
var _move_tween: Tween

# ================================= 计时器 =================================
var _move_timer: float = 0.0

# ================================= 格子尺寸（需与 GridManager 一致）=======================
var _cell_size: Vector2 = Vector2(128, 64)

func _ready():
	print(">>> [Character2D] _ready 开始初始化")
	_init_sprite()
	_init_position()
	_init_grid_manager()
	_move_timer = move_interval  # 首次等待时间
	print(">>> [Character2D] 初始化完成，初始位置: %s" % [_current_grid])

# ================================= 初始化精灵 =================================
func _init_sprite():
	sprite = Sprite2D.new()
	sprite.name = "CharacterSprite"
	add_child(sprite)

	# 设置第一帧纹理
	if frames.size() > 0 and frames[0] != null:
		sprite.texture = frames[0]
		print(">>> [Character2D] 帧0 纹理: %s, size=%s" % [sprite.texture.resource_path, sprite.texture.get_size()])
	else:
		print(">>> [Character2D] 警告: frames[0] 为 null")

	sprite.flip_h = false  # 默认朝左
	_refresh_z_index()
	print(">>> [Character2D] sprite.texture: %s" % sprite.texture)

# ================================= 初始化位置 =================================
func _init_position():
	position = _grid_to_world(_current_grid)
	_refresh_z_index()
	print(">>> [Character2D] 位置: %s, z_index: %d, sprite.visible: %s" % [position, sprite.z_index, sprite.visible])

# ================================= 初始化网格管理器引用 =================================
func _init_grid_manager():
	grid_manager = get_node_or_null("../GridManager")
	if grid_manager == null:
		print(">>> [Character2D] 警告: 未找到 GridManager，纯客户端移动")
	else:
		print(">>> [Character2D] 已绑定 GridManager")

# ================================= 每帧更新 =================================
func _process(delta):
	_update_timer(delta)
	_update_animation(delta)
	_update_z_index()

# ================================= 计时器更新 =================================
func _update_timer(delta: float):
	if _is_moving:
		return

	_move_timer += delta
	if _move_timer >= move_interval:
		_move_timer = 0.0
		_try_move_to_random_neighbor()

# ================================= 动画更新 =================================
func _update_animation(delta: float):
	if frames.size() <= 1:
		return

	# 只有在移动时才更新帧
	if not _is_moving:
		return

	_animation_timer += delta
	if _animation_timer >= frame_interval:
		_animation_timer = 0.0
		_current_frame = (_current_frame + 1) % frames.size()
		sprite.texture = frames[_current_frame]

# ================================= 动态 Z 轴更新 =================================
func _update_z_index():
	var base_z: int = 100
	var dynamic_z: int = int(position.y) + base_z
	sprite.z_index = dynamic_z

# ================================= 尝试随机移动 =================================
func _try_move_to_random_neighbor():
	# 四个方向：右、下、左、上（菱形网格的相邻格子）
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),   # 右（gx+1, gy）
		Vector2i(0, 1),   # 下（gx, gy+1）
		Vector2i(-1, 0), # 左（gx-1, gy）
		Vector2i(0, -1)  # 上（gx, gy-1）
	]
	directions.shuffle()

	for d in directions:
		var next_grid = _current_grid + d
		if _can_move_to(next_grid):
			_move_to_grid(next_grid, d)
			return

# ================================= 移动能力检查 =================================
func _can_move_to(grid: Vector2i) -> bool:
	# 地图边界检查（与 GridManager 的 map_width=10, map_height=8 一致）
	if grid.x < 1 or grid.x > 9 or grid.y < 1 or grid.y > 7:
		return false

	# 检查家具占用
	if grid_manager != null:
		var occupied = grid_manager.get("grid_occupied")
		if occupied != null and occupied.size() > grid.y:
			if occupied[grid.y].size() > grid.x:
				if occupied[grid.y][grid.x] == true:
					return false
	return true

# ================================= 移动到目标格子 =================================
func _move_to_grid(target: Vector2i, direction: Vector2i):
	_is_moving = true
	_target_grid = target

	# 根据移动方向设置朝向
	_update_facing(direction)

	var end_pos = _grid_to_world(target)
	var duration = 1.0 / move_speed

	_move_tween = create_tween()
	_move_tween.set_parallel(true)
	_move_tween.tween_property(self, "position", end_pos, duration)
	_move_tween.finished.connect(_on_move_finished)

# ================================= 根据移动方向更新朝向 =================================
func _update_facing(direction: Vector2i):
	if direction == Vector2i(0, -1) or direction == Vector2i(1, 0):
		sprite.flip_h = true
	else:
		sprite.flip_h = false

# ================================= 移动完成回调 =================================
func _on_move_finished():
	_current_grid = _target_grid
	_is_moving = false
	_current_frame = 0
	sprite.texture = frames[_current_frame] if frames.size() > 0 else null
	_refresh_z_index()

# ================================= 刷新 z_index（深度排序）=================================
func _refresh_z_index():
	_update_z_index()

# ================================= 坐标转换：格子 -> 世界坐标 =================================
func _grid_to_world(grid: Vector2i) -> Vector2:
	var half_w = _cell_size.x * 0.5
	var half_h = _cell_size.y * 0.5
	var wx = (grid.x - grid.y) * half_w
	var wy = (grid.x + grid.y) * half_h
	return Vector2(wx, wy)
