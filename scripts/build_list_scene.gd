extends Control

## 建造清单面板

signal build_completed(build_id: int)

var _build_items: Array[Control] = []
var _build_loader: BuildConfigLoader = BuildConfigLoader.new()

func _ready() -> void:
	_build_loader.load_config()
	$VBox/CloseBtn.pressed.connect(_on_close_pressed)
	_refresh_build_list()


func _refresh_build_list() -> void:
	var vbox: VBoxContainer = $VBox/ScrollContainer/BuildListVBox
	var stars_label: Label = $VBox/StarsLabel

	# 清空现有项
	for item in _build_items:
		item.queue_free()
	_build_items.clear()

	# 显示星星数量
	var current_stars: int = TaskManager.get_stars()
	stars_label.text = "★ %d" % current_stars

	# 获取玩家等级和已完成的建造
	var player_level: int = TaskManager.get_level()
	var completed_ids: Array = _get_completed_build_ids()

	# 遍历配置表显示可建造项目
	for i in range(1, 11):
		var config = _build_loader.get_build(i)
		if config.is_empty():
			continue

		# 检查是否解锁（等级达到且未完成）
		var is_unlocked: bool = config.unlockLevel <= player_level
		var is_completed: bool = completed_ids.has(i)

		if not is_unlocked and not is_completed:
			continue

		var item = _create_build_item(config, is_unlocked, is_completed)
		vbox.add_child(item)
		_build_items.append(item)


func _create_build_item(config, is_unlocked: bool, is_completed: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)

	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size.y = 80
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	# 家具图标
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(60, 60)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if is_completed:
		icon.modulate = Color(0.5, 0.5, 0.5, 1)
	else:
		var sprite_path: String = ItemManager.get_sprite_path(config.furnitureId)
		if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
			icon.texture = load(sprite_path)
	hbox.add_child(icon)

	# 名称和消耗信息
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = config.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info_vbox.add_child(name_label)

	var cost_label := Label.new()
	if is_completed:
		cost_label.text = "已完成"
		cost_label.modulate = Color(0.5, 0.8, 0.5, 1)
	else:
		cost_label.text = "★ %d" % config.starCost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info_vbox.add_child(cost_label)

	# 奖励信息（经验+物品图标）
	var reward_hbox := HBoxContainer.new()
	reward_hbox.add_theme_constant_override("separation", 8)

	# 经验奖励
	if config.expReward > 0:
		var exp_label := Label.new()
		exp_label.text = "+%d经验" % config.expReward
		exp_label.modulate = Color(0.3, 0.8, 0.3, 1)
		reward_hbox.add_child(exp_label)

	# 物品奖励图标
	for item_id in config.itemReward:
		var reward_icon := TextureRect.new()
		reward_icon.custom_minimum_size = Vector2(32, 32)
		reward_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		reward_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var sprite_path: String = ItemManager.get_sprite_path(item_id)
		if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
			reward_icon.texture = load(sprite_path)
		else:
			reward_icon.modulate = Color(0.5, 0.5, 0.5, 1)
		reward_hbox.add_child(reward_icon)

	info_vbox.add_child(reward_hbox)

	hbox.add_child(info_vbox)

	# 建造按钮（未解锁或已完成时禁用）
	if is_unlocked and not is_completed:
		var build_btn := Button.new()
		build_btn.custom_minimum_size = Vector2(120, 50)

		# 按钮内添加星星图标和数量
		var btn_hbox := HBoxContainer.new()
		btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_hbox.add_theme_constant_override("separation", 6)

		var star_icon := TextureRect.new()
		star_icon.texture = load("res://art/sprites/UI/icon/star.png")
		star_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		star_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star_icon.custom_minimum_size = Vector2(28, 28)

		var star_label := Label.new()
		star_label.text = str(config.starCost)
		star_label.add_theme_font_size_override("font_size", 24)

		btn_hbox.add_child(star_icon)
		btn_hbox.add_child(star_label)
		build_btn.add_child(btn_hbox)

		build_btn.pressed.connect(_on_build_pressed.bind(config.id))
		hbox.add_child(build_btn)
	else:
		var status_label := Label.new()
		if is_completed:
			status_label.text = "完成"
		else:
			status_label.text = "未解锁 Lv.%d" % config.unlockLevel
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(status_label)

	return panel


func _on_build_pressed(build_id: int) -> void:
	SoundSystem.play_button_click()
	var config = _build_loader.get_build(build_id)
	if config.is_empty():
		return

	# 检查星星是否足够
	var current_stars: int = TaskManager.get_stars()
	if current_stars < config.starCost:
		_popup_not_enough_stars()
		return

	# 构建奖励信息
	var exp_reward: int = config.get("expReward", 0)
	var item_rewards: Array = config.get("itemReward", [])
	var reward_desc := ""
	if exp_reward > 0:
		reward_desc += "+%d 经验\n" % exp_reward
	if not item_rewards.is_empty():
		reward_desc += "+%d 个物品" % item_rewards.size()

	# 显示确认弹窗
	PopupSystem.show(
		"确认建造",
		"消耗 ★ %d\n\n%s" % [config.starCost, reward_desc],
		"是否确认建造？",
		"建造",
		"取消",
		_on_build_confirmed.bind(build_id),
		Callable()
	)
	# 设置奖励图标
	PopupSystem.set_reward_icons(item_rewards)


func _on_build_confirmed(build_id: int) -> void:
	var config = _build_loader.get_build(build_id)
	if config.is_empty():
		return

	# 扣除星星，添加经验，发放奖励
	TaskManager.add_stars(-config.starCost)
	SoundSystem.play_sfx("res://art/audio/sfx/gameboard/sfx_getcoin.ogg")
	TaskManager.add_exp(config.expReward)

	# 发放物品奖励（移入局外道具栏）
	for item_id in config.itemReward:
		GameManager.add_out_item(item_id)

	# 标记完成
	_save_build_completed(build_id)

	# 刷新显示
	_refresh_build_list()

	build_completed.emit(build_id)


func _popup_not_enough_stars() -> void:
	TipManager.show_tip("星星不足，建造所需的星星不够了")


func _get_completed_build_ids() -> Array:
	return TaskManager.get_completed_build_ids()


func _save_build_completed(build_id: int) -> void:
	var completed: Array = _get_completed_build_ids()
	if not completed.has(build_id):
		completed.append(build_id)
		TaskManager.save_completed_build_ids(completed)


func _on_close_pressed() -> void:
	SoundSystem.play_button_click()
	queue_free()
