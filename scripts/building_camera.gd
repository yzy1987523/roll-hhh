extends Camera2D

## 建造场景相机缩放控制
## 支持鼠标滚轮和触屏捏合手势

# 缩放限制
const ZOOM_MIN: float = 0.8
const ZOOM_MAX: float = 1.2
const ZOOM_STEP: float = 0.05
const ZOOM_TWEEN_DURATION: float = 0.15

# 当前目标缩放
var _target_zoom: float = 1.0
var _zoom_tween: Tween = null

# 触屏捏合
var _touch_points: Dictionary = {}
var _initial_pinch_distance: float = 0.0
var _initial_pinch_zoom: float = 1.0


func _ready() -> void:
	_target_zoom = zoom.x
	print(">>> [BuildingCamera] 相机缩放初始化: zoom=%s" % zoom)


func _unhandled_input(event: InputEvent) -> void:
	# 鼠标滚轮缩放
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(-ZOOM_STEP)

	# 触屏捏合缩放
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
		else:
			_touch_points.erase(event.index)
		if _touch_points.size() == 2:
			var points = _touch_points.values()
			_initial_pinch_distance = points[0].distance_to(points[1])
			_initial_pinch_zoom = _target_zoom

	if event is InputEventScreenDrag:
		_touch_points[event.index] = event.position
		if _touch_points.size() == 2:
			var points = _touch_points.values()
			var current_distance: float = points[0].distance_to(points[1])
			if _initial_pinch_distance > 0:
				var zoom_factor: float = current_distance / _initial_pinch_distance
				var new_zoom: float = clampf(_initial_pinch_zoom * zoom_factor, ZOOM_MIN, ZOOM_MAX)
				_set_target_zoom(new_zoom)


func _zoom_by(amount: float) -> void:
	_set_target_zoom(clampf(_target_zoom + amount, ZOOM_MIN, ZOOM_MAX))


func _set_target_zoom(new_zoom: float) -> void:
	_target_zoom = new_zoom
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(self, "zoom", Vector2(_target_zoom, _target_zoom), ZOOM_TWEEN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
