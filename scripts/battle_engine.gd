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
	_log("战斗开始! 我方 %d 人 vs %s (HP:%d ATK:%d DEF:%d)" % [
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
	_log("--- 第 %d 战斗回合 ---" % turn)

	# 1. 回合开始 Buff 触发
	_trigger_round_start_buffs()

	# 2. 我方全员同步攻击 (先手优势, 集火敌方)
	_allies_attack()

	# 3. 检查敌方是否阵亡
	if not enemy.is_alive():
		battle_result = RESULT_WIN
		_log("敌方阵亡! 我方胜利!")
		return battle_result

	# 4. 敌方攻击 (攻击前排)
	_enemy_attack()

	# 5. 检查我方是否全灭
	_refresh_alive_list()
	if allies.size() == 0:
		battle_result = RESULT_LOSE
		_log("我方全员阵亡! 战斗失败!")
		return battle_result

	# 6. 检查回合数
	if GameManager.is_battle_timeout():
		battle_result = RESULT_DRAW
		_log("战斗超时! 平局!")
		return battle_result

	return RESULT_ONGOING


# ---- 我方攻击阶段 ----

func _allies_attack() -> void:
	for ch in allies:
		if not ch.is_alive():
			continue
		if not enemy.is_alive():
			break

		var damage: int = _calc_damage(ch.attack, enemy.defense)

		# 法师穿透伤害 (特技1002)
		var penetrate: int = 0
		if ch.job == DataModels.Job.MAGE and ch.skill_level > 0:
			penetrate = ch.skill_level  # 每回合额外1点穿透 * 特技等级
			_log("  %s Lv.%d 穿透伤害 +%d" % [ch.get_job_name(), ch.level, penetrate])

		var total_damage: int = damage + penetrate
		enemy.take_damage(total_damage)
		_log("  %s Lv.%d 攻击敌方, 伤害 %d (基础%d+穿透%d), 敌方剩余HP: %d" % [
			ch.get_job_name(), ch.level, total_damage, damage, penetrate, enemy.hp
		])

		# 触发攻击时 Buff
		_trigger_on_attack(ch)


# ---- 敌方攻击阶段 ----

func _enemy_attack() -> void:
	if not enemy.is_alive():
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

		# 战士格挡 (特技1001): 每3回合格挡一次伤害
		if target.job == DataModels.Job.WARRIOR and target.skill_level > 0:
			if GameManager.battle_turn % 3 == 0:
				_log("  %s Lv.%d 触发格挡, 免疫本次伤害!" % [target.get_job_name(), target.level])
				damage = 0

		target.take_damage(damage)
		_log("  敌方攻击 %s Lv.%d, 伤害 %d, 剩余HP: %d/%d" % [
			target.get_job_name(), target.level, damage, target.hp, target.max_hp
		])

		# 敌方特技触发
		_trigger_enemy_skill_on_attack(target)


# ---- 回合开始 Buff ----

func _trigger_round_start_buffs() -> void:
	# 牧师回复 (特技1003): 每回合为身旁己方伤员回复1血
	for ch in allies:
		if not ch.is_alive():
			continue
		if ch.job == DataModels.Job.PRIEST and ch.skill_level > 0:
			var healed_count: int = _priest_heal_nearby(ch)
			if healed_count > 0:
				_log("  %s Lv.%d 回复了 %d 名伤员" % [ch.get_job_name(), ch.level, healed_count])

	# 敌方回合开始特技
	_trigger_enemy_round_start()


func _priest_heal_nearby(priest: DataModels.CharacterData) -> int:
	var healed: int = 0
	var heal_amount: int = priest.skill_level  # 回复量 = 特技等级
	var px: int = priest.position.x
	var py: int = priest.position.y

	# 检查上下左右相邻格
	var neighbors := [
		Vector2i(px - 1, py), Vector2i(px + 1, py),
		Vector2i(px, py - 1), Vector2i(px, py + 1)
	]

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
			_log("  敌方触发[吸血], 回复 %d HP" % heal_amt)
		2005:  # 虚弱: 降低目标防御
			var debuff: int = maxi(int(1 * sv), 1)
			target.defense = maxi(target.defense - debuff, 0)
			_log("  敌方触发[虚弱], %s 防御 -%d" % [target.get_job_name(), debuff])
		2006:  # 燃烧: 附加持续伤害
			var burn: int = maxi(int(1 * sv), 1)
			target.take_damage(burn)
			_log("  敌方触发[燃烧], %s 受到 %d 灼烧伤害" % [target.get_job_name(), burn])
		2007:  # 冰冻: 概率冻结 (简化: 跳过下次攻击, 暂用日志记录)
			if randf() < 0.2 * sv:
				_log("  敌方触发[冰冻], %s 被冻结!" % target.get_job_name())
		2008:  # 剧毒: 持续毒素伤害
			var poison: int = maxi(int(1 * sv), 1)
			target.take_damage(poison)
			_log("  敌方触发[剧毒], %s 受到 %d 毒素伤害" % [target.get_job_name(), poison])
		3001:  # BOSS雷霆一击: 高额伤害
			var bonus: int = maxi(int(3 * sv), 1)
			target.take_damage(bonus)
			_log("  BOSS触发[雷霆一击], %s 额外受到 %d 伤害" % [target.get_job_name(), bonus])
		3006:  # BOSS恐惧: 使目标无法行动 (简化: 日志)
			if randf() < 0.15 * sv:
				_log("  BOSS触发[恐惧], %s 陷入恐惧!" % target.get_job_name())
		3007:  # BOSS诅咒: 降低攻击
			var debuff: int = maxi(int(1 * sv), 1)
			target.attack = maxi(target.attack - debuff, 0)
			_log("  BOSS触发[诅咒], %s 攻击 -%d" % [target.get_job_name(), debuff])


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
			_log("  敌方触发[护盾], 回复 %d HP" % shield)
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
				_log("  BOSS触发[群体攻击], %s 受到溅射 %d 伤害" % [splash_target.get_job_name(), splash_dmg])
		3003:  # BOSS再生: 持续回复
			var regen: int = maxi(int(3 * sv), 1)
			enemy.hp = mini(enemy.hp + regen, enemy.max_hp)
			_log("  BOSS触发[再生], 回复 %d HP" % regen)
		3004:  # BOSS狂暴: 低血量攻击增强
			if enemy.hp < enemy.max_hp * 0.3:
				var bonus: int = maxi(int(2 * sv), 1)
				enemy.attack += bonus
				_log("  BOSS触发[狂暴], 攻击 +%d" % bonus)
		3005:  # BOSS护甲强化 (on_battle_start, 仅首回合)
			if GameManager.battle_turn == 1:
				var def_bonus: int = maxi(int(2 * sv), 1)
				enemy.defense += def_bonus
				_log("  BOSS触发[护甲强化], 防御 +%d" % def_bonus)
		3008:  # BOSS复活 (on_death, 在死亡检查时处理)
			pass


func _trigger_on_attack(ch: DataModels.CharacterData) -> void:
	# 预留: 角色攻击时 Buff 触发扩展点
	pass


# ---- 工具方法 ----

func _calc_damage(atk: int, def: int) -> int:
	return maxi(atk - def, 0)


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
