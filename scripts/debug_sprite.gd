extends SceneTree

## 调试精灵图加载

func _init():
	print("=== [Debug] 精灵图加载调试 ===")

	var t := create_timer(0.1)
	await t.timeout

	# 加载主菜单 -> 开始游戏
	change_scene_to_file("res://scenes/main_menu.tscn")
	t = create_timer(0.3)
	await t.timeout

	var main_menu = root.get_child(-1)
	var start_btn = main_menu.get_node_or_null("VBoxContainer/StartButton")
	start_btn.pressed.emit()
	t = create_timer(0.5)
	await t.timeout

	var board = root.get_child(-1)
	print(">>> [Debug] GameBoard: %s" % board.name)

	# 获取棋盘格子
	var grid = board.get_node_or_null("MainLayout/BoardCenter/GridContainer")
	if grid:
		print(">>> [Debug] GridContainer found, child count: %d" % grid.get_child_count())
		var first_cell = grid.get_child(0)
		if first_cell:
			print(">>> [Debug] First cell: %s" % first_cell.name)
			# 遍历所有子节点
			for i in range(first_cell.get_child_count()):
				var child = first_cell.get_child(i)
				print(">>> [Debug]   Child[%d]: %s (type: %s)" % [i, child.name, child.get_class()])

	# 直接测试加载图片
	print("")
	print("=== [Debug] 直接测试图片加载 ===")
	var test_path := "res://art/sprites/chars/char_02/char_020301.png"
	print(">>> [Debug] 测试路径: %s" % test_path)
	print(">>> [Debug] 文件存在: %s" % FileAccess.file_exists(test_path))
	var tex = load(test_path)
	if tex:
		print(">>> [Debug] 加载成功: %s" % tex.get_path())
		print(">>> [Debug] 图片尺寸: %s" % tex.get_size())
	else:
		print(">>> [Debug] 加载失败!")

	# 测试其他路径变体
	var variants = [
		"res://art/sprites/chars/char_02/char_020301.png",
		"res://art/sprites/chars/char_02/char_020301",
		"res://art/sprites/chars/char_02/03.png",
		"art/sprites/chars/char_02/char_020301.png",
	]
	print("")
	print("=== [Debug] 测试不同路径 ===")
	for v in variants:
		var exists = FileAccess.file_exists(v)
		print(">>> [Debug] %s -> %s" % [v, "存在" if exists else "不存在"])

	# 列出目录内容
	print("")
	print("=== [Debug] 目录内容 ===")
	var dir = DirAccess.open("res://art/sprites/chars/char_02/")
	if dir:
		dir.list_dir_begin()
		var f = dir.get_next()
		var count = 0
		while f != "" and count < 20:
			print(">>> [Debug]   %s" % f)
			f = dir.get_next()
			count += 1
	else:
		print(">>> [Debug] 无法打开目录!")

	_end_test(true)


func _end_test(success: bool) -> void:
	print("")
	print("=== [Debug] 完成 ===")
	quit()
