extends RefCounted
class_name CharacterFactory

## 角色工厂
## 负责角色属性成长计算和角色实例创建

# ---- 1级基础属性 (来自设计文档) ----
# [hp, defense, attack, skill_id]
const BASE_STATS := {
	DataModels.Job.WARRIOR: { "hp": 3, "def": 1, "atk": 1, "skill_id": 1001 },
	DataModels.Job.MAGE:    { "hp": 1, "def": 0, "atk": 2, "skill_id": 1002 },
	DataModels.Job.PRIEST:  { "hp": 2, "def": 0, "atk": 0, "skill_id": 1003 },
}

# ---- 每级成长系数 ----
# 合成升级: 两个同职业同等级 → 高1级
# 属性公式: base + floor(base * (level-1) * growth_rate)
# 战士: 高HP/DEF成长, 中等ATK成长 (坦克定位)
# 法师: 高ATK成长, 低HP/DEF成长 (输出定位)
# 牧师: 中等HP成长, 低ATK成长 (辅助定位, 0基础ATK不参与攻击)
const GROWTH_RATE := {
	DataModels.Job.WARRIOR: { "hp": 0.6, "def": 0.4, "atk": 0.45 },
	DataModels.Job.MAGE:    { "hp": 0.35, "def": 0.2, "atk": 0.5 },
	DataModels.Job.PRIEST:  { "hp": 0.45, "def": 0.25, "atk": 0.15 },
}

# ---- 最高等级 ----
const MAX_LEVEL := 9

# ---- 特技强化等级节点 ----
const SKILL_UPGRADE_LEVELS := [3, 5, 7, 9]

# ---- 唯一ID计数器 ----
static var _next_id: int = 1


# ---- 属性计算 ----

## 计算指定职业和等级的血量
static func calc_hp(job: int, level: int) -> int:
	var base: int = BASE_STATS[job]["hp"]
	var rate: float = GROWTH_RATE[job]["hp"]
	return base + int(floor(base * (level - 1) * rate))


## 计算指定职业和等级的防御
static func calc_defense(job: int, level: int) -> int:
	var base: int = BASE_STATS[job]["def"]
	var rate: float = GROWTH_RATE[job]["def"]
	return base + int(floor(base * (level - 1) * rate))


## 计算指定职业和等级的攻击
static func calc_attack(job: int, level: int) -> int:
	var base: int = BASE_STATS[job]["atk"]
	var rate: float = GROWTH_RATE[job]["atk"]
	return base + int(floor(base * (level - 1) * rate))


## 计算特技等级 (基于角色等级)
static func calc_skill_level(level: int) -> int:
	var skill_lv: int = 0
	for threshold in SKILL_UPGRADE_LEVELS:
		if level >= threshold:
			skill_lv += 1
	return skill_lv


# ---- 角色创建 ----

## 创建指定职业和等级的角色
static func create_character(job: int, level: int) -> DataModels.CharacterData:
	var ch := DataModels.CharacterData.new()
	ch.id = _next_id
	_next_id += 1
	ch.job = job
	ch.level = clampi(level, 1, MAX_LEVEL)
	ch.max_hp = calc_hp(job, ch.level)
	ch.hp = ch.max_hp
	ch.attack = calc_attack(job, ch.level)
	ch.defense = calc_defense(job, ch.level)
	ch.skill_id = BASE_STATS[job]["skill_id"]
	ch.skill_level = calc_skill_level(ch.level)
	ch.buffs = []
	ch.position = Vector2i(-1, -1)
	
	# 应用遗物加成
	_apply_stat_buff_relics(ch)
	
	return ch


## 随机生成角色 (1-3级随机, 职业随机)
static func create_random_character() -> DataModels.CharacterData:
	var job: int = randi_range(0, 2)
	var level: int = randi_range(1, 3)
	var ch := create_character(job, level)
	print(">>> [CharacterFactory] 生成 %s Lv.%d (HP:%d ATK:%d DEF:%d)" % [
		ch.get_job_name(), ch.level, ch.max_hp, ch.attack, ch.defense
	])
	return ch


## 合成升级: 两个同职业同等级角色 → 高1级角色
## 返回升级后的新角色, 失败返回 null
static func merge_characters(a: DataModels.CharacterData, b: DataModels.CharacterData) -> DataModels.CharacterData:
	if a.job != b.job:
		print(">>> [CharacterFactory] 合成失败: 职业不同 (%s vs %s)" % [a.get_job_name(), b.get_job_name()])
		return null
	if a.level != b.level:
		print(">>> [CharacterFactory] 合成失败: 等级不同 (%d vs %d)" % [a.level, b.level])
		return null
	if a.level >= MAX_LEVEL:
		print(">>> [CharacterFactory] 合成失败: 已达最高等级")
		return null

	var new_level: int = a.level + 1
	var ch := create_character(a.job, new_level)
	ch.position = a.position  # 继承位置
	print(">>> [CharacterFactory] 合成成功: %s Lv.%d → Lv.%d (HP:%d ATK:%d DEF:%d)" % [
		ch.get_job_name(), a.level, ch.level, ch.max_hp, ch.attack, ch.defense
	])
	return ch


## 重新计算角色属性 (用于遗物加成等场景)
## apply_relics: 是否应用遗物加成 (默认true)
static func recalc_stats(ch: DataModels.CharacterData, apply_relics: bool = true) -> void:
	ch.max_hp = calc_hp(ch.job, ch.level)
	ch.attack = calc_attack(ch.job, ch.level)
	ch.defense = calc_defense(ch.job, ch.level)
	ch.skill_level = calc_skill_level(ch.level)
	
	# 应用遗物加成
	if apply_relics:
		_apply_stat_buff_relics(ch)


## 应用 stat_buff 类型遗物的属性加成
static func _apply_stat_buff_relics(ch: DataModels.CharacterData) -> void:
	if not is_instance_valid(GameManager.board_data):
		return
	
	var relics: Array = GameManager.relics
	for relic in relics:
		var cfg: Dictionary = MechanicsDb.get_relic_effect(relic.id)
		if cfg.get("effect_type", "") != "stat_buff":
			continue
		
		var target: String = cfg.get("target", "")
		var stat: String = cfg.get("stat", "")
		var value: int = cfg.get("value", 0)
		
		# 检查目标匹配
		var matches: bool = false
		match target:
			"all":
				matches = true
			"warrior":
				matches = (ch.job == DataModels.Job.WARRIOR)
			"mage":
				matches = (ch.job == DataModels.Job.MAGE)
			"priest":
				matches = (ch.job == DataModels.Job.PRIEST)
		
		if not matches:
			continue
		
		# 应用属性加成
		match stat:
			"hp":
				ch.max_hp += value
				ch.hp += value
			"atk":
				ch.attack += value
			"def":
				ch.defense += value
			"penetrate":
				# 穿透在战斗时生效，不计入基础属性
				pass


## 刷新所有角色的遗物加成 (获得/失去遗物时调用)
static func refresh_all_characters_relics() -> void:
	if not is_instance_valid(GameManager.board_data):
		return
	
	var bd: BoardData = GameManager.board_data
	
	# 刷新棋盘上的角色
	for i in range(BoardData.BOARD_SLOTS):
		var ch: DataModels.CharacterData = bd.get_character_at_index(i)
		if ch != null:
			recalc_stats(ch, true)
	
	# 刷新宿舍里的角色
	for i in range(bd.dorm_characters.size()):
		var ch: DataModels.CharacterData = bd.dorm_characters[i]
		if ch != null:
			recalc_stats(ch, true)
	
	print(">>> [CharacterFactory] 已刷新所有角色的遗物加成")


# ---- 属性预览 (调试用) ----

## 打印指定职业 1-16 级属性表
static func print_stat_table(job: int) -> void:
	var job_name: String
	if JobAdvanced.is_advanced_job(job):
		job_name = JobAdvanced.get_advanced_job_name(job)
	else:
		match job:
			DataModels.Job.WARRIOR: job_name = LocalizationSystem.get_text("jobs.warrior")
			DataModels.Job.MAGE: job_name = LocalizationSystem.get_text("jobs.mage")
			DataModels.Job.PRIEST: job_name = LocalizationSystem.get_text("jobs.priest")
			_: job_name = LocalizationSystem.get_text("jobs.unknown")

	print("=== %s 属性成长表 ===" % job_name)
	print("等级 | 血量 | 攻击 | 防御 | 特技等级")
	for lv in range(1, 17):
		print("Lv.%2d | %4d | %4d | %4d | %d" % [
			lv, calc_hp(job, lv), calc_attack(job, lv),
			calc_defense(job, lv), calc_skill_level(lv)
		])
