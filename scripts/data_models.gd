extends RefCounted
class_name DataModels

## 数据模型定义
## 包含 BuffEffect、Character、Item 内部类

# ---- 职业常量 ----
enum Job { WARRIOR = 0, MAGE = 1, PRIEST = 2 }

# ---- 物品类型常量 ----
enum ItemType { CONSUMABLE = 0, RELIC = 1 }

# ---- Buff 触发时机 ----
enum BuffTrigger {
	ON_HIT,            # 受到攻击时
	ON_ATTACK,         # 攻击时
	ON_ROUND_START,    # 回合开始时
	ON_ROUND_END,      # 回合结束时
	ON_MERGE,          # 合成时
	ON_SACRIFICE,      # 献祭时
	ON_BATTLE_START,   # 战斗开始时
	ON_DEATH,          # 死亡时
	ON_LOW_HP,         # 低血量时
	ON_HIT_RECEIVED,   # 被攻击时
	PASSIVE            # 被动常驻
}

# ---- Buff 效果类型 ----
enum BuffType {
	DAMAGE,
	HEAL,
	SHIELD,
	ENERGY,
	EVADE,
	BURN,
	FREEZE,
	POISON,
	STUN,
	DEBUFF_DEFENSE,
	DEBUFF_ATTACK,
	DAMAGE_BOOST,
	DEFENSE_BOOST,
	SPLASH,
	REGEN,
	REVIVE,
	PENETRATE        # 穿透伤害
}

# ==== BuffEffect ====
class BuffEffect:
	var id: int = 0
	var type: int = 0            # BuffType enum
	var value: int = 0
	var target: String = "self"  # "self", "ally", "enemy", "all"
	var trigger: int = 0         # BuffTrigger enum
	var duration: int = -1       # -1 = 永久, >0 = 剩余回合数

	func _init(p_id: int = 0, p_type: int = 0, p_value: int = 0,
			p_target: String = "self", p_trigger: int = 0, p_duration: int = -1) -> void:
		id = p_id
		type = p_type
		value = p_value
		target = p_target
		trigger = p_trigger
		duration = p_duration

	func duplicate_buff() -> BuffEffect:
		return BuffEffect.new(id, type, value, target, trigger, duration)


# ==== Character ====
class CharacterData:
	var id: int = 0
	var job: int = 0             # Job enum: 0=战士, 1=法师, 2=牧师
	var level: int = 1           # 1-9
	var hp: int = 0
	var max_hp: int = 0
	var attack: int = 0
	var defense: int = 0
	var skill_id: int = 0        # 特技序号
	var skill_level: int = 0     # 特技等级
	var buffs: Array = []        # Array of BuffEffect
	var position: Vector2i = Vector2i(-1, -1)  # (-1,-1) = 宿舍

	# 是否在棋盘上
	func is_on_board() -> bool:
		return position.x >= 0 and position.y >= 0

	# 是否存活
	func is_alive() -> bool:
		return hp > 0

	# 受到伤害 (已扣除防御后的净伤害)
	func take_damage(amount: int) -> int:
		var actual: int = maxi(amount, 0)
		hp = maxi(hp - actual, 0)
		return actual

	# 回复血量
	func heal(amount: int) -> int:
		var actual: int = mini(amount, max_hp - hp)
		hp += actual
		return actual

	# 满血恢复
	func full_heal() -> void:
		hp = max_hp

	# 获取棋盘一维索引 (6列)
	func get_board_index() -> int:
		if not is_on_board():
			return -1
		return position.y * 6 + position.x

	# 获取职业名称
	func get_job_name() -> String:
		# 先检查转职职业
		var adv_name: String = JobAdvanced.get_advanced_job_name(job)
		if adv_name != "":
			return adv_name
		match job:
			Job.WARRIOR: return LocalizationSystem.get_text("jobs.warrior")
			Job.MAGE: return LocalizationSystem.get_text("jobs.mage")
			Job.PRIEST: return LocalizationSystem.get_text("jobs.priest")
			_: return LocalizationSystem.get_text("jobs.unknown")

	# 获取基础职业 (转职前的原始职业)
	func get_base_job() -> int:
		if JobAdvanced.is_advanced_job(job):
			if job >= 30: return Job.PRIEST
			if job >= 20: return Job.MAGE
			return Job.WARRIOR
		return job

	# 获取精灵图路径
	# 格式: char_JJLLAA (职业_等级_动画)
	# JJ=职业(01=战士,02=法师,03=牧师,04=暗牧师), LL=等级(01-09), AA=动画(01=待机,02=攻击)
	func get_sprite_path(anim_id: int = 1, _frame: int = 1) -> String:
		var job_code: int = _job_to_sprite_code(job)
		var job_str: String = str(job_code).pad_zeros(2)       # 01-03
		var level_str: String = str(level).pad_zeros(2)       # 01-13
		var anim_str: String = str(anim_id).pad_zeros(2)       # 01-02
		return "char_%s%s%s" % [job_str, level_str, anim_str]

	# 获取精灵图文件夹路径 (如 "char_02")
	func get_sprite_folder() -> String:
		var job_code: int = _job_to_sprite_code(job)
		return "char_%s" % str(job_code).pad_zeros(2)

	# 职业ID转换为精灵图职业代码
	func _job_to_sprite_code(_j: int) -> int:
		# 转职职业: 每个职业有独立的精灵图文件夹
		match _j:
			JobAdvanced.JOB_KNIGHT: return 4       # 骑士
			JobAdvanced.JOB_BERSERKER: return 5    # 狂战士
			JobAdvanced.JOB_ICEMAGE: return 6     # 冰法师
			JobAdvanced.JOB_FIREMAGE: return 7    # 火法师
			JobAdvanced.JOB_DARKPRIEST: return 8   # 暗牧师
			JobAdvanced.JOB_PALADIN: return 9      # 圣骑士
		# 基础职业
		var base: int = get_base_job()
		match base:
			Job.WARRIOR: return 1
			Job.MAGE: return 2
			Job.PRIEST: return 3
		return 1

	# 序列化为字典
	func to_dict() -> Dictionary:
		return {
			"id": id, "job": job, "level": level,
			"hp": hp, "max_hp": max_hp,
			"attack": attack, "defense": defense,
			"skill_id": skill_id, "skill_level": skill_level,
			"pos_x": position.x, "pos_y": position.y
		}

	# 从字典反序列化
	static func from_dict(d: Dictionary) -> CharacterData:
		var ch := CharacterData.new()
		ch.id = d.get("id", 0)
		ch.job = d.get("job", 0)
		ch.level = d.get("level", 1)
		ch.hp = d.get("hp", 1)
		ch.max_hp = d.get("max_hp", 1)
		ch.attack = d.get("attack", 0)
		ch.defense = d.get("defense", 0)
		ch.skill_id = d.get("skill_id", 0)
		ch.skill_level = d.get("skill_level", 0)
		ch.position = Vector2i(d.get("pos_x", -1), d.get("pos_y", -1))
		return ch


# ==== Item ====
class ItemData:
	var id: int = 0
	var type: int = 0            # ItemType: 0=道具, 1=遗物
	var name: String = ""
	var description: String = ""
	var buffs: Array = []        # Array of BuffEffect
	var stackable: bool = false  # 是否可叠加 (仅战绩徽章)
	var stack_count: int = 1
	var price: int = 0           # 商店价格

	func is_relic() -> bool:
		return type == ItemType.RELIC

	func is_consumable() -> bool:
		return type == ItemType.CONSUMABLE

	# 序列化为字典
	func to_dict() -> Dictionary:
		return {
			"id": id, "type": type, "name": name,
			"description": description, "stackable": stackable,
			"stack_count": stack_count, "price": price
		}

	# 从字典反序列化
	static func from_dict(d: Dictionary) -> ItemData:
		var item := ItemData.new()
		item.id = d.get("id", 0)
		item.type = d.get("type", 0)
		item.name = d.get("name", "")
		item.description = d.get("description", "")
		item.stackable = d.get("stackable", false)
		item.stack_count = d.get("stack_count", 1)
		item.price = d.get("price", 0)
		return item
