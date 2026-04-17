extends Node2D

# ================================= 动画配置 =================================
@export var frames: Array[Texture2D] = []
@export var frame_interval: float = 0.4  # 每帧间隔秒数

# ================================= 移动配置 =================================
@export var move_speed: float = 2.0  # 移动速度（格子/秒）
@export var move_interval: float = 1.0  # 移动间隔（秒）
@export var initial_grid: Vector2i = Vector2i(2, 2)  # 初始格子位置

# ================================= 节点引用 =================================
var sprite: Sprite2D
var grid_manager: Node2D

# ================================= 状态变量 =================================
var _current_grid: Vector2i = Vector2i(2, 2)
var _target_grid: Vector2i = Vector2i(2, 2)
var _is_moving: bool = false
var _animation_timer: float = 0.0
var _current_frame: int = 0
var _move_tween: Tween

# ================================= 计时器 =================================
var _move_timer: float = 0.0

# ================================= 地板范围（基于 Floor_0_0 的实际世界坐标）=======================
# Floor_0_0 position = (-97, 26), polygon 点: (-7,-38),(321,147),(-11,336),(-337,148)
# 转换为世界坐标后的菱形多边形
var _floor_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(-97 + -7, 26 + -38),    # 顶 (-104, -12)
	Vector2(-97 + 321, 26 + 147),   # 右 (224, 173)
	Vector2(-97 + -11, 26 + 336),   # 底 (-108, 362)
	Vector2(-97 + -337, 26 + 148)   # 左 (-434, 174)
])

func _is_point_on_floor(world_pos: Vector2) -> bool:
	# 使用实际地板多边形做精确检测（菱形，而非矩形）
	return Geometry2D.is_point_in_polygon(world_pos, _floor_polygon)

func _ready():
	_init_sprite()
	_init_position()
	_init_grid_manager()
	_move_timer = move_interval  # 首次等待时间
	print(">>> [Character2D] 使用多边形地板边界检测，顶点数=%d" % _floor_polygon.size())

# ================================= 格子尺寸（需与 GridManager 一致）=======================
var _cell_size: Vector2 = Vector2(128, 64)

# ================================= 初始化精灵 =================================
func _init_sprite():
	sprite = Sprite2D.new()
	sprite.name = "CharacterSprite"
	add_child(sprite)

	# 设置第一帧纹理
	if frames.size() > 0 and frames[0] != null:
		sprite.texture = frames[0]

	sprite.flip_h = false  # 默认朝左
	sprite.scale = Vector2(0.4, 0.4)  # 缩放 0.4 倍
	_refresh_z_index()

# ================================= 初始化位置 =================================
func _init_position():
	_current_grid = initial_grid
	_target_grid = initial_grid
	position = _grid_to_world(_current_grid)
	_refresh_z_index()

# ================================= 初始化网格管理器引用 =================================
func _init_grid_manager():
	grid_manager = get_node_or_null("../GridManager")

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
	# 设置在角色节点上，与家具共用 Y 坐标排序（Y 越大越靠前）
	z_index = int(position.y)

# ================================= 尝试随机移动 =================================
func _try_move_to_random_neighbor():
	# 随机化下次移动间隔（0.8 ~ 1.5秒）
	move_interval = randf_range(0.8, 1.5)

	# 收集其他角色当前和目标格子位置，避免重叠
	var occupied_by_chars: Array[Vector2i] = _get_other_character_positions()

	# 四个方向：右、下、左、上（菱形网格的相邻格子）
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),   # 右（gx+1, gy）
		Vector2i(0, 1),   # 下（gx, gy+1）
		Vector2i(-1, 0), # 左（gx-1, gy）
		Vector2i(0, -1)  # 上（gx, gy-1）
	]
	directions.shuffle()

	for d in directions:
		# 完全随机移动距离 1-3 格
		var steps_to_try: Array[int] = [1, 2, 3]
		steps_to_try.shuffle()
		for step in steps_to_try:
			var candidate: Vector2i = _current_grid + d * step
			# 检查目标是否被其他角色占用
			if candidate in occupied_by_chars:
				continue
			# 检查路径上所有格子是否可通行
			var path_clear: bool = true
			for s in range(1, step + 1):
				var check_grid: Vector2i = _current_grid + d * s
				if not _can_move_to(check_grid):
					path_clear = false
					break
				# 检查路径上是否有家具阻挡
				var blocked_grid = _get_path_blocked_by_furniture(_current_grid, check_grid)
				if blocked_grid.x != -999:
					path_clear = false
					break
			if path_clear:
				_move_to_grid(candidate, d)
				return


# ================================= 获取其他角色的当前位置和目标位置 =================================
func _get_other_character_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var parent_node = get_parent()
	if parent_node == null:
		return positions
	for child in parent_node.get_children():
		if child == self:
			continue
		if not child.name.begins_with("CharacterRoot"):
			continue
		if not child is Node2D:
			continue
		# 获取目标格子（移动中的角色）和当前格子
		var target = child.get("_target_grid")
		if target != null:
			positions.append(target as Vector2i)
		var current = child.get("_current_grid")
		if current != null and current != target:
			positions.append(current as Vector2i)
	return positions

# ================================= 移动能力检查 =================================
func _can_move_to(grid: Vector2i) -> bool:
	# 检查目标世界坐标是否在地板范围内
	var world_pos = _grid_to_world(grid)
	var in_floor = _is_point_on_floor(world_pos)
	if not in_floor:
		return false

	# 地图边界检查
	if grid.x < 1 or grid.x > 9 or grid.y < 1 or grid.y > 7:
		return false

	# 检查家具占用（grid_occupied）
	if grid_manager != null:
		var occupied = grid_manager.get("grid_occupied")
		if occupied != null and occupied.size() > grid.y:
			if occupied[grid.y].size() > grid.x:
				if occupied[grid.y][grid.x] == true:
					return false

	# 检查是否与可见家具的视觉中心过近（距离阻挡）
	if _is_blocked_by_visible_furniture(world_pos):
		return false

	return true

# ================================= 检查目标点是否被可见家具阻挡 =================================
func _is_blocked_by_visible_furniture(world_pos: Vector2) -> bool:
	var furniture_root_node = get_node_or_null("../FurnitureRoot")
	if furniture_root_node == null:
		return false
	var threshold: float = 50.0  # 家具视觉中心的阻挡半径
	for fur in furniture_root_node.get_children():
		if not fur.visible:
			continue
		if fur is Polygon2D:
			var visual_center = _get_polygon_visual_center(fur)
			if world_pos.distance_to(visual_center) < threshold:
				return true
	return false

# ================================= 获取 Polygon2D 的视觉中心（世界坐标）=================================
func _get_polygon_visual_center(poly: Polygon2D) -> Vector2:
	var points = poly.polygon
	if points.size() == 0:
		return poly.global_position
	var center = Vector2.ZERO
	for p in points:
		center += p
	center /= points.size()
	return poly.global_position + center

# ================================= 点是否在多边形内 =================================
func _is_point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	# 使用Godot的Geometry2D.is_point_in_polygon
	return Geometry2D.is_point_in_polygon(point, polygon)

# ================================= 检测路径上的家具阻挡 =================================
func _get_path_blocked_by_furniture(from: Vector2i, to: Vector2i) -> Vector2i:
	"""检测从from到to的路径上是否有家具，返回第一个遇到家具的格子，没有则返回null"""
	var dir: Vector2i = to - from
	# 确保是相邻格子
	if dir.x != 0 and dir.y != 0:
		return Vector2i(-999, -999)  # 非相邻格子不算阻挡

	var step: Vector2i = Vector2i(sign(dir.x), sign(dir.y))
	var current: Vector2i = from + step
	var threshold_dist: float = 60.0  # 家具检测距离阈值

	while current != to:
		if _has_furniture_near(current, threshold_dist):
			return current
		current += step

	return Vector2i(-999, -999)  # 没有阻挡

# ================================= 检查指定格子附近是否有家具 =================================
func _has_furniture_near(grid: Vector2i, threshold: float) -> bool:
	var world_pos = _grid_to_world(grid)
	# 遍历 FurnitureRoot 下的所有家具
	var furniture_root = get_node_or_null("../FurnitureRoot")
	if furniture_root == null:
		return false
	for fur in furniture_root.get_children():
		if fur is Node2D:
			var dist = world_pos.distance_to(fur.global_position)
			if dist < threshold:
				return true
	return false

# ================================= 移动到目标格子 =================================
func _move_to_grid(target: Vector2i, direction: Vector2i):
	_is_moving = true
	_target_grid = target

	# 根据移动方向设置朝向
	_update_facing(direction)

	var end_pos = _grid_to_world(target)
	var steps: int = maxi(absi(target.x - _current_grid.x), absi(target.y - _current_grid.y))
	var duration = float(steps) / move_speed

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
