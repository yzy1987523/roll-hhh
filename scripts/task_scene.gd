extends Control

## 任务界面
## 显示局内任务和局外成就

const TASK_ITEM_SCENE = preload("res://scenes/task_item.tscn")

@onready var tab_container: TabContainer = $VBox/TabContainer
@onready var in_task_scroll: ScrollContainer = $VBox/TabContainer/InTaskScroll
@onready var in_task_vbox: VBoxContainer = $VBox/TabContainer/InTaskScroll/InTaskVBox
@onready var out_task_scroll: ScrollContainer = $VBox/TabContainer/OutTaskScroll
@onready var out_task_vbox: VBoxContainer = $VBox/TabContainer/OutTaskScroll/OutTaskVBox
@onready var close_btn: Button = $VBox/CloseBtn
@onready var stars_label: Label = $VBox/StarsLabel
@onready var exp_label: Label = $VBox/ExpLabel
@onready var level_label: Label = $VBox/LevelLabel

func _ready() -> void:
	close_btn.clicked.connect(_on_close)
	_refresh_display()

	# 连接任务管理器信号
	TaskManager.task_completed.connect(_on_task_completed)
	TaskManager.achievement_completed.connect(_on_achievement_completed)
	TaskManager.stars_changed.connect(_on_stars_changed)
	TaskManager.exp_changed.connect(_on_exp_changed)


func show_task_ui() -> void:
	_refresh_display()
	visible = true


func hide_task_ui() -> void:
	visible = false


func _on_close() -> void:
	hide_task_ui()


func _refresh_display() -> void:
	# 更新货币显示
	stars_label.text = "★ %d" % TaskManager.stars
	exp_label.text = "经验: %d" % TaskManager.exp
	level_label.text = "Lv.%d" % TaskManager.player_level

	# 刷新局内任务列表
	_refresh_in_tasks()

	# 刷新局外成就列表
	_refresh_out_tasks()


func _refresh_in_tasks() -> void:
	# 清空现有内容
	for child in in_task_vbox.get_children():
		child.queue_free()

	# 获取当前任务
	var current_task_id: int = TaskManager.get_current_task_id()
	var completed_ids: Array = TaskManager.get_completed_in_task_ids()

	# 获取所有任务
	var all_tasks: Array = TaskManager.get_all_in_tasks()

	for task in all_tasks:
		var task_id: int = task.get("id", 0)
		var task_item = TASK_ITEM_SCENE.instantiate()
		task_item.setup_in_task(task, task_id == current_task_id, task_id in completed_ids)
		in_task_vbox.add_child(task_item)


func _refresh_out_tasks() -> void:
	# 清空现有内容
	for child in out_task_vbox.get_children():
		child.queue_free()

	var completed_ids: Array = TaskManager.get_completed_achievement_ids()
	var all_tasks: Array = TaskManager.get_all_out_tasks()

	for task in all_tasks:
		var task_id: int = task.get("id", 0)
		var progress: float = TaskManager.get_achievement_progress(task_id)
		var task_item = TASK_ITEM_SCENE.instantiate()
		task_item.setup_out_task(task, progress, task_id in completed_ids)
		out_task_vbox.add_child(task_item)


func _on_task_completed(task_id: int, _reward: Dictionary) -> void:
	print(">>> [TaskScene] 局内任务完成: %d" % task_id)
	_refresh_display()


func _on_achievement_completed(task_id: int, reward_exp: int) -> void:
	print(">>> [TaskScene] 成就完成: %d, 经验奖励: %d" % [task_id, reward_exp])
	_refresh_display()


func _on_stars_changed(new_stars: int) -> void:
	stars_label.text = "★ %d" % new_stars


func _on_exp_changed(new_exp: int) -> void:
	exp_label.text = "经验: %d" % new_exp
	level_label.text = "Lv.%d" % TaskManager.player_level
