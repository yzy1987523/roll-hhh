extends Node

## 项目启动时自动运行测试

var _test_completed := false

func _ready() -> void:
	# 等待几帧让所有系统初始化
	await get_tree().create_timer(0.5).timeout

	print("\n========================================")
	print("UI系统自动测试")
	print("========================================\n")

	_test_components()
	_test_add_character()
	_test_dormitory()
	_test_popup_tip()

	print("\n========================================")
	print("测试完成!")
	print("========================================\n")

	_test_completed = true


func _test_components() -> void:
	print("\n>>> [测试1] 检查核心组件...")

	var tests := [
		["GameManager", has_node("/root/GameManager")],
		["TipManager", has_node("/root/TipManager")],
		["PopupSystem", has_node("/root/PopupSystem")],
		["LocalizationSystem", has_node("/root/LocalizationSystem")],
	]

	for t in tests:
		var ok: bool = t[1]
		print("  %s %s: %s" % [("✅" if ok else "❌"), t[0], ok])


func _test_add_character() -> void:
	print("\n>>> [测试2] 添加角色...")

	if not has_node("/root/GameManager"):
		print("  ⚠ GameManager 未就绪")
		return

	var gm = get_node("/root/GameManager")
	var bd = gm.board_data
	var count = bd.get_character_count()
	print("  初始角色数: %d" % count)

	# 使用运行时加载
	var DataModels = load("res://scripts/data_models.gd")
	var new_ch = DataModels.CharacterData.new()
	new_ch.job = 0
	new_ch.level = 1
	new_ch.hp = 100
	new_ch.max_hp = 100
	new_ch.attack = 10
	new_ch.defense = 5

	var pos = bd.place_character_first_empty(new_ch)
	if pos.x >= 0:
		print("  ✅ 角色已添加，位置: (%d, %d)" % [pos.x, pos.y])
		print("  当前角色数: %d" % bd.get_character_count())
	else:
		print("  ❌ 添加失败")


func _test_dormitory() -> void:
	print("\n>>> [测试3] 宿舍操作...")

	if not has_node("/root/GameManager"):
		return

	var gm = get_node("/root/GameManager")
	var bd = gm.board_data

	# 找棋盘上的角色
	var found := false
	for y in range(6):
		for x in range(6):
			var ch = bd.get_character(Vector2i(x, y))
			if ch != null:
				found = true
				print("  找到角色在 (%d, %d)，移入宿舍..." % [x, y])
				bd.board_to_dormitory(Vector2i(x, y))
				print("  宿舍数量: %d" % bd.dormitory.size())

				# 标记移出
				if bd.dormitory.size() > 0:
					bd.marked_for_removal.clear()
					bd.marked_for_removal.append(0)
					print("  已标记第0个待移出")

					var removed = bd.execute_removal()
					print("  执行移出: %d 个" % removed)
					print("  宿舍剩余: %d" % bd.dormitory.size())
				break
		if found:
			break

	if not found:
		print("  ⚠ 棋盘上无角色")


func _test_popup_tip() -> void:
	print("\n>>> [测试4] 弹窗和提示...")

	if has_node("/root/PopupSystem"):
		var ps = get_node("/root/PopupSystem")
		print("  显示弹窗...")
		ps.show("测试", "这是测试内容", "确认操作?", "确认", "取消", Callable(), Callable())
		await get_tree().create_timer(1).timeout
		print("  ✅ PopupSystem 正常")
	else:
		print("  ⚠ PopupSystem 未配置")

	if has_node("/root/TipManager"):
		var tm = get_node("/root/TipManager")
		print("  显示提示...")
		tm.show_tip("测试提示信息")
		print("  ✅ TipManager 正常")
	else:
		print("  ⚠ TipManager 未配置")
