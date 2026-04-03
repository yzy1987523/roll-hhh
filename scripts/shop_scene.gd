extends Control

## 商店系统
## 上下分区显示道具和遗物，图片+价格布局，点击调用弹窗
## 改进版：商品图片、256尺寸、窗口模式、遮罩、close按钮、cell_0背景、售完移除、回合刷新

const SHOP_SLOTS := 6  # 每次刷新6个商品
const REFRESH_COST := 10  # 手动刷新费用
const ITEM_SIZE := 200  # 商品尺寸
const ITEM_SPACING := 30  # 商品间隔

var shop_items: Array = []   # 当前商品列表

# 节点引用
@onready var gold_label: Label = $ShopWindow/VBox/TitleBar/GoldLabel
@onready var item_container: HFlowContainer = $ShopWindow/VBox/ItemSection/ItemContainer
@onready var relic_container: HFlowContainer = $ShopWindow/VBox/RelicSection/RelicContainer
@onready var close_button: TextureButton = $ShopWindow/VBox/TitleBar/CloseButton

# 预加载纹理
const CELL_TEXTURE := preload("res://art/sprites/UI/items/smallItem/cell_0.png")
const CHECK_TEXTURE := preload("res://art/sprites/UI/items/smallItem/check.png")
const CLOSE_TEXTURE := preload("res://art/sprites/UI/items/smallItem/close.png")


func _ready() -> void:
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.round_changed.connect(_on_round_changed)
	_update_gold()

	# 设置关闭按钮纹理
	if close_button:
		close_button.texture_normal = CLOSE_TEXTURE
		close_button.pressed.connect(_on_close_pressed)

	# 连接刷新按钮
	var refresh_btn: Button = $ShopWindow/VBox/BottomBar/RefreshButton
	if refresh_btn:
		refresh_btn.pressed.connect(_on_refresh_pressed)

	# 初始打开商店时刷新
	_refresh_shop()
	print(">>> [Shop] 商店已打开")


func _on_round_changed(new_round: int) -> void:
	# 只在新回合开始时刷新商店
	_refresh_shop()
	print(">>> [Shop] 回合 %d 开始，商店已刷新" % new_round)


func _refresh_shop() -> void:
	shop_items.clear()

	# 从道具库和遗物库随机抽取
	var all_consumables: Array = ItemDatabase.get_all_consumables()
	var all_relics: Array = ItemDatabase.get_all_relics()

	# 过滤已拥有的唯一遗物
	var available_relics: Array = []
	for r in all_relics:
		if r.stackable or not ItemDatabase.has_relic(r.id, GameManager.relics):
			if r.price > 0:
				available_relics.append(r)

	all_consumables.shuffle()
	available_relics.shuffle()

	# 道具和遗物各取一些
	var item_count := mini(SHOP_SLOTS / 2, all_consumables.size())
	var relic_count := mini(SHOP_SLOTS - item_count, available_relics.size())

	for i in range(item_count):
		shop_items.append({"item": all_consumables[i], "is_relic": false, "sold": false})
	for i in range(relic_count):
		shop_items.append({"item": available_relics[i], "is_relic": true, "sold": false})

	shop_items.shuffle()
	_rebuild_shop_display()


func _rebuild_shop_display() -> void:
	# 清空道具列表
	for child in item_container.get_children():
		child.queue_free()
	# 清空遗物列表
	for child in relic_container.get_children():
		child.queue_free()

	# 设置容器鼠标过滤，让事件传递到商品
	item_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relic_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 设置容器间隔
	item_container.add_theme_constant_override("h_separation", ITEM_SPACING)
	item_container.add_theme_constant_override("v_separation", ITEM_SPACING)
	relic_container.add_theme_constant_override("h_separation", ITEM_SPACING)
	relic_container.add_theme_constant_override("v_separation", ITEM_SPACING)

	for i in range(shop_items.size()):
		var shop_entry = shop_items[i]
		var item: DataModels.ItemData = shop_entry["item"]
		var is_relic: bool = shop_entry["is_relic"]
		var sold: bool = shop_entry["sold"]
		
		if sold:
			continue  # 跳过已售完的商品
		
		if is_relic:
			relic_container.add_child(_create_item_cell(item, i, sold))
		else:
			item_container.add_child(_create_item_cell(item, i, sold))


func _create_item_cell(item: DataModels.ItemData, index: int, sold: bool = false) -> Control:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(ITEM_SIZE, ITEM_SIZE)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 使用 cell_0.png 作为背景
	var style := StyleBoxTexture.new()
	style.texture = CELL_TEXTURE
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	container.add_theme_stylebox_override("panel", style)
	
	# 主容器
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	container.add_child(vbox)
	
	# 图片区域
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(180, 180)
	center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_child(center)
	
	var sprite: Control
	if sold:
		# 已售完：显示check标记
		sprite = TextureRect.new()
		sprite.texture = CHECK_TEXTURE
		sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.custom_minimum_size = Vector2(80, 80)
		sprite.size = Vector2(80, 80)
	else:
		# 未售完：显示物品图片
		sprite = TextureRect.new()
		sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.custom_minimum_size = Vector2(180, 180)
		sprite.size = Vector2(180, 180)
		sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		sprite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		# 加载物品纹理
		var item_texture: Texture2D = _get_item_texture(item)
		sprite.texture = item_texture
		
		# 添加点击区域（透明但可点击）
		var click_area := Control.new()
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP
		center.add_child(click_area)
		click_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		click_area.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# 统一添加sprite（售完/未售完都在此处添加）
	center.add_child(sprite)
	
	# 价格标签区域（仅未售完时显示）
	if not sold:
		var price_container := CenterContainer.new()
		price_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(price_container)
		
		var price_label := Label.new()
		price_label.text = "💰 %d" % _get_actual_price(item)
		price_label.add_theme_font_size_override("font_size", 40)
		price_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		price_container.add_child(price_label)
	
	return container


func _get_item_texture(item: DataModels.ItemData) -> Texture2D:
	# 可用的道具图片ID列表
	var available_item_ids := [13, 15, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42]
	# 可用的遗物图片ID列表
	var available_relic_ids := [4, 5, 6, 7, 8, 9, 20, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45]
	
	if item.is_relic():
		# 遗物：根据item.id映射到可用图片ID
		var img_id: int = available_relic_ids[item.id % available_relic_ids.size()]
		var path := "res://art/sprites/UI/items/relic/relic_%03d.png" % img_id
		var tex := load(path) as Texture2D
		if tex:
			return tex
		return _create_color_texture(Color(0.4, 0.3, 0.5))
	else:
		# 道具：根据item.id映射到可用图片ID
		var img_id: int = available_item_ids[item.id % available_item_ids.size()]
		var path := "res://art/sprites/UI/items/item/item_%03d.png" % img_id
		var tex := load(path) as Texture2D
		if tex:
			return tex
		return _create_color_texture(Color(0.3, 0.4, 0.6))


func _create_color_texture(color: Color) -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	return tex


func _get_actual_price(item: DataModels.ItemData) -> int:
	var price: int = item.price
	# 商店折扣卷遗物 (ID 16)
	if ItemDatabase.has_relic(16, GameManager.relics):
		price = int(price * 0.85)
	# 临时折扣 (商店折扣券道具)
	if GameManager.has_meta("shop_discount"):
		price = int(price * GameManager.get_meta("shop_discount"))
		GameManager.remove_meta("shop_discount")
	return maxi(price, 1)


func _input(event: InputEvent) -> void:
	# 处理商品点击
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_check_item_click()


func _check_item_click() -> void:
	var mouse_pos := get_global_mouse_position()
	
	# 遍历道具容器
	var child_index := 0
	for child in item_container.get_children():
		if child is PanelContainer:
			var rect: Rect2 = child.get_global_rect()
			if rect.has_point(mouse_pos):
				# 找到对应索引的道具商品
				var idx := 0
				for shop_entry in shop_items:
					if not shop_entry["is_relic"] and not shop_entry["sold"]:
						if idx == child_index:
							_show_item_popup(shop_items.find(shop_entry))
							return
						idx += 1
		child_index += 1
	
	# 遍历遗物容器
	child_index = 0
	for child in relic_container.get_children():
		if child is PanelContainer:
			var rect: Rect2 = child.get_global_rect()
			if rect.has_point(mouse_pos):
				# 找到对应索引的遗物商品
				var idx := 0
				for shop_entry in shop_items:
					if shop_entry["is_relic"] and not shop_entry["sold"]:
						if idx == child_index:
							_show_item_popup(shop_items.find(shop_entry))
							return
						idx += 1
		child_index += 1


func _show_item_popup(index: int) -> void:
	if index < 0 or index >= shop_items.size():
		return
	
	var shop_entry = shop_items[index]
	var item: DataModels.ItemData = shop_entry["item"]
	var is_relic: bool = shop_entry["is_relic"]
	var sold: bool = shop_entry["sold"]
	
	if sold:
		return  # 已售完的商品不能购买
	
	var price: int = _get_actual_price(item)
	
	var item_type_text := "遗物" if is_relic else "道具"
	var content := "%s\n%s\n\n价格: %d 金币" % [item_type_text, item.description, price]
	
	# 检查是否可购买
	var can_buy := true
	var confirm_desc := ""
	
	if not is_relic and GameManager.items.size() >= GameManager.MAX_ITEM_SLOTS:
		can_buy = false
		confirm_desc = "道具栏已满，无法购买"
	
	if GameManager.gold < price:
		can_buy = false
		confirm_desc = "金币不足，无法购买"
	
	if can_buy:
		confirm_desc = "是否花费 %d 金币购买？" % price
	
	PopupSystem.show(
		item.name,
		content,
		confirm_desc,
		"购买" if can_buy else "",
		"关闭",
		Callable(self, "_on_confirm_buy").bind(index),
		Callable(self, "_on_popup_close")
	)


func _on_confirm_buy(index: int) -> void:
	if index < 0 or index >= shop_items.size():
		return
	
	var shop_entry = shop_items[index]
	var item: DataModels.ItemData = shop_entry["item"]
	var is_relic: bool = shop_entry["is_relic"]
	var price: int = _get_actual_price(item)

	# 检查道具栏是否已满
	if not is_relic and GameManager.items.size() >= GameManager.MAX_ITEM_SLOTS:
		TipManager.show_tip("道具栏已满")
		return

	if not GameManager.spend_gold(price):
		TipManager.show_tip("金币不足")
		return

	if is_relic:
		GameManager.add_relic(item)
	else:
		GameManager.add_item(item)

	print(">>> [Shop] 购买: %s, 花费 %d 金币" % [item.name, price])
	TipManager.show_tip("购买成功: %s" % item.name)
	
	# 标记为已售完（从显示中移除）
	shop_items[index]["sold"] = true
	_rebuild_shop_display()


func _on_popup_close() -> void:
	pass


func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "💰 %d" % new_gold


func _update_gold() -> void:
	gold_label.text = "💰 %d" % GameManager.gold


func _on_close_pressed() -> void:
	print(">>> [Shop] 关闭商店")
	# 作为弹窗关闭时，移除自己
	queue_free()


func _on_refresh_pressed() -> void:
	# 检查金币是否足够刷新
	if GameManager.gold >= REFRESH_COST:
		GameManager.spend_gold(REFRESH_COST)
		_refresh_shop()
		print(">>> [Shop] 刷新商店，花费 %d 金币" % REFRESH_COST)
	else:
		TipManager.show_tip("金币不足，无法刷新")
