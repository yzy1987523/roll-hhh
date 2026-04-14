extends SceneTree

func _init():
	print("========================================")
	print("测试 Building 场景")
	print("========================================")

	var scene = load("res://scenes/building.tscn")
	if scene == null:
		print("ERROR: 无法加载 building.tscn")
		quit()
		return

	var instance = scene.instantiate()
	if instance == null:
		print("ERROR: 无法实例化 building.tscn")
		quit()
		return

	root.add_child(instance)
	print(">>> [Building] 场景加载成功!")

	# GridManager 不依赖 autoload，可以直接测试
	var grid_manager = instance.get_node_or_null("GridManager")
	if grid_manager == null:
		print("ERROR: 找不到 GridManager 节点")
		quit()
		return

	print(">>> [Building] GridManager 初始化完成")
	print("    - 地板数量: %d" % grid_manager.floor_list.size())
	print("    - 网格尺寸: %dx%d" % [grid_manager.map_width, grid_manager.map_height])
	print("    - 编辑模式: %s" % ("开启" if grid_manager.is_edit_mode else "关闭"))

	# 测试坐标转换
	var test_world = grid_manager.grid_to_world(5, 4)
	var test_grid = grid_manager.world_to_grid(test_world)
	print(">>> [Building] 坐标转换测试: grid(5,4) -> world(%s) -> grid(%d,%d)" % [test_world, test_grid.x, test_grid.y])

	print("========================================")
	print("测试完成!")
	print("========================================")

	quit()
