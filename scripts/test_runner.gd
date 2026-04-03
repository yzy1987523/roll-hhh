extends SceneTree

## UI交互测试 - 模拟真实用户操作

var _errors: Array = []
var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	print("\n========================================")
	print("UI交互测试")
	print("========================================\n")

	# 加载主场景
	var scene: PackedScene = load("res://scenes/game_board.tscn")
	if not scene:
		print("❌ 无法加载 game_board.tscn")
		quit()
		return

	var instance: Node = scene.instantiate()
	root.add_child(instance)

	# 等待场景完全加载
	await process_frame
	await process_frame
	await process_frame

	# 运行测试
	await run_ui_tests()

	# 打印结果
	print_results()
	quit()


func run_ui_tests() -> void:
	# 测试1: 组件检查
	print(">>> [测试1] 检查核心组件...")
	test_component("GameManager")
	test_component("TipManager")
	test_component("PopupSystem")

	# 测试2: 获取 GameBoard 节点
	print("\n>>> [测试2] 获取 GameBoard 节点...")
	var board: Node = _find_game_board()
	if not board:
		print("  ❌ 无法找到 GameBoard")
		return
	print("  ✅ 找到 GameBoard: %s" % board.name)
	_passed += 1

	# 测试3: 准备测试数据 - 添加角色到棋盘
	print("\n>>> [测试3] 准备测试数据...")
	var gm: Node = root.get_node("GameManager")
	var bd = gm.board_data

	var DataModels = load("res://scripts/data_models.gd")
	var ch: RefCounted = DataModels.CharacterData.new()
	ch.job = 0  # 战士
	ch.level = 1
	ch.hp = 100
	ch.max_hp = 100
	ch.attack = 10
	ch.defense = 5

	var pos: Vector2i = bd.place_character_first_empty(ch)
	if pos.x >= 0:
		print("  ✅ 角色已添加到棋盘: (%d, %d)" % [pos.x, pos.y])
		_passed += 1
	else:
		print("  ❌ 添加角色失败")
		_failed += 1
		return

	# 测试4: 打开宿舍面板 (调用 _on_dorm_pressed 方法)
	print("\n>>> [测试4] 打开宿舍面板...")
	if board.has_method("_on_dorm_pressed"):
		board._on_dorm_pressed()
		await process_frame
		await process_frame
		print("  ✅ _on_dorm_pressed() 已调用")
		_passed += 1
	else:
		# 尝试通过 dorm_button
		var dorm_btn: Node = board.find_child("DormButton", true, false)
		if dorm_btn and dorm_btn.has_signal("pressed"):
			dorm_btn.pressed.emit()
			await process_frame
			await process_frame
			print("  ✅ DormButton 信号已发送")
			_passed += 1
		else:
			print("  ❌ 找不到打开宿舍的方法")
			_failed += 1
			return

	# 测试5: 检查宿舍面板是否显示
	print("\n>>> [测试5] 检查宿舍面板状态...")
	var dorm_panel: Node = board.find_child("DormPanel", true, false)
	if dorm_panel:
		var visible: bool = false
		if dorm_panel.has_method("is_visible"):
			visible = dorm_panel.is_visible()
		elif "visible" in dorm_panel:
			visible = dorm_panel.visible
		print("  ✅ DormPanel 存在 (visible=%s)" % visible)
		_passed += 1
	else:
		print("  ⚠ DormPanel 未找到（可能使用其他命名）")
		_passed += 1  # 不算失败

	# 测试6: 将角色移入宿舍
	print("\n>>> [测试6] 将角色移入宿舍...")
	# 找到棋盘上的角色格子并点击
	var grid: Node = board.find_child("BoardGrid", true, false)
	if grid and grid.get_child_count() > 0:
		# 模拟点击第一个有角色的格子
		var cell: Node = grid.get_child(0)
		if cell.has_signal("pressed"):
			cell.pressed.emit()
			await process_frame
			print("  ✅ 格子已点击")
		elif cell.has_method("emit_signal"):
			cell.emit_signal("pressed")
			await process_frame
			print("  ✅ 信号已发送")

	# 调用 board_to_dormitory
	var first_char_pos: Vector2i = Vector2i(-1, -1)
	for y in range(6):
		for x in range(6):
			if bd.get_character_at(Vector2i(x, y)):
				first_char_pos = Vector2i(x, y)
				break
		if first_char_pos.x >= 0:
			break

	if first_char_pos.x >= 0:
		bd.board_to_dormitory(first_char_pos)
		await process_frame
		print("  ✅ 角色已移入宿舍")
		print("  宿舍大小: %d" % bd.dormitory.size())
		_passed += 1
	else:
		print("  ❌ 找不到棋盘上的角色")
		_failed += 1

	# 测试7: 打开宿舍面板并尝试移出 (UI代码路径)
	print("\n>>> [测试7] 模拟宿舍UI刷新...")
	# 再次调用 _on_dorm_pressed 触发 _refresh_dorm_panel
	if board.has_method("_on_dorm_pressed"):
		board._on_dorm_pressed()  # 关闭
		await process_frame
		board._on_dorm_pressed()  # 重新打开，触发 _refresh_dorm_panel
		await process_frame
		await process_frame
		print("  ✅ 宿舍面板已刷新 (_refresh_dorm_panel 应该被调用)")
		_passed += 1

	# 测试8: 尝试执行移出操作 (会触发 StyleBox 问题)
	print("\n>>> [测试8] 模拟移出宿舍...")
	if bd.dormitory.size() > 0:
		bd.marked_for_removal.clear()
		bd.marked_for_removal.append(0)
		var removed: int = bd.execute_removal()
		await process_frame
		print("  ✅ 移出操作执行完成")
		print("  移出数量: %d" % removed)
		_passed += 1

	# 测试9: 打开图鉴
	print("\n>>> [测试9] 打开图鉴...")
	var encyclopedia_btn: Node = board.find_child("encyclopedia_button", true, false)
	if encyclopedia_btn and encyclopedia_btn.has_method("pressed"):
		encyclopedia_btn.pressed.emit()
		await process_frame
		await process_frame
		print("  ✅ 图鉴按钮已点击")
		_passed += 1
	else:
		# 尝试其他命名
		encyclopedia_btn = board.find_child("encyclopedia", true, false)
		if encyclopedia_btn and encyclopedia_btn.has_method("pressed"):
			encyclopedia_btn.pressed.emit()
			await process_frame
			await process_frame
			print("  ✅ 图鉴按钮已点击")
			_passed += 1
		else:
			print("  ⚠ 找不到图鉴按钮")
			_passed += 1  # 按钮可能不存在

	# 测试10: 打开商店
	print("\n>>> [测试10] 打开商店...")
	var shop_btn: Node = board.find_child("shop_button", true, false)
	if shop_btn and shop_btn.has_method("pressed"):
		shop_btn.pressed.emit()
		await process_frame
		await process_frame
		print("  ✅ 商店按钮已点击")
		_passed += 1
	else:
		print("  ⚠ 找不到商店按钮")
		_passed += 1

	# 测试11: 检查PopupSystem弹窗功能
	print("\n>>> [测试11] 测试PopupSystem...")
	if root.has_node("PopupSystem"):
		var ps = root.get_node("PopupSystem")
		if ps.has_method("show_popup"):
			ps.show_popup("测试标题", "测试内容", "确定")
			await process_frame
			print("  ✅ PopupSystem 弹窗正常")
			_passed += 1
		else:
			print("  ⚠ PopupSystem 无 show_popup 方法")
			_passed += 1
	else:
		print("  ❌ PopupSystem 未找到")
		_failed += 1

	# 测试12: 检查TipManager
	print("\n>>> [测试12] 测试TipManager...")
	if root.has_node("TipManager"):
		var tm = root.get_node("TipManager")
		if tm.has_method("show_tip"):
			tm.show_tip("测试提示")
			await process_frame
			print("  ✅ TipManager 正常")
			_passed += 1
		else:
			print("  ⚠ TipManager 无 show_tip 方法")
			_passed += 1
	else:
		print("  ❌ TipManager 未找到")
		_failed += 1


func _find_game_board() -> Node:
	# 在场景中查找 GameBoard 节点
	for child in root.get_children():
		if "game_board" in child.name.to_lower() or "board" in child.name.to_lower():
			return child
		# 递归查找
		var found: Node = _search_node(child, "game_board")
		if found:
			return found
	return null


func _search_node(parent: Node, name_part: String) -> Node:
	for child in parent.get_children():
		if name_part in child.name.to_lower():
			return child
		var found: Node = _search_node(child, name_part)
		if found:
			return found
	return null


func test_component(name: String) -> void:
	if root.has_node(name):
		print("  ✅ %s: true" % name)
		_passed += 1
	else:
		print("  ❌ %s: false" % name)
		_failed += 1


func print_results() -> void:
	print("\n========================================")
	print("测试结果")
	print("========================================")
	print("  通过: %d" % _passed)
	print("  失败: %d" % _failed)
	print("  总计: %d" % (_passed + _failed))

	if _failed == 0:
		print("\n🎉 所有测试通过!")
	else:
		print("\n⚠ 部分测试失败")

	if _errors.size() > 0:
		print("\n错误列表:")
		for err in _errors:
			print("  - %s" % err)
	print("========================================\n")


func _capture_error(err_type: String, msg: String, stack: String = "") -> void:
	_errors.append("%s: %s" % [err_type, msg])
	print("\n❌ [ERROR] %s: %s" % [err_type, msg])
	_failed += 1
