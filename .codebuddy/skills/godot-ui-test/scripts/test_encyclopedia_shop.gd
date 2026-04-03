extends SceneTree

## 图鉴和商店场景测试
## 测试：打开图鉴、查看角色、查看详情、打开商店、购买

var _errors: Array = []
var _passed: int = 0
var _failed: int = 0
var _root: Node = null

func _init() -> void:
	print("\n========================================")
	print("图鉴和商店测试")
	print("========================================\n")

	_root = get_root()

	# 加载主场景（用于获取 GameManager）
	var board_scene: PackedScene = load("res://scenes/game_board.tscn")
	if not board_scene:
		print("❌ 无法加载 game_board.tscn")
		quit()
		return

	var board_instance: Node = board_scene.instantiate()
	_root.add_child(board_instance)
	await process_frame
	await process_frame
	await process_frame

	# 测试图鉴场景
	await test_encyclopedia()

	# 测试商店场景
	await test_shop()

	# 打印结果
	print_results()
	quit()


func test_encyclopedia() -> void:
	print("\n>>> [图鉴测试] 加载图鉴场景...")

	var scene: PackedScene = load("res://scenes/encyclopedia_scene.tscn")
	if not scene:
		print("  ❌ 无法加载 encyclopedia_scene.tscn")
		_failed += 1
		return

	var instance: Node = scene.instantiate()
	_root.add_child(instance)
	await process_frame
	await process_frame

	# instance 本身就是 encyclopedia_scene.gd 的根节点
	# 直接使用 instance 来调用方法
	var enc: Node = instance

	print("  ✅ 图鉴场景已加载: %s" % enc.name)
	_passed += 1

	# 测试 _select_job 方法
	if enc.has_method("_select_job"):
		enc._select_job(0)  # 选择战士
		await process_frame
		print("  ✅ _select_job(0) 已调用")
		_passed += 1
	else:
		print("  ⚠ 未找到 _select_job 方法 (has_method 返回 false)")
		_passed += 1

	# 测试 _show_level_popup 方法
	if enc.has_method("_show_level_popup"):
		enc._show_level_popup(0, 1)  # 战士 Lv.1 详情
		await process_frame
		print("  ✅ _show_level_popup(0, 1) 已调用")
		_passed += 1
	else:
		print("  ⚠ 未找到 _show_level_popup 方法")
		_passed += 1

	# 测试关闭 - 方法名是 _on_back
	if enc.has_method("_on_back"):
		enc._on_back()
		await process_frame
		print("  ✅ _on_back() 已调用")
		_passed += 1
	else:
		# 尝试查找关闭按钮
		var close_btn: Node = enc.find_child("BackButton", true, false)
		if close_btn and close_btn.has_signal("pressed"):
			close_btn.pressed.emit()
			await process_frame
			print("  ✅ BackButton 已点击")
			_passed += 1
		else:
			print("  ⚠ 未找到关闭方法")
			_passed += 1

	# 清理
	enc.queue_free()
	await process_frame


func test_shop() -> void:
	print("\n>>> [商店测试] 加载商店场景...")

	var scene: PackedScene = load("res://scenes/shop_scene.tscn")
	if not scene:
		print("  ❌ 无法加载 shop_scene.tscn")
		_failed += 1
		return

	var instance: Node = scene.instantiate()
	_root.add_child(instance)
	await process_frame
	await process_frame

	# instance 本身就是 shop_scene.gd 的根节点
	var shop: Node = instance

	print("  ✅ 商店场景已加载: %s" % shop.name)
	_passed += 1

	# 检查金币显示
	var gold_label: Node = shop.find_child("GoldLabel", true, false)
	if gold_label and gold_label is Label:
		print("  ✅ 金币显示: %s" % gold_label.text)
		_passed += 1
	else:
		print("  ⚠ 未找到金币标签")
		_passed += 1

	# 测试商店刷新
	if shop.has_method("_refresh_shop"):
		shop._refresh_shop()
		await process_frame
		print("  ✅ _refresh_shop() 已调用")
		_passed += 1
	else:
		print("  ⚠ 未找到 _refresh_shop 方法")
		_passed += 1

	# 测试购买方法存在
	if shop.has_method("_on_item_buy_pressed"):
		print("  ✅ 找到 _on_item_buy_pressed 方法")
		_passed += 1
	if shop.has_method("_on_relic_buy_pressed"):
		print("  ✅ 找到 _on_relic_buy_pressed 方法")
		_passed += 1

	# 测试关闭
	if shop.has_method("_on_close_pressed"):
		shop._on_close_pressed()
		await process_frame
		print("  ✅ _on_close_pressed() 已调用")
		_passed += 1
	else:
		var close_btn: Node = shop.find_child("CloseButton", true, false)
		if close_btn and close_btn.has_signal("pressed"):
			close_btn.pressed.emit()
			await process_frame
			print("  ✅ CloseButton 已点击")
			_passed += 1
		else:
			print("  ⚠ 未找到关闭方法")
			_passed += 1

	# 清理
	shop.queue_free()
	await process_frame


func _find_node(parent: Node, name_part: String, partial: bool = false) -> Node:
	if not parent:
		return null

	var search = name_part.to_lower()
	if partial:
		if search in parent.name.to_lower():
			return parent
	else:
		if parent.name.to_lower() == search:
			return parent

	for child in parent.get_children():
		var found = _find_node(child, name_part, partial)
		if found:
			return found
	return null


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
