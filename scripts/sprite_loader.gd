extends RefCounted
class_name SpriteLoader

## 物品/遗物图标加载工具
## 根据mechanics.json中的sprite字段加载对应图标

const BASE_PATH := "res://art/sprites/game_items/"
const SPRITE_CACHE := {}

## 加载物品图标
static func get_item_sprite(item_id: int) -> Texture2D:
	var sprite_name := MechanicsDb.get_item_sprite(item_id)
	if sprite_name.is_empty():
		return null
	return _load_sprite(sprite_name)


## 加载遗物图标
static func get_relic_sprite(relic_id: int) -> Texture2D:
	var sprite_name := MechanicsDb.get_relic_sprite(relic_id)
	if sprite_name.is_empty():
		return null
	return _load_sprite(sprite_name)


## 缓存加载sprite
static func _load_sprite(sprite_name: String) -> Texture2D:
	if SPRITE_CACHE.has(sprite_name):
		return SPRITE_CACHE[sprite_name]

	var path := BASE_PATH + sprite_name + ".png"
	var tex := load(path) as Texture2D
	if tex:
		SPRITE_CACHE[sprite_name] = tex
	else:
		push_warning(">>> [SpriteLoader] Failed to load sprite: %s" % path)
	return tex


## 清除缓存
static func clear_cache() -> void:
	SPRITE_CACHE.clear()
