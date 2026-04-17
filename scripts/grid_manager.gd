extends Node2D

# ================================= 基础配置 =================================
@export var cell_size: Vector2 = Vector2(128, 64)
@export var map_width: int = 10
@export var map_height: int = 8

# 颜色配置
@export var floor_color: Color = Color(0.28, 0.24, 0.20)
@export var highlight_color: Color = Color(0.3, 1.0, 0.3, 0.4)
@export var occupy_color: Color = Color(0.9, 0.3, 0.3, 0.5)

# 墙体配置
@export var wall_thickness: int = 32
@export var wall_color_back: Color = Color(0.6, 0.55, 0.5)
@export var wall_color_side: Color = Color(0.5, 0.45, 0.4)

# 删除功能配置
@export var can_delete: bool = true
@export var delete_key: Key = KEY_DELETE

# 建造/编辑模式配置
@export var is_edit_mode: bool = true  # 默认开启
@export var edit_mode_key: Key = KEY_TAB

# 占位图（运行时加载）
var _placeholder_tex: Texture2D = null

# ================================= 数据存储 =================================
var floor_list: Array = []
var preview_tile: Polygon2D = null
var grid_occupied: Array = []
var furniture_root: Node2D
var wall_root: Node2D
var selected_furniture: CanvasItem = null

# 建造配置
var build_config: Dictionary = {}

# UI节点
var build_popup: Control = null
var current_build_config: Dictionary = {}
var _confirm_btn: Button = null

# 信号：建造完成后通知 building_ui 播放特效
signal build_exp_reward(furniture_world_pos: Vector2, exp_amount: int, build_id: int)

# ================================= 获取占位图 =================================
func _get_placeholder_tex() -> Texture2D:
	if _placeholder_tex == null:
		var path = "res://art/building/b001.png"
		if ResourceLoader.exists(path):
			_placeholder_tex = load(path)
		else:
			_placeholder_tex = null
	return _placeholder_tex

# ================================= 初始化 =================================
func _ready():
	# 加载建造配置
	_load_build_config()

	# 初始化格子占用（必须最先初始化）
	grid_occupied = []
	for y in range(map_height):
		var row = []
		for x in range(map_width):
			row.append(false)
		grid_occupied.append(row)

	# 检查场景中是否已有静态地板/墙体（兄弟节点，不是子节点）
	var existing_floor_root = get_node_or_null("../FloorRoot")
	var existing_wall_root = get_node_or_null("../WallRoot")

	# 地板和墙已在 building.tscn 中静态定义，直接使用
	floor_list = []
	if existing_floor_root != null:
		for child in existing_floor_root.get_children():
			floor_list.append(child)
	wall_root = existing_wall_root

	# 初始化家具父节点（FurnitureRoot 是兄弟节点，不是子节点）
	furniture_root = get_node_or_null("../FurnitureRoot")
	if furniture_root == null:
		furniture_root = find_child("FurnitureRoot", true, false)
	if furniture_root == null:
		furniture_root = Node2D.new()
		furniture_root.name = "FurnitureRoot"
		get_parent().add_child(furniture_root)

	# 静态墙体边界锁定
	set_map_border_limit()

	# 连接家具图标管理器信号
	_connect_furniture_icon_signals()

# ================================= 连接家具图标信号 =================================
func _connect_furniture_icon_signals() -> void:
	# FurnitureIconManager 是 RoomRoot 的子节点，与 GridManager 是兄弟关系
	var icon_mgr = get_node_or_null("../FurnitureIconManager")
	if icon_mgr == null:
		return
	if icon_mgr.has_signal("icon_clicked"):
		icon_mgr.icon_clicked.connect(_on_furniture_icon_clicked)


func _on_furniture_icon_clicked(build_id: int) -> void:
	# 显示建造确认弹窗
	current_build_config = build_config.get(float(build_id), {})
	if not current_build_config.is_empty():
		_show_build_popup()

# ================================= 加载建造配置 =================================
func _load_build_config():
	var file = FileAccess.open("res://config/BuildConfig.json", FileAccess.READ)
	if file == null:
		print("ERROR: 无法加载BuildConfig.json")
		return

	var json = JSON.new()
	var result = json.parse(file.get_as_text())
	file.close()

	if result != OK:
		print("ERROR: JSON解析失败")
		return

	var data = json.get_data()
	if data.has("builds"):
		for item in data["builds"]:
			build_config[item["id"]] = item

# ================================= 创建建造面板 =================================
# ================================= 建造弹窗 =================================
func _show_build_popup():
	if build_popup != null:
		build_popup.queue_free()

	# 禁用家具图标按钮，防止点击穿透弹窗
	_set_furniture_icons_enabled(false)

	build_popup = PanelContainer.new()
	build_popup.name = "BuildPopup"
	build_popup.set_anchors_preset(Control.PRESET_CENTER)
	build_popup.position = Vector2(-350, -280)
	build_popup.size = Vector2(700, 560)
	build_popup.z_index = 3000

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.7, 0.4, 1)
	build_popup.add_theme_stylebox_override("panel", style)

	# 添加到 UILayer (CanvasLayer) 以统一坐标系统
	var ui_layer = get_node_or_null("../UILayer")
	if ui_layer != null:
		ui_layer.add_child(build_popup)
	else:
		add_child(build_popup)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size = Vector2(700, 560)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	build_popup.add_child(vbox)

	# 标题
	var title = Label.new()
	title.text = "建造确认"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	# 花费（用星星图标+数字）
	var cost_title = Label.new()
	cost_title.text = "花费"
	cost_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(cost_title)

	var cost_hbox = HBoxContainer.new()
	cost_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(cost_hbox)

	var star_icon = TextureRect.new()
	star_icon.custom_minimum_size = Vector2(48, 48)
	star_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	star_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star_icon.texture = load("res://art/sprites/UI/icon/star.png")
	cost_hbox.add_child(star_icon)

	var cost_num_label = Label.new()
	cost_num_label.text = " %d" % current_build_config.get("starCost", 0)
	cost_num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cost_num_label.add_theme_font_size_override("font_size", 36)
	cost_hbox.add_child(cost_num_label)

	# 奖励区域
	var reward_title = Label.new()
	reward_title.text = "获得奖励:"
	reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_title.add_theme_font_size_override("font_size", 32)
	reward_title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	vbox.add_child(reward_title)

	# 奖励内容容器
	var reward_hbox = HBoxContainer.new()
	reward_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(reward_hbox)

	# 经验奖励（用经验图标+数字）
	var exp_reward: int = current_build_config.get("expReward", 0)
	if exp_reward > 0:
		var exp_icon = TextureRect.new()
		exp_icon.custom_minimum_size = Vector2(48, 48)
		exp_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		exp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		exp_icon.texture = load("res://art/sprites/UI/icon/jingyan.png")
		reward_hbox.add_child(exp_icon)

		var exp_num_label = Label.new()
		exp_num_label.text = "+%d" % exp_reward
		exp_num_label.add_theme_font_size_override("font_size", 32)
		exp_num_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
		reward_hbox.add_child(exp_num_label)

	# 物品奖励图标
	var item_rewards: Array = current_build_config.get("itemReward", [])
	for item_id in item_rewards:
		var item_container = VBoxContainer.new()
		item_container.alignment = BoxContainer.ALIGNMENT_CENTER
		reward_hbox.add_child(item_container)

		var item_icon = TextureRect.new()
		item_icon.custom_minimum_size = Vector2(80, 80)
		item_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sprite_path: String = ItemManager.get_sprite_path(int(item_id))
		if sprite_path != "" and ResourceLoader.exists(sprite_path):
			item_icon.texture = load(sprite_path)
		item_container.add_child(item_icon)

	# 按钮容器
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_hbox)

	# 取消按钮
	var cancel_btn = Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(200, 80)
	cancel_btn.pressed.connect(_on_cancel_build)
	btn_hbox.add_child(cancel_btn)

	# 建造按钮
	var build_btn = Button.new()
	build_btn.text = "建造"
	build_btn.custom_minimum_size = Vector2(200, 80)
	build_btn.add_theme_color_override("bg_color", Color(0.4, 0.7, 0.3))
	build_btn.pressed.connect(_on_confirm_build)
	_confirm_btn = build_btn
	btn_hbox.add_child(build_btn)

func _on_cancel_build():
	SoundSystem.play_button_click()
	if build_popup != null:
		build_popup.queue_free()
		build_popup = null
		_confirm_btn = null
	# 恢复家具图标按钮
	_set_furniture_icons_enabled(true)

func _set_furniture_icons_enabled(enabled: bool) -> void:
	var icon_mgr = get_node_or_null("../FurnitureIconManager")
	if icon_mgr == null:
		return
	var icon_root = icon_mgr.find_child("FurnitureIconRoot", true, false)
	if icon_root == null:
		return
	for icon in icon_root.get_children():
		if icon is Control:
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE if not enabled else Control.MOUSE_FILTER_STOP

func _on_confirm_build():
	SoundSystem.play_button_click()
	var cost = current_build_config["starCost"]
	var stars = _get_player_stars()
	var build_id: int = current_build_config.get("id", 0)

	if stars < cost:
		TipManager.show_tip("星星不足，需要 %d 颗星星" % cost, 2.0)
		_on_cancel_build()
		return

	# 消耗星星（直接扣减）
	TaskManager.stars -= cost
	TaskManager.stars_changed.emit(TaskManager.stars)
	TaskManager.add_completed_build_id(build_id)

	# 刷新图标显示（隐藏已完成的图标，显示家具）
	_refresh_furniture_icons()

	# 推开家具附近的角色
	_push_characters_from_furniture(build_id)

	# 发放物品奖励
	var item_rewards: Array = current_build_config.get("itemReward", [])
	for item_id in item_rewards:
		GameManager.add_out_item(int(item_id))

	# 发射信号通知 building_ui 播放经验粒子特效
	var exp_reward: int = current_build_config.get("expReward", 0)
	if exp_reward > 0:
		# 使用确认按钮的屏幕坐标作为粒子起点
		var start_pos: Vector2 = _confirm_btn.global_position + Vector2(_confirm_btn.size.x / 2, _confirm_btn.size.y / 2)
		build_exp_reward.emit(start_pos, exp_reward, build_id)

	_on_cancel_build()


func _refresh_furniture_icons() -> void:
	var icon_mgr = get_node_or_null("../FurnitureIconManager")
	if icon_mgr and icon_mgr.has_method("refresh_all"):
		icon_mgr.refresh_all()

# ================================= 获取玩家数据 =================================
func _get_player_stars() -> int:
	return TaskManager.get_stars()

func _get_player_level() -> int:
	return TaskManager.get_level()

# ================================= 获取家具世界坐标 =================================
func get_furniture_world_pos(build_id: int) -> Vector2:
	var slot_index: int = build_id - 1
	var furniture_node = furniture_root.get_node_or_null("Furniture_%d" % slot_index)
	if furniture_node == null:
		return Vector2.ZERO
	if furniture_node is Polygon2D:
		var points = furniture_node.polygon
		var poly_center = Vector2.ZERO
		for p in points:
			poly_center += p
		if points.size() > 0:
			poly_center /= points.size()
		return furniture_node.global_position + poly_center
	return furniture_node.global_position

# ================================= 推开家具附近的角色 =================================
func _push_characters_from_furniture(build_id: int) -> void:
	var furniture_pos: Vector2 = get_furniture_world_pos(build_id)
	var push_threshold: float = 80.0

	# 查找所有 CharacterRoot 节点（与 GridManager 是兄弟关系）
	var parent_node = get_parent()
	if parent_node == null:
		return

	for child in parent_node.get_children():
		if not child.name.begins_with("CharacterRoot"):
			continue
		if not child is Node2D:
			continue

		var char_pos: Vector2 = child.global_position
		if char_pos.distance_to(furniture_pos) > push_threshold:
			continue

		# 角色太近了，推到一个随机有效的相邻格子
		var char_grid: Vector2i = world_to_grid(char_pos)
		var directions: Array[Vector2i] = [
			Vector2i(1, 0), Vector2i(0, 1),
			Vector2i(-1, 0), Vector2i(0, -1)
		]
		directions.shuffle()

		var pushed: bool = false
		for d in directions:
			var candidate: Vector2i = char_grid + d
			if is_in_map(candidate.x, candidate.y) and not grid_occupied[candidate.y][candidate.x]:
				var new_pos: Vector2 = grid_to_world(candidate.x, candidate.y)
				# 使用 tween 平滑移动
				var tween = create_tween()
				tween.tween_property(child, "position", new_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				# 更新角色内部状态
				if child.has_method("_on_move_finished"):
					child.set("_current_grid", candidate)
					child.set("_target_grid", candidate)
				pushed = true
				break
		if not pushed:
			pass  # 无法推开，周围没有空格子

# ================================= 核心：坐标转换 =================================
func grid_to_world(gx: int, gy: int) -> Vector2:
	var half_w = cell_size.x * 0.5
	var half_h = cell_size.y * 0.5
	var wx = (gx - gy) * half_w
	var wy = (gx + gy) * half_h
	return Vector2(wx, wy)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var half_w = cell_size.x * 0.5
	var half_h = cell_size.y * 0.5
	var gx = (world_pos.x / half_w + world_pos.y / half_h) * 0.5
	var gy = (world_pos.y / half_h - world_pos.x / half_w) * 0.5
	return Vector2i(round(gx), round(gy))

# ================================= 地板生成（菱形）=================================
func generate_isometric_grid():
	for gx in range(map_width):
		for gy in range(map_height):
			var floor_polygon = _create_diamond_floor(gx, gy)
			floor_list.append(floor_polygon)
			add_child(floor_polygon)

func _create_diamond_floor(gx: int, gy: int) -> Polygon2D:
	var polygon = Polygon2D.new()
	polygon.name = "Floor_%d_%d" % [gx, gy]

	# 菱形四个顶点：中心在上方和下方交替
	# 顶点在(0, -half_h)，底顶点在(0, +half_h)
	# 左顶点在(-half_w, 0)，右顶点在(+half_w, 0)
	var half_w = cell_size.x / 2
	var half_h = cell_size.y / 2
	var center = grid_to_world(gx, gy)

	# 菱形顶点：顶、右、底、左（顺时针）
	var points = [
		center + Vector2(0, -half_h),      # 顶点（上）
		center + Vector2(half_w, 0),       # 右
		center + Vector2(0, half_h),       # 底（下）
		center + Vector2(-half_w, 0)       # 左
	]
	polygon.polygon = PackedVector2Array(points)
	polygon.color = floor_color

	return polygon

func init_preview():
	preview_tile = Polygon2D.new()
	var half_w = cell_size.x / 2
	var half_h = cell_size.y / 2
	var points = [
		Vector2(0, -half_h),   # 顶点（上）
		Vector2(half_w, 0),     # 右
		Vector2(0, half_h),     # 底（下）
		Vector2(-half_w, 0)     # 左
	]
	preview_tile.polygon = PackedVector2Array(points)
	preview_tile.modulate = Color(1, 1, 1, 0.6)
	add_child(preview_tile)

# ================================= 墙体生成（Polygon2D方案：边缘与地面平行）=================================
func generate_room_walls():
	var half_w = cell_size.x / 2
	var half_h = cell_size.y / 2

	# 1. 后墙（地图最上沿 gy=0 整排的上边缘）
	# 地板菱形的上边缘：从顶点(0, -half_h)到左点(-half_w, 0)
	# 边缘方向向量：(−half_w, half_h)，即左下方向
	for gx in range(map_width):
		var center = grid_to_world(gx, 0)

		# 上边缘起点（格子顶点）和终点（左点）
		var edge_start = center + Vector2(0, -half_h)      # 顶点
		var edge_end = center + Vector2(-half_w, 0)         # 左点

		# 边缘向量和法向量（垂直于边缘，朝外）
		var edge_vec = edge_end - edge_start  # (−half_w, half_h)
		var normal = Vector2(-edge_vec.y, edge_vec.x).normalized()  # (half_h, half_w)/√(hw²+hh²)

		# 墙体多边形（4个顶点）：内边缘2点 + 外边缘2点
		var wall_polygon = [
			edge_start,                    # 内起点
			edge_end,                       # 内终点
			edge_end + normal * wall_thickness,    # 外终点
			edge_start + normal * wall_thickness    # 外起点
		]

		var wall = Polygon2D.new()
		wall.name = "BackWall_%d" % gx
		wall.polygon = PackedVector2Array(wall_polygon)
		wall.color = wall_color_back
		wall.z_index = 1000
		wall_root.add_child(wall)

	# 2. 左侧墙（地图最左列 gx=0 的左边缘）
	# 地板菱形的左边缘：从左点(-half_w, 0)到顶点(0, half_h)
	# 边缘方向向量：(half_w, half_h)，即右下方向
	for gy in range(map_height):
		var center = grid_to_world(0, gy)

		# 左边缘起点（左点）和终点（顶点）
		var edge_start = center + Vector2(-half_w, 0)     # 左点
		var edge_end = center + Vector2(0, half_h)         # 顶点

		# 边缘向量和法向量（垂直于边缘，朝外）
		var edge_vec = edge_end - edge_start  # (half_w, half_h)
		var normal = Vector2(-edge_vec.y, edge_vec.x).normalized()  # (−half_h, half_w)/√(...)

		# 墙体多边形
		var wall_polygon = [
			edge_start,
			edge_end,
			edge_end + normal * wall_thickness,
			edge_start + normal * wall_thickness
		]

		var wall = Polygon2D.new()
		wall.name = "LeftWall_%d" % gy
		wall.polygon = PackedVector2Array(wall_polygon)
		wall.color = wall_color_side
		wall.z_index = 999
		wall_root.add_child(wall)

	# 3. 右侧墙（地图最右列 gx=map_width-1 的右边缘）
	# 地板菱形的右边缘：从顶点(0, -half_h)到右点(half_w, 0)
	# 边缘方向向量：(half_w, half_h)，即右下方向
	for gy in range(map_height):
		var center = grid_to_world(map_width - 1, gy)

		# 右边缘起点（顶点）和终点（右点）
		var edge_start = center + Vector2(0, -half_h)     # 顶点
		var edge_end = center + Vector2(half_w, 0)           # 右点

		# 边缘向量和法向量（垂直于边缘，朝外）
		var edge_vec = edge_end - edge_start  # (half_w, half_h)
		var normal = Vector2(-edge_vec.y, edge_vec.x).normalized()  # (−half_h, half_w)/√(...)

		# 墙体多边形
		var wall_polygon = [
			edge_start,
			edge_end,
			edge_end + normal * wall_thickness,
			edge_start + normal * wall_thickness
		]

		var wall = Polygon2D.new()
		wall.name = "RightWall_%d" % gy
		wall.polygon = PackedVector2Array(wall_polygon)
		wall.color = wall_color_side
		wall.z_index = 999
		wall_root.add_child(wall)

	set_map_border_limit()

func set_map_border_limit():
	# 后墙行（gy=0）全部锁定
	for x in range(map_width):
		if grid_occupied.size() > 0 and grid_occupied[0].size() > x:
			grid_occupied[0][x] = true
	# 左右侧墙列（gx=0、gx=map_width-1）全部锁定
	for y in range(map_height):
		if grid_occupied.size() > y:
			grid_occupied[y][0] = true
			grid_occupied[y][map_width - 1] = true

# ================================= 每帧更新 =================================
func _process(_delta):
	refresh_furniture_sort()
	update_mouse_preview()

func update_mouse_preview():
	if preview_tile == null:
		return
	var mouse_g = world_to_grid(get_global_mouse_position())
	if is_in_map(mouse_g.x, mouse_g.y):
		preview_tile.visible = true
		preview_tile.position = grid_to_world(mouse_g.x, mouse_g.y)
		preview_tile.color = occupy_color if grid_occupied[mouse_g.y][mouse_g.x] else highlight_color
		preview_tile.modulate = Color(1, 1, 1, 0.6) if is_edit_mode else Color(0.5, 0.5, 0.5, 0.4)
	else:
		preview_tile.visible = false

func is_in_map(x: int, y: int) -> bool:
	return x >= 0 && y >= 0 && x < map_width && y < map_height

func refresh_furniture_sort():
	for item in furniture_root.get_children():
		if item is Polygon2D:
			# 使用多边形视觉中心的 Y 坐标排序（Y 越大越靠前，与角色 z_index 一致）
			var visual_center_y = get_furniture_visual_center_y(item)
			item.z_index = int(visual_center_y)
		elif item is CanvasItem:
			item.z_index = int(item.global_position.y)

# ================================= 获取家具视觉中心（世界坐标）=================================
func get_furniture_visual_center(poly: Polygon2D) -> Vector2:
	var points = poly.polygon
	if points.size() == 0:
		return poly.global_position
	var center = Vector2.ZERO
	for p in points:
		center += p
	center /= points.size()
	return poly.global_position + center

func get_furniture_visual_center_y(poly: Polygon2D) -> float:
	return get_furniture_visual_center(poly).y

# ================================= 模式控制 =================================
func toggle_edit_mode():
	is_edit_mode = !is_edit_mode
	if not is_edit_mode:
		selected_furniture = null

func can_operate() -> bool:
	return is_edit_mode

# ================================= 输入处理 =================================
func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == edit_mode_key:
		toggle_edit_mode()
		return

	if event is InputEventMouseButton and event.pressed:
		var mouse_g = world_to_grid(get_global_mouse_position())
		if not is_in_map(mouse_g.x, mouse_g.y):
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if not can_operate():
				return

			var click_fur = get_furniture_at_grid(mouse_g)
			if click_fur != null:
				selected_furniture = click_fur
				return
			if not grid_occupied[mouse_g.y][mouse_g.x]:
				spawn_furniture(mouse_g.x, mouse_g.y)

		if event.button_index == MOUSE_BUTTON_RIGHT:
			if not can_operate():
				return

			var click_fur = get_furniture_at_grid(mouse_g)
			if click_fur != null:
				delete_furniture(click_fur)
				selected_furniture = null
			else:
				selected_furniture = null

	if event is InputEventMouseMotion and selected_furniture != null:
		if not can_operate():
			return

		var mouse_g = world_to_grid(get_global_mouse_position())
		if is_in_map(mouse_g.x, mouse_g.y) and not grid_occupied[mouse_g.y][mouse_g.x]:
			clear_furniture_grid_occupy(selected_furniture)
			selected_furniture.position = grid_to_world(mouse_g.x, mouse_g.y)
			grid_occupied[mouse_g.y][mouse_g.x] = true

	if event is InputEventKey and event.pressed and event.keycode == delete_key:
		if not can_operate():
			return
		if selected_furniture != null:
			delete_furniture(selected_furniture)

# ================================= 家具操作 =================================
func spawn_furniture(gx: int, gy: int):
	var fur = ColorRect.new()
	fur.name = "Furniture"
	fur.size = Vector2(96, 96)
	fur.color = Color(0.7, 0.55, 0.4)
	fur.pivot_offset = Vector2(fur.size.x / 2, fur.size.y)
	fur.position = grid_to_world(gx, gy)
	furniture_root.add_child(fur)
	grid_occupied[gy][gx] = true
	return fur

func delete_furniture(fur: CanvasItem) -> void:
	if not can_delete:
		return
	clear_furniture_grid_occupy(fur)
	fur.queue_free()
	if selected_furniture == fur:
		selected_furniture = null

func clear_furniture_grid_occupy(fur: CanvasItem):
	var old_g = world_to_grid(fur.position)
	if is_in_map(old_g.x, old_g.y):
		grid_occupied[old_g.y][old_g.x] = false

func get_furniture_at_grid(target_g: Vector2i) -> CanvasItem:
	for fur in furniture_root.get_children():
		var g = world_to_grid(fur.position)
		if g == target_g:
			return fur
	return null
