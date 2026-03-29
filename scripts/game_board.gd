extends Control

@onready var grid_container: GridContainer = $CenterContainer/GridContainer
@onready var back_button: Button = $BackButton

const GRID_SIZE := 6
const CELL_SIZE := 80

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	setup_board()
	print(">>> [GameBoard] 游戏界面已加载")

func setup_board() -> void:
	grid_container.columns = GRID_SIZE
	for i in range(GRID_SIZE * GRID_SIZE):
		var cell = ColorRect.new()
		cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		# 棋盘格颜色交替 (奇偶行交替)
		@warning_ignore("integer_division")
		var row := i / GRID_SIZE
		var col := i % GRID_SIZE
		var is_even := (row + col) % 2 == 0
		cell.color = Color("#4A90D9") if is_even else Color("#FFFFFF")
		grid_container.add_child(cell)
	print(">>> [GameBoard] %dx%d 棋盘格已生成" % [GRID_SIZE, GRID_SIZE])

func _on_back_pressed() -> void:
	print(">>> [GameBoard] 返回按钮被点击")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
