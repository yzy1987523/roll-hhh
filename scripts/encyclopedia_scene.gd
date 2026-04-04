extends Control

## 图鉴系统（弹窗模式）
## 9个角色图片 + 1-9级进化路线 + 详情弹窗

const CELL_SIZE := 180
const CELL_SPACING := 10
const SPRITE_SIZE := 168
const CELL_TEXTURE := preload("res://art/sprites/UI/items/smallItem/cell_0.png")
const CELL_SELECTED_TEXTURE := preload("res://art/sprites/UI/items/smallItem/cell_1.png")
const CLOSE_TEXTURE := preload("res://art/sprites/UI/items/smallItem/close.png")

const ALL_JOBS := [
	{"id": 0, "name": "战士", "char_type": 1},
	{"id": 1, "name": "法师", "char_type": 2},
	{"id": 2, "name": "牧师", "char_type": 3},
	{"id": 10, "name": "狂战士", "char_type": 4},
	{"id": 11, "name": "骑士", "char_type": 4},
	{"id": 20, "name": "冰法", "char_type": 4},
	{"id": 21, "name": "火法", "char_type": 4},
	{"id": 30, "name": "暗牧", "char_type": 4},
	{"id": 31, "name": "圣骑士", "char_type": 4},
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

@onready var close_button: TextureButton = $EncyclopediaWindow/VBox/TitleBar/CloseButton
@onready var job_grid: GridContainer = $EncyclopediaWindow/VBox/MainHBox/LeftPanel/JobGrid
@onready var evolution_container: HFlowContainer = $EncyclopediaWindow/VBox/MainHBox/RightPanel/ScrollContainer/EvolutionContainer
@onready var evolution_title: Label = $EncyclopediaWindow/VBox/MainHBox/RightPanel/EvolutionTitle

var selected_job: int = -1
var job_cells: Array = []


func _ready() -> void:
	# 添加 panel.png 背景
	var encyclopedia_window = $EncyclopediaWindow
	if encyclopedia_window and (encyclopedia_window.get_child_count() == 0 or not encyclopedia_window.get_child(0).name == "PanelBg"):
		var panel_texture := preload("res://art/sprites/UI/panels/panel.png")
		var bg := TextureRect.new()
		bg.name = "PanelBg"
		bg.texture = panel_texture
		bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		encyclopedia_window.add_child(bg)
		encyclopedia_window.move_child(bg, 0)  # 移到最底层
	
	# 设置层级，确保在角色之上
	encyclopedia_window.z_index = 50
	
	close_button.texture_normal = CLOSE_TEXTURE
	close_button.pressed.connect(_on_close)
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
		
		# 角色名称（底部，最上层）
		var name_lbl := Label.new()
		name_lbl.text = job_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.position = Vector2(0, CELL_SIZE - 22)
		name_lbl.size = Vector2(CELL_SIZE, 20)
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
	var tex: Texture2D = null
	
	if job_id < 3:
		var path := "res://art/sprites/chars/char_%02d/char_%02d%02d01.png" % [char_type, char_type, level]
		tex = load(path) as Texture2D
		if tex:
			var rect := TextureRect.new()
			rect.texture = tex
			return rect
	
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
		evolution_title.text = "选择上方角色查看进化路线"
		return
	
	var job_name := _get_job_name(selected_job)
	evolution_title.text = "%s 的进化路线" % job_name
	
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
			_show_level_popup(job_id, level)


func _show_level_popup(job_id: int, level: int) -> void:
	var job_name := _get_job_name(job_id)
	var hp: int = _calc_hp(job_id, level)
	var atk: int = _calc_attack(job_id, level)
	var def: int = _calc_defense(job_id, level)
	var skill_lv: int = CharacterFactory.calc_skill_level(level)
	var skill_desc: String = _get_skill_description(job_id)
	var skill_full_desc: String = _get_skill_full_description(job_id, skill_lv)
	
	var content := "等级: %d\n\n属性:\n  血量: %d\n  攻击: %d\n  防御: %d\n\n%s\n%s" % [
		level, hp, atk, def, skill_desc, skill_full_desc
	]
	
	PopupSystem.show(
		"%s Lv.%d" % [job_name, level],
		content,
		"",
		"",
		"关闭",
		Callable(),
		Callable()
	)


func _get_job_name(job_id: int) -> String:
	var adv_name: String = JobAdvanced.get_advanced_job_name(job_id)
	if adv_name != "":
		return adv_name
	match job_id:
		0: return "战士"
		1: return "法师"
		2: return "牧师"
		_: return "未知"


func _get_skill_description(job_id: int) -> String:
	if JobAdvanced.is_advanced_job(job_id):
		match job_id:
			10: return "特技: 狂暴打击"
			11: return "特技: 坚守"
			20: return "特技: 冰霜护盾"
			21: return "特技: 火焰冲击"
			30: return "特技: 暗影庇护"
			31: return "特技: 圣光庇护"
			_: return "特技: 无"
	match job_id:
		0: return "特技: 格挡"
		1: return "特技: 穿透"
		2: return "特技: 治疗"
		_: return "特技: 无"


func _get_skill_full_description(job_id: int, skill_lv: int) -> String:
	var desc := ""
	match skill_lv:
		1: desc = "初级效果"
		2: desc = "中级效果"
		3: desc = "高级效果"
		4: desc = "终极效果"
		_: desc = "基础效果"
	return "特技等级: Lv.%d (%s)" % [skill_lv, desc]


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
	queue_free()


func _on_localization_changed(lang: String) -> void:
	print(">>> [Encyclopedia] 语言切换为: %s" % lang)
