extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var leaderboard_button: Button = $VBoxContainer/LeaderboardButton
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var settings_vbox: VBoxContainer = $SettingsPanel/SettingsVBox
@onready var language_button: Button = $SettingsPanel/SettingsVBox/LanguageRow/LanguageButton
@onready var volume_slider: HSlider = $SettingsPanel/SettingsVBox/VolumeRow/VolumeSlider
@onready var reset_tutorial_button: Button = $SettingsPanel/SettingsVBox/ResetTutorialButton
@onready var close_button: Button = $SettingsPanel/SettingsVBox/CloseButton
@onready var reset_confirm_label: Label = $SettingsPanel/ResetConfirmLabel

# Web 环境必须用 preload 预加载字体，不能动态 load
@onready var chinese_font = preload("res://fonts/NotoSansSC-Regular.ttf")

# ---- 设置状态 ----
var settings_visible: bool = false


func _ready() -> void:
	# 全局设置中文字体（所有 Label 生效）
	ThemeDB.set_fallback_font(chinese_font)

	# 连接按钮信号
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	language_button.pressed.connect(_on_language_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	reset_tutorial_button.pressed.connect(_on_reset_tutorial_pressed)
	close_button.pressed.connect(_on_close_settings)

	# 初始化UI
	_update_language_button()
	_load_settings()


func _on_start_pressed() -> void:
	print(">>> [MainMenu] 开始游戏按钮被点击")
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")


func _on_settings_pressed() -> void:
	print(">>> [MainMenu] 设置按钮被点击")
	_show_settings()


func _on_leaderboard_pressed() -> void:
	print(">>> [MainMenu] 排行榜按钮被点击")
	get_tree().change_scene_to_file("res://scenes/leaderboard_scene.tscn")


func _show_settings() -> void:
	settings_visible = true
	settings_panel.visible = true
	_update_language_button()
	_reset_confirm_label_visible(false)


func _hide_settings() -> void:
	settings_visible = false
	settings_panel.visible = false


func _on_close_settings() -> void:
	_hide_settings()


func _on_language_toggled() -> void:
	# 切换语言
	var current_lang: String = LocalizationSystem.current_lang
	if current_lang == "en":
		LocalizationSystem.set_language("zh")
	else:
		LocalizationSystem.set_language("en")

	_update_language_button()
	_update_ui_texts()
	print(">>> [MainMenu] 语言切换为: %s" % LocalizationSystem.current_lang)


func _update_language_button() -> void:
	var current_lang: String = LocalizationSystem.current_lang
	if current_lang == "en":
		language_button.text = "EN"
	else:
		language_button.text = "中文"


func _update_ui_texts() -> void:
	# 更新设置面板文本
	var settings_title: Label = $SettingsPanel/SettingsVBox/SettingsTitle
	settings_title.text = LocalizationSystem.get_text("settings.title")

	var language_label: Label = $SettingsPanel/SettingsVBox/LanguageRow/LanguageLabel
	language_label.text = LocalizationSystem.get_text("settings.language")

	var volume_label: Label = $SettingsPanel/SettingsVBox/VolumeRow/VolumeLabel
	volume_label.text = LocalizationSystem.get_text("settings.volume")

	reset_tutorial_button.text = LocalizationSystem.get_text("settings.reset_tutorial")
	close_button.text = LocalizationSystem.get_text("settings.close")


func _on_volume_changed(value: float) -> void:
	# 保存音量设置
	_save_settings()
	# 注意: 实际音量控制需要AudioServer，这里仅保存设置
	print(">>> [MainMenu] 音量设置为: %.1f" % value)


func _on_reset_tutorial_pressed() -> void:
	# 重置教程状态
	GameManager.reset_tutorial()
	_reset_confirm_label_visible(true)


func _reset_confirm_label_visible(visible: bool) -> void:
	reset_confirm_label.visible = visible
	if visible:
		reset_confirm_label.text = LocalizationSystem.get_text("settings.reset_confirm")


func _load_settings() -> void:
	# 从配置文件加载设置
	var config := ConfigFile.new()
	var err := config.load("user://settings.cfg")
	if err == OK:
		var volume: float = config.get_value("audio", "volume", 1.0)
		volume_slider.value = volume


func _save_settings() -> void:
	# 保存设置到配置文件
	var config := ConfigFile.new()
	config.set_value("audio", "volume", volume_slider.value)
	config.save("user://settings.cfg")
