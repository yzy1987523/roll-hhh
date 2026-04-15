extends SceneTree

func _init():
	print("========================================")
	print("测试 FurnitureIconManager")
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

	# 等待足够长时间让 _ready 完成
	await Engine.get_main_loop().process(2.0)

	# 检查节点
	var icon_mgr = instance.find_child("FurnitureIconManager", true, false)
	if icon_mgr == null:
		print("ERROR: 找不到 FurnitureIconManager")
		quit()
		return
	print(">>> [FurnitureIconManager] 找到!")

	var fur_root = instance.find_child("FurnitureRoot", true, false)
	if fur_root == null:
		print("ERROR: 找不到 FurnitureRoot")
		quit()
		return
	print(">>> [FurnitureRoot] 找到，子节点数: %d" % fur_root.get_child_count())

	# 检查图标
	var icon_root = icon_mgr.find_child("FurnitureIconRoot", true, false)
	if icon_root:
		print(">>> [FurnitureIconRoot] 子节点数: %d" % icon_root.get_child_count())
		for child in icon_root.get_children():
			print("    - %s at position %s" % [child.name, child.position])
	else:
		print("WARNING: FurnitureIconRoot 未创建（可能还没到点击解锁阶段）")

	# 手动调用 refresh_all
	icon_mgr.refresh_all()
	await Engine.get_main_loop().process(0.5)

	icon_root = icon_mgr.find_child("FurnitureIconRoot", true, false)
	if icon_root:
		print(">>> [refresh_all后] FurnitureIconRoot 子节点数: %d" % icon_root.get_child_count())
		for child in icon_root.get_children():
			print("    - %s at position %s" % [child.name, child.position])

	print("========================================")
	print("测试完成!")
	print("========================================")

	quit()
