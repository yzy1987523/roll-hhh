extends PanelContainer

## 单个任务/成就条目

@onready var status_icon: TextureRect = $HBox/StatusIcon
@onready var task_name: Label = $HBox/InfoVBox/TaskName
@onready var task_desc: Label = $HBox/InfoVBox/TaskDesc
@onready var coin_icon: TextureRect = $HBox/RewardHBox/CoinIcon
@onready var coin_label: Label = $HBox/RewardHBox/CoinLabel
@onready var star_icon: TextureRect = $HBox/RewardHBox/StarIcon
@onready var star_label: Label = $HBox/RewardHBox/StarLabel
@onready var exp_label: Label = $HBox/RewardHBox/ExpLabel
@onready var progress_bar: ProgressBar = $HBox/ProgressBar

# 图标路径
const ICON_PATH := {
	"completed": "res://art/sprites/UI/icon/ok.png",
	"current": "res://art/sprites/UI/icon/new.png",
	"locked": "res://art/sprites/UI/icon/lock.png",
	"coin": "res://art/sprites/UI/icon/jinbi.png",
	"star": "res://art/sprites/UI/icon/jingyan.png",
}


func setup_in_task(task_data: Dictionary, is_current: bool, is_completed: bool) -> void:
	"""设置局内任务显示"""
	task_name.text = task_data.get("name", "")
	task_desc.text = task_data.get("content", "")

	# 状态图标
	if is_completed:
		_set_icon(status_icon, ICON_PATH["completed"])
		modulate = Color(0.6, 0.6, 0.6)  # 已完成变灰
	elif is_current:
		_set_icon(status_icon, ICON_PATH["current"])
		modulate = Color(1, 1, 1)
	else:
		# 未解锁或未接取
		_set_icon(status_icon, ICON_PATH["locked"])
		modulate = Color(0.5, 0.5, 0.5)

	# 奖励显示
	var reward: Dictionary = task_data.get("reward", {})
	var coin: int = reward.get("coin", 0)
	var star: int = reward.get("star", 0)
	var items: Array = reward.get("items", [])

	if coin > 0:
		coin_icon.visible = true
		coin_label.visible = true
		coin_label.text = "+%d" % coin

	if star > 0:
		star_icon.visible = true
		star_label.visible = true
		star_label.text = "+%d" % star

	# 局内任务没有进度条
	progress_bar.visible = false


func setup_out_task(task_data: Dictionary, progress: float, is_completed: bool) -> void:
	"""设置局外成就显示"""
	task_name.text = task_data.get("name", "")
	task_desc.text = task_data.get("desc", "")

	# 状态图标
	if is_completed:
		_set_icon(status_icon, ICON_PATH["completed"])
		modulate = Color(0.6, 0.6, 0.6)
	elif progress > 0:
		_set_icon(status_icon, ICON_PATH["current"])
		modulate = Color(1, 1, 1)
	else:
		_set_icon(status_icon, ICON_PATH["locked"])
		modulate = Color(0.5, 0.5, 0.5)

	# 经验奖励
	var exp_reward: int = task_data.get("expReward", 0)
	if exp_reward > 0:
		exp_label.visible = true
		exp_label.text = "+%dexp" % exp_reward

	# 进度条
	progress_bar.visible = true
	progress_bar.value = progress

	# 隐藏coin和star
	coin_icon.visible = false
	coin_label.visible = false
	star_icon.visible = false
	star_label.visible = false


func _set_icon(texture_rect: TextureRect, path: String) -> void:
	if ResourceLoader.exists(path):
		texture_rect.texture = load(path)
	else:
		texture_rect.texture = null
