extends CharacterBody2D
class_name BattleBullet

## 子弹脚本 - 负责移动和碰撞检测

# ---- 子弹类型 ----
enum BulletType {
	ATTACK,     # 攻击子弹
	HEAL,       # 治疗子弹
	BLESS,      # 祝福子弹
	ENEMY,      # 敌方子弹
}

# ---- 信号 ----
signal bullet_hit(target_idx: int, damage: int, bullet_type: int)
signal bullet_finished()

# ---- 属性 ----
var bullet_type: int = BulletType.ATTACK
var damage: int = 0
var target_index: int = -1  # 目标在棋盘格子中的索引
var source_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var speed: float = 800.0  # 像素/秒
var is_active: bool = false

# ---- 子弹颜色（按类型） ----
const BULLET_COLORS: Dictionary = {
	BulletType.ATTACK: Color("#FF4444"),   # 红色 - 物理攻击
	BulletType.HEAL: Color("#44FF44"),     # 绿色 - 治疗
	BulletType.BLESS: Color("#FFD700"),    # 金色 - 祝福
	BulletType.ENEMY: Color("#9400D3"),    # 紫色 - 敌方子弹
}

# ---- 子弹图标（按职业） ----
const JOB_BULLET_SHAPES: Dictionary = {
	0: "circle",   # WARRIOR - 圆形
	1: "diamond",  # MAGE - 菱形
	2: "star",     # PRIEST - 星星
}


func _ready() -> void:
	# 设置碰撞层
	collision_layer = 0
	collision_mask = 0  # 子弹不与物理对象碰撞，靠脚本逻辑


func setup(p_bullet_type: int, p_damage: int, p_target_index: int,
		p_source_pos: Vector2, p_target_pos: Vector2) -> void:
	bullet_type = p_bullet_type
	damage = p_damage
	target_index = p_target_index
	source_position = p_source_pos
	target_position = p_target_pos
	is_active = true

	# 设置位置
	global_position = p_source_pos

	# 设置颜色
	var color: Color = BULLET_COLORS.get(p_bullet_type, Color.WHITE)
	modulate = color

	# 设置大小
	var base_size: float = 8.0
	if p_bullet_type == BulletType.ENEMY:
		base_size = 10.0  # 敌方子弹稍大
	elif p_bullet_type == BulletType.BLESS:
		base_size = 6.0  # 祝福子弹较小

	# 创建视觉元素
	_setup_bullet_visual(p_bullet_type, base_size)


func _setup_bullet_visual(b_type: int, size: float) -> void:
	# 创建简单的圆形精灵
	var tex := GradientTexture2D.new()
	tex.width = int(size * 2)
	tex.height = int(size * 2)

	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = gradient

	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	add_child(sprite)

	# 添加发光效果
	var glow := PointLight2D.new()
	glow.color = BULLET_COLORS.get(b_type, Color.WHITE)
	glow.energy = 0.5
	glow.range_layer_min = -1
	glow.range_layer_max = 1
	add_child(glow)


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# 移动向目标
	var direction: Vector2 = (target_position - global_position).normalized()
	var distance: float = global_position.distance_to(target_position)

	if distance < speed * delta:
		# 到达目标
		global_position = target_position
		_on_hit()
	else:
		global_position += direction * speed * delta


func _on_hit() -> void:
	is_active = false
	bullet_hit.emit(target_index, damage, bullet_type)
	# 播放命中特效
	_play_hit_effect()
	await get_tree().create_timer(0.2).timeout
	bullet_finished.emit()
	# 不在这里销毁子弹，由对象池管理


func _play_hit_effect() -> void:
	# 简单的消失动画
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
