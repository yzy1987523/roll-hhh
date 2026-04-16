extends PanelContainer

## 弹窗预制体脚本

signal confirmed()
signal closed()

@onready var title_label: Label = $VBox/TitleBar/Title
@onready var close_button: Button = $VBox/TitleBar/CloseButton
@onready var content_label: Label = $VBox/Content
@onready var description_label: Label = $VBox/Description
@onready var confirm_button: Button = $VBox/ButtonContainer/ConfirmButton
@onready var close_btn_bottom: Button = $VBox/ButtonContainer/CloseButton
@onready var icon_container: HBoxContainer = $VBox/IconContainer

var _on_confirm_cb: Callable = Callable()
var _on_close_cb: Callable = Callable()


func _ready() -> void:
	# 关闭按钮（标题栏的X按钮）
	close_button.pressed.connect(_on_close_button_pressed)
	# 确认按钮（底部）
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	# 关闭按钮（底部）
	if close_btn_bottom:
		close_btn_bottom.pressed.connect(_on_close_button_pressed)


func setup(
	p_title: String,
	p_content: String = "",
	p_description: String = "",
	p_confirm_text: String = "",
	p_close_text: String = "",
	p_on_confirm: Callable = Callable(),
	p_on_close: Callable = Callable()
) -> void:
	# 手动获取节点引用（因为 setup() 可能在 _ready() 之前调用）
	if title_label == null:
		title_label = $VBox/TitleBar/Title
	if content_label == null:
		content_label = $VBox/Content
	if description_label == null:
		description_label = $VBox/Description
	if confirm_button == null:
		confirm_button = $VBox/ButtonContainer/ConfirmButton
	if close_button == null:
		close_button = $VBox/TitleBar/CloseButton
	if close_btn_bottom == null:
		close_btn_bottom = $VBox/ButtonContainer/CloseButton
	if icon_container == null:
		icon_container = $VBox/IconContainer
	
	title_label.text = p_title
	content_label.text = p_content if p_content != "" else " "
	description_label.text = "\n" + p_description if p_description != "" else ""
	description_label.visible = p_description != ""

	_on_confirm_cb = p_on_confirm
	_on_close_cb = p_on_close

	confirm_button.visible = p_confirm_text != ""
	close_btn_bottom.visible = p_close_text != ""


func set_reward_icons(item_ids: Array) -> void:
	# 清除旧图标
	for child in icon_container.get_children():
		child.queue_free()

	if item_ids.is_empty():
		icon_container.visible = false
		return

	icon_container.visible = true
	for item_id in item_ids:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var sprite_path: String = ItemManager.get_sprite_path(item_id)
		if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
			icon.texture = load(sprite_path)
		else:
			icon.modulate = Color(0.5, 0.5, 0.5, 1)
		icon_container.add_child(icon)


func _on_confirm_button_pressed() -> void:
	SoundSystem.play_button_click()
	confirmed.emit()
	if _on_confirm_cb.is_valid():
		_on_confirm_cb.call()


func _on_close_button_pressed() -> void:
	SoundSystem.play_button_click()
	closed.emit()
	if _on_close_cb.is_valid():
		_on_close_cb.call()
