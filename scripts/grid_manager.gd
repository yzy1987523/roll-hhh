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
var build_items: Array = []  # UI家具列表

# UI节点
var build_panel: Control = null
var build_popup: Control = null
var current_build_config: Dictionary = {}

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

	# 初始化父节点
	furniture_root = Node2D.new()
	furniture_root.name = "FurnitureRoot"
	add_child(furniture_root)

	wall_root = Node2D.new()
	wall_root.name = "WallRoot"
	add_child(wall_root)

	# 初始化格子占用
	grid_occupied = []
	for y in range(map_height):
		var row = []
		for x in range(map_width):
			row.append(false)
		grid_occupied.append(row)

	# 生成地图
	init_preview()
	generate_isometric_grid()
	generate_room_walls()

	# 创建UI
	_create_build_panel()

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
			print(">>> [GridManager] 加载建造配置: id=%d, name=%s, unlockLevel=%d" % [item["id"], item["name"], item["unlockLevel"]])

# ================================= 创建建造面板 =================================
func _create_build_panel():
	# 创建面板容器
	build_panel = PanelContainer.new()
	build_panel.name = "BuildPanel"
	build_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	build_panel.position = Vector2(-220, 10)
	build_panel.size = Vector2(210, 400)
	build_panel.z_index = 2000

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	build_panel.add_theme_stylebox_override("panel", style)

	add_child(build_panel)

	# 标题
	var title = Label.new()
	title.text = "建造列表"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position = Vector2(0, 5)
	title.size = Vector2(190, 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	build_panel.add_child(title)

	# 星星数量
	var stars_label = Label.new()
	stars_label.name = "StarsLabel"
	stars_label.text = "★ %d" % _get_player_stars()
	stars_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stars_label.position = Vector2(0, 30)
	stars_label.size = Vector2(190, 20)
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_panel.add_child(stars_label)

	# 滚动容器
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	scroll.position = Vector2(0, 55)
	scroll.size = Vector2(210, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	build_panel.add_child(scroll)

	# 家具列表容器
	var vbox = VBoxContainer.new()
	vbox.name = "FurnitureList"
	vbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	vbox.size = Vector2(190, 0)
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# 刷新家具列表
	_refresh_build_list()

func _refresh_build_list():
	var vbox = build_panel.get_node_or_null("Scroll/FurnitureList")
	if vbox == null:
		return

	# 清空现有
	for child in vbox.get_children():
		child.queue_free()

	# 刷新星星
	var stars_label = build_panel.get_node_or_null("StarsLabel")
	if stars_label:
		stars_label.text = "★ %d" % _get_player_stars()

	var player_level = _get_player_level()

	# 遍历所有建造配置
	for id in build_config.keys():
		var config = build_config[id]
		var is_unlocked = config["unlockLevel"] <= player_level

		var item = _create_furniture_item(config, is_unlocked)
		vbox.add_child(item)

func _create_furniture_item(config: Dictionary, is_unlocked: bool) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(190, 60)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.3, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# 家具图标
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(50, 50)
	icon.texture = _get_placeholder_tex()
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hbox.add_child(icon)

	# 名称和等级
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	name_label.text = config["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	var level_label = Label.new()
	level_label.text = "Lv.%d" % config["unlockLevel"]
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	level_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	level_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(level_label)

	# 未解锁时灰显
	if not is_unlocked:
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		icon.modulate = Color(0.5, 0.5, 0.5)

	hbox.add_child(vbox)

	# 星星费用（只有解锁了才显示可点击）
	if is_unlocked:
		var star_btn = Button.new()
		star_btn.custom_minimum_size = Vector2(50, 35)
		star_btn.text = "★ %d" % config["starCost"]
		star_btn.add_theme_color_override("font_color", Color(1, 0.8, 0))
		star_btn.add_theme_font_size_override("font_size", 16)
		star_btn.pressed.connect(_on_build_star_pressed.bind(config))
		hbox.add_child(star_btn)
	else:
		var lock = Label.new()
		lock.text = "🔒"
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(lock)

	return panel

func _on_build_star_pressed(config: Dictionary):
	current_build_config = config
	_show_build_popup()

# ================================= 建造弹窗 =================================
func _show_build_popup():
	if build_popup != null:
		build_popup.queue_free()

	build_popup = PanelContainer.new()
	build_popup.name = "BuildPopup"
	build_popup.set_anchors_preset(Control.PRESET_CENTER)
	build_popup.position = Vector2(-150, -100)
	build_popup.size = Vector2(300, 200)
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

	add_child(build_popup)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size = Vector2(300, 200)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 15)
	build_popup.add_child(vbox)

	# 标题
	var title = Label.new()
	title.text = "建造确认"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	# 描述
	var desc = Label.new()
	desc.text = "花费 ★%d 建造 %s" % [current_build_config["starCost"], current_build_config["name"]]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 16)
	vbox.add_child(desc)

	# 按钮容器
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_hbox)

	# 取消按钮
	var cancel_btn = Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(100, 40)
	cancel_btn.pressed.connect(_on_cancel_build)
	btn_hbox.add_child(cancel_btn)

	# 建造按钮
	var build_btn = Button.new()
	build_btn.text = "建造"
	build_btn.custom_minimum_size = Vector2(100, 40)
	build_btn.add_theme_color_override("bg_color", Color(0.4, 0.7, 0.3))
	build_btn.pressed.connect(_on_confirm_build)
	btn_hbox.add_child(build_btn)

func _on_cancel_build():
	if build_popup != null:
		build_popup.queue_free()
		build_popup = null

func _on_confirm_build():
	var cost = current_build_config["starCost"]
	var stars = _get_player_stars()

	if stars < cost:
		print(">>> [GridManager] 星星不足! 需要%d, 当前%d" % [cost, stars])
		_on_cancel_build()
		return

	# 消耗星星（通过TaskManager）
	TaskManager.add_stars(-cost)

	# 放置家具到棋盘
	_place_furniture_at_empty()

	# 刷新列表
	_refresh_build_list()
	_on_cancel_build()

# ================================= 获取玩家数据 =================================
func _get_player_stars() -> int:
	if TaskManager and TaskManager.has_method("get_stars"):
		return TaskManager.get_stars()
	return 0

func _get_player_level() -> int:
	if TaskManager and TaskManager.has_method("get_level"):
		return TaskManager.get_level()
	return 1

# ================================= 放置家具到空格子 =================================
func _place_furniture_at_empty():
	var placed = false
	for gy in range(1, map_height):  # 从第二行开始找
		for gx in range(1, map_width):
			if not grid_occupied[gy][gx]:
				_spawn_furniture_with_texture(gx, gy, current_build_config["furnitureId"])
				placed = true
				break
		if placed:
			break

	if not placed:
		print(">>> [GridManager] 棋盘已满!")

# ================================= 带纹理的家具生成 =================================
func _spawn_furniture_with_texture(gx: int, gy: int, furniture_id: int):
	var fur = Sprite2D.new()
	fur.name = "Furniture_%d" % furniture_id

	# 尝试加载对应家具纹理
	var tex_path = "res://art/building/%s.png" % str(furniture_id)
	var tex = load(tex_path) if ResourceLoader.exists(tex_path) else _get_placeholder_tex()
	fur.texture = tex

	fur.position = grid_to_world(gx, gy)
	fur.offset = Vector2(0, -fur.texture.get_size().y * 0.5)  # 底部对齐
	furniture_root.add_child(fur)
	grid_occupied[gy][gx] = true
	print(">>> [GridManager] 放置家具 id=%d at (%d,%d)" % [furniture_id, gx, gy])
	return fur

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

# ================================= 墙体生成（沿菱形边缘）=================================
func generate_room_walls():
	var half_w = cell_size.x / 2
	var half_h = cell_size.y / 2

	# 绘制右侧墙体 - 沿每个地板格子的右边缘
	# 右边缘：从顶点(0, -half_h)到右点(half_w, 0)
	# 墙体厚度方向：垂直于边缘，斜率为-dy/dx = -half_h/half_w = -H/W
	for gx in range(map_width):
		for gy in range(map_height):
			var center = grid_to_world(gx, gy)

			# 右边缘的起点和终点
			var edge_start = center + Vector2(0, -half_h)      # 顶点
			var edge_end = center + Vector2(half_w, 0)          # 右点

			# 边缘向量
			var edge_vec = edge_end - edge_start

			# 边缘的法向量（垂直于边缘）
			var normal = Vector2(-edge_vec.y, edge_vec.x).normalized()

			# 墙体的四个顶点
			var wall_polygon = [
				edge_start + normal * wall_thickness,
				edge_end + normal * wall_thickness,
				edge_end - normal * wall_thickness,
				edge_start - normal * wall_thickness
			]

			var right_wall = Polygon2D.new()
			right_wall.name = "RightWall_%d_%d" % [gx, gy]
			right_wall.polygon = PackedVector2Array(wall_polygon)
			right_wall.color = wall_color_side
			right_wall.z_index = 1000
			wall_root.add_child(right_wall)

	# 绘制顶部墙体 - 沿每个地板格子的上边缘
	# 上边缘：从顶点(0, -half_h)到左点(-half_w, 0)
	for gx in range(map_width):
		for gy in range(map_height):
			var center = grid_to_world(gx, gy)

			# 上边缘的起点和终点
			var edge_start = center + Vector2(0, -half_h)      # 顶点
			var edge_end = center + Vector2(-half_w, 0)         # 左点

			# 边缘向量
			var edge_vec = edge_end - edge_start

			# 边缘的法向量
			var normal = Vector2(-edge_vec.y, edge_vec.x).normalized()

			# 墙体的四个顶点
			var wall_polygon = [
				edge_start + normal * wall_thickness,
				edge_end + normal * wall_thickness,
				edge_end - normal * wall_thickness,
				edge_start - normal * wall_thickness
			]

			var top_wall = Polygon2D.new()
			top_wall.name = "TopWall_%d_%d" % [gx, gy]
			top_wall.polygon = PackedVector2Array(wall_polygon)
			top_wall.color = wall_color_back
			top_wall.z_index = 1001
			wall_root.add_child(top_wall)

	set_map_border_limit()

func set_map_border_limit():
	for x in range(map_width):
		grid_occupied[0][x] = true
	for y in range(map_height):
		grid_occupied[y][0] = true

# ================================= 每帧更新 =================================
func _process(_delta):
	refresh_furniture_sort()
	update_mouse_preview()

func update_mouse_preview():
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
		if item is CanvasItem:
			item.z_index = -int(item.global_position.y)

# ================================= 模式控制 =================================
func toggle_edit_mode():
	is_edit_mode = !is_edit_mode
	print(">>> [GridManager] 编辑模式: %s" % ("开启" if is_edit_mode else "关闭"))
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
