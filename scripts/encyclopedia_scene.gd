extends Control

## 图鉴系统（弹窗模式）
## 9个角色图片 + 1-9级进化路线 + 详情弹窗

const CELL_SIZE := 130
const CELL_SPACING := 10
const SPRITE_SIZE := 118
const CELL_TEXTURE := preload("res://art/sprites/UI/items/smallItem/cell_0.png")
const CELL_SELECTED_TEXTURE := preload("res://art/sprites/UI/items/smallItem/cell_1.png")

# 图鉴显示顺序：按职业类型分列（战士、法师、牧师各一列）
const ALL_JOBS := [
	{"id": 0, "name": "战士", "char_type": 1},      # 战士列
	{"id": 1, "name": "法师", "char_type": 2},      # 法师列
	{"id": 2, "name": "牧师", "char_type": 3},      # 牧师列
	{"id": 10, "name": "狂战士", "char_type": 5},   # 战士转职
	{"id": 20, "name": "冰法", "char_type": 6},     # 法师转职
	{"id": 30, "name": "暗牧", "char_type": 8},     # 牧师转职
	{"id": 11, "name": "骑士", "char_type": 4},     # 战士转职
	{"id": 21, "name": "火法", "char_type": 7},     # 法师转职
	{"id": 31, "name": "圣骑士", "char_type": 9},   # 牧师转职
]

const EVOLUTION_LEVELS := [1, 2, 3, 4, 5, 6, 7, 8, 9]

const JOB_COLORS := {
	0: Color(0.85, 0.25, 0.25),
	1: Color(0.4, 0.25, 0.85),
	2: Color(0.25, 0.7, 0.25),
	10: Color(0.9, 0.3, 0.1),
	11: Color(0.5, 0.5, 0.6),
	20: Color(0.3, 0.8, 0.9),
	21: Color(0.9, 0.4, 0.1),
	30: Color(0.4, 0.2, 0.5),
	31: Color(0.9, 0.85, 0.5),
}

@onready var close_button: TextureButton = $EncyclopediaWindow/ContentMargin/VBox/TitleBarMargin/TitleBar/CloseButton
@onready var title_label: Label = $EncyclopediaWindow/ContentMargin/VBox/TitleBarMargin/TitleBar/TitleLabel
@onready var section_title: Label = $EncyclopediaWindow/ContentMargin/VBox/TopPanel/SectionTitle
@onready var job_grid: GridContainer = $EncyclopediaWindow/ContentMargin/VBox/TopPanel/JobGridCenter/JobGrid
@onready var evolution_scroll: ScrollContainer = $EncyclopediaWindow/ContentMargin/VBox/BottomPanel/ScrollWrapper/ScrollContainer
@onready var evolution_container: HBoxContainer = $EncyclopediaWindow/ContentMargin/VBox/BottomPanel/ScrollWrapper/ScrollContainer/ContentMargin/EvolutionContainer
@onready var evolution_title: Label = $EncyclopediaWindow/ContentMargin/VBox/BottomPanel/EvolutionTitle

var selected_job: int = -1
var job_cells: Array = []

# 拖拽滚动相关
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var scroll_start_x: float = 0.0
const DRAG_THRESHOLD: float = 10.0  # 超过此距离视为拖拽


func _ready() -> void:
	# 移除 PanelContainer 默认黑底
	var encyclopedia_window = $EncyclopediaWindow
	var empty_style := StyleBoxEmpty.new()
	encyclopedia_window.add_theme_stylebox_override("panel", empty_style)
	
	# 设置遮罩层级（在窗口之下）
	var dark_overlay = $DarkOverlay
	if dark_overlay:
		dark_overlay.z_index = 100
		dark_overlay.z_as_relative = false

	# 设置标题
	if title_label:
		title_label.text = LocalizationSystem.get_text("encyclopedia.title")
	if section_title:
		section_title.text = LocalizationSystem.get_text("encyclopedia.section_title")

	# 为 ScrollContainer 添加拖拽滚动支持
	evolution_scroll.gui_input.connect(_on_evolution_scroll_input)
	
	# 隐藏滚动条
	var h_scroll: HScrollBar = evolution_scroll.get_h_scroll_bar()
	var v_scroll: VScrollBar = evolution_scroll.get_v_scroll_bar()
	if h_scroll:
		h_scroll.modulate.a = 0
	if v_scroll:
		v_scroll.modulate.a = 0
	
	close_button.pressed.connect(_on_close)
	_add_button_feedback(close_button)
	LocalizationSystem.language_changed.connect(_on_localization_changed)
	_build_job_grid()
	_update_evolution_display()
	print(">>> [Encyclopedia] 图鉴已打开")


func _build_job_grid() -> void:
	for child in job_grid.get_children():
		child.queue_free()
	job_cells.clear()
	
	job_grid.columns = 3
	job_grid.add_theme_constant_override("h_separation", CELL_SPACING)
	job_grid.add_theme_constant_override("v_separation", CELL_SPACING)

	for job_info in ALL_JOBS:
		var job_id: int = job_info["id"]
		var cell := _create_job_cell(job_id, job_info["name"], job_info["char_type"])
		job_grid.add_child(cell)
		job_cells.append(cell)


func _create_job_cell(job_id: int, job_name: String, char_type: int) -> Control:
	# 使用 Control 作为容器，支持纹理叠加
	var container := Control.new()
	container.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	container.size = Vector2(CELL_SIZE, CELL_SIZE)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.clip_contents = true  # 裁剪超出内容
	
	var any_unlocked: bool = _is_any_level_unlocked(job_id)
	
	# 底层：cell_0 格子背景
	var cell_bg := TextureRect.new()
	cell_bg.texture = CELL_TEXTURE
	cell_bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	cell_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cell_bg.modulate = Color(1, 1, 1, 1)  # 保持原色
	cell_bg.size = Vector2(CELL_SIZE, CELL_SIZE)
	container.add_child(cell_bg)
	
	# 选中框：cell_1（在角色下方，初始隐藏）
	var selection_frame := TextureRect.new()
	selection_frame.texture = CELL_SELECTED_TEXTURE
	selection_frame.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	selection_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	selection_frame.modulate = Color(1, 1, 1, 1)
	selection_frame.size = Vector2(CELL_SIZE, CELL_SIZE)
	selection_frame.visible = false
	selection_frame.name = "SelectionFrame"
	container.add_child(selection_frame)
	
	if any_unlocked:
		# 角色精灵（居中显示，最上层）
		var sprite := _create_job_sprite(job_id, 1, char_type)
		sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.custom_minimum_size = Vector2(SPRITE_SIZE, SPRITE_SIZE)
		sprite.size = Vector2(SPRITE_SIZE, SPRITE_SIZE)
		sprite.position = Vector2((CELL_SIZE - SPRITE_SIZE) / 2.0, (CELL_SIZE - SPRITE_SIZE) / 2.0 - 10)
		container.add_child(sprite)
		
		# 角色名称（底部，最上层，隐藏）
		var name_lbl := Label.new()
		name_lbl.text = job_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.position = Vector2(0, CELL_SIZE - 22)
		name_lbl.size = Vector2(CELL_SIZE, 20)
		name_lbl.visible = false
		container.add_child(name_lbl)
	else:
		var unknown := Label.new()
		unknown.text = "?"
		unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unknown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		unknown.add_theme_font_size_override("font_size", 48)
		unknown.modulate = Color(0.5, 0.5, 0.5)
		unknown.size = Vector2(CELL_SIZE, CELL_SIZE)
		container.add_child(unknown)
	
	container.gui_input.connect(_on_job_cell_input.bind(job_id))
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	return container


func _create_job_sprite(job_id: int, level: int, char_type: int) -> TextureRect:
	# 加载图片
	var path := "res://art/sprites/chars/char_%02d/char_%02d%02d01.png" % [char_type, char_type, level]
	var tex: Texture2D = load(path) as Texture2D
	
	if tex:
		var rect := TextureRect.new()
		rect.texture = tex
		return rect
	
	# 加载失败时返回纯色方块
	print(">>> [Encyclopedia] 无法加载图片: %s" % path)
	var rect := TextureRect.new()
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(JOB_COLORS.get(job_id, Color(0.5, 0.5, 0.5)))
	rect.texture = ImageTexture.create_from_image(img)
	return rect


func _is_any_level_unlocked(job_id: int) -> bool:
	var save_node = get_node_or_null("/root/SaveSystem")
	if save_node == null:
		return true
	for lv in range(1, 10):
		if save_node.is_encyclopedia_unlocked(job_id, lv):
			return true
	return false


func _on_job_cell_input(event: InputEvent, job_id: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			SoundSystem.play_button_click()
			# 检查是否有任何等级解锁
			if not _is_any_level_unlocked(job_id):
				TipManager.show_tip(LocalizationSystem.get_text("encyclopedia.character_locked"))
				return
			_select_job(job_id)


func _select_job(job_id: int) -> void:
	selected_job = job_id
	
	for i in range(job_cells.size()):
		var cell = job_cells[i]
		var job_info = ALL_JOBS[i]
		var selection_frame: TextureRect = cell.get_node_or_null("SelectionFrame")
		
		if selection_frame:
			selection_frame.visible = (job_info["id"] == job_id)
	
	_update_evolution_display()


func _update_evolution_display() -> void:
	for child in evolution_container.get_children():
		child.queue_free()
	
	if selected_job < 0:
		evolution_title.text = LocalizationSystem.get_text("encyclopedia.evolution_hint")
		return

	var job_name := _get_job_name(selected_job)
	evolution_title.text = LocalizationSystem.get_text("encyclopedia.evolution_route", {"name": job_name})
	
	var job_color: Color = JOB_COLORS.get(selected_job, Color(0.5, 0.5, 0.5))
	var char_type: int = 1
	for job_info in ALL_JOBS:
		if job_info["id"] == selected_job:
			char_type = job_info["char_type"]
			break
	
	for level in EVOLUTION_LEVELS:
		var level_cell := _create_evolution_cell(selected_job, level, job_color, char_type)
		evolution_container.add_child(level_cell)


func _create_evolution_cell(job_id: int, level: int, job_color: Color, char_type: int) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE + 20)
	container.size = Vector2(CELL_SIZE, CELL_SIZE + 20)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.clip_contents = true  # 裁剪超出内容
	
	var is_unlocked: bool = _is_level_unlocked(job_id, level)
	
	# 底层：cell_0 格子背景
	var cell_bg := TextureRect.new()
	cell_bg.texture = CELL_TEXTURE
	cell_bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	cell_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cell_bg.modulate = Color(1, 1, 1, 1) if is_unlocked else Color(0.5, 0.5, 0.5, 1)
	cell_bg.size = Vector2(CELL_SIZE, CELL_SIZE)
	container.add_child(cell_bg)
	
	if is_unlocked:
		# 角色精灵（居中显示）
		var sprite := _create_job_sprite(job_id, level, char_type)
		sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.custom_minimum_size = Vector2(SPRITE_SIZE, SPRITE_SIZE)
		sprite.size = Vector2(SPRITE_SIZE, SPRITE_SIZE)
		sprite.position = Vector2((CELL_SIZE - SPRITE_SIZE) / 2.0, (CELL_SIZE - SPRITE_SIZE) / 2.0 - 10)
		container.add_child(sprite)
	else:
		var unknown := Label.new()
		unknown.text = "?"
		unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unknown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		unknown.add_theme_font_size_override("font_size", 32)
		unknown.modulate = Color(0.5, 0.5, 0.5)
		unknown.size = Vector2(CELL_SIZE, CELL_SIZE)
		container.add_child(unknown)
	
	# 等级标签（底部）
	var level_lbl := Label.new()
	level_lbl.text = "Lv.%d" % level
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_font_size_override("font_size", 14)
	if not is_unlocked:
		level_lbl.modulate = Color(0.5, 0.5, 0.5)
	level_lbl.position = Vector2(0, CELL_SIZE)
	level_lbl.size = Vector2(CELL_SIZE, 20)
	container.add_child(level_lbl)
	
	container.gui_input.connect(_on_evolution_input.bind(job_id, level))
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	return container


func _is_level_unlocked(job_id: int, level: int) -> bool:
	var save_node = get_node_or_null("/root/SaveSystem")
	if save_node == null:
		return true
	return save_node.is_encyclopedia_unlocked(job_id, level)


func _on_evolution_input(event: InputEvent, job_id: int, level: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# 记录按下位置（用于判断是否拖拽）
			is_dragging = false
			drag_start_pos = mb.global_position
			scroll_start_x = evolution_scroll.scroll_horizontal
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			# 抬起时判断：如果没有拖拽，则视为点击
			if not is_dragging:
				SoundSystem.play_button_click()
				# 检查是否解锁
				if not _is_level_unlocked(job_id, level):
					TipManager.show_tip(LocalizationSystem.get_text("encyclopedia.character_locked"))
					return
				_show_level_popup(job_id, level)
			is_dragging = false
	
	elif event is InputEventMouseMotion:
		# 拖拽滚动（仅在左键按住时）
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var drag_delta: float = drag_start_pos.x - event.global_position.x
			if abs(drag_delta) > DRAG_THRESHOLD:
				is_dragging = true
			if is_dragging:
				evolution_scroll.scroll_horizontal = int(scroll_start_x + drag_delta)


## ScrollContainer 拖拽滚动处理（空白区域）
func _on_evolution_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				is_dragging = false
				drag_start_pos = mb.global_position
				scroll_start_x = evolution_scroll.scroll_horizontal
			else:
				is_dragging = false
	
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var drag_delta: float = drag_start_pos.x - event.global_position.x
			if abs(drag_delta) > DRAG_THRESHOLD:
				is_dragging = true
			if is_dragging:
				evolution_scroll.scroll_horizontal = int(scroll_start_x + drag_delta)


func _show_level_popup(job_id: int, level: int) -> void:
	var job_name := _get_job_name(job_id)
	var hp: int = _calc_hp(job_id, level)
	var atk: int = _calc_attack(job_id, level)
	var def: int = _calc_defense(job_id, level)
	var skill_lv: int = CharacterFactory.calc_skill_level(level)
	var skill_desc: String = _get_skill_description(job_id)
	var skill_full_desc: String = _get_skill_full_description(job_id, skill_lv)
	
	var content := "%s: %d\n\n%s:\n  %s: %d\n  %s: %d\n  %s: %d\n\n%s\n%s" % [
		LocalizationSystem.get_text("encyclopedia.level_label"), level,
		LocalizationSystem.get_text("encyclopedia.hp_label"),
		LocalizationSystem.get_text("encyclopedia.hp_label"), hp,
		LocalizationSystem.get_text("encyclopedia.attack_label"), atk,
		LocalizationSystem.get_text("encyclopedia.defense_label"), def,
		skill_desc, skill_full_desc
	]
	
	PopupSystem.show(
		LocalizationSystem.get_text("encyclopedia.level_format", {"name": job_name, "level": level}),
		content,
		"",
		"",
		LocalizationSystem.get_text("encyclopedia.back"),
		Callable(),
		Callable()
	)


func _get_job_name(job_id: int) -> String:
	var adv_name: String = JobAdvanced.get_advanced_job_name(job_id)
	if adv_name != "":
		return adv_name
	match job_id:
		0: return LocalizationSystem.get_text("jobs.warrior")
		1: return LocalizationSystem.get_text("jobs.mage")
		2: return LocalizationSystem.get_text("jobs.priest")
		_: return LocalizationSystem.get_text("jobs.unknown")


func _get_skill_id(job_id: int) -> int:
	# 返回角色的特技ID
	if JobAdvanced.is_advanced_job(job_id):
		return JobAdvanced.ADVANCED_BASE.get(job_id, {}).get("skill_id", 0)
	match job_id:
		0: return 1001  # 战士格挡
		1: return 1002  # 法师穿透
		2: return 1003  # 牧师治疗
		_: return 0


func _get_skill_description(job_id: int) -> String:
	var skill_id: int = _get_skill_id(job_id)
	if skill_id == 0:
		return LocalizationSystem.get_text("encyclopedia.skill_label") + ": " + LocalizationSystem.get_text("encyclopedia.no_skill")
	
	var skill_name: String = LocalizationSystem.get_text("skill.%d_name" % skill_id, {})
	return LocalizationSystem.get_text("encyclopedia.skill_label") + ": " + skill_name


func _get_skill_full_description(job_id: int, skill_lv: int) -> String:
	var skill_id: int = _get_skill_id(job_id)
	if skill_id == 0:
		return ""
	
	var skill_desc: String = LocalizationSystem.get_text("skill.%d_desc" % skill_id, {})
	var level_text: String = ""
	if skill_lv > 0:
		level_text = " (Lv.%d)" % skill_lv
	
	return LocalizationSystem.get_text("encyclopedia.effect_label") + ": " + skill_desc + level_text


func _calc_hp(job_id: int, level: int) -> int:
	if JobAdvanced.is_advanced_job(job_id):
		return JobAdvanced.calc_advanced_hp(job_id, level)
	return CharacterFactory.calc_hp(job_id, level)


func _calc_attack(job_id: int, level: int) -> int:
	if JobAdvanced.is_advanced_job(job_id):
		return JobAdvanced.calc_advanced_attack(job_id, level)
	return CharacterFactory.calc_attack(job_id, level)


func _calc_defense(job_id: int, level: int) -> int:
	if JobAdvanced.is_advanced_job(job_id):
		return JobAdvanced.calc_advanced_defense(job_id, level)
	return CharacterFactory.calc_defense(job_id, level)


func _on_close() -> void:
	print(">>> [Encyclopedia] 关闭图鉴")
	SoundSystem.play_button_click()
	queue_free()


func _on_localization_changed(_lang: String) -> void:
	print(">>> [Encyclopedia] 语言切换为: %s" % _lang)
	# 更新标题
	if title_label:
		title_label.text = LocalizationSystem.get_text("encyclopedia.title")
	if section_title:
		section_title.text = LocalizationSystem.get_text("encyclopedia.section_title")
	_update_evolution_display()


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
