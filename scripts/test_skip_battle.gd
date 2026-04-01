extends SceneTree

## 快速测试战斗流程

func _init():
	print("=== [Test] 快速战斗测试 ===")

	var t := create_timer(0.1)
	await t.timeout

	# 加载主菜单 -> 开始游戏 -> 进入战斗
	change_scene_to_file("res://scenes/main_menu.tscn")
	t = create_timer(0.2)
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
	t = create_timer(0.3)
	await t.timeout

	# 点击结束回合
	var board = root.get_child(-1)
	var end_turn = _find_node(board, "EndTurnButton")
	if end_turn == null:
		print(">>> [ERROR] EndTurnButton 未找到")
		_end_test(false)
		return
	end_turn.pressed.emit()
	t = create_timer(0.3)
	await t.timeout

	# 战斗场景
	var battle = root.get_child(-1)
	if battle == null or "BattleScene" not in battle.name:
		print(">>> [ERROR] BattleScene 未加载")
		_end_test(false)
		return

	print(">>> 战斗场景已加载: %s" % battle.name)

	# 等待并跳过
	t = create_timer(0.5)
	await t.timeout

	var skip_btn = _find_node(battle, "SkipButton")
	if skip_btn != null:
		print(">>> 点击 SkipButton...")
		skip_btn.pressed.emit()

	t = create_timer(1.0)
	await t.timeout

	var result_panel = _find_node(battle, "ResultPanel")
	if result_panel != null:
		print(">>> 结果面板 visible: %s" % result_panel.visible)
		var result_label = _find_node(battle, "ResultLabel")
		if result_label != null:
			print(">>> 结果: %s" % result_label.text)
			_end_test(true)
	else:
		print(">>> 战斗进行中...")
		t = create_timer(1.0)
		await t.timeout
		_end_test(true)


func _find_node(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var found = _find_node(child, name)
		if found != null:
			return found
	return null


func _end_test(success: bool) -> void:
	print("")
	if success:
		print("=== [Test] 测试成功 ===")
	else:
		print("=== [Test] 测试失败 ===")
	quit()
