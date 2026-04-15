extends Node

## 声音系统 (Autoload 单例)
## 管理BGM淡入淡出切换和音效播放

# ---- BGM配置 ----
const BGM_PREPARE := "res://art/audio/bgm/bgm_0.ogg"  # 备战阶段
const BGM_BATTLE := "res://art/audio/bgm/bgm_1.ogg"   # 战斗阶段

# ---- 音效路径 ----
const SFX_ATTACK_FIRE := "res://art/audio/sfx/battle/sfx_attack_fire.ogg"
const SFX_BULLET_HIT := "res://art/audio/sfx/battle/sfx_bullet_hit.ogg"
const SFX_VICTORY := "res://art/audio/sfx/battle/sfx_victory.ogg"
const SFX_MERGE := "res://art/audio/sfx/gameboard/sfx_merge.ogg"
const SFX_BUTTON_CLICK := "res://art/audio/sfx/ui/sfx_button_click.ogg"

# ---- 音频节点 ----
var _bgm_player_a: AudioStreamPlayer = null
var _bgm_player_b: AudioStreamPlayer = null
var _sfx_player: AudioStreamPlayer = null
var _active_player: AudioStreamPlayer = null  # 当前活跃的BGM播放器

# ---- 配置 ----
const BGM_FADE_DURATION := 1.0  # 淡入淡出时长(秒)
const BGM_VOLUME_DB := -5.0     # BGM音量
const SFX_VOLUME_DB := 0.0      # 音效音量

# ---- 状态 ----
var _current_bgm: String = ""


func _ready() -> void:
	_create_audio_players()
	_connect_phase_signal()


func _create_audio_players() -> void:
	# 创建两个BGM播放器用于交叉淡入淡出
	_bgm_player_a = AudioStreamPlayer.new()
	_bgm_player_a.bus = "Master"  # 使用Master确保存在
	_bgm_player_a.volume_db = -80.0  # 初始静音

	_bgm_player_b = AudioStreamPlayer.new()
	_bgm_player_b.bus = "Master"
	_bgm_player_b.volume_db = -80.0

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Master"
	_sfx_player.volume_db = SFX_VOLUME_DB

	add_child(_bgm_player_a)
	add_child(_bgm_player_b)
	add_child(_sfx_player)

	_active_player = _bgm_player_a


func _connect_phase_signal() -> void:
	# 监听游戏阶段变化
	if is_instance_valid(get_node_or_null("/root/GameManager")):
		GameManager.phase_changed.connect(_on_phase_changed)


# ---- BGM管理 ----

## 播放BGM（带淡入淡出过渡）
func play_bgm(bgm_path: String, fade_duration: float = BGM_FADE_DURATION) -> void:
	if bgm_path == _current_bgm:
		return  # 相同BGM不重复播放
	
	_current_bgm = bgm_path
	
	# 确定下一个播放器
	var next_player: AudioStreamPlayer
	if _active_player == _bgm_player_a:
		next_player = _bgm_player_b
	else:
		next_player = _bgm_player_a
	
	# 加载新的BGM
	var stream := load(bgm_path) as AudioStream
	if stream == null:
		push_error(">>> [SoundSystem] 无法加载BGM: %s" % bgm_path)
		return

	next_player.stream = stream
	next_player.volume_db = -80.0
	stream.loop = true  # 设置BGM循环
	next_player.play()
	
	# 创建交叉淡入淡出动画
	var tween := create_tween()
	tween.set_parallel(true)
	
	# 淡出当前BGM
	tween.tween_property(_active_player, "volume_db", -80.0, fade_duration)
	# 淡入新BGM
	tween.tween_property(next_player, "volume_db", BGM_VOLUME_DB, fade_duration)
	
	# 切换活跃播放器
	_active_player = next_player
	
	# 停止旧的播放器
	await get_tree().create_timer(fade_duration).timeout
	if _active_player == _bgm_player_a:
		_bgm_player_b.stop()
	else:
		_bgm_player_a.stop()


## 停止BGM（淡出）
func stop_bgm(fade_duration: float = BGM_FADE_DURATION) -> void:
	if _active_player.playing:
		var tween := create_tween()
		tween.tween_property(_active_player, "volume_db", -80.0, fade_duration)
		await tween.finished
		_active_player.stop()
		_current_bgm = ""


## 立即停止BGM
func stop_bgm_immediate() -> void:
	_bgm_player_a.stop()
	_bgm_player_b.stop()
	_current_bgm = ""


# ---- 音效播放 ----

## 播放音效
func play_sfx(sfx_path: String) -> void:
	var stream := load(sfx_path) as AudioStream
	if stream == null:
		push_error(">>> [SoundSystem] 无法加载音效: %s" % sfx_path)
		return
	
	# 如果正在播放，创建新的播放器
	if _sfx_player.playing:
		var temp_player := AudioStreamPlayer.new()
		temp_player.bus = "Master"
		temp_player.volume_db = SFX_VOLUME_DB
		temp_player.stream = stream
		add_child(temp_player)
		temp_player.play()
		temp_player.finished.connect(temp_player.queue_free)
	else:
		_sfx_player.stream = stream
		_sfx_player.play()


## 播放按钮点击音效
func play_button_click() -> void:
	play_sfx(SFX_BUTTON_CLICK)


## 播放合成音效
func play_merge() -> void:
	play_sfx(SFX_MERGE)


## 播放攻击音效
func play_attack_fire() -> void:
	play_sfx(SFX_ATTACK_FIRE)


## 播放子弹命中音效
func play_bullet_hit() -> void:
	play_sfx(SFX_BULLET_HIT)


## 播放胜利音效
func play_victory() -> void:
	play_sfx(SFX_VICTORY)


# ---- 阶段变化回调 ----

func _on_phase_changed(new_phase: String) -> void:
	match new_phase:
		GameManager.PHASE_PREPARE:
			play_bgm(BGM_PREPARE)
		GameManager.PHASE_BATTLE:
			play_bgm(BGM_BATTLE)
		GameManager.PHASE_GAME_OVER:
			stop_bgm()


# ---- 场景切换 ----

## 进入主菜单时调用
func play_menu_bgm() -> void:
	play_bgm(BGM_PREPARE)


## 退出游戏时调用
func cleanup() -> void:
	stop_bgm_immediate()
