extends Node

## 国际化/本地化管理系统
## 使用配置表管理多语言文本

var config: Dictionary = {}
var current_lang: String = "en"

func _ready() -> void:
	load_config()

func load_config() -> void:
	var file_path := "res://configs/localization.json"
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open localization file: %s" % file_path)
		return

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_str)
	if parse_result != OK:
		push_error("Failed to parse localization JSON")
		return

	config = json.data
	current_lang = config.get("current_language", "en")

func get_text(key: String, replacements: Dictionary = {}) -> String:
	"""
	获取本地化文本
	key: 点分隔的键路径，如 "menu.start_game"
	replacements: 可选的替换变量，如 {"value": 100}
	"""
	var keys := key.split(".")
	var current: Variant = config.get("languages", {}).get(current_lang, {})

	for k in keys:
		if current is Dictionary:
			current = current.get(k, "")
		else:
			return key  # 未找到

	var text := str(current)

	# 替换变量
	for placeholder in replacements:
		text = text.replace("{" + placeholder + "}", str(replacements[placeholder]))

	return text

func set_language(lang: String) -> void:
	if config.get("languages", {}).has(lang):
		current_lang = lang
		config["current_language"] = lang
		save_config()

func save_config() -> void:
	var file_path := "res://configs/localization.json"
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write localization file")
		return

	var json_str := JSON.stringify(config, "\t")
	file.store_string(json_str)
	file.close()

func get_available_languages() -> Array:
	return config.get("languages", {}).keys()
