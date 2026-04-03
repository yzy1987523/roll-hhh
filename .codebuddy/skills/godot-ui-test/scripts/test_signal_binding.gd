extends SceneTree

## UI 信号绑定检测工具
## 检测场景中的按钮、控件是否正确绑定了信号

var _bound_count: int = 0
var _unbound_count: int = 0
var _results: Array = []

func _init() -> void:
	print("\n========================================")
	print("UI 信号绑定检测")
	print("========================================\n")

	# 加载游戏
	print(">>> [初始化] 加载游戏...")
	change_scene_to_file("res://scenes/game_board.tscn")
	await process_frame
	await process_frame

	var gm: Node = root.get_node("GameManager")
	print("  ✅ GameManager 就绪\n")

	# 检测各个场景
	await _check_scene("shop_scene.tscn", "ShopScene")
	await _check_scene("encyclopedia_scene.tscn", "EncyclopediaScene")

	# 检测 GameBoard
	await _check_game_board()

	print_results()
	quit()


func _check_scene(scene_path: String, scene_name: String) -> void:
	"""检测场景的信号绑定"""
	print(">>> 检测 %s..." % scene_name)

	var scene: PackedScene = load("res://scenes/" + scene_path)
	if not scene:
		print("  ❌ 无法加载 %s" % scene_path)
		return

	var instance: Node = scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame

	_scan_node_signals(instance, scene_name)

	instance.queue_free()
	print("")


func _check_game_board() -> void:
	"""检测 GameBoard 的信号绑定"""
	print(">>> 检测 GameBoard...")

	var board: Node = null
	for child in root.get_children():
		if "game_board" in child.name.to_lower():
			board = child
			break

	if not board:
		print("  ❌ 找不到 GameBoard")
		return

	_scan_node_signals(board, "GameBoard")
	print("")


func _scan_node_signals(node: Node, prefix: String) -> void:
	"""递归扫描节点，检查信号绑定"""
	var buttons: Array = _find_buttons(node)

	for btn in buttons:
		var btn_name: String = btn.name
		var connections: Array = btn.get_signal_connection_list("pressed")

		if connections.size() > 0:
			print("  ✅ %s/%s: 已绑定 (%d 个连接)" % [prefix, btn_name, connections.size()])
			_results.append({"node": "%s/%s" % [prefix, btn_name], "bound": true, "count": connections.size()})
			_bound_count += 1
		else:
			print("  ❌ %s/%s: 未绑定!" % [prefix, btn_name])
			_results.append({"node": "%s/%s" % [prefix, btn_name], "bound": false, "count": 0})
			_unbound_count += 1

	# 递归检查子节点
	for child in node.get_children():
		_scan_node_signals(child, prefix)


func _find_buttons(node: Node) -> Array:
	"""查找所有 Button 类型的节点"""
	var buttons: Array = []

	if node is Button:
		buttons.append(node)

	# 递归查找子节点
	for child in node.get_children():
		buttons.append_array(_find_buttons(child))

	return buttons


func print_results() -> void:
	print("\n========================================")
	print("信号绑定检测结果")
	print("========================================")
	print("  已绑定: %d" % _bound_count)
	print("  未绑定: %d" % _unbound_count)
	print("  总计: %d" % (_bound_count + _unbound_count))

	if _unbound_count > 0:
		print("\n⚠ 以下按钮未绑定信号:")
		for result in _results:
			if not result["bound"]:
				print("  - %s" % result["node"])

	if _unbound_count == 0:
		print("\n🎉 所有按钮都已正确绑定!")
	else:
		print("\n⚠ 请修复未绑定的按钮")
	print("========================================\n")
