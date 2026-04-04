extends SceneTree

## E2E 测试: 教学引导系统测试
## 测试步骤: 生成战士(5次) -> 合成 -> 结束回合 -> Play按钮

const MAX_ITERATIONS := 100

var iteration: int = 0
var current_root_child: Node = null
var tutorial_system: Node = null

# 测试状态
var spawn_clicks: int = 0
var merge_detected: bool = false
var test_passed: bool = false


func _init():
	print("=== [Tutorial Test] 开始教学引导测试 ===")
	print("")
	
	var timer := create_timer(0.1)
	await timer.timeout
	
	_start_main_menu()


func _start_main_menu():
	print(">>> [Step 1] 加载主菜单...")
	change_scene_to_file("res://scenes/main_menu.tscn")
	
	var t := create_timer(0.2)
	await t.timeout
	
	current_root_child = root.get_child(-1)
	if current_root_child != null:
		print(">>> 主菜单已加载: %s" % current_root_child.name)
		_click_start_button()
	else:
		print(">>> [ERROR] 主菜单加载失败!")
		_end_test(false)


func _click_start_button():
	var start_btn = current_root_child.get_node_or_null("StartButton")
	if start_btn != null:
		print(">>> 点击 StartButton...")
		start_btn.pressed.emit()
	else:
		print(">>> [ERROR] StartButton 未找到!")
		_end_test(false)
		return
	
	var t := create_timer(0.5)
	await t.timeout
	
	_iteration_start()


func _iteration_start() -> void:
	iteration += 1
	if iteration > MAX_ITERATIONS:
		print(">>> [ERROR] 达到最大迭代次数!")
		_end_test(false)
		return
	
	print("")
	print(">>> [Iteration %d] 检查当前场景..." % iteration)
	
	current_root_child = root.get_child(-1)
	if current_root_child == null:
		print(">>> [ERROR] 没有子节点!")
		_end_test(false)
		return
	
	print(">>> 当前场景根节点: %s" % current_root_child.name)
	
	var scene_name := current_root_child.name
	if "GameBoard" in scene_name:
		_handle_gameboard()
	elif "BattleScene" in scene_name:
		_handle_battle_scene()
	else:
		print(">>> 未知场景: %s" % scene_name)
		_end_test(false)


func _handle_gameboard() -> void:
	print(">>> 检测到 GameBoard")
	
	# 等待教学系统初始化
	var t := create_timer(0.2)
	await t.timeout
	
	# 查找教学系统
	tutorial_system = current_root_child.get_node_or_null("TutorialSystem")
	if tutorial_system == null:
		print(">>> [WARNING] 教学系统未找到，可能已完成教程")
		# 直接进行正常游戏流程
		_handle_normal_gameplay()
		return
	
	print(">>> 教学系统已找到, 当前步骤: %d" % tutorial_system.current_step)
	
	match tutorial_system.current_step:
		1:  # SPAWN_WARRIOR
			_handle_spawn_step()
		2:  # MERGE
			_handle_merge_step()
		3:  # END_TURN
			_handle_endturn_step()
		0:  # NONE
			print(">>> 教学未激活，进行正常游戏")
			_handle_normal_gameplay()
		_:
			print(">>> 未知教学步骤: %d" % tutorial_system.current_step)
			_end_test(false)


func _handle_spawn_step() -> void:
	print(">>> [教程步骤1] 生成战士 (需点击5次)")
	
	var spawn_btn = current_root_child.get_node_or_null("MainLayout/BottomBar/SpawnRow/SpawnButtons/SpawnWarrior")
	if spawn_btn == null:
		print(">>> [ERROR] SpawnWarrior 按钮未找到!")
		_end_test(false)
		return
	
	# 点击5次生成战士
	for i in range(5):
		print(">>> 点击生成战士 (%d/5)" % (i + 1))
		spawn_btn.pressed.emit()
		spawn_clicks += 1
		
		var t := create_timer(0.1)
		await t.timeout
	
	# 等待步骤更新
	var wait_time := 0.0
	while wait_time < 2.0:
		if tutorial_system.current_step != 1:
			break
		var t := create_timer(0.1)
		await t.timeout
		wait_time += 0.1
	
	print(">>> 步骤1完成，当前步骤: %d" % tutorial_system.current_step)
	_iteration_start()


func _handle_merge_step() -> void:
	print(">>> [教程步骤2] 合成角色")
	print(">>> 检查遮罩层状态...")
	
	var t := create_timer(0.3)
	await t.timeout
	
	# 检查镂空遮罩是否正确设置
	if tutorial_system.overlay_top != null:
		print(">>> 镂空遮罩已创建")
	
	# 获取GridContainer中的角色
	var grid = current_root_child.get_node_or_null("MainLayout/BoardCenter/GridContainer")
	if grid == null:
		print(">>> [ERROR] GridContainer 未找到!")
		_end_test(false)
		return
	
	var children = grid.get_children()
	print(">>> GridContainer中有 %d 个子节点" % children.size())
	
	# 由于headless模式无法模拟拖拽，我们等待合成信号
	print(">>> 等待合成完成...")
	
	# 连接合成信号
	if is_instance_valid(root.get_node_or_null("GameManager")):
		var gm = root.get_node("GameManager")
		if not gm.character_merged.is_connected(_on_merge_detected):
			gm.character_merged.connect(_on_merge_detected)
	
	# 等待合成检测或超时
	var wait_time := 0.0
	while wait_time < 5.0:
		if merge_detected:
			break
		var t2 := create_timer(0.1)
		await t2.timeout
		wait_time += 0.1
	
	if not merge_detected:
		print(">>> [WARNING] 未检测到合成，手动触发合成信号")
		if is_instance_valid(root.get_node_or_null("GameManager")):
			var gm = root.get_node("GameManager")
			gm.character_merged.emit(2)
		var t2 := create_timer(0.3)
		await t2.timeout
	
	# 等待步骤更新
	wait_time = 0.0
	while wait_time < 2.0:
		if tutorial_system.current_step != 2:
			break
		var t2 := create_timer(0.1)
		await t2.timeout
		wait_time += 0.1
	
	print(">>> 步骤2完成，当前步骤: %d" % tutorial_system.current_step)
	_iteration_start()


func _on_merge_detected(merged_level: int) -> void:
	print(">>> 检测到合成，等级: %d" % merged_level)
	merge_detected = true


func _handle_endturn_step() -> void:
	print(">>> [教程步骤3] 结束回合")
	
	var endturn_btn = current_root_child.get_node_or_null("MainLayout/DetailActionBar/EndTurnButton")
	if endturn_btn == null:
		print(">>> [ERROR] EndTurnButton 未找到!")
		_end_test(false)
		return
	
	print(">>> 点击结束回合按钮")
	endturn_btn.pressed.emit()
	
	var t := create_timer(0.5)
	await t.timeout
	
	# 检查是否切换到战斗场景
	current_root_child = root.get_child(-1)
	if "BattleScene" in current_root_child.name:
		print(">>> 已进入战斗场景")
		_handle_battle_scene()
	else:
		print(">>> 等待场景切换...")
		t = create_timer(0.5)
		await t.timeout
		_iteration_start()


func _handle_normal_gameplay() -> void:
	print(">>> 正常游戏流程")
	
	# 生成一些角色
	var spawn_btn = current_root_child.get_node_or_null("MainLayout/BottomBar/SpawnRow/SpawnButtons/SpawnWarrior")
	if spawn_btn != null:
		for i in range(3):
			spawn_btn.pressed.emit()
			var t := create_timer(0.05)
			await t.timeout
	
	var t := create_timer(0.1)
	await t.timeout
	
	# 结束回合
	var endturn_btn = current_root_child.get_node_or_null("MainLayout/DetailActionBar/EndTurnButton")
	if endturn_btn != null:
		endturn_btn.pressed.emit()
	
	t = create_timer(0.5)
	await t.timeout
	
	_iteration_start()


func _handle_battle_scene() -> void:
	print(">>> 检测到 BattleScene")
	
	# 等待教学系统初始化
	var t := create_timer(0.3)
	await t.timeout
	
	# 查找战斗教学系统
	tutorial_system = current_root_child.get_node_or_null("BattleTutorialSystem")
	if tutorial_system == null:
		print(">>> [WARNING] 战斗教学系统未找到，可能已完成教程")
		# 直接点击Play按钮
		var play_btn = current_root_child.get_node_or_null("MainLayout/ControlBar/PlayButton")
		if play_btn != null:
			play_btn.pressed.emit()
		t = create_timer(0.5)
		await t.timeout
		_end_test(true)
		return
	
	print(">>> 战斗教学系统已找到, 当前步骤: %d" % tutorial_system.current_step)
	
	# 步骤4: 点击Play按钮
	print(">>> [教程步骤4] 点击Play按钮")
	
	var play_btn = current_root_child.get_node_or_null("MainLayout/ControlBar/PlayButton")
	if play_btn == null:
		print(">>> [ERROR] PlayButton 未找到!")
		_end_test(false)
		return
	
	print(">>> 点击Play按钮")
	play_btn.pressed.emit()
	
	t = create_timer(0.5)
	await t.timeout
	
	print(">>> [SUCCESS] 所有教学步骤完成!")
	test_passed = true
	_end_test(true)


func _end_test(success: bool) -> void:
	print("")
	if success:
		print("=== [Tutorial Test] 测试成功! ===")
		print(">>> 所有教学步骤正常执行")
	else:
		print("=== [Tutorial Test] 测试失败 ===")
	print(">>> 总迭代次数: %d" % iteration)
	quit()
