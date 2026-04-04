extends RefCounted
class_name BattleEngine

## 战斗引擎
## 任务 3.2: 战斗流程 + 任务 3.4: Buff触发

# ---- 战斗结果 ----
const RESULT_ONGOING := 0
const RESULT_WIN := 1
const RESULT_LOSE := 2
const RESULT_DRAW := 3

# ---- 信号回调 (由 UI 层设置) ----
var on_log: Callable = Callable()  # func(msg: String)

# ---- 战斗数据 ----
var allies: Array = []       # Array of CharacterData (棋盘上存活角色)
var enemy: EnemyFactory.EnemyData = null
var battle_result: int = RESULT_ONGOING
var turn_logs: Array = []    # 战斗日志


## 初始化战斗
func setup(board_data: BoardData, current_round: int, cycle_count: int) -> void:
	allies = board_data.get_alive_characters()
	enemy = EnemyFactory.create_enemy(current_round, cycle_count)
	battle_result = RESULT_ONGOING
	turn_logs.clear()
	_log(LocalizationSystem.get_text("battle_log.start") % [
		allies.size(), enemy.get_type_name(), enemy.hp, enemy.attack, enemy.defense
	])


## 执行完整战斗 (跳过模式, 瞬间结算)
func run_full_battle() -> int:
	while battle_result == RESULT_ONGOING:
		execute_turn()
	return battle_result


## 执行单回合
func execute_turn() -> int:
	if battle_result != RESULT_ONGOING:
		return battle_result

	GameManager.advance_battle_turn()
	var turn: int = GameManager.battle_turn
	_log(LocalizationSystem.get_text("battle_log.turn") % turn)

	# 1. 回合开始 Buff 触发
	_trigger_round_start_buffs()

	# 2. 我方全员同步攻击 (先手优势, 集火敌方)
	_allies_attack()

	# 3. 检查敌方是否阵亡
	if not enemy.is_alive():
		# BOSS复活特技 (3008)
		if enemy.skill_id == 3008 and not enemy.has_meta("revived"):
			var revive_chance: float = 0.5 * enemy.skill_value
			if randf() < revive_chance:
				enemy.hp = int(enemy.max_hp * 0.3)
				enemy.set_meta("revived", true)
				_log(LocalizationSystem.get_text("battle_log.boss_revive") % enemy.hp)
			else:
				battle_result = RESULT_WIN
				_log(LocalizationSystem.get_text("battle_log.enemy_dead"))
				return battle_result
		else:
			battle_result = RESULT_WIN
			_log(LocalizationSystem.get_text("battle_log.enemy_dead"))
			return battle_result

	# 4. 敌方攻击 (攻击前排)
	_enemy_attack()

	# 5. 检查我方是否全灭
	_refresh_alive_list()
	if allies.size() == 0:
		battle_result = RESULT_LOSE
		_log(LocalizationSystem.get_text("battle_log.ally_dead"))
		return battle_result

	# 6. 检查回合数
	if GameManager.is_battle_timeout():
		battle_result = RESULT_DRAW
		_log(LocalizationSystem.get_text("battle_log.timeout"))
		return battle_result

	return RESULT_ONGOING


# ---- 我方攻击阶段 ----

func _allies_attack() -> void:
	for ch in allies:
		if not ch.is_alive():
			continue
		if not enemy.is_alive():
			break

		# 闪避检查 (精英特技2004)
		if enemy.skill_id == 2004:
			var evade_chance: float = 0.2 * enemy.skill_value
			if randf() < evade_chance:
				_log(LocalizationSystem.get_text("battle_log.enemy_evade") % ch.get_job_name())
				continue

		var damage: int = _calc_damage(ch.attack, enemy.defense)

		# 狂战士特技 (1101): 低血量时攻击力提升
		if ch.job == JobAdvanced.JOB_BERSERKER and ch.skill_level > 0:
			var hp_ratio: float = float(ch.hp) / float(ch.max_hp)
			if hp_ratio < 0.5:  # 血量低于50%
				var bonus_multiplier: float = 1.0 + (0.5 - hp_ratio) * ch.skill_level * 0.5
				damage = int(damage * bonus_multiplier)
				var bonus_pct: int = int(round((bonus_multiplier - 1.0) * 100))
				_log(LocalizationSystem.get_text("battle_log.berserk_rage") % [ch.get_job_name(), bonus_pct])

		# 法师穿透伤害 (特技1002) / 转职法师系穿透
		var penetrate: int = 0
		var base_job: int = ch.get_base_job()
		if base_job == DataModels.Job.MAGE and ch.skill_level > 0:
			penetrate = ch.skill_level

		# 遗物: 穿透之箭(ID23) 所有攻击+1穿透
		if ItemDatabase.has_relic(23, GameManager.relics):
			penetrate += 1

		if penetrate > 0:
			_log(LocalizationSystem.get_text("battle_log.penetrate") % [ch.get_job_name(), ch.level, penetrate])

		var total_damage: int = damage + penetrate

		# 遗物: 连击之心(ID25) 15%概率2倍伤害
		if ItemDatabase.has_relic(25, GameManager.relics) and randf() < 0.15:
			total_damage *= 2
			_log(LocalizationSystem.get_text("battle_log.crit") % ch.get_job_name())

		enemy.take_damage(total_damage)
		_log(LocalizationSystem.get_text("battle_log.attack") % [
			ch.get_job_name(), ch.level, total_damage, enemy.hp
		])

		# 反击检查 (精英特技2001)
		if enemy.skill_id == 2001 and enemy.is_alive():
			var counter_chance: float = 0.3 * enemy.skill_value
			if randf() < counter_chance:
				var counter_dmg: int = maxi(int(enemy.attack * 0.5), 1)
				ch.take_damage(counter_dmg)
				_log(LocalizationSystem.get_text("battle_log.counter") % [ch.get_job_name(), counter_dmg])

		# 遗物: 复仇之魂(ID14) 击杀后再攻击一次
		if not enemy.is_alive() and ItemDatabase.has_relic(14, GameManager.relics):
			_log(LocalizationSystem.get_text("battle_log.revenge") % ch.get_job_name())

		_trigger_on_attack(ch)


# ---- 敌方攻击阶段 ----

func _enemy_attack() -> void:
	if not enemy.is_alive():
		return

	# 冰冻效果检测
	if enemy.get_meta("frozen", false):
		enemy.set_meta("frozen", false)
		_log(LocalizationSystem.get_text("battle_log.freeze_skip") % enemy.name)
		return

	# 获取前排目标
	var front_row: Array = GameManager.board_data.get_front_row_characters()
	if front_row.size() == 0:
		return

	# 敌方攻击前排所有角色
	for target in front_row:
		if not target.is_alive():
			continue
		if not enemy.is_alive():
			break

		var damage: int = _calc_damage(enemy.attack, target.defense)

		# 战士系格挡 (特技1001): 每3回合格挡一次伤害
		var base_job: int = target.get_base_job()
		if base_job == DataModels.Job.WARRIOR and target.skill_level > 0:
			if GameManager.battle_turn % 3 == 0:
				_log(LocalizationSystem.get_text("battle_log.block") % [target.get_job_name(), target.level])
				damage = 0

		# 骑士守护特技 (1102): 为相邻队友分担伤害
		var knight_protection: Dictionary = _check_knight_protection(target)
		if knight_protection.has("knight") and knight_protection.has("redirect"):
			var knight: DataModels.CharacterData = knight_protection["knight"]
			var redirect_ratio: float = knight_protection["redirect"]
			var redirected_dmg: int = int(damage * redirect_ratio)
			var remaining_dmg: int = damage - redirected_dmg
			
			# 目标承受部分伤害
			target.take_damage(remaining_dmg)
			# 骑士承受部分伤害
			knight.take_damage(redirected_dmg)
			_log(LocalizationSystem.get_text("battle_log.knight_protection") % [
				knight.get_job_name(), target.get_job_name(), redirected_dmg, remaining_dmg
			])
			damage = 0  # 已处理伤害，跳过后续

		# 遗物: 免控护符(ID24) 免疫敌方特技效果
		var immune_skills: bool = ItemDatabase.has_relic(24, GameManager.relics)

		target.take_damage(damage)

		# 遗物: 守护天使(ID13) 首次致命保留1血
		if not target.is_alive() and ItemDatabase.has_relic(13, GameManager.relics):
			if not target.has_meta("angel_used"):
				target.hp = 1
				target.set_meta("angel_used", true)
				_log(LocalizationSystem.get_text("battle_log.guardian_angel") % target.get_job_name())

		_log(LocalizationSystem.get_text("battle_log.enemy_attack") % [
			target.get_job_name(), target.level, damage, target.hp, target.max_hp
		])

		# 敌方特技触发 (免控护符可阻止)
		if not immune_skills:
			_trigger_enemy_skill_on_attack(target)


# ---- 回合开始 Buff ----

func _trigger_round_start_buffs() -> void:
	# 牧师系回复 (特技1003): 每回合为身旁己方伤员回复1血
	for ch in allies:
		if not ch.is_alive():
			continue
		var base_job: int = ch.get_base_job()
		if base_job == DataModels.Job.PRIEST and ch.skill_level > 0:
			var healed_count: int = _priest_heal_nearby(ch)
			if healed_count > 0:
				_log(LocalizationSystem.get_text("battle_log.heal") % [ch.get_job_name(), ch.level, healed_count])

	# 敌方回合开始特技
	_trigger_enemy_round_start()


func _priest_heal_nearby(priest: DataModels.CharacterData) -> int:
	var healed: int = 0
	var heal_amount: int = priest.skill_level  # 回复量 = 特技等级
	
	# 遗物: 牧师系额外治疗 (ID 7) - 增加治疗量
	if ItemDatabase.has_relic(7, GameManager.relics):
		var cfg: Dictionary = MechanicsDb.get_relic_effect(7)
		var bonus: int = cfg.get("heal_amount", 1)
		heal_amount += bonus
	
	var px: int = priest.position.x
	var py: int = priest.position.y

	# 检查上下左右相邻格
	var neighbors := [
		Vector2i(px - 1, py), Vector2i(px + 1, py),
		Vector2i(px, py - 1), Vector2i(px, py + 1)
	]
	
	# 遗物: 牧师系范围加成 (ID 8) - 扩大治疗范围（包含对角线）
	if ItemDatabase.has_relic(8, GameManager.relics):
		neighbors.append_array([
			Vector2i(px - 1, py - 1), Vector2i(px + 1, py - 1),
			Vector2i(px - 1, py + 1), Vector2i(px + 1, py + 1)
		])

	for npos in neighbors:
		if not BoardData.is_valid_pos(npos):
			continue
		var target: DataModels.CharacterData = GameManager.board_data.get_character_at(npos)
		if target != null and target.is_alive() and target.hp < target.max_hp:
			target.heal(heal_amount)
			healed += 1

	return healed


# ---- 敌方特技触发 ----

func _trigger_enemy_skill_on_attack(target: DataModels.CharacterData) -> void:
	if enemy.skill_id == 0:
		return

	var sv: float = enemy.skill_value
	match enemy.skill_id:
		2002:  # 吸血: 造成伤害时回复生命
			var heal_amt: int = maxi(int(2 * sv), 1)
			enemy.hp = mini(enemy.hp + heal_amt, enemy.max_hp)
			_log(LocalizationSystem.get_text("battle_log.lifesteal") % heal_amt)
		2005:  # 虚弱: 降低目标防御
			var debuff: int = maxi(int(1 * sv), 1)
			target.defense = maxi(target.defense - debuff, 0)
			_log(LocalizationSystem.get_text("battle_log.weak") % [target.get_job_name(), debuff])
		2006:  # 燃烧: 附加持续伤害
			var burn: int = maxi(int(1 * sv), 1)
			target.take_damage(burn)
			_log(LocalizationSystem.get_text("battle_log.burn") % [target.get_job_name(), burn])
		2007:  # 冰冻: 概率冻结 (简化: 跳过下次攻击, 暂用日志记录)
			if randf() < 0.2 * sv:
				_log(LocalizationSystem.get_text("battle_log.freeze") % target.get_job_name())
		2008:  # 剧毒: 持续毒素伤害
			var poison: int = maxi(int(1 * sv), 1)
			target.take_damage(poison)
			_log(LocalizationSystem.get_text("battle_log.poison") % [target.get_job_name(), poison])
		3001:  # BOSS雷霆一击: 高额伤害
			var bonus: int = maxi(int(3 * sv), 1)
			target.take_damage(bonus)
			_log(LocalizationSystem.get_text("battle_log.thunder") % [target.get_job_name(), bonus])
		3006:  # BOSS恐惧: 使目标无法行动 (简化: 日志)
			if randf() < 0.15 * sv:
				_log(LocalizationSystem.get_text("battle_log.fear") % target.get_job_name())
		3007:  # BOSS诅咒: 降低攻击
			var debuff: int = maxi(int(1 * sv), 1)
			target.attack = maxi(target.attack - debuff, 0)
			_log(LocalizationSystem.get_text("battle_log.curse") % [target.get_job_name(), debuff])


func _trigger_enemy_round_start() -> void:
	if enemy.skill_id == 0 or not enemy.is_alive():
		return

	var sv: float = enemy.skill_value
	match enemy.skill_id:
		2001:  # 反击 (on_hit, 在被攻击时触发, 此处跳过)
			pass
		2003:  # 护盾: 每回合获得临时护盾 (简化: 回复HP)
			var shield: int = maxi(int(3 * sv), 1)
			enemy.hp = mini(enemy.hp + shield, enemy.max_hp)
			_log(LocalizationSystem.get_text("battle_log.shield") % shield)
		2004:  # 闪避 (on_hit_received, 在受击时判断)
			pass
		3002:  # BOSS群体攻击: 溅射后排 (简化: 随机攻击一个非前排角色)
			var non_front: Array = []
			var front: Array = GameManager.board_data.get_front_row_characters()
			for ch in allies:
				if ch.is_alive() and not front.has(ch):
					non_front.append(ch)
			if non_front.size() > 0:
				var splash_target: DataModels.CharacterData = non_front[randi_range(0, non_front.size() - 1)]
				var splash_dmg: int = maxi(int(enemy.attack * 0.5 * sv), 1)
				splash_target.take_damage(splash_dmg)
				_log(LocalizationSystem.get_text("battle_log.splash") % [splash_target.get_job_name(), splash_dmg])
		3003:  # BOSS再生: 持续回复
			var regen: int = maxi(int(3 * sv), 1)
			enemy.hp = mini(enemy.hp + regen, enemy.max_hp)
			_log(LocalizationSystem.get_text("battle_log.regen") % regen)
		3004:  # BOSS狂暴: 低血量攻击增强
			if enemy.hp < enemy.max_hp * 0.3:
				var bonus: int = maxi(int(2 * sv), 1)
				enemy.attack += bonus
				_log(LocalizationSystem.get_text("battle_log.berserk") % bonus)
		3005:  # BOSS护甲强化 (on_battle_start, 仅首回合)
			if GameManager.battle_turn == 1:
				var def_bonus: int = maxi(int(2 * sv), 1)
				enemy.defense += def_bonus
				_log(LocalizationSystem.get_text("battle_log.armor") % def_bonus)
		3008:  # BOSS复活 (on_death, 在死亡检查时处理)
			pass


func _trigger_on_attack(ch: DataModels.CharacterData) -> void:
	# 转职职业技能触发 (在攻击后)
	var job: int = ch.job
	match job:
		JobAdvanced.JOB_ICEMAGE:  # 冰法师: 冰霜层数
			_apply_frost_stacks(ch)
		JobAdvanced.JOB_FIREMAGE:  # 火法师: 点燃层数
			_apply_burn_stacks(ch)
		JobAdvanced.JOB_DARKPRIEST:  # 暗牧师: 诅咒层数
			_apply_curse_stacks(ch)
		JobAdvanced.JOB_PALADIN:  # 圣骑士: 祝福层数 (应用于前排队友)
			_apply_blessing_stacks()


# ---- 冰法师: 冰霜层数 ----
func _apply_frost_stacks(_ch: DataModels.CharacterData) -> void:
	if not enemy.is_alive():
		return
	var stacks: int = enemy.get_meta("frost_stacks", 0)
	stacks += 1
	enemy.set_meta("frost_stacks", stacks)
	_log(LocalizationSystem.get_text("battle_log.frost_stack") % [enemy.name, stacks])
	if stacks >= 50:
		enemy.set_meta("frozen", true)
		enemy.set_meta("frost_stacks", 0)
		_log(LocalizationSystem.get_text("battle_log.frost_freeze") % enemy.name)


# ---- 火法师: 点燃层数 ----
func _apply_burn_stacks(_ch: DataModels.CharacterData) -> void:
	if not enemy.is_alive():
		return
	var stacks: int = enemy.get_meta("burn_stacks", 0)
	stacks += 1
	enemy.set_meta("burn_stacks", stacks)
	_log(LocalizationSystem.get_text("battle_log.burn_stack") % [enemy.name, stacks])
	if stacks >= 10:
		var explosion_dmg: int = stacks * 2  # 爆炸伤害 = 层数 * 2
		enemy.take_damage(explosion_dmg)
		enemy.set_meta("burn_stacks", 0)
		_log(LocalizationSystem.get_text("battle_log.burn_explosion") % [enemy.name, explosion_dmg])


# ---- 暗牧师: 诅咒层数 (降低敌方1%攻/防, 最高50层) ----
func _apply_curse_stacks(_ch: DataModels.CharacterData) -> void:
	if not enemy.is_alive():
		return
	var stacks: int = enemy.get_meta("curse_stacks", 0)
	if stacks >= 50:
		return  # 已达上限
	stacks += 1
	enemy.set_meta("curse_stacks", stacks)
	# 诅咒效果: 随机降低1% ATK 或 DEF
	var is_atk: bool = randi_range(0, 1) == 0
	if is_atk:
		var reduction: float = enemy.attack * 0.01
		enemy.attack = maxi(enemy.attack - int(reduction), 0)
		_log(LocalizationSystem.get_text("battle_log.curse_stack_atk") % [enemy.name, stacks])
	else:
		var reduction: float = enemy.defense * 0.01
		enemy.defense = maxi(enemy.defense - int(reduction), 0)
		_log(LocalizationSystem.get_text("battle_log.curse_stack_def") % [enemy.name, stacks])


# ---- 圣骑士: 祝福层数 (增加前排队友1%攻/防, 最高50层/人) ----
func _apply_blessing_stacks() -> void:
	var front_row: Array = GameManager.board_data.get_front_row_characters()
	for ally in front_row:
		if not ally.is_alive():
			continue
		var pos_key: String = str(ally.position.x) + "_" + str(ally.position.y)
		var stacks: int = ally.get_meta("blessing_stacks_" + pos_key, 0)
		if stacks >= 50:
			continue  # 该角色已达上限
		stacks += 1
		ally.set_meta("blessing_stacks_" + pos_key, stacks)
		# 祝福效果: 随机增加1% ATK 或 DEF
		var is_atk: bool = randi_range(0, 1) == 0
		if is_atk:
			var bonus: float = ally.attack * 0.01
			ally.attack += maxi(int(bonus), 1)
			_log(LocalizationSystem.get_text("battle_log.bless_stack_atk") % [ally.get_job_name(), stacks])
		else:
			var bonus: float = ally.defense * 0.01
			ally.defense += maxi(int(bonus), 0)
			_log(LocalizationSystem.get_text("battle_log.bless_stack_def") % [ally.get_job_name(), stacks])


# ---- 工具方法 ----

func _calc_damage(atk: int, def: int) -> int:
	return maxi(atk - def, 0)


## 检查骑士守护 (特技1102): 查找目标相邻的骑士
## 返回: {"knight": CharacterData, "redirect": float} 或空字典
func _check_knight_protection(target: DataModels.CharacterData) -> Dictionary:
	if target.job == JobAdvanced.JOB_KNIGHT:
		return {}  # 骑士不保护自己
	
	var tx: int = target.position.x
	var ty: int = target.position.y
	var neighbors := [
		Vector2i(tx - 1, ty), Vector2i(tx + 1, ty),
		Vector2i(tx, ty - 1), Vector2i(tx, ty + 1)
	]
	
	for npos in neighbors:
		if not BoardData.is_valid_pos(npos):
			continue
		var knight: DataModels.CharacterData = GameManager.board_data.get_character_at(npos)
		if knight != null and knight.is_alive() and knight.job == JobAdvanced.JOB_KNIGHT:
			if knight.skill_level > 0:
				var redirect_ratio: float = mini(0.2 + knight.skill_level * 0.05, 0.5)  # 20% + 5%每级, 最高50%
				return {"knight": knight, "redirect": redirect_ratio}
	
	return {}


func _refresh_alive_list() -> void:
	var new_list: Array = []
	for ch in allies:
		if ch.is_alive():
			new_list.append(ch)
	allies = new_list


func _log(msg: String) -> void:
	turn_logs.append(msg)
	if on_log.is_valid():
		on_log.call(msg)
	print(">>> [Battle] %s" % msg)
