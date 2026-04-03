extends Node

## 提示信息管理器 (Autoload 单例)
## 显示1秒钟的提示信息后自动隐藏

# ---- UI 节点 ----
var _tip_label: Label = null
var _tip_container: PanelContainer = null
var _fade_tween: Tween = null

# ---- 常量 ----
const DEFAULT_DURATION := 1.0
const TIP_COLOR := Color(0.1, 0.1, 0.1, 0.85)
const TEXT_COLOR := Color(1.0, 1.0, 0.9, 1.0)


func _ready() -> void:
	_create_tip_ui()


func _create_tip_ui() -> void:
	# 容器
	_tip_container = PanelContainer.new()
	_tip_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tip_container.anchor_left = 0.5
	_tip_container.anchor_right = 0.5
	_tip_container.offset_left = -150
	_tip_container.offset_top = 20
	_tip_container.offset_right = 150
	_tip_container.offset_bottom = 60
	_tip_container.custom_minimum_size = Vector2(300, 40)
	_tip_container.modulate = Color(1, 1, 1, 0)  # 初始隐藏

	# 样式
	var style := StyleBoxFlat.new()
	style.bg_color = TIP_COLOR
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_tip_container.add_theme_stylebox_override("panel", style)

	# 标签
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tip_container.add_child(center)

	_tip_label = Label.new()
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tip_label.add_theme_color_override("font_color", TEXT_COLOR)
	_tip_label.add_theme_font_size_override("font_size", 18)
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(_tip_label)

	# 添加到根节点
	# 添加到根节点 (延迟到场景树准备好)
	if not _tip_container.get_parent() == get_tree().root:
		get_tree().root.call_deferred("add_child", _tip_container)


## 显示提示信息（默认1秒后自动隐藏）
func show_tip(text: String, duration: float = DEFAULT_DURATION) -> void:
	if _tip_container == null:
		_create_tip_ui()

	# 停止之前的动画
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	# 设置文本
	_tip_label.text = text
	_tip_container.visible = true
	_tip_container.modulate = Color(1, 1, 1, 0)

	# 淡入动画
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(_tip_container, "modulate:a", 1.0, 0.15)

	# 等待持续时间
	await get_tree().create_timer(duration - 0.15).timeout

	# 淡出动画
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(_tip_container, "modulate:a", 0.0, 0.15)

	# 等待淡出完成后隐藏
	await get_tree().create_timer(0.15).timeout
	_tip_container.visible = false


## 立即隐藏提示
func hide_tip() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if _tip_container != null:
		_tip_container.modulate = Color(1, 1, 1, 0)
		_tip_container.visible = false
