extends Control

## 图鉴系统
## 任务 6.2: 角色详情 + 1-13级属性展示

# Job list (all jobs to display)
const ALL_JOBS := [
	{"id": 0, "name": "战士"},
	{"id": 1, "name": "法师"},
	{"id": 2, "name": "牧师"},
	{"id": 10, "name": "狂战士"},
	{"id": 11, "name": "骑士"},
	{"id": 12, "name": "大剑士"},
	{"id": 20, "name": "魔导师"},
	{"id": 21, "name": "死灵法师"},
	{"id": 30, "name": "大祭司"},
	{"id": 31, "name": "圣骑士"},
]

@onready var job_list: VBoxContainer = $MainHBox/LeftPanel/ScrollContainer/JobList
@onready var detail_panel: VBoxContainer = $MainHBox/RightPanel/DetailScroll/DetailContent
@onready var back_button: Button = $TopBar/BackButton
@onready var title_label: Label = $TopBar/TitleLabel

var selected_job: int = -1


func _ready() -> void:
	back_button.pressed.connect(_on_back)
	LocalizationSystem.language_changed.connect(_on_localization_changed)
	_build_job_list()
	print(">>> [Encyclopedia] 图鉴已打开")


func _build_job_list() -> void:
	for child in job_list.get_children():
		child.queue_free()

	for job_info in ALL_JOBS:
		var btn := Button.new()
		var job_id: int = job_info["id"]
		# Check if any level is unlocked for this job
		var any_unlocked: bool = _is_any_level_unlocked(job_id)

		if any_unlocked:
			btn.text = job_info["name"]
		else:
			btn.text = "???"
			btn.modulate = Color(0.5, 0.5, 0.5, 1)

		btn.pressed.connect(_on_job_selected.bind(job_id))
		job_list.add_child(btn)


func _is_any_level_unlocked(job_id: int) -> bool:
	var save_node = get_node_or_null("/root/SaveSystem")
	if save_node == null:
		return true  # Treat all as unlocked when SaveSystem not available
	for lv in range(1, 17):
		if save_node.is_encyclopedia_unlocked(job_id, lv):
			return true
	return false


func _on_job_selected(job_id: int) -> void:
	selected_job = job_id
	_show_job_details(job_id)


func _show_job_details(job_id: int) -> void:
	for child in detail_panel.get_children():
		child.queue_free()

	# Job name header
	var name_label := Label.new()
	var job_name: String = _get_job_name(job_id)
	name_label.text = job_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 40)
	detail_panel.add_child(name_label)

	# Skill description
	var skill_label := Label.new()
	skill_label.text = _get_skill_description(job_id)
	skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(skill_label)

	# Separator
	var sep := HSeparator.new()
	detail_panel.add_child(sep)

	# Stats table header
	var header := HBoxContainer.new()
	for col_name in ["等级", "血量", "攻击", "防御", "特技Lv"]:
		var lbl := Label.new()
		lbl.text = col_name
		lbl.custom_minimum_size = Vector2(60, 0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(lbl)
	detail_panel.add_child(header)

	# Stats rows for level 1-9
	var save_node = get_node_or_null("/root/SaveSystem")
	for lv in range(1, 10):
		var is_unlocked: bool = true  # Default unlocked when no SaveSystem
		if save_node:
			is_unlocked = save_node.is_encyclopedia_unlocked(job_id, lv)

		var row := HBoxContainer.new()

		if is_unlocked:
			var hp: int = _calc_hp(job_id, lv)
			var atk: int = _calc_attack(job_id, lv)
			var def: int = _calc_defense(job_id, lv)
			var skill_lv: int = CharacterFactory.calc_skill_level(lv)

			for val in [str(lv), str(hp), str(atk), str(def), str(skill_lv)]:
				var lbl := Label.new()
				lbl.text = val
				lbl.custom_minimum_size = Vector2(60, 0)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				row.add_child(lbl)
		else:
			# Locked - show level number but grey out stats
			var lv_lbl := Label.new()
			lv_lbl.text = str(lv)
			lv_lbl.custom_minimum_size = Vector2(60, 0)
			lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(lv_lbl)

			for i in range(4):
				var lbl := Label.new()
				lbl.text = "?"
				lbl.custom_minimum_size = Vector2(60, 0)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.modulate = Color(0.4, 0.4, 0.4, 1)
				row.add_child(lbl)

		# Highlight skill upgrade levels (3, 5, 7, 9)
		if lv in CharacterFactory.SKILL_UPGRADE_LEVELS:
			row.modulate = Color(1.0, 0.9, 0.6, 1)

		detail_panel.add_child(row)


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
			10: return "特技: 狂暴打击 - 攻击时概率造成双倍伤害"
			11: return "特技: 坚守 - 每2回合格挡一次伤害"
			12: return "特技: 横扫 - 攻击附带溅射伤害"
			20: return "特技: 魔力爆发 - 穿透伤害增强"
			21: return "特技: 亡灵召唤 - 击杀后回复自身生命"
			30: return "特技: 神圣祷言 - 回复范围和量增强"
			31: return "特技: 圣光庇护 - 为周围队友提供护盾"
			_: return ""
	match job_id:
		0: return "特技: 格挡 - 每3回合格挡一次伤害"
		1: return "特技: 穿透 - 每回合额外造成穿透伤害"
		2: return "特技: 治疗 - 每回合为身旁己方伤员回复血量"
		_: return ""


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
	title_label.text = LocalizationSystem.get_text("encyclopedia.title")
	back_button.text = LocalizationSystem.get_text("encyclopedia.back")
	# 重建图鉴列表以应用新语言
	_build_job_list()
	print(">>> [Encyclopedia] 语言切换为: %s" % lang)
