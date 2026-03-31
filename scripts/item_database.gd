extends RefCounted
class_name ItemDatabase

## 道具与遗物数据库
## 任务 4.2 + 4.3: 道具/遗物数据定义与使用逻辑

# ======== 道具定义 (22个) ========

static func get_all_consumables() -> Array:
	return [
		_item(1, "1", 10),
		_item(2, "2", 18),
		_item(3, "3", 30),
		_item(4, "4", 20),
		_item(5, "5", 35),
		_item(6, "6", 50),
		_item(7, "7", 30),
		_item(8, "8", 30),
		_item(9, "9", 30),
		_item(10, "10", 30),
		_item(11, "11", 45),
		_item(12, "12", 80),
		_item(13, "13", 20),
		_item(14, "14", 20),
		_item(15, "15", 20),
		_item(16, "16", 40),
		_item(17, "17", 40),
		_item(18, "18", 80),
		_item(19, "19", 20),
		_item(20, "20", 25),
		_item(21, "21", 30),
		_item(22, "22", 50),
	]


static func _item(id: int, item_key: String, price: int) -> DataModels.ItemData:
	var item := DataModels.ItemData.new()
	item.id = id
	item.type = DataModels.ItemType.CONSUMABLE
	item.name = LocalizationSystem.get_text("items." + item_key + "_name")
	item.description = LocalizationSystem.get_text("items." + item_key + "_desc")
	item.price = price
	item.stackable = false
	return item


static func get_consumable_by_id(id: int) -> DataModels.ItemData:
	for item in get_all_consumables():
		if item.id == id:
			return item
	return null


# ======== 遗物定义 (26个) ========

static func get_all_relics() -> Array:
	return [
		_relic(1, "1", false),
		_relic(2, "2", false),
		_relic(3, "3", false),
		_relic(4, "4", false),
		_relic(5, "5", false),
		_relic(6, "6", false),
		_relic(7, "7", false),
		_relic(8, "8", false),
		_relic(9, "9", false),
		_relic(10, "10", false),
		_relic(11, "11", false),
		_relic(12, "12", false),
		_relic(13, "13", false),
		_relic(14, "14", false),
		_relic(15, "15", false),
		_relic(16, "16", false),
		_relic(17, "17", false),
		_relic(18, "18", false),
		_relic(19, "19", false),
		_relic(20, "20", false),
		_relic(21, "21", false),
		_relic(22, "22", false),
		_relic(23, "23", false),
		_relic(24, "24", false),
		_relic(25, "25", false),
		_relic(26, "26", true),
	]


static func _relic(id: int, relic_key: String, stackable: bool) -> DataModels.ItemData:
	var item := DataModels.ItemData.new()
	item.id = id
	item.type = DataModels.ItemType.RELIC
	item.name = LocalizationSystem.get_text("relics." + relic_key + "_name")
	item.description = LocalizationSystem.get_text("relics." + relic_key + "_desc")
	item.stackable = stackable
	# 遗物商店价格
	item.price = 80 if id <= 9 else 120
	if stackable:
		item.price = 0  # 战绩徽章不出售
	return item


static func get_relic_by_id(id: int) -> DataModels.ItemData:
	for relic in get_all_relics():
		if relic.id == id:
			return relic
	return null


# ======== 道具使用逻辑 ========

## 使用道具, 返回是否成功
## target_index: 指定角色的棋盘索引, -1 = 无需指定
static func use_consumable(item: DataModels.ItemData, target_index: int = -1) -> bool:
	var bd: BoardData = GameManager.board_data
	var target: DataModels.CharacterData = null
	if target_index >= 0:
		target = bd.get_character_at_index(target_index)

	match item.id:
		1:  # 小血瓶
			if target == null: return false
			target.heal(5)
			print(">>> [Item] %s 回复5血, HP: %d/%d" % [target.get_job_name(), target.hp, target.max_hp])
		2:  # 中血瓶
			if target == null: return false
			target.heal(10)
		3:  # 大血瓶
			if target == null: return false
			target.heal(20)
		4:  # 能量药水
			GameManager.restore_energy(10)
		5:  # 能量饮料
			GameManager.restore_energy(20)
		6:  # 角色礼包: 随机3个2-3级角色
			for n in range(3):
				if bd.is_board_full(): break
				var job: int = randi_range(0, 2)
				var lv: int = randi_range(2, 3)
				var ch := CharacterFactory.create_character(job, lv)
				bd.place_character_first_empty(ch)
		7:  # 战士召唤符
			if bd.is_board_full(): return false
			var ch := CharacterFactory.create_character(DataModels.Job.WARRIOR, 3)
			bd.place_character_first_empty(ch)
		8:  # 法师召唤符
			if bd.is_board_full(): return false
			var ch := CharacterFactory.create_character(DataModels.Job.MAGE, 3)
			bd.place_character_first_empty(ch)
		9:  # 牧师召唤符
			if bd.is_board_full(): return false
			var ch := CharacterFactory.create_character(DataModels.Job.PRIEST, 3)
			bd.place_character_first_empty(ch)
		10:  # 经验药水: 随机1个角色升1级
			var chars: Array = bd.get_all_board_characters()
			if chars.size() == 0: return false
			var ch: DataModels.CharacterData = chars[randi_range(0, chars.size() - 1)]
			if ch.level >= 16: return false
			ch.level = mini(ch.level + 1, 16)
			CharacterFactory.recalc_stats(ch)
			ch.full_heal()
		11:  # 高级经验书: 指定角色升1级
			if target == null or target.level >= 16: return false
			target.level = mini(target.level + 1, 16)
			CharacterFactory.recalc_stats(target)
			target.full_heal()
		12:  # 直升卷轴: 随机角色直升3级
			var chars: Array = bd.get_all_board_characters()
			if chars.size() == 0: return false
			var ch: DataModels.CharacterData = chars[randi_range(0, chars.size() - 1)]
			ch.level = mini(ch.level + 3, 16)
			CharacterFactory.recalc_stats(ch)
			ch.full_heal()
		13:  # 临时护盾 (简化: 加5临时HP)
			if target == null: return false
			target.max_hp += 5
			target.hp += 5
		14:  # 攻击符印
			if target == null: return false
			target.attack += 2
		15:  # 防御符印
			if target == null: return false
			target.defense += 2
		16:  # 无敌药水 (简化: 大幅增加防御)
			if target == null: return false
			target.defense += 999
		17:  # 献祭卷轴 (标记, 由献祭逻辑读取)
			GameManager.set_meta("sacrifice_mult", 2)
		18:  # 双重献祭符
			GameManager.set_meta("sacrifice_mult", 3)
		19:  # 刷新令牌 (由商店系统处理)
			GameManager.set_meta("shop_refresh", true)
		20:  # 商店折扣券
			GameManager.set_meta("shop_discount", 0.7)
		21:  # 命运骰子
			var chars: Array = bd.get_all_board_characters()
			if chars.size() == 0: return false
			var ch: DataModels.CharacterData = chars[randi_range(0, chars.size() - 1)]
			if randi_range(0, 1) == 0:
				ch.attack += 2
				ch.max_hp += 3
				ch.hp += 3
				print(">>> [Item] 命运骰子: %s 强化! ATK+2 HP+3" % ch.get_job_name())
			else:
				ch.attack = maxi(ch.attack - 1, 0)
				ch.max_hp = maxi(ch.max_hp - 2, 1)
				ch.hp = mini(ch.hp, ch.max_hp)
				print(">>> [Item] 命运骰子: %s 弱化! ATK-1 HP-2" % ch.get_job_name())
		22:  # 时光沙漏
			GameManager.reset_energy()
		_:
			print(">>> [Item] 未知道具ID: %d" % item.id)
			return false

	print(">>> [Item] 使用道具: %s" % item.name)
	return true


# ======== 遗物效果检查 (被其他系统调用) ========

## 检查是否拥有指定遗物
static func has_relic(relic_id: int, relics: Array) -> bool:
	for r in relics:
		if r.id == relic_id:
			return true
	return false
