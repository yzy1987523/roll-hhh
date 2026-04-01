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

	# 清理子节点（发光效果等）- 使用循环因为节点会变化
	while bullet.get_child_count() > 0:
		var child = bullet.get_child(0)
		child.queue_free()

	pool.append(bullet)


func return_all() -> void:
	while active_bullets.size() > 0:
		return_bullet(active_bullets[0])


func get_active_count() -> int:
	return active_bullets.size()


func get_pool_count() -> int:
	return pool.size()
