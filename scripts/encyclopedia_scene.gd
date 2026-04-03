extends Control

## 图鉴系统
## 9个角色图片 + 进化路线 + 详情弹窗

# 职业列表（3x3 网格）
const ALL_JOBS := [
	{"id": 0, "name": "战士"},
	{"id": 1, "name": "法师"},
	{"id": 2, "name": "牧师"},
	{"id": 10, "name": "狂战士"},
	{"id": 11, "name": "骑士"},
	{"id": 20, "name": "冰法"},
	{"id": 21, "name": "火法"},
	{"id": 30, "name": "暗牧"},
	{"id": 31, "name": "圣骑士"},
]

# 进化路线等级
const EVOLUTION_LEVELS := [1, 3, 6, 9]

# 职业颜色
const JOB_COLORS := {
	0: Color(0.85, 0.25, 0.25),   # 战士 - 红色
	1: Color(0.4, 0.25, 0.85),   # 法师 - 紫色
	2: Color(0.25, 0.7, 0.25),   # 牧师 - 绿色
	10: Color(0.9, 0.3, 0.1),    # 狂战士 - 深红
	11: Color(0.5, 0.5, 0.6),    # 骑士 - 银灰
	20: Color(0.3, 0.8, 0.9),     # 冰法 - 冰蓝
	21: Color(0.9, 0.4, 0.1),     # 火法 - 橙红
	30: Color(0.4, 0.2, 0.5),     # 暗牧 - 暗紫
	31: Color(0.9, 0.85, 0.5),    # 圣骑士 - 金色
}

@onready var back_button: Button = $TopBar/BackButton
@onready var job_grid: GridContainer = $MainHBox/LeftPanel/JobGrid
@onready var evolution_container: VBoxContainer = $MainHBox/RightPanel/EvolutionContainer
@onready var evolution_title: Label = $MainHBox/RightPanel/EvolutionTitle

var selected_job: int = -1  # 当前选中的职业ID
var job_cells: Array = []   # 职业格子节点列表


func _ready() -> void:
	back_button.pressed.connect(_on_back)
	LocalizationSystem.language_changed.connect(_on_localization_changed)
	_build_job_grid()
	_update_evolution_display()
	print(">>> [Encyclopedia] 图鉴已打开")


func _build_job_grid() -> void:
	# 清空旧内容
	for child in job_grid.get_children():
		child.queue_free()
	job_cells.clear()

	for job_info in ALL_JOBS:
		var job_id: int = job_info["id"]
		var cell := _create_job_cell(job_id, job_info["name"])
		job_grid.add_child(cell)
		job_cells.append(cell)


func _create_job_cell(job_id: int, job_name: String) -> Control:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(100, 100)
	
	# 检查是否解锁
	var any_unlocked: bool = _is_any_level_unlocked(job_id)
	
	# 样式
	var style := StyleBoxFlat.new()
	style.bg_color = JOB_COLORS.get(job_id, Color(0.5, 0.5, 0.5))
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	container.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	container.add_child(vbox)
	
	if any_unlocked:
		# 已解锁 - 显示职业图标
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(80, 60)
		icon.color = JOB_COLORS.get(job_id, Color(0.5, 0.5, 0.5))
		vbox.add_child(icon)
		
		# 职业名
		var name_lbl := Label.new()
		name_lbl.text = job_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 14)
		vbox.add_child(name_lbl)
	else:
		# 未解锁 - 显示问号
		var unknown := Label.new()
		unknown.text = "?"
		unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unknown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		unknown.add_theme_font_size_override("font_size", 48)
		unknown.modulate = Color(0.5, 0.5, 0.5)
		container.add_child(unknown)
	
	# 点击事件
	container.gui_input.connect(_on_job_cell_input.bind(job_id))
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	return container


func _is_any_level_unlocked(job_id: int) -> bool:
	var save_node = get_node_or_null("/root/SaveSystem")
	if save_node == null:
		return true  # 无存档系统时全部解锁
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
	
	# 更新格子高亮
	for i in range(job_cells.size()):
		var cell = job_cells[i]
		var job_info = ALL_JOBS[i]
		if job_info["id"] == job_id:
			# 选中高亮
			var style := StyleBoxFlat.new()
			style.bg_color = JOB_COLORS.get(job_id, Color(0.5, 0.5, 0.5))
			style.border_width_all = 3
			style.border_color = Color(1, 0.9, 0.5)
			style.corner_radius_top_left = 10
			style.corner_radius_top_right = 10
			style.corner_radius_bottom_left = 10
			style.corner_radius_bottom_right = 10
			cell.add_theme_stylebox_override("panel", style)
		else:
			# 取消高亮
			var style := StyleBoxFlat.new()
			style.bg_color = JOB_COLORS.get(job_info["id"], Color(0.5, 0.5, 0.5))
			style.corner_radius_top_left = 10
			style.corner_radius_top_right = 10
			style.corner_radius_bottom_left = 10
			style.corner_radius_bottom_right = 10
			cell.add_theme_stylebox_override("panel", style)
	
	_update_evolution_display()


func _update_evolution_display() -> void:
	# 清空进化路线容器
	for child in evolution_container.get_children():
		child.queue_free()
	
	if selected_job < 0:
		evolution_title.text = "选择上方角色查看进化路线"
		return
	
	var job_name := _get_job_name(selected_job)
	evolution_title.text = "%s 的进化路线" % job_name
	
	# 获取职业颜色
	var job_color: Color = JOB_COLORS.get(selected_job, Color(0.5, 0.5, 0.5))
	
	# 创建进化等级行
	var level_row := HFlowContainer.new()
	level_row.add_theme_constant_override("h_separation", 8)
	evolution_container.add_child(level_row)
	
	for level in EVOLUTION_LEVELS:
		var level_cell := _create_evolution_cell(selected_job, level, job_color)
		level_row.add_child(level_cell)
	
	# 进化箭头
	var arrow_row := HBoxContainer.new()
	arrow_row.alignment = BoxContainer.ALIGNMENT_CENTER
	evolution_container.add_child(arrow_row)
	
	for i in range(EVOLUTION_LEVELS.size() - 1):
		var arrow := Label.new()
		arrow.text = "→"
		arrow.add_theme_font_size_override("font_size", 20)
		arrow_row.add_child(arrow)


func _create_evolution_cell(job_id: int, level: int, job_color: Color) -> Control:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(90, 100)
	
	# 检查是否解锁
	var is_unlocked: bool = _is_level_unlocked(job_id, level)
	
	# 样式
	var style := StyleBoxFlat.new()
	style.bg_color = job_color if is_unlocked else Color(0.3, 0.3, 0.3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	container.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	container.add_child(vbox)
	
	# 等级图标
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(70, 55)
	icon.color = job_color if is_unlocked else Color(0.4, 0.4, 0.4)
	vbox.add_child(icon)
	
	# 等级标签
	var level_lbl := Label.new()
	level_lbl.text = "Lv.%d" % level
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_font_size_override("font_size", 14)
	if not is_unlocked:
		level_lbl.modulate = Color(0.5, 0.5, 0.5)
	vbox.add_child(level_lbl)
	
	# 点击事件
	container.gui_input.connect(_on_evolution_input.bind(job_id, level))
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	return container


func _is_level_unlocked(job_id: int, level: int) -> bool:
	var save_node = get_node_or_null("/root/SaveSystem")
	if save_node == null:
		return true  # 无存档系统时全部解锁
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


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")


func _on_localization_changed(lang: String) -> void:
	print(">>> [Encyclopedia] 语言切换为: %s" % lang)
