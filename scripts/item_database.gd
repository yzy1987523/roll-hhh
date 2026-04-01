extends RefCounted
class_name ItemDatabase

## 道具与遗物数据库
## 任务 4.2 + 4.3: 道具/遗物数据定义与使用逻辑

# ======== 道具使用逻辑 (从mechanics.json读取配置) ========

## 使用道具, 返回是否成功
## target_index: 指定角色的棋盘索引, -1 = 无需指定
static func use_consumable(item: DataModels.ItemData, target_index: int = -1) -> bool:
	var bd: BoardData = GameManager.board_data
	var target: DataModels.CharacterData = null
	if target_index >= 0:
		target = bd.get_character_at_index(target_index)

	# 从配置读取效果参数
	var eff: Dictionary = MechanicsDb.get_item_effect(item.id)
	var effect_type: String = eff.get("effect_type", "")
	var value: int = eff.get("value", 0)
	var levels: int = eff.get("levels", 0)

	match effect_type:
		"heal":
			if target == null: return false
			target.heal(value)
			print(">>> [Item] %s 回复%d血, HP: %d/%d" % [target.get_job_name(), value, target.hp, target.max_hp])

		"restore_energy":
			GameManager.restore_energy(value)

		"spawn_characters":
			var count: int = eff.get("count", 1)
			var min_lv: int = eff.get("min_level", 1)
			var max_lv: int = eff.get("max_level", 1)
			for n in range(count):
				if bd.is_board_full(): break
				var job: int = randi_range(0, 2)
				var lv: int = randi_range(min_lv, max_lv)
				var ch := CharacterFactory.create_character(job, lv)
				bd.place_character_first_empty(ch)

		"summon":
			if bd.is_board_full(): return false
			var job: int = eff.get("job", 0)
			var lv: int = eff.get("level", 1)
			var ch := CharacterFactory.create_character(job, lv)
			bd.place_character_first_empty(ch)

		"level_up_random":
			var chars: Array = bd.get_all_board_characters()
			if chars.size() == 0: return false
			var c: DataModels.CharacterData = chars[randi_range(0, chars.size() - 1)]
			if c.level >= CharacterFactory.MAX_LEVEL: return false
			c.level = mini(c.level + levels, CharacterFactory.MAX_LEVEL)
			CharacterFactory.recalc_stats(c)
			c.full_heal()

		"level_up_target":
			if target == null or target.level >= CharacterFactory.MAX_LEVEL: return false
			target.level = mini(target.level + levels, CharacterFactory.MAX_LEVEL)
			CharacterFactory.recalc_stats(target)
			target.full_heal()

		"temp_shield":
			if target == null: return false
			target.max_hp += value
			target.hp += value

		"stat_buff_target":
			if target == null: return false
			var stat: String = eff.get("stat", "atk")
			match stat:
				"atk": target.attack += value
				"def": target.defense += value
				"hp": target.max_hp += value; target.hp += value

		"meta":
			var key: String = eff.get("key", "")
			var meta_val: Variant = eff.get("value", 0)
			GameManager.set_meta(key, meta_val)

		"dice_of_fate":
			var chars: Array = bd.get_all_board_characters()
			if chars.size() == 0: return false
			var c: DataModels.CharacterData = chars[randi_range(0, chars.size() - 1)]
			if randi_range(0, 1) == 0:
				c.attack += 2
				c.max_hp += 3
				c.hp += 3
				print(">>> [Item] 命运骰子: %s 强化! ATK+2 HP+3" % c.get_job_name())
			else:
				c.attack = maxi(c.attack - 1, 0)
				c.max_hp = maxi(c.max_hp - 2, 1)
				c.hp = mini(c.hp, c.max_hp)
				print(">>> [Item] 命运骰子: %s 弱化! ATK-1 HP-2" % c.get_job_name())

		"reset_energy":
			GameManager.reset_energy()

		_:
			print(">>> [Item] 未知道具效果类型: %s (ID: %d)" % [effect_type, item.id])
			return false

	print(">>> [Item] 使用道具: %s" % item.name)
	return true


# ======== 道具/遗物定义 (从mechanics.json读取) ========

## 获取所有道具
static func get_all_consumables() -> Array:
	var result: Array = []
	var configs: Array = MechanicsDb.get_all_items()
	for cfg in configs:
		var item_id: int = cfg.get("id", 0)
		result.append(_create_item(item_id))
	return result


static func _create_item(id: int) -> DataModels.ItemData:
	var item := DataModels.ItemData.new()
	item.id = id
	item.type = DataModels.ItemType.CONSUMABLE
	item.name = LocalizationSystem.get_text("items." + str(id) + "_name")
	item.description = LocalizationSystem.get_text("items." + str(id) + "_desc")
	item.price = MechanicsDb.get_item_price(id)
	item.stackable = false
	return item


## 根据ID获取道具
static func get_consumable_by_id(id: int) -> DataModels.ItemData:
	var all_items: Array = get_all_consumables()
	for item in all_items:
		if item.id == id:
			return item
	return null


## 获取所有遗物
static func get_all_relics() -> Array:
	var result: Array = []
	var configs: Array = MechanicsDb.get_all_relics()
	for cfg in configs:
		var relic_id: int = cfg.get("id", 0)
		result.append(_create_relic(relic_id))
	return result


static func _create_relic(id: int) -> DataModels.ItemData:
	var cfg: Dictionary = MechanicsDb.get_relic_effect(id)

	var item := DataModels.ItemData.new()
	item.id = id
	item.type = DataModels.ItemType.RELIC
	item.name = LocalizationSystem.get_text("relics." + str(id) + "_name")
	item.description = LocalizationSystem.get_text("relics." + str(id) + "_desc")
	item.stackable = cfg.get("stackable", false)
	# 遗物商店价格
	item.price = 80 if id <= 9 else 120
	if item.stackable:
		item.price = 0  # 战绩徽章不出售
	return item


## 根据ID获取遗物
static func get_relic_by_id(id: int) -> DataModels.ItemData:
	var all_relics: Array = get_all_relics()
	for relic in all_relics:
		if relic.id == id:
			return relic
	return null


# ======== 遗物效果检查 (被其他系统调用) ========

## 检查是否拥有指定遗物
static func has_relic(relic_id: int, relics: Array) -> bool:
	return MechanicsDb.has_relic(relic_id, relics)
