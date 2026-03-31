extends SceneTree

## E2E 测试: 完整游戏流程测试
## 目标: 击败 2 个 BOSS

# 最大回合限制 (防止无限循环)
const MAX_ITERATIONS := 30

# 节点路径
const PATH_START_BUTTON := "VBoxContainer/StartButton"
const PATH_END_TURN_BUTTON := "MainLayout/BottomBar/ActionRow/EndTurnButton"
const PATH_SKIP_BUTTON := "MainLayout/BottomBar/SkipButton"
const PATH_CONTINUE_BUTTON := "ResultPanel/ResultVBox/ContinueButton"
const PATH_SPAWN_WARRIOR := "MainLayout/BottomBar/SpawnRow/SpawnWarrior"
const PATH_SPAWN_MAGE := "MainLayout/BottomBar/SpawnRow/SpawnMage"
const PATH_SPAWN_PRIEST := "MainLayout/BottomBar/SpawnRow/SpawnPriest"

var boss_victories: int = 0
var cycle_count: int = 0  # 完成的完整循环数
var iteration: int = 0
var current_scene_name: String = ""
var game_manager: Node = null
var current_root_child: Node = null


func _init():
	print("=== [E2E Test] 开始游戏流程测试 ===")
	print("目标: 击败 2 个 BOSS (需要完成 2 个完整循环)")
	print("")

	# 等待一帧让 Autoload 完全初始化
	var timer := create_timer(0.1)
	await timer.timeout

	_init_game()


func _init_game():
	# 注意: GameManager 是 Autoload 单例,但在 headless 测试中访问可能有问题
	# BOSS 检测基于:
	# - 战斗后获得 100 金币 (BOSS 奖励)
	# - 完成循环时增加 cycle_count
	print("[E2E Test] 注意: BOSS 检测基于游戏日志输出")

	# 启动测试流程
	_start_main_menu()


func _start_main_menu():
	print(">>> [Step 1] 加载主菜单...")
	change_scene_to_file("res://scenes/main_menu.tscn")

	# 等待场景加载
	var t := create_timer(0.1)
	await t.timeout

	# 获取当前根节点
	current_root_child = root.get_child(-1)
	if current_root_child != null:
		print(">>> [Step 1] 主菜单已加载, 根节点: %s" % current_root_child.name)
		_click_start_button()
	else:
		print(">>> [ERROR] 主菜单加载失败!")
		_end_test(false)


func _click_start_button():
	# 查找 StartButton
	var start_btn = current_root_child.get_node_or_null(PATH_START_BUTTON) if current_root_child != null else null
	if start_btn != null:
		print(">>> [Step 2] 点击 StartButton...")
		start_btn.pressed.emit()
	else:
		print(">>> [ERROR] StartButton 未找到!")
		_print_root_children()
		_end_test(false)
		return

	# 等待场景切换
	var t := create_timer(0.2)
	await t.timeout
	t = create_timer(0.1)
	await t.timeout

	_iteration_start()


func _iteration_start() -> void:
	iteration += 1
	print("")
	print(">>> [Iteration %d] 检查当前场景..." % iteration)

	# 获取当前根节点
	current_root_child = root.get_child(-1)
	if current_root_child == null:
		print(">>> [ERROR] 没有子节点!")
		_end_test(false)
		return

	print(">>> 当前场景根节点: %s" % current_root_child.name)

	# 根据场景名称判断
	var scene_name := current_root_child.name
	if "MainMenu" in scene_name:
		print(">>> 检测到 MainMenu (主菜单)")
		_click_start_button()
	elif "GameBoard" in scene_name:
		print(">>> 检测到 GameBoard (备战阶段)")
		_handle_prepare_phase()
	elif "BattleScene" in scene_name:
		print(">>> 检测到 BattleScene (战斗阶段)")
		_handle_battle_phase()
	else:
		print(">>> 未知场景: %s" % scene_name)
		_print_root_children()
		_end_test(false)


func _handle_prepare_phase() -> void:
	print(">>> [Prepare Phase] 准备阶段 - 等待按钮可点击...")

	# 等待 UI 加载
	var t := create_timer(0.1)
	await t.timeout
	t = create_timer(0.1)
	await t.timeout

	# 生成多个角色来组建更强队伍
	var spawn_warrior = current_root_child.get_node_or_null(PATH_SPAWN_WARRIOR)
	var spawn_mage = current_root_child.get_node_or_null(PATH_SPAWN_MAGE)
	var spawn_priest = current_root_child.get_node_or_null(PATH_SPAWN_PRIEST)

	# 生成战士
	if spawn_warrior != null:
		for i in range(2):
			spawn_warrior.pressed.emit()
			print(">>> [Prepare] 生成战士 #%d" % (i + 1))
			t = create_timer(0.03)
			await t.timeout

	# 生成法师
	if spawn_mage != null:
		for i in range(2):
			spawn_mage.pressed.emit()
			print(">>> [Prepare] 生成法师 #%d" % (i + 1))
			t = create_timer(0.03)
			await t.timeout

	# 生成牧师
	if spawn_priest != null:
		for i in range(2):
			spawn_priest.pressed.emit()
			print(">>> [Prepare] 生成牧师 #%d" % (i + 1))
			t = create_timer(0.03)
			await t.timeout

	# 额外等待
	t = create_timer(0.1)
	await t.timeout
	t = create_timer(0.1)
	await t.timeout

	# 点击结束回合按钮
	var end_turn_btn = current_root_child.get_node_or_null(PATH_END_TURN_BUTTON)
	if end_turn_btn != null:
		print(">>> [Prepare Phase] 点击 EndTurnButton, 进入战斗...")
		end_turn_btn.pressed.emit()
	else:
		print(">>> [ERROR] EndTurnButton 未找到!")
		_print_scene_structure(current_root_child)
		_end_test(false)
		return

	# 等待切换到战斗场景
	t = create_timer(0.2)
	await t.timeout
	t = create_timer(0.1)
	await t.timeout

	_iteration_start()


func _handle_battle_phase() -> void:
	print(">>> [Battle Phase] 战斗阶段 - 等待按钮...")

	# 等待几帧
	var t := create_timer(0.1)
	await t.timeout
	t = create_timer(0.1)
	await t.timeout

	# 点击跳过按钮 (快速战斗)
	var skip_btn = current_root_child.get_node_or_null(PATH_SKIP_BUTTON)
	var play_btn = current_root_child.get_node_or_null("MainLayout/BottomBar/PlayButton")

	if skip_btn != null and not skip_btn.disabled:
		print(">>> [Battle Phase] 点击 SkipButton (快速战斗)...")
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

	# 等待战斗结束
	t = create_timer(0.3)
	await t.timeout
	t = create_timer(0.2)
	await t.timeout
	t = create_timer(0.2)
	await t.timeout

	# 点击继续按钮
	var continue_btn = current_root_child.get_node_or_null(PATH_CONTINUE_BUTTON)
	if continue_btn != null:
		print(">>> [Battle Phase] 点击 ContinueButton...")
		continue_btn.pressed.emit()
	else:
		print(">>> [ERROR] ContinueButton 未找到!")
		_print_scene_structure(current_root_child)
		_end_test(false)
		return

	# 等待切换回备战场景
	t = create_timer(0.2)
	await t.timeout
	t = create_timer(0.1)
	await t.timeout

	# 检查是否达到目标 (击败 2 个 BOSS = 完成 2 个循环)
	if boss_victories >= 2:
		t = create_timer(0.1)
		await t.timeout
		_end_test(true)
	elif cycle_count >= 2:
		# 完成 2 个循环意味着击败了 2 个 BOSS
		boss_victories = cycle_count
		t = create_timer(0.1)
		await t.timeout
		_end_test(true)
	elif iteration >= MAX_ITERATIONS:
		print(">>> [WARNING] 达到最大迭代次数 %d, 退出" % MAX_ITERATIONS)
		_end_test(false)
	else:
		_iteration_start()


func _print_root_children() -> void:
	print(">>> root.get_children() 内容:")
	for i in range(root.get_child_count()):
		var child = root.get_child(i)
		print(">>>   [%d] %s (type: %s)" % [i, child.name, child.get_class()])


func _print_scene_structure(node: Node, indent: int = 0) -> void:
	var prefix = "  ".repeat(indent)
	print("%s%s (type: %s)" % [prefix, node.name, node.get_class()])
	for child in node.get_children():
		_print_scene_structure(child, indent + 1)


func _end_test(success: bool) -> void:
	print("")
	if success:
		print("=== [E2E Test] 测试成功! ===")
		print(">>> 击败 BOSS 数量: %d/2" % boss_victories)
	else:
		print("=== [E2E Test] 测试失败 ===")
	print(">>> 总迭代次数: %d" % iteration)
	print(">>> 完成循环数: %d" % cycle_count)
	quit()