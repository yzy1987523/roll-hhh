extends Node

## 存档系统
## 任务 6.1: LocalStorage 自动存档

# 预加载依赖类 (Autoload 需要显式预加载)
const BD = preload("res://scripts/board_data.gd")
const DM = preload("res://scripts/data_models.gd")

const SAVE_KEY := "roll_hhh_save"
const ENCYCLOPEDIA_KEY := "roll_hhh_encyclopedia"
const TUTORIAL_KEY := "roll_hhh_tutorial_done"

## 图鉴数据 (永久保留)
var encyclopedia: Dictionary = {}  # key: "job_level" string, value: true

func _ready() -> void:
	load_encyclopedia()
	# Try to load game save
	var save_data: Dictionary = _load_from_storage(SAVE_KEY)
	if save_data.size() > 0:
		_apply_save(save_data)
		print(">>> [SaveSystem] 存档已加载")
	else:
		print(">>> [SaveSystem] 无存档, 使用默认状态")


## 保存游戏状态
func save_game() -> void:
	var data: Dictionary = _build_save_data()
	_write_to_storage(SAVE_KEY, data)
	save_encyclopedia()
	print(">>> [SaveSystem] 游戏已保存")


## 清除游戏存档 (战败后调用, 保留图鉴)
func clear_game_save() -> void:
	_remove_from_storage(SAVE_KEY)
	save_encyclopedia()
	print(">>> [SaveSystem] 游戏存档已清除 (图鉴保留)")


## 解锁图鉴条目
func unlock_encyclopedia(job: int, level: int) -> void:
	var key: String = "%d_%d" % [job, level]
	if not encyclopedia.has(key):
		encyclopedia[key] = true
		print(">>> [SaveSystem] 图鉴解锁: job=%d level=%d" % [job, level])


## 检查图鉴是否解锁
func is_encyclopedia_unlocked(job: int, level: int) -> bool:
	return encyclopedia.has("%d_%d" % [job, level])


## 保存图鉴
func save_encyclopedia() -> void:
	_write_to_storage(ENCYCLOPEDIA_KEY, encyclopedia)


## 加载图鉴
func load_encyclopedia() -> void:
	var data: Dictionary = _load_from_storage(ENCYCLOPEDIA_KEY)
	if data.size() > 0:
		encyclopedia = data


## 检查新手教学是否已完成
func is_tutorial_done() -> bool:
	var raw: String = ""
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("localStorage.getItem('%s')" % TUTORIAL_KEY)
		if result != null and result is String and result != "null":
			raw = result
	else:
		var file := FileAccess.open("user://%s.json" % TUTORIAL_KEY, FileAccess.READ)
		if file:
			raw = file.get_as_text()
			file.close()
	return raw == "true"


## 标记新手教学已完成
func mark_tutorial_done() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("localStorage.setItem('%s', 'true')" % TUTORIAL_KEY)
	else:
		var file := FileAccess.open("user://%s.json" % TUTORIAL_KEY, FileAccess.WRITE)
		if file:
			file.store_string("true")
			file.close()
	print(">>> [SaveSystem] 新手教学标记完成")


# ---- 构建存档数据 ----

func _build_save_data() -> Dictionary:
	var data: Dictionary = {}
	# 游戏状态
	data["phase"] = GameManager.phase
	data["gold"] = GameManager.gold
	data["energy"] = GameManager.energy
	data["max_energy"] = GameManager.max_energy
	data["current_round"] = GameManager.current_round
	data["cycle_count"] = GameManager.cycle_count
	data["battle_turn"] = GameManager.battle_turn

	# 棋盘角色
	var board_chars: Array = []
	for i in range(BD.BOARD_SLOTS):
		var ch = GameManager.board_data.board[i]
		if ch != null:
			var d: Dictionary = ch.to_dict()
			d["board_index"] = i
			board_chars.append(d)
	data["board"] = board_chars

	# 宿舍角色
	var dorm_chars: Array = []
	for ch in GameManager.board_data.dormitory:
		dorm_chars.append(ch.to_dict())
	data["dormitory"] = dorm_chars

	# 道具
	var items_data: Array = []
	for item in GameManager.items:
		items_data.append(item.to_dict())
	data["items"] = items_data

	# 遗物
	var relics_data: Array = []
	for relic in GameManager.relics:
		relics_data.append(relic.to_dict())
	data["relics"] = relics_data

	return data


# ---- 应用存档数据 ----

func _apply_save(data: Dictionary) -> void:
	# 游戏状态
	GameManager.phase = data.get("phase", GameManager.PHASE_PREPARE)
	GameManager.gold = data.get("gold", 0)
	GameManager.energy = data.get("energy", GameManager.DEFAULT_MAX_ENERGY)
	GameManager.max_energy = data.get("max_energy", GameManager.DEFAULT_MAX_ENERGY)
	GameManager.current_round = data.get("current_round", 1)
	GameManager.cycle_count = data.get("cycle_count", 0)
	GameManager.battle_turn = data.get("battle_turn", 0)

	# 清空棋盘再填充
	GameManager.board_data.clear_board()

	# 恢复棋盘角色
	var board_chars: Array = data.get("board", [])
	for cd in board_chars:
		var ch := DM.CharacterData.from_dict(cd)
		var idx: int = cd.get("board_index", -1)
		if idx >= 0 and idx < BD.BOARD_SLOTS:
			var pos: Vector2i = BD.index_to_pos(idx)
			GameManager.board_data.board[idx] = ch
			ch.position = pos

	# 恢复宿舍角色
	var dorm_chars: Array = data.get("dormitory", [])
	for cd in dorm_chars:
		var ch := DM.CharacterData.from_dict(cd)
		ch.position = Vector2i(-1, -1)
		GameManager.board_data.dormitory.append(ch)

	# 恢复道具
	GameManager.items.clear()
	var items_data: Array = data.get("items", [])
	for id_data in items_data:
		var item := DM.ItemData.from_dict(id_data)
		GameManager.items.append(item)

	# 恢复遗物
	GameManager.relics.clear()
	var relics_data: Array = data.get("relics", [])
	for rd in relics_data:
		var item := DM.ItemData.from_dict(rd)
		GameManager.relics.append(item)

	# 发射信号更新UI
	GameManager.gold_changed.emit(GameManager.gold)
	GameManager.energy_changed.emit(GameManager.energy)
	GameManager.round_changed.emit(GameManager.current_round)
	GameManager.items_changed.emit()
	GameManager.relics_changed.emit()


# ---- LocalStorage 底层操作 ----

func _write_to_storage(key: String, data) -> void:
	var json_str: String = JSON.stringify(data)
	if OS.has_feature("web"):
		var js_code: String = "localStorage.setItem('%s', '%s')" % [key, json_str.replace("\\", "\\\\").replace("'", "\\'")]
		JavaScriptBridge.eval(js_code)
	else:
		# 非web环境: 文件存档
		var file := FileAccess.open("user://%s.json" % key, FileAccess.WRITE)
		if file:
			file.store_string(json_str)
			file.close()


func _load_from_storage(key: String) -> Dictionary:
	var json_str: String = ""
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("localStorage.getItem('%s')" % key)
		if result != null and result is String and result != "null" and result != "":
			json_str = result
	else:
		var file := FileAccess.open("user://%s.json" % key, FileAccess.READ)
		if file:
			json_str = file.get_as_text()
			file.close()

	if json_str == "":
		return {}

	var json := JSON.new()
	var err := json.parse(json_str)
	if err != OK:
		print(">>> [SaveSystem] JSON解析失败: %s" % json.get_error_message())
		return {}

	var parsed_data = json.data
	if parsed_data is Dictionary:
		return parsed_data
	return {}


## 提交排行榜分数
func submit_leaderboard_score(score: int) -> void:
	var player_data: Dictionary = _load_player_data()
	var leaderboard: Array = _load_leaderboard_data()

	var player_id: String = player_data.get("id", "")
	var player_name: String = player_data.get("name", "")

	if player_id == "":
		player_id = "Guest_%d" % randi_range(10000, 99999)
		player_name = player_id
		_write_to_storage("roll_hhh_player_id", {"id": player_id, "name": player_name})

	# Update or add entry
	var found: bool = false
	for entry in leaderboard:
		if entry is Dictionary and entry.get("id", "") == player_id:
			if score > entry.get("score", 0):
				entry["score"] = score
				entry["name"] = player_name
			found = true
			break

	if not found:
		leaderboard.append({"id": player_id, "name": player_name, "score": score})

	leaderboard.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))
	if leaderboard.size() > 50:
		leaderboard.resize(50)

	var json_str: String = JSON.stringify(leaderboard)
	if OS.has_feature("web"):
		var escaped: String = json_str.replace("\\", "\\\\").replace("'", "\\'")
		JavaScriptBridge.eval("localStorage.setItem('roll_hhh_leaderboard', '%s')" % escaped)
	else:
		var file := FileAccess.open("user://roll_hhh_leaderboard.json", FileAccess.WRITE)
		if file:
			file.store_string(json_str)
			file.close()

	print(">>> [SaveSystem] 排行榜分数已提交: %d" % score)


func _load_player_data() -> Dictionary:
	var data: Dictionary = {}
	var raw: String = ""
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("localStorage.getItem('roll_hhh_player_id')")
		if result != null and result is String and result != "null":
			raw = result
	else:
		var file := FileAccess.open("user://roll_hhh_player_id.json", FileAccess.READ)
		if file:
			raw = file.get_as_text()
			file.close()

	if raw != "":
		var json := JSON.new()
		if json.parse(raw) == OK and json.data is Dictionary:
			data = json.data
	return data


func _load_leaderboard_data() -> Array:
	var raw: String = ""
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("localStorage.getItem('roll_hhh_leaderboard')")
		if result != null and result is String and result != "null":
			raw = result
	else:
		var file := FileAccess.open("user://roll_hhh_leaderboard.json", FileAccess.READ)
		if file:
			raw = file.get_as_text()
			file.close()

	if raw != "":
		var json := JSON.new()
		if json.parse(raw) == OK and json.data is Array:
			return json.data
	return []


func _remove_from_storage(key: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("localStorage.removeItem('%s')" % key)
	else:
		var path: String = "user://%s.json" % key
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
