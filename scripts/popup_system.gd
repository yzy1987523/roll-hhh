extends Node

## 统一弹窗系统 (Autoload 单例)
## 使用 popup_scene.tscn 预制体

# ---- UI 节点 ----
var _backdrop: ColorRect = null
var _current_popup: Control = null

# ---- 回调 ----
var _on_confirm_cb: Callable = Callable()
var _on_close_cb: Callable = Callable()

func _ready() -> void:
	_create_backdrop()


func _create_backdrop() -> void:
	# 遮罩层
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.6)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.visible = false
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.z_index = 199
	get_tree().root.call_deferred("add_child", _backdrop)


## 显示弹窗
func show(
	p_title: String,
	p_content: String = "",
	p_description: String = "",
	p_confirm_text: String = "",
	p_close_text: String = "",
	p_on_confirm: Callable = Callable(),
	p_on_close: Callable = Callable()
) -> void:
	# 隐藏之前的弹窗
	if _current_popup != null:
		hide()

	# 实例化预制体（运行时加载）
	var popup_scene: PackedScene = ResourceLoader.load("res://scenes/popup_scene.tscn")
	_current_popup = popup_scene.instantiate()
	_current_popup.setup(
		p_title,
		p_content,
		p_description,
		p_confirm_text,
		p_close_text,
		p_on_confirm,
		p_on_close
	)

	# 连接信号
	_current_popup.confirmed.connect(_on_popup_confirmed)
	_current_popup.closed.connect(_on_popup_closed)

	# 添加到根节点
	get_tree().root.add_child(_current_popup)

	# 移动到根节点最前面
	var root: Window = get_tree().root
	root.move_child(_backdrop, root.get_child_count() - 1)
	root.move_child(_current_popup, root.get_child_count() - 1)

	# 显示背景
	_backdrop.visible = true

	# 淡入动画
	_current_popup.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_current_popup, "modulate:a", 1.0, 0.15)


## 隐藏弹窗
func hide() -> void:
	if _current_popup == null:
		return

	var popup = _current_popup
	_current_popup = null
	_on_confirm_cb = Callable()
	_on_close_cb = Callable()

	# 淡出动画
	var tween := create_tween()
	tween.tween_property(popup, "modulate:a", 0.0, 0.1)
	await tween.finished

	if is_instance_valid(popup):
		popup.queue_free()

	_backdrop.visible = false


## 设置奖励图标（显示物品图标列表）
func set_reward_icons(item_ids: Array) -> void:
	if _current_popup != null and _current_popup.has_method("set_reward_icons"):
		_current_popup.set_reward_icons(item_ids)


## 检查弹窗是否打开
func is_open() -> bool:
	return _current_popup != null and is_instance_valid(_current_popup)


func _on_popup_confirmed() -> void:
	var cb := _on_confirm_cb
	hide()
	if cb.is_valid():
		cb.call()


func _on_popup_closed() -> void:
	var cb := _on_close_cb
	hide()
	if cb.is_valid():
		cb.call()
