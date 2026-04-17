extends RefCounted
class_name DataModels

## 数据模型定义
## 包含 BuffEffect、Character、Item 内部类

# 预加载依赖类
const JA = preload("res://scripts/job_advanced.gd")

# 运行时获取LocalizationSystem单例
static func _get_localization_system():
	if Engine.has_singleton("LocalizationSystem"):
		return Engine.get_singleton("LocalizationSystem")
	var tree = Engine.get_main_loop()
	if tree and tree.root.has_node("/root/LocalizationSystem"):
		return tree.root.get_node("/root/LocalizationSystem")
	return null

# ---- 职业常量 ----
enum Job { WARRIOR = 0, MAGE = 1, PRIEST = 2 }

# ---- 物品类型常量 ----
enum ItemType { CONSUMABLE = 0, RELIC = 1 }

# ---- 棋盘物品类型常量 (对应ItemConfig.json中的type字段) ----
enum BoardItemType {
	COIN = 0,         # 金币
	COMPOSITE = 1,    # 可合成物品
	MAX = 2,          # 最高级合成物
	EGG = 3,          # 龙蛋类
	MAXEGG = 4,      # 最高级龙蛋
	PRODUCTION = 5,  # 生产型物品
	MAXPRODUCTION = 6, # 最高级生产型物品
	CONSUMABLE = 7    # 消耗品(体力球等)
}

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

	# 物品配置数据 (从ItemConfig获取, 用于显示物品sprite)
	var item_id: int = 0         # 物品配置ID
	var merge_chain: int = 0      # 合成链ID (用于判断不同物品是否能合成, item_id/100)
	var sprite_override: String = ""  # 物品sprite覆盖路径 (为空则用职业默认sprite)

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
		var adv_name: String = JA.get_advanced_job_name(job)
		if adv_name != "":
			return adv_name
		var ls = DataModels._get_localization_system()
		if not ls:
			return "Job"
		match job:
			Job.WARRIOR: return ls.get_text("jobs.warrior")
			Job.MAGE: return ls.get_text("jobs.mage")
			Job.PRIEST: return ls.get_text("jobs.priest")
			_: return ls.get_text("jobs.unknown")

	# 获取基础职业 (转职前的原始职业)
	func get_base_job() -> int:
		if JA.is_advanced_job(job):
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
			"pos_x": position.x, "pos_y": position.y,
			"item_id": item_id, "merge_chain": merge_chain, "sprite_override": sprite_override
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
		ch.item_id = d.get("item_id", 0)
		ch.merge_chain = d.get("merge_chain", 0)
		ch.sprite_override = d.get("sprite_override", "")
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
		# 根据类型重新获取本地化的 name 和 description
		var ls = DataModels._get_localization_system()
		if ls:
			if item.type == ItemType.RELIC:
				item.name = ls.get_text("relics." + str(item.id) + "_name")
				item.description = ls.get_text("relics." + str(item.id) + "_desc")
			else:
				item.name = ls.get_text("items." + str(item.id) + "_name")
				item.description = ls.get_text("items." + str(item.id) + "_desc")
		item.stackable = d.get("stackable", false)
		item.stack_count = d.get("stack_count", 1)
		item.price = d.get("price", 0)
		return item


# ==== BoardItemData ====
# 棋盘物品数据 (从ItemConfig获取, 用于显示物品sprite和合成链)
class BoardItemData:
	var id: int = 0          # 物品配置ID
	var name: String = ""    # 物品名称(key, 用于本地化)
	var level: int = 1      # 等级
	var sprite: String = ""   # 精灵图文件名(不含路径)
	var item_type: int = 0   # BoardItemType enum
	var next_composite: int = 0  # 合成后的物品ID (0=不可合成)
	var count: int = 1      # 叠加数量
	var content: String = ""   # 物品内容描述

	# 生成器配置 (从 ItemConfig 获取)
	var max_count: int = 0    # 最大库存 (production 类型)
	var recovery_time: float = 0.0  # 恢复1个库存所需时间 (秒)
	var cooldown_time: float = 0.0   # 冷却时间 (秒)

	# 是否可合成
	func can_merge() -> bool:
		return next_composite > 0

	# 获取合成后的物品ID
	func get_next_item_id() -> int:
		return next_composite

	# 获取合成链ID (物品ID/100)
	func get_merge_chain() -> int:
		return id / 100

	# 获取完整精灵图路径
	func get_sprite_path() -> String:
		if sprite.is_empty():
			print(">>> [BoardItemData.get_sprite_path] id=%s, sprite为空" % id)
			return ""
		# UI图标使用特殊路径
		var path: String
		if sprite.begins_with("UI/"):
			path = "res://art/sprites/%s.png" % sprite
		else:
			path = "res://art/sprites/items/%s.png" % sprite
		return path

	# 是否可叠加
	func is_stackable() -> bool:
		return count > 1

	# 叠加物品
	func add_count(amount: int = 1) -> void:
		count += amount

	# 是否是生成器类型
	func is_producer() -> bool:
		return item_type == DataModels.BoardItemType.PRODUCTION or item_type == DataModels.BoardItemType.MAXPRODUCTION

	# 从配置字典创建
	static func from_config(cfg: Dictionary) -> BoardItemData:
		var data := BoardItemData.new()
		# id 可能是字符串或整数，统一转为 int
		var id_val = cfg.get("id", 0)
		data.id = int(id_val) if id_val is String or id_val is int else 0
		data.name = cfg.get("name", "")
		data.level = cfg.get("level", 1)
		data.sprite = cfg.get("sprite", "")
		data.content = cfg.get("content", "")
		# type 是字符串，需要映射到 BoardItemType enum
		data.item_type = _parse_item_type(cfg.get("type", ""))
		# next_composite 可能是字符串或整数，空字符串转为 0
		var nc_val = cfg.get("next_composite", 0)
		if nc_val is String:
			data.next_composite = int(nc_val) if nc_val != "" else 0
		else:
			data.next_composite = nc_val
		data.count = 1
		# 生成器配置
		data.max_count = cfg.get("maxCount", 0)
		data.recovery_time = cfg.get("recovery_time", 0.0)
		data.cooldown_time = cfg.get("cooldown_time", 0.0)
		return data

	# 将配置中的 type 字符串映射为 BoardItemType enum
	static func _parse_item_type(type_str: String) -> int:
		match type_str:
			"composite": return BoardItemType.COMPOSITE
			"production": return BoardItemType.PRODUCTION
			"maxproduction": return BoardItemType.MAXPRODUCTION
			"stockproduction": return BoardItemType.PRODUCTION  # 库存型也当作生产型
			"autoproduction": return BoardItemType.PRODUCTION
			"coinpile": return BoardItemType.COIN
			"egg", "maxegg": return BoardItemType.EGG
			"energy": return BoardItemType.CONSUMABLE
			"consumable": return BoardItemType.CONSUMABLE
		return BoardItemType.CONSUMABLE

	# 复制物品
	func duplicate() -> BoardItemData:
		var data := BoardItemData.new()
		data.id = id
		data.name = name
		data.level = level
		data.sprite = sprite
		data.item_type = item_type
		data.next_composite = next_composite
		data.count = count
		data.content = content
		data.max_count = max_count
		data.recovery_time = recovery_time
		data.cooldown_time = cooldown_time
		return data

	# 序列化为字典 (仅包含需要持久化的字段)
	func to_dict() -> Dictionary:
		return {
			"id": id, "name": name, "level": level,
			"sprite": sprite, "item_type": item_type,
			"next_composite": next_composite, "count": count,
			"content": content
		}

	# 从字典反序列化
	static func from_dict(d: Dictionary) -> BoardItemData:
		var data := BoardItemData.new()
		data.id = d.get("id", 0)
		data.name = d.get("name", "")
		data.level = d.get("level", 1)
		data.sprite = d.get("sprite", "")
		data.item_type = d.get("item_type", 0)
		data.next_composite = d.get("next_composite", 0)
		data.count = d.get("count", 1)
		data.content = d.get("content", "")
		
		# 如果 content 为空（旧存档），从 ItemConfig 补充
		if data.content.is_empty() and data.id > 0:
			var im = Engine.get_main_loop().root.get_node_or_null("ItemManager")
			if im != null:
				var item_data: BoardItemData = im.get_item(data.id)
				if item_data != null:
					data.content = item_data.content
		
		return data
