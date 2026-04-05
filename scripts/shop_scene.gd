extends Control

## 商店系统
## 上下分区显示道具和遗物，图片+价格布局，点击调用弹窗
## 改进版：panel.png背景、格子150x150、图片130x130、购买后格子留下、同回合不刷新

const SHOP_SLOTS := 6  # 每次刷新6个商品
const REFRESH_COST := 10  # 手动刷新费用
const CELL_SIZE := 150  # 格子尺寸
const ITEM_SIZE := 130  # 商品图片尺寸
const ITEM_SPACING := 20  # 商品间隔

var shop_items: Array = []   # 当前商品列表

# 节点引用
@onready var round_label: Label = $ShopWindow/VBox/TitleBarMargin/TitleBar/RoundLabel
@onready var shop_title: Label = $ShopWindow/VBox/TitleBarMargin/TitleBar/ShopTitle
@onready var item_section_title: Label = $ShopWindow/VBox/ItemSection/SectionTitle
@onready var relic_section_title: Label = $ShopWindow/VBox/RelicSection/SectionTitle
@onready var item_container: HBoxContainer = $ShopWindow/VBox/ItemSection/ItemCenter/ItemContainer
@onready var relic_container: HBoxContainer = $ShopWindow/VBox/RelicSection/RelicCenter/RelicContainer
@onready var close_button: TextureButton = $ShopWindow/VBox/TitleBarMargin/TitleBar/CloseButton

# 预加载纹理
const CELL_TEXTURE := preload("res://art/sprites/UI/items/smallItem/cell_0.png")
const CHECK_TEXTURE := preload("res://art/sprites/UI/items/smallItem/check.png")


func _ready() -> void:
	# 移除 PanelContainer 默认黑底
	var shop_window = $ShopWindow
	var empty_style := StyleBoxEmpty.new()
	shop_window.add_theme_stylebox_override("panel", empty_style)

	# 设置关闭按钮信号
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
		_add_button_feedback(close_button)

	# 设置商店标题
	if shop_title:
		shop_title.text = LocalizationSystem.get_text("shop.title")

	# 设置道具和遗物区域标题
	if item_section_title:
		item_section_title.text = LocalizationSystem.get_text("shop.tag_consumable")
	if relic_section_title:
		relic_section_title.text = LocalizationSystem.get_text("shop.tag_relic")

	# 更新回合数显示
	_update_round_display()

	# 初始打开商店时判断是否需要刷新（仅当新回合时）
	_check_and_refresh()
	LocalizationSystem.language_changed.connect(_on_localization_changed)
	print(">>> [Shop] 商店已打开")


func _on_localization_changed(_lang: String) -> void:
	# 更新标题
	if shop_title:
		shop_title.text = LocalizationSystem.get_text("shop.title")
	# 更新道具和遗物区域标题
	if item_section_title:
		item_section_title.text = LocalizationSystem.get_text("shop.tag_consumable")
	if relic_section_title:
		relic_section_title.text = LocalizationSystem.get_text("shop.tag_relic")
	_update_round_display()


func _update_round_display() -> void:
	# 更新回合数显示
	if round_label:
		round_label.text = LocalizationSystem.get_text("shop.round", {"value": GameManager.current_round})


func _check_and_refresh() -> void:
	# 判断是否需要刷新（新回合或首次打开）
	if GameManager.shop_last_refresh_round != GameManager.current_round:
		_refresh_shop()
		GameManager.shop_last_refresh_round = GameManager.current_round
		_save_shop_data()
		print(">>> [Shop] 回合 %d，商店已刷新" % GameManager.current_round)
	else:
		# 同一回合，恢复商品列表
		_restore_shop_data()
		# 如果恢复后商品列表为空，强制刷新
		if shop_items.size() == 0:
			_refresh_shop()
			_save_shop_data()
			print(">>> [Shop] 商品列表为空，强制刷新")
		else:
			_rebuild_shop_display()


func _save_shop_data() -> void:
	# 保存商品数据到 GameManager
	GameManager.shop_items_data.clear()
	for entry in shop_items:
		GameManager.shop_items_data.append({
			"id": entry["item"].id,
			"is_relic": entry["is_relic"],
			"sold": entry["sold"]
		})
	SaveSystem.save_game()


func _restore_shop_data() -> void:
	# 从 GameManager 恢复商品数据
	shop_items.clear()
	for data in GameManager.shop_items_data:
		var item_id: int = data.get("id", -1)
		var is_relic: bool = data.get("is_relic", false)
		var sold: bool = data.get("sold", false)
		
		var item: DataModels.ItemData
		if is_relic:
			item = ItemDatabase.get_relic_by_id(item_id)
		else:
			item = ItemDatabase.get_consumable_by_id(item_id)
		
		if item:
			shop_items.append({"item": item, "is_relic": is_relic, "sold": sold})


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

	# 设置容器间隔
	item_container.add_theme_constant_override("separation", ITEM_SPACING)
	relic_container.add_theme_constant_override("separation", ITEM_SPACING)

	for i in range(shop_items.size()):
		var shop_entry = shop_items[i]
		var item: DataModels.ItemData = shop_entry["item"]
		var is_relic: bool = shop_entry["is_relic"]
		var sold: bool = shop_entry["sold"]

		if is_relic:
			relic_container.add_child(_create_item_cell(item, i, sold))
		else:
			item_container.add_child(_create_item_cell(item, i, sold))


func _create_item_cell(item: DataModels.ItemData, index: int, sold: bool = false) -> Control:
	# 外层容器：格子大小
	var container := Control.new()
	container.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE + 40)  # 格子 + 价格区域
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 格子背景
	var cell_bg := TextureRect.new()
	cell_bg.texture = CELL_TEXTURE
	cell_bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	cell_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cell_bg.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	cell_bg.size = Vector2(CELL_SIZE, CELL_SIZE)
	cell_bg.position = Vector2(0, 0)
	container.add_child(cell_bg)
	
	if not sold:
		# 未售完：显示物品图片
		var sprite := TextureRect.new()
		sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.custom_minimum_size = Vector2(ITEM_SIZE, ITEM_SIZE)
		sprite.size = Vector2(ITEM_SIZE, ITEM_SIZE)
		sprite.position = Vector2((CELL_SIZE - ITEM_SIZE) / 2.0, (CELL_SIZE - ITEM_SIZE) / 2.0)
		sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		sprite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		# 加载物品纹理
		var item_texture: Texture2D = _get_item_texture(item)
		sprite.texture = item_texture
		container.add_child(sprite)
		
		# 价格标签（格子下方）
		var price_label := Label.new()
		price_label.text = "$ %d" % _get_actual_price(item)
		price_label.add_theme_font_size_override("font_size", 30)
		price_label.add_theme_color_override("font_color", Color(1, 0.141, 0.290))
		price_label.add_theme_color_override("font_outline_color", Color.BLACK)
		price_label.add_theme_constant_override("outline_size", 2)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.position = Vector2(0, CELL_SIZE + 5)
		price_label.size = Vector2(CELL_SIZE, 35)
		container.add_child(price_label)
		
		# 阴影层（偏移1像素）
		var shadow_label := Label.new()
		shadow_label.text = "$ %d" % _get_actual_price(item)
		shadow_label.add_theme_font_size_override("font_size", 30)
		shadow_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		shadow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shadow_label.position = Vector2(1, CELL_SIZE + 6)
		shadow_label.size = Vector2(CELL_SIZE, 35)
		shadow_label.z_index = -1
		container.add_child(shadow_label)
	else:
		# 已售完：显示已售标记（格子中央）
		var check := TextureRect.new()
		check.texture = CHECK_TEXTURE
		check.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		check.custom_minimum_size = Vector2(60, 60)
		check.size = Vector2(60, 60)
		check.position = Vector2((CELL_SIZE - 60) / 2.0, (CELL_SIZE - 60) / 2.0)
		check.modulate.a = 0.5
		container.add_child(check)
	
	return container


func _get_item_texture(item: DataModels.ItemData) -> Texture2D:
	if item.is_relic():
		# 遗物: ID 1-26
		var path := "res://art/sprites/UI/items/relic/relic_%03d.png" % item.id
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
		return _create_color_texture(Color(0.4, 0.3, 0.5))
	else:
		# 道具: ID 1-22
		var path := "res://art/sprites/UI/items/item/item_%03d.png" % item.id
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
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
	# 如果弹窗打开，不处理点击
	if PopupSystem.is_open():
		return

	# 处理商品点击
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# 检查点击是否在商店窗口内
			var shop_window = $ShopWindow
			if shop_window and shop_window.get_global_rect().has_point(get_global_mouse_position()):
				_check_item_click()
			else:
				# 点击在商店窗口外，关闭商店
				_on_close_pressed()


func _check_item_click() -> void:
	var mouse_pos := get_global_mouse_position()
	
	# 遍历道具容器
	for child in item_container.get_children():
		if child is Control:
			var rect: Rect2 = child.get_global_rect()
			if rect.has_point(mouse_pos):
				# 找到对应索引的道具商品
				var idx := 0
				for shop_entry in shop_items:
					if not shop_entry["is_relic"]:
						if idx == child.get_index():
							_show_item_popup(shop_items.find(shop_entry))
							return
						idx += 1
	
	# 遍历遗物容器
	for child in relic_container.get_children():
		if child is Control:
			var rect: Rect2 = child.get_global_rect()
			if rect.has_point(mouse_pos):
				# 找到对应索引的遗物商品
				var idx := 0
				for shop_entry in shop_items:
					if shop_entry["is_relic"]:
						if idx == child.get_index():
							_show_item_popup(shop_items.find(shop_entry))
							return
						idx += 1


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
	
	var item_type_text := LocalizationSystem.get_text("shop.tag_relic") if is_relic else LocalizationSystem.get_text("shop.tag_consumable")
	var content := "%s\n%s\n\n%s" % [item_type_text, item.description, LocalizationSystem.get_text("shop.detail_price", {"price": price})]
	
	# 检查是否可购买
	var can_buy := true
	var confirm_desc := ""
	
	if not is_relic and GameManager.items.size() >= GameManager.MAX_ITEM_SLOTS:
		can_buy = false
		confirm_desc = LocalizationSystem.get_text("shop.confirm_buy_inventory_full")
	
	if GameManager.gold < price:
		can_buy = false
		confirm_desc = LocalizationSystem.get_text("shop.confirm_buy_cannot_afford")
	
	if can_buy:
		confirm_desc = LocalizationSystem.get_text("shop.confirm_buy", {"price": price})
	
	PopupSystem.show(
		item.name,
		content,
		confirm_desc,
		LocalizationSystem.get_text("shop.buy") if can_buy else "",
		LocalizationSystem.get_text("shop.close"),
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
		TipManager.show_tip(LocalizationSystem.get_text("shop.item_full"))
		return

	if not GameManager.spend_gold(price):
		TipManager.show_tip(LocalizationSystem.get_text("shop.not_enough_gold"))
		return

	if is_relic:
		GameManager.add_relic(item)
	else:
		GameManager.add_item(item)

	print(">>> [Shop] 购买: %s, 花费 %d 金币" % [item.name, price])
	TipManager.show_tip(LocalizationSystem.get_text("shop.purchase_success", {"name": item.name}))

	# 标记为已售完（格子留下，只移除图片和价格）
	shop_items[index]["sold"] = true
	_save_shop_data()  # 保存购买状态
	_rebuild_shop_display()


func _on_popup_close() -> void:
	pass


func _on_close_pressed() -> void:
	print(">>> [Shop] 关闭商店")
	SoundSystem.play_button_click()
	# 作为弹窗关闭时，移除自己
	queue_free()


func _on_refresh_pressed() -> void:
	SoundSystem.play_button_click()
	# 检查金币是否足够刷新
	if GameManager.gold >= REFRESH_COST:
		GameManager.spend_gold(REFRESH_COST)
		_refresh_shop()
		print(">>> [Shop] 刷新商店，花费 %d 金币" % REFRESH_COST)
	else:
		TipManager.show_tip(LocalizationSystem.get_text("shop.not_enough_gold_refresh"))


## 为按钮添加hover和press视觉反馈
func _add_button_feedback(btn: BaseButton) -> void:
	btn.mouse_entered.connect(_on_button_mouse_entered.bind(btn))
	btn.mouse_exited.connect(_on_button_mouse_exited.bind(btn))
	btn.button_down.connect(_on_button_down.bind(btn))
	btn.button_up.connect(_on_button_up.bind(btn))


func _on_button_mouse_entered(btn: BaseButton) -> void:
	var alpha := btn.modulate.a
	btn.modulate = Color(0.9, 0.9, 0.9, alpha)


func _on_button_mouse_exited(btn: BaseButton) -> void:
	var alpha := btn.modulate.a
	btn.modulate = Color(1, 1, 1, alpha)


func _on_button_down(btn: BaseButton) -> void:
	var alpha := btn.modulate.a
	btn.modulate = Color(0.8, 0.8, 0.8, alpha)


func _on_button_up(btn: BaseButton) -> void:
	var alpha := btn.modulate.a
	btn.modulate = Color(0.9, 0.9, 0.9, alpha) if btn.get_global_rect().has_point(btn.get_viewport().get_mouse_position()) else Color(1, 1, 1, alpha)
