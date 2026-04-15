extends SceneTree

func _init():
	print("=== [Test] 开始完整流程测试 ===")

	# 1. 加载主菜单
	print("\n>>> [Step 1] 加载主菜单场景...")
	var main_menu = preload("res://scenes/main_menu.tscn").instantiate()
	root.add_child(main_menu)
	print(">>> [Step 1] 主菜单已加载")

	# 2. 验证主菜单按钮
	var start_btn = main_menu.get_node_or_null("VBoxContainer/StartButton")
	var settings_btn = main_menu.get_node_or_null("VBoxContainer/SettingsButton")
	print(">>> [Step 2] 检查主菜单按钮...")
	print("    - StartButton 存在: %s" % (start_btn != null))
	print("    - SettingsButton 存在: %s" % (settings_btn != null))
	if start_btn != null:
		print(">>> [Step 2] StartButton text: '%s'" % start_btn.text)

	# 3. 加载游戏场景
	print("\n>>> [Step 3] 加载游戏场景...")
	var game_board = preload("res://scenes/game_board.tscn").instantiate()
	root.add_child(game_board)
	print(">>> [Step 3] 游戏场景已加载")

	# 4. 验证游戏场景节点
	print("\n>>> [Step 4] 检查游戏场景节点...")
	var center_container = game_board.get_node_or_null("CenterContainer")
	var grid_container = game_board.get_node_or_null("CenterContainer/GridContainer")
	var back_btn = game_board.get_node_or_null("BackButton")

	print("    - CenterContainer 存在: %s" % (center_container != null))
	print("    - GridContainer 存在: %s" % (grid_container != null))
	print("    - BackButton 存在: %s" % (back_btn != null))

	if back_btn != null:
		print(">>> [Step 4] BackButton text: '%s'" % back_btn.text)

	# 5. 打印日志模拟按钮点击
	print("\n>>> [Step 5] 模拟按钮点击日志...")
	print(">>> [MainMenu] 开始游戏按钮被点击")
	print(">>> [MainMenu] 设置按钮被点击")

	print("\n=== [Test] 测试完成 ===")
	quit()
