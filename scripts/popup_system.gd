extends Node

## 统一弹窗系统 (Autoload 单例)
## 所有需要弹出信息弹窗的地方都调用这个系统

# ---- UI 节点 ----
var _backdrop: ColorRect = null
var _popup_panel: PanelContainer = null
var _title_label: Label = null
var _content_label: Label = null
var _description_label: Label = null
var _confirm_button: Button = null
var _close_button: TextureButton = null
var _button_container: HBoxContainer = null

# ---- 回调 ----
var _on_confirm_cb: Callable = Callable()
var _on_close_cb: Callable = Callable()

# ---- 常量 ----
const POPUP_WIDTH := 800
const POPUP_HEIGHT := 600
const POPUP_PADDING := 32
const BUTTON_HEIGHT := 56
const CLOSE_TEXTURE := preload("res://art/sprites/UI/items/smallItem/close.png")
const POP_TEXTURE := preload("res://art/sprites/UI/panels/pop.png")


func _ready() -> void:
	_create_popup_ui()


func _create_popup_ui() -> void:
	# 遮罩层
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.6)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.visible = false
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.z_index = 99  # 设置层级
	# 添加到根节点 (延迟到场景树准备好)
	get_tree().root.call_deferred("add_child", _backdrop)

	# 弹窗面板
	_popup_panel = PanelContainer.new()
	_popup_panel.set_anchors_preset(Control.PRESET_CENTER)
	_popup_panel.anchor_left = 0.5
	_popup_panel.anchor_top = 0.5
	_popup_panel.anchor_right = 0.5
	_popup_panel.anchor_bottom = 0.5
	_popup_panel.offset_left = -POPUP_WIDTH / 2.0
	_popup_panel.offset_top = -POPUP_HEIGHT / 2.0
	_popup_panel.offset_right = POPUP_WIDTH / 2.0
	_popup_panel.offset_bottom = POPUP_HEIGHT / 2.0
	_popup_panel.custom_minimum_size = Vector2(POPUP_WIDTH, POPUP_HEIGHT)
	_popup_panel.visible = false
	_popup_panel.z_index = 100  # 设置层级，确保在所有面板之上

	# 样式：使用 pop.png 作为背景
	var style := StyleBoxTexture.new()
	style.texture = POP_TEXTURE
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = POPUP_PADDING
	style.content_margin_right = POPUP_PADDING
	style.content_margin_top = POPUP_PADDING
	style.content_margin_bottom = POPUP_PADDING
	_popup_panel.add_theme_stylebox_override("panel", style)

	# 主容器
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	_popup_panel.add_child(vbox)

	# 标题栏（使用 HBoxContainer 实现标题居中）
	var title_bar := HBoxContainer.new()
	title_bar.custom_minimum_size.y = 80
	vbox.add_child(title_bar)

	# 左侧占位（与右侧关闭按钮对称）
	var left_spacer := Control.new()
	left_spacer.custom_minimum_size = Vector2(80, 80)
	title_bar.add_child(left_spacer)

	# 标题（居中）
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(_title_label)

	# 关闭按钮（右侧，150x150）
	_close_button = TextureButton.new()
	_close_button.texture_normal = CLOSE_TEXTURE
	_close_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_close_button.ignore_texture_size = true
	_close_button.custom_minimum_size = Vector2(80, 80)
	_close_button.pressed.connect(_on_close_pressed)
	title_bar.add_child(_close_button)

	# 分割线
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 内容
	_content_label = Label.new()
	_content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # 左右居中
	_content_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_label.add_theme_font_size_override("font_size", 24)
	_content_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_content_label.custom_minimum_size.y = 200
	_content_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_content_label)

	# 说明前添加空行
	var desc_spacer := Control.new()
	desc_spacer.custom_minimum_size.y = 20
	vbox.add_child(desc_spacer)

	# 说明（用于确认键的作用）
	_description_label = Label.new()
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_font_size_override("font_size", 24)
	_description_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_description_label.visible = false
	vbox.add_child(_description_label)

	# 按钮容器
	_button_container = HBoxContainer.new()
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 12)
	vbox.add_child(_button_container)

	# 确认按钮
	_confirm_button = Button.new()
	_confirm_button.custom_minimum_size = Vector2(150, BUTTON_HEIGHT)
	_confirm_button.text = "确认"
	_confirm_button.add_theme_font_size_override("font_size", 22)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_button_container.add_child(_confirm_button)

	# 添加到根节点 (延迟到场景树准备好)
	get_tree().root.call_deferred("add_child", _popup_panel)


## 显示弹窗
## title: 标题（物品名/角色名）
## content: 内容（详细说明）
## description: 说明（确认键的作用，如"是否购买？"）
## confirm_text: 确认键文字（null则隐藏确认键）
## close_text: 关闭键文字（null则隐藏关闭键）
## on_confirm: 确认回调
## on_close: 关闭回调
func show(
	title: String,
	content: String = "",
	description: String = "",
	confirm_text: String = "",
	close_text: String = "",
	on_confirm: Callable = Callable(),
	on_close: Callable = Callable()
) -> void:
	if _popup_panel == null:
		_create_popup_ui()

	# 设置内容
	_title_label.text = title
	_content_label.text = content if content != "" else " "
	# 说明文字换行时多空一行
	_description_label.text = "\n" + description if description != "" else ""
	_description_label.visible = description != ""

	# 设置回调
	_on_confirm_cb = on_confirm
	_on_close_cb = on_close

	# 设置按钮
	_confirm_button.text = confirm_text if confirm_text != "" else "确认"
	_confirm_button.visible = confirm_text != ""

	# 固定尺寸，无需动态计算
	# _update_popup_size()

	# 显示（确保在最上层）
	_backdrop.visible = true
	_popup_panel.visible = true
	_popup_panel.modulate = Color(1, 1, 1, 0)
	
	# 移动到根节点最前面
	var root: Window = get_tree().root
	root.move_child(_backdrop, root.get_child_count() - 1)
	root.move_child(_popup_panel, root.get_child_count() - 1)

	var tween := create_tween()
	tween.tween_property(_popup_panel, "modulate:a", 1.0, 0.15)


func _update_popup_size() -> void:
	# 固定尺寸 800x600，不再动态计算
	pass


## 隐藏弹窗
func hide() -> void:
	if _popup_panel == null:
		return

	var tween := create_tween()
	tween.tween_property(_popup_panel, "modulate:a", 0.0, 0.1)
	await tween.finished

	_backdrop.visible = false
	_popup_panel.visible = false
	_on_confirm_cb = Callable()
	_on_close_cb = Callable()


## 检查弹窗是否打开
func is_open() -> bool:
	return _popup_panel != null and _popup_panel.visible


func _on_confirm_pressed() -> void:
	var cb := _on_confirm_cb
	hide()
	if cb.is_valid():
		cb.call()


func _on_close_pressed() -> void:
	var cb := _on_close_cb
	hide()
	if cb.is_valid():
		cb.call()
