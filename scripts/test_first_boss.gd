extends SceneTree

## E2E 测试: 击败第一个BOSS
## 目标: 完成9轮游戏（第一个循环）

# 最大回合限制
const MAX_ITERATIONS := 15

# 节点路径
const PATH_START_BUTTON := "StartButton"
const PATH_END_TURN_BUTTON := "MainLayout/DetailActionBar/EndTurnButton"
const PATH_SKIP_BUTTON := "MainLayout/BottomBarContainer/BottomBar/SkipButton"
const PATH_CONTINUE_BUTTON := "ResultPanel/ResultVBox/ContinueButton"
const PATH_SPAWN_WARRIOR := "MainLayout/BottomBarContainer/BottomBar/SpawnRow/SpawnWarrior"
const PATH_SPAWN_MAGE := "MainLayout/BottomBarContainer/BottomBar/SpawnRow/SpawnMage"
const PATH_SPAWN_PRIEST := "MainLayout/BottomBarContainer/BottomBar/SpawnRow/SpawnPriest"

var cycle_count: int = 0
var iteration: int = 0
var current_root_child: Node = null


func _init():
	print("=== [E2E Test] 开始测试: 击败第一个BOSS ===")
	print("目标: 完成9轮游戏 (第一个循环)")
	print("")

	var timer := create_timer(0.1)
	await timer.timeout

	_start_main_menu()


func _start_main_menu():
	print(">>> [Step 1] 加载主菜单...")
	change_scene_to_file("res://scenes/main_menu.tscn")

	var t := create_timer(0.1)
	await t.timeout

	current_root_child = root.get_child(-1)
	if current_root_child != null:
		print(">>> [Step 1] 主菜单已加载, 根节点: %s" % current_root_child.name)
		_click_start_button()
	else:
		print(">>> [ERROR] 主菜单加载失败!")
		_end_test(false)


func _click_start_button():
	var start_btn = current_root_child.get_node_or_null(PATH_START_BUTTON)
	if start_btn != null:
		print(">>> [Step 2] 点击 StartButton...")
		start_btn.pressed.emit()
	else:
		print(">>> [ERROR] StartButton 未找到!")
		_end_test(false)
		return

	var t := create_timer(0.2)
	await t.timeout

	_iteration_start()


func _iteration_start() -> void:
	iteration += 1
	print("")
	print(">>> [Iteration %d] 检查当前场景..." % iteration)

	current_root_child = root.get_child(-1)
	if current_root_child == null:
		print(">>> [ERROR] 没有子节点!")
		_end_test(false)
		return

	print(">>> 当前场景根节点: %s" % current_root_child.name)

	var scene_name := current_root_child.name
	if "MainMenu" in scene_name:
		print(">>> 检测到 MainMenu")
		_click_start_button()
	elif "GameBoard" in scene_name:
		print(">>> 检测到 GameBoard (备战阶段)")
		_handle_prepare_phase()
	elif "BattleScene" in scene_name:
		print(">>> 检测到 BattleScene (战斗阶段)")
		_handle_battle_phase()
	else:
		print(">>> 未知场景: %s" % scene_name)
		_end_test(false)


func _handle_prepare_phase() -> void:
	print(">>> [Prepare Phase] 准备阶段...")

	var t := create_timer(0.1)
	await t.timeout

	# 生成角色
	var spawn_warrior = current_root_child.get_node_or_null(PATH_SPAWN_WARRIOR)
	var spawn_mage = current_root_child.get_node_or_null(PATH_SPAWN_MAGE)
	var spawn_priest = current_root_child.get_node_or_null(PATH_SPAWN_PRIEST)

	if spawn_warrior != null:
		for i in range(2):
			spawn_warrior.pressed.emit()
			t = create_timer(0.03)
			await t.timeout

	if spawn_mage != null:
		for i in range(2):
			spawn_mage.pressed.emit()
			t = create_timer(0.03)
			await t.timeout

	if spawn_priest != null:
		for i in range(2):
			spawn_priest.pressed.emit()
			t = create_timer(0.03)
			await t.timeout

	t = create_timer(0.1)
	await t.timeout

	# 点击结束回合
	var end_turn_btn = current_root_child.get_node_or_null(PATH_END_TURN_BUTTON)
	if end_turn_btn != null:
		print(">>> [Prepare Phase] 点击 EndTurnButton, 进入战斗...")
		end_turn_btn.pressed.emit()
	else:
		print(">>> [ERROR] EndTurnButton 未找到!")
		_end_test(false)
		return

	t = create_timer(0.2)
	await t.timeout

	_iteration_start()


func _handle_battle_phase() -> void:
	print(">>> [Battle Phase] 战斗阶段...")

	var t := create_timer(0.1)
	await t.timeout

	# 检查当前回合和循环数
	if is_instance_valid(root.get_node_or_null("GameManager")):
		var gm = root.get_node("GameManager")
		print(">>> [Battle Phase] 当前回合: %d, 循环数: %d" % [gm.current_round, gm.cycle_count])

	# 点击跳过按钮
	var skip_btn = current_root_child.get_node_or_null(PATH_SKIP_BUTTON)
	var play_btn = current_root_child.get_node_or_null("MainLayout/BottomBar/PlayButton")

	if skip_btn != null and not skip_btn.disabled:
		print(">>> [Battle Phase] 点击 SkipButton...")
		skip_btn.pressed.emit()
	elif play_btn != null and not play_btn.disabled:
		print(">>> [Battle Phase] 点击 PlayButton...")
		play_btn.pressed.emit()
	else:
		print(">>> [Battle Phase] 等待按钮可用...")
		t = create_timer(0.1)
		await t.timeout
		_handle_battle_phase()
		return

	t = create_timer(0.3)
	await t.timeout

	# 点击继续按钮
	var continue_btn = current_root_child.get_node_or_null(PATH_CONTINUE_BUTTON)
	if continue_btn != null:
		print(">>> [Battle Phase] 点击 ContinueButton...")
		continue_btn.pressed.emit()
	else:
		print(">>> [ERROR] ContinueButton 未找到!")
		_end_test(false)
		return

	t = create_timer(0.2)
	await t.timeout

	# 更新循环计数
	if is_instance_valid(root.get_node_or_null("GameManager")):
		var gm = root.get_node("GameManager")
		cycle_count = gm.cycle_count

	# 检查是否完成第一个循环
	if cycle_count >= 1:
		t = create_timer(0.1)
		await t.timeout
		_end_test(true)
	elif iteration >= MAX_ITERATIONS:
		print(">>> [WARNING] 达到最大迭代次数 %d" % MAX_ITERATIONS)
		_end_test(false)
	else:
		_iteration_start()


func _end_test(success: bool) -> void:
	print("")
	if success:
		print("=== [E2E Test] 测试成功! ===")
		print(">>> 已击败第一个BOSS")
	else:
		print("=== [E2E Test] 测试失败 ===")
	print(">>> 总迭代次数: %d" % iteration)
	print(">>> 完成循环数: %d" % cycle_count)
	quit()
