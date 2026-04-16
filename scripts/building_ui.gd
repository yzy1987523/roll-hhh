extends CanvasLayer

const BuildListScene = preload("res://scenes/build_list_scene.tscn")
var _build_list_instance: Control = null

# 等级配置缓存
var _level_config: Dictionary = {}

# 资源购买按钮
@onready var _energy_buy_btn: Button = find_child("EnergyBuyBtn", true, false)
@onready var _gold_buy_btn: Button = find_child("GoldBuyBtn", true, false)
@onready var _diamond_buy_btn: Button = find_child("DiamondBuyBtn", true, false)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos: Vector2 = event.global_position
		# 检测是否点在 EnergyBuyBtn 上
		if _energy_buy_btn != null:
			var btn_rect = Rect2(_energy_buy_btn.global_position, _energy_buy_btn.size)
			print(">>> [BuildingUI] mouse_pos=%s, energy_btn_rect=%s, contains=%s" % [mouse_pos, btn_rect, btn_rect.has_point(mouse_pos)])


# ================================= 初始化 =================================
func _ready() -> void:
	print(">>> [BuildingUI] _ready 开始执行")
	_load_level_config()
	_connect_grid_manager_signal()
	_connect_level_up_signal()
	_connect_exp_changed_signal()
	_connect_resource_signals()
	_connect_save_system_signal()
	_update_level_display()
	_update_exp_bar()
	_update_resource_display()
	# 延迟连接购买按钮，等待子场景加载完成
	await get_tree().process_frame
	print(">>> [BuildingUI] 延迟后，开始连接购买按钮")
	_connect_buy_buttons()
	print(">>> [BuildingUI] _ready 执行完成")


# ================================= 连接 GridManager 的 build_exp_reward 信号 =================================
func _connect_grid_manager_signal() -> void:
	# GridManager 是 RoomRoot 的子节点，UILayer 也是 RoomRoot 的子节点
	var grid_mgr = get_node_or_null("../GridManager")
	if grid_mgr == null:
		# 延迟查找
		await get_tree().process_frame
		grid_mgr = get_node_or_null("../GridManager")
	if grid_mgr != null and grid_mgr.has_signal("build_exp_reward"):
		grid_mgr.build_exp_reward.connect(_on_build_exp_reward)
		print(">>> [BuildingUI] 已连接 GridManager.build_exp_reward 信号")


func _connect_level_up_signal() -> void:
	TaskManager.level_up.connect(_on_level_up)
	print(">>> [BuildingUI] 已连接 TaskManager.level_up 信号")


func _connect_exp_changed_signal() -> void:
	TaskManager.exp_changed.connect(_on_exp_changed)
	print(">>> [BuildingUI] 已连接 TaskManager.exp_changed 信号")


func _connect_resource_signals() -> void:
	if GameManager.has_signal("gold_changed"):
		GameManager.gold_changed.connect(_on_gold_changed)
	if GameManager.has_signal("energy_changed"):
		GameManager.energy_changed.connect(_on_energy_changed)
	if GameManager.has_signal("diamond_changed"):
		GameManager.diamond_changed.connect(_on_diamond_changed)
	# 连接星星数量变化信号
	TaskManager.stars_changed.connect(_on_stars_changed)
	print(">>> [BuildingUI] 已连接资源变化信号")


func _connect_save_system_signal() -> void:
	if SaveSystem.has_signal("save_cleared"):
		SaveSystem.save_cleared.connect(_on_save_cleared)
		print(">>> [BuildingUI] 已连接 SaveSystem.save_cleared 信号")


func _on_save_cleared() -> void:
	print(">>> [BuildingUI] 收到清空存档信号，刷新 UI")
	_update_level_display()
	_update_exp_bar()
	_update_resource_display()


func _on_stars_changed(_new_stars: int) -> void:
	var star_label = find_child("StarLabel", true, false)
	if star_label != null:
		star_label.text = str(_new_stars)


func _on_gold_changed(_amount) -> void:
	_update_resource_display()


func _on_energy_changed(_amount) -> void:
	_update_resource_display()


func _on_diamond_changed(_amount) -> void:
	_update_resource_display()


func _update_resource_display() -> void:
	var energy_label = find_child("EnergyLabel", true, false)
	if energy_label != null:
		var current_energy: int = GameManager.get("energy") if GameManager.get("energy") != null else 0
		energy_label.text = str(current_energy)

	var gold_label = find_child("GoldLabel", true, false)
	if gold_label != null:
		var gold: int = GameManager.get("gold") if GameManager.get("gold") != null else 0
		gold_label.text = str(gold)

	var diamond_label = find_child("DiamondLabel", true, false)
	if diamond_label != null:
		var diamond: int = GameManager.get("diamond") if GameManager.get("diamond") != null else 0
		diamond_label.text = str(diamond)

	var star_label = find_child("StarLabel", true, false)
	if star_label != null:
		var stars: int = TaskManager.get_stars()
		star_label.text = str(stars)


# ================================= 加载等级配置 =================================
func _load_level_config() -> void:
	var file = FileAccess.open("res://config/LevelConfig.json", FileAccess.READ)
	if file == null:
		print(">>> [BuildingUI] 无法加载 LevelConfig.json")
		return
	var json = JSON.new()
	var result = json.parse(file.get_as_text())
	file.close()
	if result != OK:
		print(">>> [BuildingUI] LevelConfig.json 解析失败")
		return
	_level_config = json.get_data()
	print(">>> [BuildingUI] 等级配置加载完成")


# ================================= 本地弹窗显示（解决 CanvasLayer 遮挡问题） =================================
func _show_popup(
	p_title: String,
	p_content: String = "",
	p_description: String = "",
	p_confirm_text: String = "",
	p_close_text: String = "",
	p_on_confirm: Callable = Callable(),
	p_on_close: Callable = Callable()
) -> void:
	# 实例化预制体
	var popup_scene: PackedScene = ResourceLoader.load("res://scenes/popup_scene.tscn")
	var popup: Control = popup_scene.instantiate()
	popup.setup(
		p_title,
		p_content,
		p_description,
		p_confirm_text,
		p_close_text,
		p_on_confirm,
		p_on_close
	)

	# 设置弹窗层级高于 CanvasLayer
	popup.z_index = 3000

	# 添加到当前 CanvasLayer 子节点
	add_child(popup)

	# 居中到屏幕中央
	popup.global_position = (get_viewport().get_visible_rect().size - Vector2(800, 600)) / 2

	# 用 lambda 捕获 popup 引用，确保正确关闭
	popup.confirmed.connect(func(): _close_popup(popup))
	popup.closed.connect(func(): _close_popup(popup))


# ================================= 资源购买按钮连接 =================================
func _connect_buy_buttons() -> void:
	print(">>> [BuildingUI] _connect_buy_buttons 开始")
	print(">>> [BuildingUI] _energy_buy_btn=%s", _energy_buy_btn)
	print(">>> [BuildingUI] _gold_buy_btn=%s", _gold_buy_btn)
	print(">>> [BuildingUI] _diamond_buy_btn=%s", _diamond_buy_btn)
	if _energy_buy_btn:
		_energy_buy_btn.pressed.connect(_on_energy_buy_pressed)
		print(">>> [BuildingUI] EnergyBuyBtn 信号已连接")
	if _gold_buy_btn:
		_gold_buy_btn.pressed.connect(_on_gold_buy_pressed)
	if _diamond_buy_btn:
		_diamond_buy_btn.pressed.connect(_on_diamond_buy_pressed)


func _on_energy_buy_pressed() -> void:
	print(">>> [BuildingUI] 点击体力购买按钮")
	SoundSystem.play_button_click()
	var cost: int = GameManager.get_energy_purchase_cost()
	var cost_text: String = LocalizationSystem.get_text("game_board.buy_energy_confirm", {"cost": cost})
	_show_popup(
		LocalizationSystem.get_text("game_board.buy_energy_title"),
		cost_text,
		"",  # description
		LocalizationSystem.get_text("common.confirm"),  # confirm_text
		LocalizationSystem.get_text("common.close"),  # close_text
		Callable(self, "_do_energy_buy"),  # on_confirm
		Callable(self, "_on_popup_close")  # on_close
	)


func _do_energy_buy() -> void:
	if GameManager.purchase_energy():
		TipManager.show_tip(LocalizationSystem.get_text("game_board.buy_energy_success"))
	else:
		TipManager.show_tip(LocalizationSystem.get_text("game_board.buy_energy_failed"))


func _on_popup_close() -> void:
	pass


func _close_popup(popup: Control) -> void:
	if is_instance_valid(popup):
		popup.queue_free()


func _on_gold_buy_pressed() -> void:
	print(">>> [BuildingUI] 点击金币购买按钮")
	SoundSystem.play_button_click()
	_show_popup(
		LocalizationSystem.get_text("game_board.gold_buy_title"),
		LocalizationSystem.get_text("game_board.gold_buy_desc"),
		"",  # description
		LocalizationSystem.get_text("common.confirm"),  # confirm_text
		LocalizationSystem.get_text("common.close"),  # close_text
		Callable(self, "_do_gold_buy"),  # on_confirm
		Callable(self, "_on_popup_close")  # on_close
	)


func _do_gold_buy() -> void:
	# 直接增加1000金币
	GameManager.add_gold(1000)
	TipManager.show_tip("获得 1000 金币！")


func _on_diamond_buy_pressed() -> void:
	print(">>> [BuildingUI] 点击钻石购买按钮")
	SoundSystem.play_button_click()
	_show_popup(
		LocalizationSystem.get_text("game_board.diamond_buy_title"),
		LocalizationSystem.get_text("game_board.diamond_buy_desc"),
		"",  # description
		LocalizationSystem.get_text("common.confirm"),  # confirm_text
		LocalizationSystem.get_text("common.close"),  # close_text
		Callable(self, "_do_diamond_buy"),  # on_confirm
		Callable(self, "_on_popup_close")  # on_close
	)


func _do_diamond_buy() -> void:
	# 直接增加1000钻石
	GameManager.add_diamond(1000)
	TipManager.show_tip("获得 1000 钻石！")


# ================================= Play按钮 =================================
func _on_play_pressed() -> void:
	print(">>> [BuildingUI] 点击播放按钮，进入合成界面")
	SoundSystem.play_button_click()
	# 播放按钮缩放动画
	var play_btn: TextureButton = find_child("PlayBtn", true, false)
	if play_btn:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(play_btn, "scale", Vector2(1.1, 1.1), 0.15)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(play_btn, "scale", Vector2(1.0, 1.0), 0.1)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(0.1)
		tween.finished.connect(func(): TransitionManager.change_scene_with_transition("res://scenes/game_board.tscn"))
	else:
		TransitionManager.change_scene_with_transition("res://scenes/game_board.tscn")


# ================================= 建造清单按钮 =================================
func _on_build_list_pressed() -> void:
	print(">>> [BuildingUI] 点击建造清单按钮")
	SoundSystem.play_button_click()
	if _build_list_instance != null and is_instance_valid(_build_list_instance):
		return
	_build_list_instance = BuildListScene.instantiate()
	_build_list_instance.build_completed.connect(_on_build_completed)
	add_child(_build_list_instance)


# ================================= 建造完成回调（来自 build_list） =================================
func _on_build_completed(build_id: int) -> void:
	print(">>> [BuildingUI] 建造完成(build_list): %d" % build_id)
	var build_config = BuildConfigLoader.new().get_build(build_id)
	if build_config.is_empty():
		return
	var exp_reward: int = build_config.get("expReward", 0)
	if exp_reward <= 0:
		return
	var end_pos: Vector2 = _get_exp_bar_center()
	var start_pos: Vector2 = Vector2(540, 400)
	_play_explosion_then_fly(start_pos, end_pos, exp_reward)


# ================================= GridManager 建造经验奖励回调 =================================
func _on_build_exp_reward(furniture_world_pos: Vector2, exp_amount: int, _build_id: int) -> void:
	print(">>> [BuildingUI] _on_build_exp_reward: pos=%s, exp=%d" % [furniture_world_pos, exp_amount])
	# 将世界坐标转换为屏幕坐标（CanvasLayer 子节点使用屏幕空间）
	var start_pos: Vector2 = get_viewport().get_canvas_transform() * furniture_world_pos
	print(">>> [BuildingUI] 坐标转换: world=%s → screen=%s, canvas_transform=%s" % [furniture_world_pos, start_pos, get_viewport().get_canvas_transform()])
	var end_pos: Vector2 = _get_exp_bar_center()
	_play_explosion_then_fly(start_pos, end_pos, exp_amount)


# ================================= 获取经验条中心位置 =================================
func _get_exp_bar_center() -> Vector2:
	var exp_bar = find_child("ExpProgressBar", true, false)
	if exp_bar != null:
		return exp_bar.global_position + Vector2(exp_bar.size.x / 2, exp_bar.size.y / 2)
	return Vector2(120, 120)


# ================================= 爆炸粒子 + 飞向经验条 =================================
func _play_explosion_then_fly(start_pos: Vector2, end_pos: Vector2, exp_amount: int) -> void:
	var EXP_ICON := preload("res://art/sprites/UI/icon/jingyan.png")
	var particle_container := Node2D.new()
	particle_container.global_position = start_pos
	add_child(particle_container)

	var particle_count: int = clampi(randi_range(8, 12), 8, 12)
	var particles: Array[Sprite2D] = []

	# Phase 1: 爆炸散开 (0.3s)
	for i in range(particle_count):
		var particle := Sprite2D.new()
		particle.texture = EXP_ICON
		particle.scale = Vector2(0.8, 0.8)
		particle.global_position = start_pos
		particle_container.add_child(particle)
		particles.append(particle)

		var angle: float = TAU * float(i) / float(particle_count) + randf_range(-0.2, 0.2)
		var scatter_dist: float = randf_range(40, 80)
		var scatter_pos: Vector2 = start_pos + Vector2(cos(angle), sin(angle)) * scatter_dist

		var scatter_tween := create_tween()
		scatter_tween.tween_property(particle, "global_position", scatter_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		scatter_tween.tween_property(particle, "scale", Vector2(1.2, 1.2), 0.3)

	# Phase 2: 收束飞向经验条 (0.4s) - 延迟 0.3s 后开始
	await get_tree().create_timer(0.3).timeout
	for particle in particles:
		if not is_instance_valid(particle):
			continue
		var fly_tween := create_tween()
		var random_offset := Vector2(randf_range(-15, 15), randf_range(-15, 15))
		fly_tween.tween_property(particle, "global_position", end_pos + random_offset, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly_tween.parallel().tween_property(particle, "scale", Vector2(0.6, 0.6), 0.4)
		fly_tween.tween_property(particle, "modulate:a", 0.0, 0.1)

	# Phase 3: 粒子到达后添加经验
	await get_tree().create_timer(0.45).timeout
	TaskManager.add_exp(exp_amount)
	_update_exp_bar()
	print(">>> [BuildingUI] 经验粒子到达，添加经验: %d" % exp_amount)

	# 清理
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(particle_container):
		particle_container.queue_free()


# ================================= 旧版经验粒子特效（保留兼容） =================================
func _play_exp_particle_effect(start_pos: Vector2, end_pos: Vector2, exp_amount: int) -> void:
	_play_explosion_then_fly(start_pos, end_pos, exp_amount)


# ================================= 更新经验条 =================================
func _update_exp_bar() -> void:
	var exp_bar = find_child("ExpProgressBar", true, false)
	if exp_bar == null:
		return
	var current_exp: int = TaskManager.exp
	# 每100经验升一级
	@warning_ignore("integer_division")
	var level_exp: int = current_exp % 100
	exp_bar.value = level_exp


func _on_exp_changed(_new_exp: int) -> void:
	_update_exp_bar()


# ================================= 更新等级显示 =================================
func _update_level_display() -> void:
	var level_label = find_child("LevelLabel", true, false)
	if level_label != null:
		level_label.text = "Lv.%d" % TaskManager.get_level()


# ================================= 升级回调 =================================
func _on_level_up(new_level: int) -> void:
	print(">>> [BuildingUI] 升级! new_level=%d" % new_level)
	_update_level_display()
	_update_exp_bar()
	# 获取升级奖励
	var levels_data: Dictionary = _level_config.get("levels", {})
	var level_key: String = str(new_level)
	if not levels_data.has(level_key):
		print(">>> [BuildingUI] 无等级 %s 的奖励配置" % level_key)
		return
	var level_data: Dictionary = levels_data[level_key]
	var rewards: Dictionary = level_data.get("rewards", {})
	_show_level_up_popup(new_level, rewards)


# ================================= 升级弹窗 =================================
func _show_level_up_popup(new_level: int, rewards: Dictionary) -> void:
	var popup = PanelContainer.new()
	popup.name = "LevelUpPopup"
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.position = Vector2(-175, -150)
	popup.size = Vector2(350, 300)
	popup.z_index = 4000

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.95)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 0.85, 0.2, 1)
	popup.add_theme_stylebox_override("panel", style)

	add_child(popup)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	popup.add_child(vbox)

	# 标题
	var title = Label.new()
	title.text = "升级!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	vbox.add_child(title)

	# 等级
	var level_label = Label.new()
	level_label.text = "达到 Lv.%d" % new_level
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(level_label)

	# 奖励标题
	var reward_title = Label.new()
	reward_title.text = "获得奖励:"
	reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_title.add_theme_font_size_override("font_size", 16)
	reward_title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	vbox.add_child(reward_title)

	# 奖励内容
	var reward_hbox = HBoxContainer.new()
	reward_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(reward_hbox)

	var coin_reward: int = int(rewards.get("coin", 0))
	if coin_reward > 0:
		var coin_label = Label.new()
		coin_label.text = "金币 +%d" % coin_reward
		coin_label.add_theme_font_size_override("font_size", 16)
		coin_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		reward_hbox.add_child(coin_label)

	var item_rewards: Array = rewards.get("items", [])
	for item_id in item_rewards:
		var item_icon = TextureRect.new()
		item_icon.custom_minimum_size = Vector2(40, 40)
		item_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sprite_path: String = ItemManager.get_sprite_path(int(item_id))
		if sprite_path != "" and ResourceLoader.exists(sprite_path):
			item_icon.texture = load(sprite_path)
		reward_hbox.add_child(item_icon)

	# 确认按钮（居中）
	var center_container = CenterContainer.new()
	vbox.add_child(center_container)

	var confirm_btn = Button.new()
	confirm_btn.text = "领取"
	confirm_btn.custom_minimum_size = Vector2(120, 44)
	confirm_btn.pressed.connect(_on_level_up_confirm.bind(popup, rewards))
	center_container.add_child(confirm_btn)


func _on_level_up_confirm(popup: Control, rewards: Dictionary) -> void:
	# 按钮动画
	var tween := create_tween()
	tween.tween_property(popup, "scale", Vector2(1.05, 1.05), 0.1)
	tween.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.1)

	# 发放金币奖励
	var coin_reward: int = int(rewards.get("coin", 0))
	if coin_reward > 0:
		GameManager.add_gold(coin_reward)
		print(">>> [BuildingUI] 升级奖励: 金币 +%d" % coin_reward)

	# 发放物品奖励
	var item_rewards: Array = rewards.get("items", [])
	for item_id in item_rewards:
		GameManager.add_out_item(int(item_id))
		print(">>> [BuildingUI] 升级奖励: 物品 %d" % int(item_id))

	# 关闭弹窗
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(popup):
		popup.queue_free()
