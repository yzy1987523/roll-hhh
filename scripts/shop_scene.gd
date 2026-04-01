extends Control

## 商店系统
## 任务 4.1: 商店UI + 随机刷新 + 库存 + 购买

const SHOP_SLOTS := 5  # 每次刷新5个商品
const REFRESH_COST := 10  # 手动刷新费用

var shop_items: Array = []   # 当前商品列表
var item_buttons: Array = []
var relic_buttons: Array = []

@onready var title_label: Label = $VBox/Title
@onready var gold_label: Label = $VBox/GoldBar/GoldLabel
@onready var item_list: VBoxContainer = $VBox/ItemScroll/ItemList
@onready var relic_list: VBoxContainer = $VBox/RelicScroll/RelicList
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
	LocalizationSystem.language_changed.connect(_on_localization_changed)
	_refresh_shop()
	_update_gold()
	_update_ui_texts()
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
	var item_count := mini(SHOP_SLOTS / 2 + 1, all_consumables.size())
	var relic_count := mini(SHOP_SLOTS - item_count, available_relics.size())

	for i in range(item_count):
		shop_items.append({"item": all_consumables[i], "is_relic": false})
	for i in range(relic_count):
		shop_items.append({"item": available_relics[i], "is_relic": true})

	shop_items.shuffle()
	_rebuild_item_list()


func _rebuild_item_list() -> void:
	# 清空道具列表
	for child in item_list.get_children():
		child.queue_free()
	item_buttons.clear()
	# 清空遗物列表
	for child in relic_list.get_children():
		child.queue_free()
	relic_buttons.clear()

	for i in range(shop_items.size()):
		var shop_entry = shop_items[i]
		var item: DataModels.ItemData = shop_entry["item"]
		var is_relic: bool = shop_entry["is_relic"]
		var target_list: VBoxContainer = relic_list if is_relic else item_list

		var row := HBoxContainer.new()
		target_list.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = item.name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var price_lbl := Label.new()
		var actual_price: int = _get_actual_price(item)
		price_lbl.text = LocalizationSystem.get_text("shop.price_format", {"value": actual_price})
		price_lbl.custom_minimum_size = Vector2(50, 0)
		row.add_child(price_lbl)

		var btn := Button.new()
		btn.text = LocalizationSystem.get_text("shop.view")
		btn.pressed.connect(_on_item_select.bind(i))
		row.add_child(btn)

		if is_relic:
			relic_buttons.append(btn)
		else:
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
	var shop_entry = shop_items[index]
	var item: DataModels.ItemData = shop_entry["item"]
	detail_name.text = item.name
	detail_desc.text = item.description
	detail_price.text = LocalizationSystem.get_text("shop.detail_price", {"price": _get_actual_price(item)})
	buy_button.disabled = false
	detail_panel.visible = true


func _on_buy() -> void:
	if selected_shop_index < 0:
		return
	var shop_entry = shop_items[selected_shop_index]
	var item: DataModels.ItemData = shop_entry["item"]
	var is_relic: bool = shop_entry["is_relic"]
	var price: int = _get_actual_price(item)

	# 检查道具栏是否已满（仅对道具有效）
	if not is_relic and GameManager.items.size() >= GameManager.MAX_ITEM_SLOTS:
		print(">>> [Shop] 购买失败: 道具栏已满")
		return

	if not GameManager.spend_gold(price):
		print(">>> [Shop] 购买失败: 金币不足")
		return

	if is_relic:
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


func _on_localization_changed(lang: String) -> void:
	_update_ui_texts()
	_refresh_shop()
	print(">>> [Shop] 语言切换为: %s" % lang)


func _update_ui_texts() -> void:
	title_label.text = LocalizationSystem.get_text("shop.title")
	refresh_button.text = LocalizationSystem.get_text("shop.refresh")
	close_button.text = LocalizationSystem.get_text("shop.close")
	buy_button.text = LocalizationSystem.get_text("shop.buy")
	detail_close.text = LocalizationSystem.get_text("shop.cancel")
	_update_gold()
