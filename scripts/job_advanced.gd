extends RefCounted
class_name JobAdvanced

## 转职系统
## 任务 5.1: 7个转职分支, 独立属性成长+专属特技

# ---- 转职职业ID (从10开始, 避免与基础职业冲突) ----
const JOB_BERSERKER := 10     # 狂战士 (战士分支)
const JOB_KNIGHT := 11        # 骑士 (战士分支)
const JOB_ICEMAGE := 20       # 冰法师 (法师分支)
const JOB_FIREMAGE := 21      # 火法师 (法师分支)
const JOB_DARKPRIEST := 30    # 暗牧师 (牧师分支)
const JOB_PALADIN := 31       # 圣骑士 (牧师分支)

# ---- 转职映射: 原始职业 → 可转职分支 ----
const ADVANCE_MAP := {
	DataModels.Job.WARRIOR: [JOB_BERSERKER, JOB_KNIGHT],
	DataModels.Job.MAGE: [JOB_ICEMAGE, JOB_FIREMAGE],
	DataModels.Job.PRIEST: [JOB_DARKPRIEST, JOB_PALADIN],
}

# ---- 转职职业基础属性 ----
const ADVANCED_BASE := {
	JOB_BERSERKER:    { "hp": 4, "def": 0, "atk": 2, "skill_id": 1101, "name_key": "berserker" },
	JOB_KNIGHT:       { "hp": 5, "def": 2, "atk": 1, "skill_id": 1102, "name_key": "knight" },
	JOB_ICEMAGE:      { "hp": 1, "def": 0, "atk": 3, "skill_id": 1201, "name_key": "ice_mage" },
	JOB_FIREMAGE:     { "hp": 1, "def": 0, "atk": 3, "skill_id": 1202, "name_key": "fire_mage" },
	JOB_DARKPRIEST:   { "hp": 3, "def": 0, "atk": 0, "skill_id": 1301, "name_key": "dark_priest" },
	JOB_PALADIN:      { "hp": 4, "def": 1, "atk": 1, "skill_id": 1302, "name_key": "paladin" },
}

# ---- 转职职业成长系数 ----
const ADVANCED_GROWTH := {
	JOB_BERSERKER:    { "hp": 0.5, "def": 0.15, "atk": 0.55 },
	JOB_KNIGHT:       { "hp": 0.7, "def": 0.5, "atk": 0.3 },
	JOB_ICEMAGE:      { "hp": 0.25, "def": 0.15, "atk": 0.65 },
	JOB_FIREMAGE:     { "hp": 0.25, "def": 0.15, "atk": 0.65 },
	JOB_DARKPRIEST:   { "hp": 0.5, "def": 0.2, "atk": 0.1 },
	JOB_PALADIN:      { "hp": 0.55, "def": 0.4, "atk": 0.35 },
}


## 检查是否为转职职业
static func is_advanced_job(job: int) -> bool:
	return ADVANCED_BASE.has(job)


## 获取转职职业名称
static func get_advanced_job_name(job: int) -> String:
	if not ADVANCED_BASE.has(job):
		return ""
	var adv_info: Dictionary = ADVANCED_BASE[job]
	var key: String = adv_info["name_key"]
	return LocalizationSystem.get_text("jobs." + key)


## 计算转职职业属性
static func calc_advanced_hp(job: int, level: int) -> int:
	var base: int = ADVANCED_BASE[job]["hp"]
	var rate: float = ADVANCED_GROWTH[job]["hp"]
	return base + int(floor(base * (level - 1) * rate))


static func calc_advanced_attack(job: int, level: int) -> int:
	var base: int = ADVANCED_BASE[job]["atk"]
	var rate: float = ADVANCED_GROWTH[job]["atk"]
	return base + int(floor(base * (level - 1) * rate))


static func calc_advanced_defense(job: int, level: int) -> int:
	var base: int = ADVANCED_BASE[job]["def"]
	var rate: float = ADVANCED_GROWTH[job]["def"]
	return base + int(floor(base * (level - 1) * rate))


## 执行转职: 将角色转为指定转职分支
## 保留原等级, 重新计算属性
static func advance_character(ch: DataModels.CharacterData, advanced_job: int) -> bool:
	if not ADVANCED_BASE.has(advanced_job):
		print(">>> [JobAdvanced] 转职失败: 无效职业ID %d" % advanced_job)
		return false

	var old_name: String = ch.get_job_name()
	ch.job = advanced_job
	ch.max_hp = calc_advanced_hp(advanced_job, ch.level)
	ch.hp = ch.max_hp
	ch.attack = calc_advanced_attack(advanced_job, ch.level)
	ch.defense = calc_advanced_defense(advanced_job, ch.level)
	ch.skill_id = ADVANCED_BASE[advanced_job]["skill_id"]
	ch.skill_level = CharacterFactory.calc_skill_level(ch.level)

	print(">>> [JobAdvanced] %s 转职为 %s Lv.%d (HP:%d ATK:%d DEF:%d)" % [
		old_name, get_advanced_job_name(advanced_job), ch.level,
		ch.max_hp, ch.attack, ch.defense
	])
	return true


## 随机转职 (根据原始职业)
static func random_advance(ch: DataModels.CharacterData) -> bool:
	var base_job: int = ch.job
	if is_advanced_job(base_job):
		print(">>> [JobAdvanced] 已是转职职业, 不可再转")
		return false

	if not ADVANCE_MAP.has(base_job):
		return false

	var options: Array = ADVANCE_MAP[base_job]
	var target: int = options[randi_range(0, options.size() - 1)]
	return advance_character(ch, target)


## 生成角色时的转职概率检查
## base_chance: 基础概率 (默认5%)
## has_relic_17: 是否有转职令牌遗物 (+5%)
static func check_advance_on_spawn(ch: DataModels.CharacterData, has_relic_17: bool = false) -> bool:
	var chance: float = 0.05
	if has_relic_17:
		chance += 0.05
	if randf() < chance:
		return random_advance(ch)
	return false
