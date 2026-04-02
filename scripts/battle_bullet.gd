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

# ---- 子弹精灵路径 ----
const BULLET_SPRITE_BASE_PATH: String = "res://art/sprites/UI/items/bullet/"

# ---- 子弹职业(Job)到精灵索引的映射 ----
# job: 0=战士, 1=法师, 2=牧师, 3=敌人
const JOB_TO_SPRITE_INDEX: Dictionary = {
	0: 1,   # WARRIOR -> 1
	1: 2,   # MAGE -> 2
	2: 3,   # PRIEST -> 3
	3: 4,   # ENEMY -> 4
}

var job: int = 0       # 子弹职业 (0-3)
var tier: int = 1      # 子弹 tier (1-3)


func _ready() -> void:
	# 设置碰撞层
	collision_layer = 0
	collision_mask = 0  # 子弹不与物理对象碰撞，靠脚本逻辑


func setup(p_bullet_type: int, p_damage: int, p_target_index: int,
		p_source_pos: Vector2, p_target_pos: Vector2, p_job: int = 0, p_tier: int = 1) -> void:
	bullet_type = p_bullet_type
	damage = p_damage
	target_index = p_target_index
	source_position = p_source_pos
	target_position = p_target_pos
	is_active = true
	job = p_job
	tier = p_tier

	# 设置位置
	global_position = p_source_pos

	# 设置颜色为白色
	modulate = Color.WHITE

	# 创建视觉元素
	_setup_bullet_visual()


func _setup_bullet_visual() -> void:
	# 构建子弹精灵路径: bullet_{job}_{tier}.png
	var sprite_job: int = JOB_TO_SPRITE_INDEX.get(job, 1)
	var sprite_path: String = BULLET_SPRITE_BASE_PATH + "bullet_%d_%d.png" % [sprite_job, tier]

	# 加载精灵图
	var tex: Texture2D = null
	if ResourceLoader.exists(sprite_path):
		tex = load(sprite_path)

	var sprite := Sprite2D.new()
	if tex != null:
		sprite.texture = tex
		sprite.centered = true
	else:
		# Fallback: 创建简单圆形精灵
		var fallback_tex := GradientTexture2D.new()
		fallback_tex.width = 16
		fallback_tex.height = 16
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		fallback_tex.gradient = gradient
		sprite.texture = fallback_tex
		sprite.centered = true
		print(">>> [BattleBullet] 子弹精灵加载失败，使用默认: " + sprite_path)

	add_child(sprite)
	# 设置子弹尺寸为原来的0.3倍
	sprite.scale = Vector2(0.3, 0.3)

	# 添加发光效果
	var glow := PointLight2D.new()
	glow.color = Color.WHITE
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

	# 设置子弹旋转，使上方朝向目标
	rotation = direction.angle() - PI / 2

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
