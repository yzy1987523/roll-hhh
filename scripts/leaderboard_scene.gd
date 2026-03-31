extends Control

## 排行榜系统
## 任务 6.3: 排行榜UI + 本地存储 + 飞书集成预留

const LEADERBOARD_KEY := "roll_hhh_leaderboard"
const PLAYER_ID_KEY := "roll_hhh_player_id"
const MAX_ENTRIES := 50

@onready var title_label: Label = $VBox/TopBar/TitleLabel
@onready var back_button: Button = $VBox/TopBar/BackButton
@onready var player_info_label: Label = $VBox/PlayerInfo
@onready var list_container: VBoxContainer = $VBox/ScrollContainer/LeaderList
@onready var nickname_input: LineEdit = $VBox/BottomBar/NicknameInput
@onready var set_name_button: Button = $VBox/BottomBar/SetNameButton

var player_id: String = ""
var player_nickname: String = ""
var leaderboard_data: Array = []  # Array of {id, name, score, timestamp}


func _ready() -> void:
	back_button.pressed.connect(_on_back)
	set_name_button.pressed.connect(_on_set_nickname)
	_load_player_id()
	_load_leaderboard()
	_update_display()
	print(">>> [Leaderboard] 排行榜已打开")


func _load_player_id() -> void:
	var saved_id: String = _read_storage(PLAYER_ID_KEY)
	if saved_id != "":
		# Parse JSON to get id and nickname
		var json := JSON.new()
		if json.parse(saved_id) == OK and json.data is Dictionary:
			player_id = json.data.get("id", "")
			player_nickname = json.data.get("name", "")

	if player_id == "":
		# Generate random guest ID
		player_id = "Guest_%d" % randi_range(10000, 99999)
		player_nickname = player_id
		_save_player_id()

	if player_nickname == "":
		player_nickname = player_id


func _save_player_id() -> void:
	var data: Dictionary = {"id": player_id, "name": player_nickname}
	_write_storage(PLAYER_ID_KEY, JSON.stringify(data))


func _load_leaderboard() -> void:
	leaderboard_data.clear()
	var raw: String = _read_storage(LEADERBOARD_KEY)
	if raw == "":
		return
	var json := JSON.new()
	if json.parse(raw) == OK and json.data is Array:
		leaderboard_data = json.data


func _save_leaderboard() -> void:
	_write_storage(LEADERBOARD_KEY, JSON.stringify(leaderboard_data))


## 提交分数 (由外部调用, 如游戏结束时)
func submit_score(score: int) -> void:
	_load_player_id()
	_load_leaderboard()

	# Check if player already has an entry
	var found: bool = false
	for entry in leaderboard_data:
		if entry is Dictionary and entry.get("id", "") == player_id:
			# Update if new score is higher
			if score > entry.get("score", 0):
				entry["score"] = score
				entry["name"] = player_nickname
			found = true
			break

	if not found:
		leaderboard_data.append({
			"id": player_id,
			"name": player_nickname,
			"score": score,
		})

	# Sort by score descending
	leaderboard_data.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))

	# Trim to max entries
	if leaderboard_data.size() > MAX_ENTRIES:
		leaderboard_data.resize(MAX_ENTRIES)

	_save_leaderboard()


func _update_display() -> void:
	# Player info
	player_info_label.text = "玩家: %s  |  最高循环: %d" % [player_nickname, _get_my_best_score()]
	nickname_input.text = player_nickname

	# Clear list
	for child in list_container.get_children():
		child.queue_free()

	# Header row
	var header := HBoxContainer.new()
	for col in ["排名", "玩家", "最高循环"]:
		var lbl := Label.new()
		lbl.text = col
		lbl.custom_minimum_size = Vector2(80, 0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if col == "玩家":
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(lbl)
	list_container.add_child(header)

	# Add separator
	var sep := HSeparator.new()
	list_container.add_child(sep)

	# Entries
	if leaderboard_data.size() == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "暂无记录"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_container.add_child(empty_lbl)
		return

	for i in range(leaderboard_data.size()):
		var entry: Dictionary = leaderboard_data[i]
		var row := HBoxContainer.new()

		# Rank
		var rank_lbl := Label.new()
		rank_lbl.text = "#%d" % (i + 1)
		rank_lbl.custom_minimum_size = Vector2(80, 0)
		rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(rank_lbl)

		# Name
		var name_lbl := Label.new()
		name_lbl.text = entry.get("name", "???")
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(name_lbl)

		# Score
		var score_lbl := Label.new()
		score_lbl.text = str(entry.get("score", 0))
		score_lbl.custom_minimum_size = Vector2(80, 0)
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(score_lbl)

		# Highlight current player
		if entry.get("id", "") == player_id:
			row.modulate = Color(1.0, 0.9, 0.5, 1)

		list_container.add_child(row)


func _get_my_best_score() -> int:
	for entry in leaderboard_data:
		if entry is Dictionary and entry.get("id", "") == player_id:
			return entry.get("score", 0)
	return 0


func _on_set_nickname() -> void:
	var new_name: String = nickname_input.text.strip_edges()
	if new_name == "":
		return

	# Update nickname in leaderboard entries
	for entry in leaderboard_data:
		if entry is Dictionary and entry.get("id", "") == player_id:
			entry["name"] = new_name

	player_nickname = new_name
	_save_player_id()
	_save_leaderboard()
	_update_display()
	print(">>> [Leaderboard] 昵称已更新: %s" % new_name)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ---- LocalStorage 操作 ----

func _write_storage(key: String, value: String) -> void:
	if OS.has_feature("web"):
		var escaped: String = value.replace("\\", "\\\\").replace("'", "\\'")
		JavaScriptBridge.eval("localStorage.setItem('%s', '%s')" % [key, escaped])
	else:
		var file := FileAccess.open("user://%s.json" % key, FileAccess.WRITE)
		if file:
			file.store_string(value)
			file.close()


func _read_storage(key: String) -> String:
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("localStorage.getItem('%s')" % key)
		if result != null and result is String and result != "null":
			return result
		return ""
	else:
		var file := FileAccess.open("user://%s.json" % key, FileAccess.READ)
		if file:
			var text: String = file.get_as_text()
			file.close()
			return text
		return ""
