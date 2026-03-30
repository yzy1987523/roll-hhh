extends Control

## 商店系统
## 任务 4.1: 商店UI + 随机刷新 + 库存 + 购买

const SHOP_SLOTS := 5  # 每次刷新5个商品
const REFRESH_COST := 10  # 手动刷新费用

var shop_items: Array = []   # 当前商品列表
var shop_stock: Array = []   # 库存数量
var item_buttons: Array = []

@onready var title_label: Label = $VBox/Title
@onready var gold_label: Label = $VBox/GoldBar/GoldLabel
@onready var item_list: VBoxContainer = $VBox/ScrollContainer/ItemList
@onready var refresh_button: Button = $VBox/BottomBar/RefreshButton
@onready var close_button: Button = $VBox/BottomBar/CloseButton
@onready var detail_panel: PanelContainer = $DetailPanel
@onready var detail_name: Label = $DetailPanel/DVBox/DetailName
@onready var detail_desc: Label = $DetailPanel/DVBox/DetailDesc
@onready var detail_price: Label = $DetailPanel/DVBox/DetailPrice
@onready var buy_button: Button = $DetailPanel/DVBox/BuyButton
@onready var detail_close: Button = $DetailPanel/DVBox/DetailClose

var selected_shop_index: int = -1


func _ready() -> void:
	refresh_button.pressed.connect(_on_refresh)
	close_button.pressed.connect(_on_close)
	buy_button.pressed.connect(_on_buy)
	detail_close.pressed.connect(_on_detail_close)
	detail_panel.visible = false
	GameManager.gold_changed.connect(_on_gold_changed)
	_refresh_shop()
	_update_gold()
	print(">>> [Shop] 商店已打开")


func _refresh_shop() -> void:
	shop_items.clear()
	shop_stock.clear()

	# 从道具库和遗物库随机抽取
	var all_consumables: Array = ItemDatabase.get_all_consumables()
	var all_relics: Array = ItemDatabase.get_all_relics()

	# 过滤已拥有的唯一遗物
	var available_relics: Array = []
	for r in all_relics:
		if r.stackable or not ItemDatabase.has_relic(r.id, GameManager.relics):
			if r.price > 0:
				available_relics.append(r)

	var pool: Array = []
	pool.append_array(all_consumables)
	pool.append_array(available_relics)
	pool.shuffle()

	for i in range(mini(SHOP_SLOTS, pool.size())):
		shop_items.append(pool[i])
		shop_stock.append(randi_range(1, 3))

	_rebuild_item_list()


func _rebuild_item_list() -> void:
	for child in item_list.get_children():
		child.queue_free()
	item_buttons.clear()

	for i in range(shop_items.size()):
		var item: DataModels.ItemData = shop_items[i]
		var stock: int = shop_stock[i]

		var row := HBoxContainer.new()
		item_list.add_child(row)

		var type_tag := Label.new()
		type_tag.text = LocalizationSystem.get_text("shop.tag_relic") if item.is_relic() else LocalizationSystem.get_text("shop.tag_consumable")
		type_tag.custom_minimum_size = Vector2(50, 0)
		row.add_child(type_tag)

		var name_lbl := Label.new()
		name_lbl.text = item.name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var price_lbl := Label.new()
		var actual_price: int = _get_actual_price(item)
		price_lbl.text = LocalizationSystem.get_text("shop.price_format", {"value": actual_price})
		price_lbl.custom_minimum_size = Vector2(50, 0)
		row.add_child(price_lbl)

		var stock_lbl := Label.new()
		stock_lbl.text = LocalizationSystem.get_text("shop.stock_format", {"value": stock}) if stock > 0 else LocalizationSystem.get_text("shop.sold_out")
		stock_lbl.custom_minimum_size = Vector2(40, 0)
		row.add_child(stock_lbl)

		var btn := Button.new()
		btn.text = LocalizationSystem.get_text("shop.view")
		btn.disabled = stock <= 0
		btn.pressed.connect(_on_item_select.bind(i))
		row.add_child(btn)
		item_buttons.append(btn)


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


func _on_item_select(index: int) -> void:
	if index < 0 or index >= shop_items.size():
		return
	selected_shop_index = index
	var item: DataModels.ItemData = shop_items[index]
	detail_name.text = item.name
	detail_desc.text = item.description
	detail_price.text = LocalizationSystem.get_text("shop.detail_price", {"price": _get_actual_price(item), "stock": shop_stock[index]})
	buy_button.disabled = shop_stock[index] <= 0
	detail_panel.visible = true


func _on_buy() -> void:
	if selected_shop_index < 0:
		return
	var item: DataModels.ItemData = shop_items[selected_shop_index]
	var price: int = _get_actual_price(item)

	if not GameManager.spend_gold(price):
		print(">>> [Shop] 购买失败: 金币不足")
		return

	if shop_stock[selected_shop_index] <= 0:
		print(">>> [Shop] 购买失败: 已售罄")
		return

	shop_stock[selected_shop_index] -= 1

	if item.is_relic():
		GameManager.add_relic(item)
	else:
		GameManager.add_item(item)

	print(">>> [Shop] 购买: %s, 花费 %d 金币" % [item.name, price])
	detail_panel.visible = false
	_rebuild_item_list()


func _on_refresh() -> void:
	# 检查是否有刷新令牌
	if GameManager.has_meta("shop_refresh"):
		GameManager.remove_meta("shop_refresh")
		_refresh_shop()
		print(">>> [Shop] 使用刷新令牌刷新商店")
		return

	if not GameManager.spend_gold(REFRESH_COST):
		print(">>> [Shop] 刷新失败: 金币不足 (需%d)" % REFRESH_COST)
		return
	_refresh_shop()
	print(">>> [Shop] 花费 %d 金币刷新商店" % REFRESH_COST)


func _on_close() -> void:
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")


func _on_detail_close() -> void:
	detail_panel.visible = false
	selected_shop_index = -1


func _update_gold() -> void:
	gold_label.text = LocalizationSystem.get_text("shop.gold_label", {"value": GameManager.gold})


func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = LocalizationSystem.get_text("shop.gold_label", {"value": new_gold})
