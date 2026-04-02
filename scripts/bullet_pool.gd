extends RefCounted
class_name BulletPool

## 子弹对象池 - 避免频繁实例化和销毁

var pool: Array = []
var active_bullets: Array = []
var bullet_scene: PackedScene
var container: Node
var max_pool_size: int = 30


func _init(p_container: Node, p_max_size: int = 30) -> void:
	container = p_container
	max_pool_size = p_max_size
	bullet_scene = preload("res://scenes/battle_bullet.tscn")
	_preload_pool()


func _preload_pool() -> void:
	for i in range(max_pool_size):
		var bullet = bullet_scene.instantiate()
		bullet.is_active = false
		bullet.visible = false
		container.add_child(bullet)
		pool.append(bullet)


func get_bullet() -> CharacterBody2D:
	var bullet: CharacterBody2D

	if pool.size() > 0:
		bullet = pool.pop_back()
	else:
		# 池为空，动态创建
		bullet = bullet_scene.instantiate()
		container.add_child(bullet)

	bullet.is_active = false
	bullet.visible = true
	active_bullets.append(bullet)
	return bullet


func return_bullet(bullet: CharacterBody2D) -> void:
	if bullet == null or not is_instance_valid(bullet):
		return

	bullet.is_active = false
	bullet.visible = false
	bullet.global_position = Vector2(-1000, -1000)  # 移出可见区域

	var idx := active_bullets.find(bullet)
	if idx >= 0:
		active_bullets.remove_at(idx)

	# 断开该子弹的所有信号连接（信号在 battle_scene.gd 中连接）
	_disconnect_bullet_signals(bullet)

	# 清理子节点（发光效果等）
	for child in bullet.get_children():
		child.queue_free()

	pool.append(bullet)


## 断开子弹的所有信号连接
func _disconnect_bullet_signals(bullet: CharacterBody2D) -> void:
	# 获取所有信号的连接列表并断开
	for signal_name in ["bullet_hit", "bullet_finished"]:
		var signal_obj: Signal = bullet.get(signal_name)
		if signal_obj.get_connections().size() > 0:
			for conn in signal_obj.get_connections():
				var callable: Callable = conn.callable
				if callable.is_valid():
					signal_obj.disconnect(callable)


func return_all() -> void:
	while active_bullets.size() > 0:
		return_bullet(active_bullets[0])


func get_active_count() -> int:
	return active_bullets.size()


func get_pool_count() -> int:
	return pool.size()
