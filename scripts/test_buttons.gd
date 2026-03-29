extends SceneTree

func _init():
	print(">>> [Test] 测试脚本开始运行")
	var scene = preload("res://scenes/main_menu.tscn").instantiate()
	root.add_child(scene)
	print(">>> [Test] 场景已加载")
	quit()
