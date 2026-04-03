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
var _close_button: Button = null
var _button_container: HBoxContainer = null

# ---- 回调 ----
var _on_confirm_cb: Callable = Callable()
var _on_close_cb: Callable = Callable()

# ---- 常量 ----
const POPUP_WIDTH := 360
const POPUP_PADDING := 24
const BUTTON_HEIGHT := 44


func _ready() -> void:
	_create_popup_ui()


func _create_popup_ui() -> void:
	# 遮罩层
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.6)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.visible = false
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().root.add_child(_backdrop)

	# 弹窗面板
	_popup_panel = PanelContainer.new()
	_popup_panel.set_anchors_preset(Control.PRESET_CENTER)
	_popup_panel.anchor_left = 0.5
	_popup_panel.anchor_top = 0.5
	_popup_panel.anchor_right = 0.5
	_popup_panel.anchor_bottom = 0.5
	_popup_panel.offset_left = -POPUP_WIDTH / 2.0
	_popup_panel.offset_top = -150.0
	_popup_panel.offset_right = POPUP_WIDTH / 2.0
	_popup_panel.offset_bottom = 150.0
	_popup_panel.visible = false

	# 样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.98)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = POPUP_PADDING
	style.content_margin_right = POPUP_PADDING
	style.content_margin_top = POPUP_PADDING
	style.content_margin_bottom = POPUP_PADDING
	_popup_panel.add_theme_stylebox_override("panel", style)

	# 主容器
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_popup_panel.add_child(vbox)

	# 标题
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	vbox.add_child(_title_label)

	# 分割线
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 内容
	_content_label = Label.new()
	_content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_content_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_label.add_theme_font_size_override("font_size", 16)
	_content_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_content_label.custom_minimum_size.y = 80
	vbox.add_child(_content_label)

	# 说明（用于确认键的作用）
	_description_label = Label.new()
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_font_size_override("font_size", 14)
	_description_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_description_label.visible = false
	vbox.add_child(_description_label)

	# 按钮容器
	_button_container = HBoxContainer.new()
	_button_container.alignment = BoxContainer.ALIGNMENT_END
	_button_container.add_theme_constant_override("separation", 12)
	vbox.add_child(_button_container)

	# 关闭按钮
	_close_button = Button.new()
	_close_button.custom_minimum_size = Vector2(100, BUTTON_HEIGHT)
	_close_button.text = "关闭"
	_close_button.pressed.connect(_on_close_pressed)
	_button_container.add_child(_close_button)

	# 确认按钮
	_confirm_button = Button.new()
	_confirm_button.custom_minimum_size = Vector2(100, BUTTON_HEIGHT)
	_confirm_button.text = "确认"
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_button_container.add_child(_confirm_button)

	get_tree().root.add_child(_popup_panel)


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
	_description_label.text = description
	_description_label.visible = description != ""

	# 设置回调
	_on_confirm_cb = on_confirm
	_on_close_cb = on_close

	# 设置按钮
	_close_button.text = close_text if close_text != "" else "关闭"
	_close_button.visible = close_text != ""

	_confirm_button.text = confirm_text if confirm_text != "" else "确认"
	_confirm_button.visible = confirm_text != ""

	# 计算弹窗高度
	_update_popup_size()

	# 显示
	_backdrop.visible = true
	_popup_panel.visible = true
	_popup_panel.modulate = Color(1, 1, 1, 0)

	var tween := create_tween()
	tween.tween_property(_popup_panel, "modulate:a", 1.0, 0.15)


func _update_popup_size() -> void:
	# 根据内容调整高度
	var content_height: float = max(_content_label.get_minimum_size().y, 60.0)
	if _description_label.visible:
		content_height += 30.0

	# 估计总高度
	var total_height: float = POPUP_PADDING * 2.0 + 40.0 + 8.0 + content_height + 8.0
	if _description_label.visible:
		total_height += 30.0
	total_height += BUTTON_HEIGHT + 16.0

	_popup_panel.offset_top = -total_height / 2.0
	_popup_panel.offset_bottom = total_height / 2.0
	_content_label.custom_minimum_size.y = content_height


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
