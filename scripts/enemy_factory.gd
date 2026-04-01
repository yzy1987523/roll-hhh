extends RefCounted
class_name EnemyFactory

## 敌人工厂
## 根据回合数和循环数生成敌人数据

# ---- 敌人类型 ----
const TYPE_NORMAL := 0
const TYPE_ELITE := 1
const TYPE_BOSS := 2

# ---- 基础属性 (1循环第1个普通敌人) ----
const BASE_NORMAL := { "hp": 8, "atk": 1, "def": 0 }
const BASE_ELITE := { "hp": 25, "atk": 3, "def": 1 }
const BASE_BOSS := { "hp": 70, "atk": 5, "def": 2 }

# ---- 每循环递增系数 ----
const CYCLE_SCALE_NORMAL := 0.3
const CYCLE_SCALE_ELITE := 0.4
const CYCLE_SCALE_BOSS := 0.5

# ---- 同循环内轮次递增 (普通敌人6个, 逐个变强) ----
const INTRA_CYCLE_SCALE := 0.1

# ---- 精英特技池 (2000系列) ----
const ELITE_SKILLS := [2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008]

# ---- BOSS特技池 (3000系列) ----
const BOSS_SKILLS := [3001, 3002, 3003, 3004, 3005, 3006, 3007, 3008]

# ---- 敌人ID分配 (20个敌人) ----
# Normal:  1-14  (6 per cycle)
# Elite:  15-18  (2 per cycle)
# Boss:   19-20  (1 per cycle)
const NORMAL_BASE_ID := 1
const ELITE_BASE_ID := 15
const BOSS_BASE_ID := 19

# ---- 配置数据 (从JSON加载, 静态) ----
static var _base_normal: Dictionary = BASE_NORMAL.duplicate()
static var _base_elite: Dictionary = BASE_ELITE.duplicate()
static var _base_boss: Dictionary = BASE_BOSS.duplicate()
static var _cycle_scale_normal: float = CYCLE_SCALE_NORMAL
static var _cycle_scale_elite: float = CYCLE_SCALE_ELITE
static var _cycle_scale_boss: float = CYCLE_SCALE_BOSS
static var _intra_cycle_scale: float = INTRA_CYCLE_SCALE
static var _elite_skills: Array = ELITE_SKILLS.duplicate()
static var _boss_skills: Array = BOSS_SKILLS.duplicate()
static var _loaded: bool = false

# ---- 敌人定义 (从JSON加载) ----
static var _enemy_definitions: Array = []


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	# 加载敌人基础参数
	var file := FileAccess.open("res://configs/enemies.json", FileAccess.READ)
	if file:
		var text := file.get_as_text()
		file.close()
		var json := JSON.new()
		if json.parse(text) == OK and json.data is Dictionary:
			var data: Dictionary = json.data
			var base_stats: Dictionary = data.get("base_stats", {})
			_base_normal = base_stats.get("normal", BASE_NORMAL)
			_base_elite = base_stats.get("elite", BASE_ELITE)
			_base_boss = base_stats.get("boss", BASE_BOSS)
			var cycle_scale: Dictionary = data.get("cycle_scale", {})
			_cycle_scale_normal = cycle_scale.get("normal", CYCLE_SCALE_NORMAL)
			_cycle_scale_elite = cycle_scale.get("elite", CYCLE_SCALE_ELITE)
			_cycle_scale_boss = cycle_scale.get("boss", CYCLE_SCALE_BOSS)
			_intra_cycle_scale = data.get("intra_cycle_scale", INTRA_CYCLE_SCALE)
			_elite_skills = data.get("elite_skills", ELITE_SKILLS)
			_boss_skills = data.get("boss_skills", BOSS_SKILLS)

	# 加载敌人定义 (名称、描述)
	var def_file := FileAccess.open("res://configs/enemy_definitions.json", FileAccess.READ)
	if def_file:
		var text := def_file.get_as_text()
		def_file.close()
		var json := JSON.new()
		if json.parse(text) == OK and json.data is Dictionary:
			_enemy_definitions = json.data.get("enemies", [])
			print(">>> [EnemyFactory] 敌人定义已加载: %d 个" % _enemy_definitions.size())


# ---- 敌人数据结构 ----
class EnemyData:
	var type: int = TYPE_NORMAL
	var hp: int = 0
	var max_hp: int = 0
	var attack: int = 0
	var defense: int = 0
	var skill_id: int = 0
	var skill_value: float = 1.0
	var name: String = ""
	var description: String = ""
	var enemy_id: int = 0  # 配置表中的敌人ID (1-20)

	func is_alive() -> bool:
		return hp > 0

	func take_damage(amount: int) -> int:
		var actual: int = maxi(amount, 0)
		hp = maxi(hp - actual, 0)
		return actual

	func get_type_name() -> String:
		match type:
			TYPE_NORMAL: return LocalizationSystem.get_text("enemy.normal")
			TYPE_ELITE: return LocalizationSystem.get_text("enemy.elite")
			TYPE_BOSS: return LocalizationSystem.get_text("enemy.boss")
			_: return LocalizationSystem.get_text("enemy.unknown")


## 根据当前回合生成敌人
static func create_enemy(current_round: int, cycle_count: int) -> EnemyData:
	_ensure_loaded()

	var enemy_type: int = _get_enemy_type(current_round)
	var enemy := EnemyData.new()
	enemy.type = enemy_type

	# 计算敌人配置ID (1-20)
	var cfg_id: int = _get_enemy_cfg_id(current_round, enemy_type, cycle_count)
	enemy.enemy_id = cfg_id

	# 从定义表获取名称和描述
	var def: Dictionary = _get_enemy_def(cfg_id)
	var name_key: String = def.get("name_key", "")
	var desc_key: String = def.get("desc_key", "")
	enemy.name = LocalizationSystem.get_text(name_key) if name_key else _get_default_name(cfg_id)
	enemy.description = LocalizationSystem.get_text(desc_key) if desc_key else ""

	match enemy_type:
		TYPE_NORMAL:
			_apply_normal_stats(enemy, current_round, cycle_count)
		TYPE_ELITE:
			_apply_elite_stats(enemy, current_round, cycle_count)
		TYPE_BOSS:
			_apply_boss_stats(enemy, current_round, cycle_count)

	enemy.max_hp = enemy.hp
	print(">>> [EnemyFactory] 生成 %s[%d]: %s HP=%d ATK=%d DEF=%d" % [
		enemy.get_type_name(), cfg_id, enemy.name, enemy.hp, enemy.attack, enemy.defense
	])
	return enemy


## 获取敌人定义字典
static func _get_enemy_def(cfg_id: int) -> Dictionary:
	for def in _enemy_definitions:
		if def.get("id", 0) == cfg_id:
			return def
	return {}


## 获取敌人配置ID (1-20)
static func _get_enemy_cfg_id(current_round: int, enemy_type: int, cycle_count: int) -> int:
	var pos_in_cycle: int = (current_round - 1) % 9  # 0-8

	if enemy_type == TYPE_NORMAL:
		# 6个普通位置循环
		var normal_positions := [0, 1, 3, 4, 6, 7]
		var idx: int = normal_positions.find(pos_in_cycle)  # 0-5
		return NORMAL_BASE_ID + idx + (cycle_count * 6) % 14

	elif enemy_type == TYPE_ELITE:
		# 2个精英位置循环
		var elite_positions := [2, 5]
		var idx: int = elite_positions.find(pos_in_cycle)  # 0-1
		return ELITE_BASE_ID + idx + (cycle_count * 2) % 4

	else:  # BOSS
		return BOSS_BASE_ID + (cycle_count % 2)


static func _get_default_name(cfg_id: int) -> String:
	if cfg_id <= 14:
		return LocalizationSystem.get_text("enemy.normal_name", {"round": cfg_id})
	elif cfg_id <= 18:
		return LocalizationSystem.get_text("enemy.elite_name", {"round": cfg_id - 14})
	else:
		return LocalizationSystem.get_text("enemy.boss_name", {"round": cfg_id - 18})


static func _get_enemy_type(current_round: int) -> int:
	var index: int = (current_round - 1) % 9
	match index:
		2, 5: return TYPE_ELITE
		8: return TYPE_BOSS
		_: return TYPE_NORMAL


static func _apply_normal_stats(enemy: EnemyData, current_round: int, cycle_count: int) -> void:
	var cycle_mult: float = 1.0 + cycle_count * _cycle_scale_normal
	var intra_index: int = _get_normal_index_in_cycle(current_round)
	var intra_mult: float = 1.0 + intra_index * _intra_cycle_scale

	enemy.hp = maxi(int(_base_normal.get("hp", 8) * cycle_mult * intra_mult), 1)
	enemy.attack = maxi(int(_base_normal.get("atk", 1) * cycle_mult * intra_mult), 1)
	enemy.defense = int(_base_normal.get("def", 0) * cycle_mult)
	enemy.skill_id = 0


static func _apply_elite_stats(enemy: EnemyData, _current_round: int, cycle_count: int) -> void:
	var cycle_mult: float = 1.0 + cycle_count * _cycle_scale_elite
	enemy.hp = maxi(int(_base_elite.get("hp", 25) * cycle_mult), 1)
	enemy.attack = maxi(int(_base_elite.get("atk", 3) * cycle_mult), 1)
	enemy.defense = int(_base_elite.get("def", 1) * cycle_mult)
	if _elite_skills.size() > 0:
		enemy.skill_id = _elite_skills[randi_range(0, _elite_skills.size() - 1)]
	else:
		enemy.skill_id = ELITE_SKILLS[randi_range(0, ELITE_SKILLS.size() - 1)]
	@warning_ignore("integer_division")
	enemy.skill_value = 1.0 + (cycle_count / 3) * 0.1


static func _apply_boss_stats(enemy: EnemyData, _current_round: int, cycle_count: int) -> void:
	var cycle_mult: float = 1.0 + cycle_count * _cycle_scale_boss
	enemy.hp = maxi(int(_base_boss.get("hp", 70) * cycle_mult), 1)
	enemy.attack = maxi(int(_base_boss.get("atk", 5) * cycle_mult), 1)
	enemy.defense = int(_base_boss.get("def", 2) * cycle_mult)
	if _boss_skills.size() > 0:
		enemy.skill_id = _boss_skills[randi_range(0, _boss_skills.size() - 1)]
	else:
		enemy.skill_id = BOSS_SKILLS[randi_range(0, BOSS_SKILLS.size() - 1)]
	enemy.skill_value = minf(1.0 + cycle_count * 0.05, 2.0)


static func _get_normal_index_in_cycle(current_round: int) -> int:
	var index_in_cycle: int = (current_round - 1) % 9
	var normal_positions := [0, 1, 3, 4, 6, 7]
	var pos: int = normal_positions.find(index_in_cycle)
	return maxi(pos, 0)
