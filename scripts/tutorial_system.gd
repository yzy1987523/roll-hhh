extends CanvasLayer

## 新手教学系统
## 任务 7.1: 5步引导 (生成→合成→站位→详情/献祭/图鉴→结束回合)

const TUTORIAL_KEY := "roll_hhh_tutorial_done"

signal tutorial_completed
signal step_changed(step: int)

var current_step: int = 0
var is_active: bool = false
var _game_board = null  # Reference to game_board scene

# Tutorial step definitions
var steps: Array = [
	{
		"text": "欢迎! 点击下方的[生成]按钮,\n消耗能量生成一个角色",
		"highlight": "spawn_area",
	},
	{
		"text": "再生成一些角色吧!\n同职业+同等级的角色可以合成升级",
		"highlight": "board_area",
	},
	{
		"text": "拖拽角色调整站位\n前排角色会优先承受敌方攻击",
		"highlight": "board_area",
	},
	{
		"text": "左键点击角色查看详情\n右键点击可以献祭角色回收能量\n点击[图鉴]按钮查看所有角色",
		"highlight": "info_area",
	},
	{
		"text": "准备好了吗?\n点击[结束回合]进入战斗!",
		"highlight": "end_turn_area",
	},
]

@onready var overlay: ColorRect = $Overlay
@onready var instruction_label: Label = $InstructionPanel/InstructionLabel
@onready var instruction_panel: PanelContainer = $InstructionPanel
@onready var skip_button: Button = $SkipButton
@onready var highlight_rect: ColorRect = $HighlightRect


func _ready() -> void:
	skip_button.pressed.connect(_on_skip)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


## Check if tutorial should start
func check_and_start(game_board_ref) -> void:
	_game_board = game_board_ref

	# Check if already completed
	if _is_tutorial_done():
		print(">>> [Tutorial] 教学已完成, 跳过")
		return

	start_tutorial()


func start_tutorial() -> void:
	is_active = true
	current_step = 0
	visible = true
	_show_step()
	print(">>> [Tutorial] 新手教学开始")


func advance_step() -> void:
	if not is_active:
		return
	current_step += 1
	if current_step >= steps.size():
		complete_tutorial()
		return
	_show_step()
	step_changed.emit(current_step)


func complete_tutorial() -> void:
	is_active = false
	visible = false
	_mark_tutorial_done()
	tutorial_completed.emit()
	print(">>> [Tutorial] 新手教学完成!")


func _show_step() -> void:
	if current_step >= steps.size():
		return

	var step: Dictionary = steps[current_step]
	instruction_label.text = step["text"]

	# Position highlight based on step
	_update_highlight(step["highlight"])


func _update_highlight(area: String) -> void:
	# Default: full overlay, small highlight
	overlay.visible = true
	highlight_rect.visible = true

	# Get viewport size
	var vp_size: Vector2 = get_viewport().get_visible_rect().size

	match area:
		"spawn_area":
			# Highlight bottom spawn buttons area
			highlight_rect.position = Vector2(0, vp_size.y - 100)
			highlight_rect.size = Vector2(vp_size.x, 100)
			instruction_panel.position = Vector2(20, vp_size.y * 0.4)
		"board_area":
			# Highlight the center board area
			var board_y: float = vp_size.y * 0.25
			var board_h: float = vp_size.y * 0.45
			highlight_rect.position = Vector2(10, board_y)
			highlight_rect.size = Vector2(vp_size.x - 20, board_h)
			instruction_panel.position = Vector2(20, vp_size.y * 0.05)
		"info_area":
			# Highlight top info + board area
			highlight_rect.position = Vector2(0, 0)
			highlight_rect.size = Vector2(vp_size.x, vp_size.y * 0.7)
			instruction_panel.position = Vector2(20, vp_size.y * 0.72)
		"end_turn_area":
			# Highlight bottom bar with end turn button
			highlight_rect.position = Vector2(0, vp_size.y - 100)
			highlight_rect.size = Vector2(vp_size.x, 100)
			instruction_panel.position = Vector2(20, vp_size.y * 0.4)
		_:
			highlight_rect.visible = false


func _on_skip() -> void:
	complete_tutorial()


func _is_tutorial_done() -> bool:
	var save_node = get_node_or_null("/root/SaveSystem")
	if save_node != null and save_node.has_method("is_tutorial_done"):
		return save_node.is_tutorial_done()
	# Check LocalStorage directly
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("localStorage.getItem('%s')" % TUTORIAL_KEY)
		return result != null and result is String and result == "true"
	else:
		return FileAccess.file_exists("user://%s.json" % TUTORIAL_KEY)


func _mark_tutorial_done() -> void:
	var save_node = get_node_or_null("/root/SaveSystem")
	if save_node != null and save_node.has_method("mark_tutorial_done"):
		save_node.mark_tutorial_done()
	else:
		if OS.has_feature("web"):
			JavaScriptBridge.eval("localStorage.setItem('%s', 'true')" % TUTORIAL_KEY)
		else:
			var file := FileAccess.open("user://%s.json" % TUTORIAL_KEY, FileAccess.WRITE)
			if file:
				file.store_string("true")
				file.close()
