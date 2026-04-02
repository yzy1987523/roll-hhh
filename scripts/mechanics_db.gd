extends Node

## 机制数据库
## 所有游戏机制配置表查询接口
## 注意: 此脚本作为Autoload加载, 无需class_name

# ---- 静态配置数据 (从JSON加载) ----
static var _relics_config: Array = []
static var _items_config: Array = []
static var _elite_skills_config: Array = []
static var _boss_skills_config: Array = []
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	var file := FileAccess.open("res://configs/mechanics.json", FileAccess.READ)
	if file:
		var text := file.get_as_text()
		file.close()
		var json := JSON.new()
		if json.parse(text) == OK and json.data is Dictionary:
			var data: Dictionary = json.data
			_relics_config = data.get("relics", [])
			_items_config = data.get("items", [])
			_elite_skills_config = data.get("elite_skills", [])
			_boss_skills_config = data.get("boss_skills", [])
			print(">>> [MechanicsDb] 机制配置已加载: %d遗物 %d道具 %d精英技能 %dBOSS技能" % [
				_relics_config.size(), _items_config.size(),
				_elite_skills_config.size(), _boss_skills_config.size()
			])


# ======== 遗物查询 ========

static func get_relic_effect(relic_id: int) -> Dictionary:
	_ensure_loaded()
	for cfg in _relics_config:
		if cfg.get("id", 0) == relic_id:
			return cfg
	return {}


static func get_all_relics() -> Array:
	_ensure_loaded()
	return _relics_config.duplicate()


static func get_relic_by_id(relic_id: int) -> Dictionary:
	return get_relic_effect(relic_id)


# ======== 道具查询 ========

static func get_item_effect(item_id: int) -> Dictionary:
	_ensure_loaded()
	for cfg in _items_config:
		if cfg.get("id", 0) == item_id:
			return cfg
	return {}


static func get_all_items() -> Array:
	_ensure_loaded()
	return _items_config.duplicate()


static func get_item_by_id(item_id: int) -> Dictionary:
	return get_item_effect(item_id)


# ======== 精英技能查询 ========

static func get_elite_skill(skill_id: int) -> Dictionary:
	_ensure_loaded()
	for cfg in _elite_skills_config:
		if cfg.get("id", 0) == skill_id:
			return cfg
	return {}


static func get_all_elite_skills() -> Array:
	_ensure_loaded()
	return _elite_skills_config.duplicate()


# ======== BOSS技能查询 ========

static func get_boss_skill(skill_id: int) -> Dictionary:
	_ensure_loaded()
	for cfg in _boss_skills_config:
		if cfg.get("id", 0) == skill_id:
			return cfg
	return {}


static func get_all_boss_skills() -> Array:
	_ensure_loaded()
	return _boss_skills_config.duplicate()


# ======== 效果执行辅助 ========

## 检查是否拥有指定遗物
static func has_relic(relic_id: int, relics: Array) -> bool:
	for r in relics:
		if r.id == relic_id:
			return true
	return false


## 获取遗物效果类型
static func get_relic_effect_type(relic_id: int) -> String:
	var eff: Dictionary = get_relic_effect(relic_id)
	return eff.get("effect_type", "")


## 获取道具价格
static func get_item_price(item_id: int) -> int:
	var eff: Dictionary = get_item_effect(item_id)
	return eff.get("price", 0)


## 获取道具图标sprite名称
static func get_item_sprite(item_id: int) -> String:
	var eff: Dictionary = get_item_effect(item_id)
	return eff.get("sprite", "")


## 获取遗物图标sprite名称
static func get_relic_sprite(relic_id: int) -> String:
	var eff: Dictionary = get_relic_effect(relic_id)
	return eff.get("sprite", "")
