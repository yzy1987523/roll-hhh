extends Control

## 商店系统
## 上下分区显示道具和遗物，图片+价格布局，点击调用弹窗

const SHOP_SLOTS := 6  # 每次刷新6个商品
const REFRESH_COST := 10  # 手动刷新费用

var shop_items: Array = []   # 当前商品列表

# 节点引用
@onready var gold_label: Label = $VBox/GoldBar/GoldLabel
@onready var item_container: HFlowContainer = $VBox/ItemScroll/ItemContainer
@onready var relic_container: HFlowContainer = $VBox/RelicScroll/RelicContainer

# 道具颜色映射（用于显示占位图）
const ITEM_COLORS := {
	"potion": Color(0.3, 0.8, 0.3),
	"scroll": Color(0.3, 0.5, 0.9),
	"bomb": Color(0.9, 0.4, 0.2),
	"default": Color(0.6, 0.6, 0.6)
}


func _ready() -> void:
	GameManager.gold_changed.connect(_on_gold_changed)
	_refresh_shop()
	_update_gold()
	print(">>> [Shop] 商店已打开")


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
		shop_items.append({"item": all_consumables[i], "is_relic": false})
	for i in range(relic_count):
		shop_items.append({"item": available_relics[i], "is_relic": true})

	shop_items.shuffle()
	_rebuild_shop_display()


func _rebuild_shop_display() -> void:
	# 清空道具列表
	for child in item_container.get_children():
		child.queue_free()
	# 清空遗物列表
	for child in relic_container.get_children():
		child.queue_free()

	for i in range(shop_items.size()):
		var shop_entry = shop_items[i]
		var item: DataModels.ItemData = shop_entry["item"]
		var is_relic: bool = shop_entry["is_relic"]
		
		if is_relic:
			relic_container.add_child(_create_item_cell(item, i))
		else:
			item_container.add_child(_create_item_cell(item, i))


func _create_item_cell(item: DataModels.ItemData, index: int) -> Control:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(100, 120)
	
	# 样式
	var style := StyleBoxFlat.new()
	if item.item_type == "relic":
		style.bg_color = Color(0.3, 0.25, 0.35, 0.9)  # 遗物紫色调
	else:
		style.bg_color = Color(0.2, 0.25, 0.35, 0.9)  # 道具蓝色调
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	container.add_theme_stylebox_override("panel", style)
	
	# 主容器
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	container.add_child(vbox)
	
	# 物品图片区域（用颜色块代替）
	var sprite := ColorRect.new()
	sprite.custom_minimum_size = Vector2(84, 70)
	var item_color := _get_item_display_color(item)
	sprite.color = item_color
	vbox.add_child(sprite)
	
	# 价格标签
	var price_bg := ColorRect.new()
	price_bg.color = Color(0.1, 0.1, 0.1, 0.8)
	price_bg.custom_minimum_size = Vector2(84, 24)
	vbox.add_child(price_bg)
	
	var price_container := CenterContainer.new()
	price_bg.add_child(price_container)
	
	var price_label := Label.new()
	price_label.text = "💰 %d" % _get_actual_price(item)
	price_label.add_theme_font_size_override("font_size", 14)
	price_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	price_container.add_child(price_label)
	
	# 点击事件
	container.gui_input.connect(_on_item_clicked.bind(index))
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	return container


func _get_item_display_color(item: DataModels.ItemData) -> Color:
	var color_key := "default"
	
	# 根据物品类型和ID设置颜色
	if item.item_type == "relic":
		match item.id:
			1: color_key = "potion"  # 生命护符
			2: color_key = "scroll"  # 经验书
			3: color_key = "bomb"   # 攻击护符
			4: color_key = "potion"  # 防御护符
			5: color_key = "scroll"  # 速度之靴
			6: color_key = "bomb"   # 暴击之刃
			7: color_key = "potion"  # 生命汲取
			8: color_key = "scroll"  # 法力源泉
			9: color_key = "bomb"   # 力量手套
			10: color_key = "potion" # 黄金护符
			11: color_key = "scroll"  # 治疗图腾
			12: color_key = "bomb"   # 治疗图腾
			13: color_key = "potion"  # 命运骰子
			14: color_key = "scroll"  # 商店折扣券
			15: color_key = "bomb"   # 刷新令牌
			_: color_key = "default"
	else:
		# 道具颜色
		match item.id:
			1: color_key = "potion"  # 小血瓶
			2: color_key = "potion"  # 中血瓶
			3: color_key = "potion"  # 大血瓶
			4: color_key = "scroll"  # 传送卷轴
			5: color_key = "bomb"   # 治疗卷轴
			6: color_key = "scroll"  # 传送卷轴
			7: color_key = "bomb"   # 治疗卷轴
			8: color_key = "scroll"  # 商店折扣券
			_: color_key = "default"
	
	return ITEM_COLORS.get(color_key, ITEM_COLORS["default"])


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


func _on_item_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_show_item_popup(index)


func _show_item_popup(index: int) -> void:
	if index < 0 or index >= shop_items.size():
		return
	
	var shop_entry = shop_items[index]
	var item: DataModels.ItemData = shop_entry["item"]
	var is_relic: bool = shop_entry["is_relic"]
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
	_refresh_shop()


func _on_popup_close() -> void:
	pass


func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "💰 %d" % new_gold


func _update_gold() -> void:
	gold_label.text = "💰 %d" % GameManager.gold


func _on_refresh_pressed() -> void:
	# 检查是否有刷新令牌
	if GameManager.has_meta("shop_refresh"):
		GameManager.remove_meta("shop_refresh")
		_refresh_shop()
		TipManager.show_tip("使用刷新令牌刷新商店")
		return

	if not GameManager.spend_gold(REFRESH_COST):
		TipManager.show_tip("金币不足，需要 %d 金币" % REFRESH_COST)
		return
	
	_refresh_shop()
	TipManager.show_tip("花费 %d 金币刷新商店" % REFRESH_COST)


func _on_close_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")
