extends RefCounted
class_name EnemyFactory

## 敌人工厂
## 根据回合数和循环数生成敌人数据

# ---- 敌人类型 ----
const TYPE_NORMAL := 0
const TYPE_ELITE := 1
const TYPE_BOSS := 2

# ---- 平衡调整参数 ----
# 普通敌人基础: HP 8, ATK 1, DEF 0
# 精英敌人基础: HP 25, ATK 3, DEF 1
# BOSS敌人基础: HP 70, ATK 5, DEF 2
# 普通缩放: +30%/循环
# 精英缩放: +40%/循环
# BOSS缩放: +50%/循环
# 金币奖励: 普通30, 精英60, BOSS100
# 初始能量: 36

# ---- 基础属性 (1循环第1个普通敌人) ----
const BASE_NORMAL := { "hp": 8, "atk": 1, "def": 0 }
const BASE_ELITE := { "hp": 25, "atk": 3, "def": 1 }
const BASE_BOSS := { "hp": 70, "atk": 5, "def": 2 }

# ---- 每循环递增系数 ----
const CYCLE_SCALE_NORMAL := 0.3   # 普通敌人每循环+30%
const CYCLE_SCALE_ELITE := 0.4    # 精英每循环+40%
const CYCLE_SCALE_BOSS := 0.5     # BOSS每循环+50%

# ---- 同循环内轮次递增 (普通敌人6个, 逐个变强) ----
const INTRA_CYCLE_SCALE := 0.1    # 同循环内每个普通敌人+10%

# ---- 精英特技池 (2000系列) ----
const ELITE_SKILLS := [2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008]

# ---- BOSS特技池 (3000系列) ----
const BOSS_SKILLS := [3001, 3002, 3003, 3004, 3005, 3006, 3007, 3008]


# ---- 敌人数据结构 ----
class EnemyData:
	var type: int = TYPE_NORMAL    # 0=普通, 1=精英, 2=BOSS
	var hp: int = 0
	var max_hp: int = 0
	var attack: int = 0
	var defense: int = 0
	var skill_id: int = 0          # 0=无特技
	var skill_value: float = 1.0   # 特技效果倍率
	var name: String = ""

	func is_alive() -> bool:
		return hp > 0

	func take_damage(amount: int) -> int:
		var actual: int = maxi(amount, 0)
		hp = maxi(hp - actual, 0)
		return actual

	func get_type_name() -> String:
		match type:
			TYPE_NORMAL: return "普通"
			TYPE_ELITE: return "精英"
			TYPE_BOSS: return "BOSS"
			_: return "未知"


## 根据当前回合生成敌人
static func create_enemy(current_round: int, cycle_count: int) -> EnemyData:
	var enemy_type: int = _get_enemy_type(current_round)
	var enemy := EnemyData.new()
	enemy.type = enemy_type

	match enemy_type:
		TYPE_NORMAL:
			_apply_normal_stats(enemy, current_round, cycle_count)
		TYPE_ELITE:
			_apply_elite_stats(enemy, current_round, cycle_count)
		TYPE_BOSS:
			_apply_boss_stats(enemy, current_round, cycle_count)

	enemy.max_hp = enemy.hp
	print(">>> [EnemyFactory] 生成 %s 敌人: HP=%d ATK=%d DEF=%d 特技=%d" % [
		enemy.get_type_name(), enemy.hp, enemy.attack, enemy.defense, enemy.skill_id
	])
	return enemy


static func _get_enemy_type(current_round: int) -> int:
	var index: int = (current_round - 1) % 9
	# 循环: 普通 普通 精英 普通 普通 精英 普通 普通 BOSS
	match index:
		2, 5: return TYPE_ELITE
		8: return TYPE_BOSS
		_: return TYPE_NORMAL


static func _apply_normal_stats(enemy: EnemyData, current_round: int, cycle_count: int) -> void:
	var cycle_mult: float = 1.0 + cycle_count * CYCLE_SCALE_NORMAL
	# 同循环内的普通敌人序号 (0-5)
	var intra_index: int = _get_normal_index_in_cycle(current_round)
	var intra_mult: float = 1.0 + intra_index * INTRA_CYCLE_SCALE

	enemy.hp = maxi(int(BASE_NORMAL["hp"] * cycle_mult * intra_mult), 1)
	enemy.attack = maxi(int(BASE_NORMAL["atk"] * cycle_mult * intra_mult), 1)
	enemy.defense = int(BASE_NORMAL["def"] * cycle_mult)
	enemy.skill_id = 0
	enemy.name = "普通敌人 R%d" % current_round


static func _apply_elite_stats(enemy: EnemyData, _current_round: int, cycle_count: int) -> void:
	var cycle_mult: float = 1.0 + cycle_count * CYCLE_SCALE_ELITE
	enemy.hp = maxi(int(BASE_ELITE["hp"] * cycle_mult), 1)
	enemy.attack = maxi(int(BASE_ELITE["atk"] * cycle_mult), 1)
	enemy.defense = int(BASE_ELITE["def"] * cycle_mult)
	# 随机精英特技
	enemy.skill_id = ELITE_SKILLS[randi_range(0, ELITE_SKILLS.size() - 1)]
	# 特技效果随循环增强: 每3轮循环+10%
	@warning_ignore("integer_division")
	enemy.skill_value = 1.0 + (cycle_count / 3) * 0.1
	enemy.name = "精英敌人 R%d" % _current_round


static func _apply_boss_stats(enemy: EnemyData, _current_round: int, cycle_count: int) -> void:
	var cycle_mult: float = 1.0 + cycle_count * CYCLE_SCALE_BOSS
	enemy.hp = maxi(int(BASE_BOSS["hp"] * cycle_mult), 1)
	enemy.attack = maxi(int(BASE_BOSS["atk"] * cycle_mult), 1)
	enemy.defense = int(BASE_BOSS["def"] * cycle_mult)
	# 随机BOSS特技
	enemy.skill_id = BOSS_SKILLS[randi_range(0, BOSS_SKILLS.size() - 1)]
	# BOSS特技: 每轮循环+5%, 上限+100%
	enemy.skill_value = minf(1.0 + cycle_count * 0.05, 2.0)
	enemy.name = "BOSS R%d" % _current_round


## 获取当前普通敌人在本循环中的序号 (0-5)
static func _get_normal_index_in_cycle(current_round: int) -> int:
	var index_in_cycle: int = (current_round - 1) % 9
	# 位置 0,1,3,4,6,7 是普通敌人, 映射到 0-5
	var normal_positions := [0, 1, 3, 4, 6, 7]
	var pos: int = normal_positions.find(index_in_cycle)
	return maxi(pos, 0)
