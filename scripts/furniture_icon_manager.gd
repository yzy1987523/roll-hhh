extends Node2D

## 家具图标管理器
## 管理家具上方的解锁图标（星星+费用）

# 信号
signal icon_clicked(build_id: int)

# BuildConfig
var _build_loader: BuildConfigLoader = BuildConfigLoader.new()

func _ready() -> void:
	_build_loader.load_config()
	_refresh_all_icons()


## 刷新所有图标
func refresh_all() -> void:
	_refresh_all_icons()


func _refresh_all_icons() -> void:
	# 清除现有图标
	_clear_all_icons()

	var player_level: int = _get_player_level()
	var completed_ids: Array = _get_completed_build_ids()

	# 遍历 FurnitureRoot 下所有家具（FurnitureRoot 是兄弟节点，都在 RoomRoot 下）
	var furniture_root = get_node_or_null("../FurnitureRoot")
	if furniture_root == null:
		print(">>> [FurnitureIconManager] 找不到 FurnitureRoot")
		return
	print(">>> [FurnitureIconManager] _refresh_all_icons: player_level=%d, completed_ids=%s, furniture_children=%d" % [player_level, completed_ids, furniture_root.get_child_count()])

	for child in furniture_root.get_children():
		if not child.name.begins_with("Furniture_"):
			continue

		var idx_str = child.name.trim_prefix("Furniture_")
		var slot_index: int = idx_str.to_int()
		var build_id: int = slot_index + 1  # Furniture_0 -> build_id 1

		var config: Dictionary = _build_loader.get_build(build_id)
		if config.is_empty():
			continue

		# 新规则：前一个家具建完才解锁下一个，与等级无关
		var is_unlocked: bool
		if build_id == 1:
			is_unlocked = true  # 第一个家具始终解锁
		else:
			is_unlocked = completed_ids.has(float(build_id - 1))  # 前一个建完才解锁
		var is_completed: bool = completed_ids.has(float(build_id))
		print(">>> [FurnitureIconManager] build_id=%d, is_unlocked=%s, is_completed=%s" % [build_id, is_unlocked, is_completed])

		# 已完成的家具：显示并更新贴图
		if is_completed:
			_show_and_update_furniture(build_id, child, config)
		# 解锁了但未完成：显示图标
		elif is_unlocked and not is_completed:
			child.visible = false  # 隐藏未完成的家具
			_create_unlock_icon(build_id, child, config)
		else:
			# 未解锁：隐藏家具，不显示图标
			child.visible = false


func _show_and_update_furniture(_build_id: int, furniture: Node, _config: Dictionary) -> void:
	# 建造完成：只显示家具，贴图已在 tscn 中设置好
	furniture.visible = true


func _clear_all_icons() -> void:
	var icon_root = get_node_or_null("FurnitureIconRoot")
	if icon_root:
		for child in icon_root.get_children():
			child.queue_free()


func _create_unlock_icon(build_id: int, furniture: Node, config: Dictionary) -> void:
	print(">>> [FurnitureIconManager] _create_unlock_icon: build_id=%d" % build_id)
	var icon_root = get_node_or_null("FurnitureIconRoot")
	if icon_root == null:
		icon_root = Node2D.new()
		icon_root.name = "FurnitureIconRoot"
		icon_root.z_index = 2000
		add_child(icon_root)

	# Debug
	print(">>> [FurnitureIconManager] === 坐标调试 ===")
	print(">>> A: furniture=" + str(furniture))
	print(">>> A: icon_root=" + str(icon_root))
	print(">>> A: position=" + str(position))
	var furniture_global: Vector2 = furniture.get_global_position()
	var icon_root_global: Vector2 = icon_root.get_global_position()
	var local_pos: Vector2 = furniture_global - icon_root_global
	var btn_pos: Vector2 = local_pos + Vector2(-40, -80)
	print(">>> B: furniture_global=" + str(furniture_global))
	print(">>> B: icon_root_global=" + str(icon_root_global))
	print(">>> B: btn_pos=" + str(btn_pos))

	# Button
	var btn = Button.new()
	btn.name = "UnlockIcon_%d" % build_id
	btn.custom_minimum_size = Vector2(80, 40)
	btn.size = btn.custom_minimum_size
	btn.position = btn_pos
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(1, 0.8, 0, 1)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.35, 0.35, 0.35, 0.95)
	style_hover.corner_radius_top_left = 8
	style_hover.corner_radius_top_right = 8
	style_hover.corner_radius_bottom_left = 8
	style_hover.corner_radius_bottom_right = 8
	style_hover.border_width_left = 2
	style_hover.border_width_top = 2
	style_hover.border_width_right = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = Color(1, 0.9, 0.2, 1)
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.4, 0.4, 0.2, 0.95)
	style_pressed.corner_radius_top_left = 8
	style_pressed.corner_radius_top_right = 8
	style_pressed.corner_radius_bottom_left = 8
	style_pressed.corner_radius_bottom_right = 8
	style_pressed.border_width_left = 2
	style_pressed.border_width_top = 2
	style_pressed.border_width_right = 2
	style_pressed.border_width_bottom = 2
	style_pressed.border_color = Color(0.8, 0.7, 0.2, 1)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	btn.pressed.connect(_on_icon_pressed.bind(build_id))
	print(">>> [FurnitureIconManager] icon position=%s, size=%s" % [btn.position, btn.size])
	icon_root.add_child(btn)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 4)
	btn.add_child(hbox)

	var star_icon = TextureRect.new()
	star_icon.custom_minimum_size = Vector2(24, 24)
	star_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	star_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var star_tex_path = "res://art/sprites/UI/icon/star.png"
	if ResourceLoader.exists(star_tex_path):
		star_icon.texture = load(star_tex_path)
	hbox.add_child(star_icon)

	var cost_label = Label.new()
	cost_label.text = str(config.get("starCost", 0))
	cost_label.add_theme_font_size_override("font_size", 20)
	cost_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	hbox.add_child(cost_label)


# Button 点击处理
func _on_icon_pressed(build_id: int) -> void:
	print(">>> [FurnitureIconManager] _on_icon_pressed: build_id=%d" % build_id)
	icon_clicked.emit(build_id)

# 全局输入检测 - 通过 _input 方法检测点击
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var icon_root = get_node_or_null("FurnitureIconRoot")
		if icon_root == null:
			return
		for icon in icon_root.get_children():
			if icon is Control:
				var icon_rect = Rect2(icon.global_position, icon.size)
				var mouse_pos = icon.get_global_mouse_position()
				print(">>> [FurnitureIconManager] _input check: icon=%s, rect=%s, mouse=%s, contains=%s" % [icon.name, icon_rect, mouse_pos, icon_rect.has_point(mouse_pos)])
				if icon_rect.has_point(mouse_pos):
					var bid_str = icon.name.trim_prefix("UnlockIcon_")
					var bid = bid_str.to_int()
					print(">>> [FurnitureIconManager] 点击了图标! build_id=%d" % bid)
					icon_clicked.emit(bid)
					break


## 获取玩家等级
func _get_player_level() -> int:
	return TaskManager.get_level()


## 获取已完成的建造ID列表
func _get_completed_build_ids() -> Array:
	return TaskManager.get_completed_build_ids()
