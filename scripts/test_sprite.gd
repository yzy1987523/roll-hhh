extends SceneTree

## 测试角色精灵图加载

func _init():
	print("=== [Test] 角色精灵图加载测试 ===")

	var t := create_timer(0.1)
	await t.timeout

	# 加载主菜单 -> 开始游戏
	change_scene_to_file("res://scenes/main_menu.tscn")
	t = create_timer(0.3)
	await t.timeout

	var main_menu = root.get_child(-1)
	if main_menu == null:
		print(">>> [ERROR] 主菜单加载失败")
		_end_test(false)
		return

	# 点击开始
	var start_btn = main_menu.get_node_or_null("VBoxContainer/StartButton")
	if start_btn == null:
		print(">>> [ERROR] StartButton 未找到")
		_end_test(false)
		return
	start_btn.pressed.emit()
	t = create_timer(0.5)
	await t.timeout

	# 获取GameBoard
	var board = root.get_child(-1)
	if board == null or "GameBoard" not in board.name:
		print(">>> [ERROR] GameBoard 未加载")
		_end_test(false)
		return

	print(">>> [Test] GameBoard 已加载")

	# 验证法师各等级精灵图文件是否存在
	var base_path := "res://art/sprites/chars/char_02/char_02"
	var all_exist := true
	for lv in range(1, 10):
		var lv_str := str(lv).pad_zeros(2)
		var sprite_name := "%s%s01.png" % [base_path, lv_str]
		var exists := FileAccess.file_exists(sprite_name)
		if not exists:
			print(">>> [ERROR] 缺少: %s" % sprite_name)
			all_exist = false

	if all_exist:
		print(">>> [Test] 法师 Lv.1-9 精灵图文件全部存在")
	else:
		print(">>> [Test] 部分精灵图文件缺失")

	# 列出所有文件
	print("")
	print(">>> [Test] 精灵图文件列表:")
	var dir := DirAccess.open("res://art/sprites/chars/char_02/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				print("  %s" % file_name)
			file_name = dir.get_next()

	_end_test(true)


func _end_test(success: bool) -> void:
	print("")
	if success:
		print("=== [Test] 测试完成 ===")
	else:
		print("=== [Test] 测试失败 ===")
	quit()
