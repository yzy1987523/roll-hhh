---
name: godot-animation-design
description: "基于对象设计的动画效果实现指南。包含缩放动画、闪烁效果、Outline Shader、高亮反馈等动效模式。适用于Godot 4 GDScript项目。"
---

# Godot Animation Design - 基于对象设计的动画效果

## 设计原则

**核心思想**：将动画函数绑定到目标对象，通过调用对象方法触发动效。

```
对象 (Node/Sprite)
    └── 动画函数 (_play_xxx_animation)
            └── Tween 动画序列
```

## 1. 缩放动画 (以中央为缩放中心)

### 问题
直接对 `scale` 属性做动画会以左上角为原点，导致图片偏移。

### 解决方案
设置 `pivot_offset` 为对象中心点：

```gdscript
# 创建时设置
var sprite := TextureRect.new()
sprite.pivot_offset = Vector2(CELL_SIZE / 2, CELL_SIZE / 2)  # 以中央为缩放中心

# 动画函数
func _play_scale_animation(target: Control) -> void:
    target.scale = Vector2(1.0, 1.0)  # 重置
    var tween := create_tween()
    tween.set_parallel(false)  # 顺序执行
    tween.tween_property(target, "scale", Vector2(0.8, 0.8), 0.1).from(Vector2(1.0, 1.0))
    tween.tween_property(target, "scale", Vector2(1.1, 1.1), 0.15)
    tween.tween_property(target, "scale", Vector2(1.0, 1.0), 0.15)
```

### 关键点
- `pivot_offset`: 设置缩放原点，必须在创建节点时设置
- `set_parallel(false)`: 顺序执行动画（默认true是并行）
- `.from(start_value)`: 指定起始值

## 2. 闪烁/发光效果

```gdscript
func _play_flash_animation(target: Control) -> void:
    var tween := create_tween()
    tween.set_parallel(true)  # 与缩放并行
    # 白色 -> 金色 -> 白色
    tween.tween_property(target, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.05)
    tween.tween_property(target, "modulate", Color(1.0, 1.0, 0.5, 1.0), 0.1)
    tween.tween_property(target, "modulate", Color.WHITE, 0.25)
```

### Modulate 颜色含义
| Color | Effect |
|-------|--------|
| `Color.WHITE` | 正常颜色 |
| `Color(2.0, 2.0, 2.0)` | 增亮 (overbright) |
| `Color(0.5, 0.5, 0.5)` | 变暗 |
| `Color(1.0, 1.0, 0.0)` | 黄色调 |

## 3. Outline Shader 高亮效果

### 创建 Shader 文件
`shaders/outline.gdshader`:
```glsl
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    if (tex.a > 0.0) {
        vec2 pixel_size = vec2(outline_width) / vec2(textureSize(TEXTURE, 0));
        float alpha = tex.a;
        alpha = max(alpha, texture(TEXTURE, UV + vec2(pixel_size.x, 0)).a);
        alpha = max(alpha, texture(TEXTURE, UV + vec2(-pixel_size.x, 0)).a);
        alpha = max(alpha, texture(TEXTURE, UV + vec2(0, pixel_size.y)).a);
        alpha = max(alpha, texture(TEXTURE, UV + vec2(0, -pixel_size.y)).a);
        if (tex.a < 0.1 && alpha > 0.1) {
            COLOR = vec4(outline_color.rgb, alpha);
        }
    }
}
```

### 应用 Outline
```gdscript
# 动态添加 Outline 效果
func _apply_outline(sprite: TextureRect, enable: bool) -> void:
    if enable:
        var mat := ShaderMaterial.new()
        mat.shader = preload("res://shaders/outline.gdshader")
        mat.set_shader_parameter("outline_color", Color(1.0, 0.8, 0.0, 1.0))  # 金色
        mat.set_shader_parameter("outline_width", 3.0)
        sprite.material = mat
    else:
        sprite.material = null
```

## 4. 拖拽预览系统

### 预览节点结构
```
Control (定位用)
    └── TextureRect (精灵图，可带Outline)
```

### 实现模式
```gdscript
# 创建拖拽预览（无背景色块）
func _create_drag_preview(cell_index: int, with_outline: bool = false) -> Control:
    var preview := Control.new()
    preview.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
    preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var sprite := TextureRect.new()
    sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
    sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    sprite.texture = load_texure()
    sprite.pivot_offset = Vector2(CELL_SIZE / 2, CELL_SIZE / 2)

    if with_outline:
        _apply_outline(sprite, true)

    preview.add_child(sprite)
    return preview

# 更新预览效果（悬停时）
func _update_preview_on_hover(preview: Control, can_merge: bool) -> void:
    var sprite: TextureRect = preview.get_child(0) as TextureRect
    if sprite:
        _apply_outline(sprite, can_merge)
```

## 5. 动画触发时机

### 合成动画触发
```gdscript
func _merge_at(src_index: int, tgt_index: int) -> void:
    # ... 执行合成逻辑 ...

    # 刷新显示
    _refresh_board_display()

    # 触发动画
    _play_merge_animation(tgt_index)
```

### 拖拽预览Outline触发
```gdscript
func _update_drag_preview(mouse_pos: Vector2) -> void:
    # ... 其他逻辑 ...

    # 检测是否悬停在可合成目标上
    var is_over_mergeable := _check_mergeable(hover_index)

    # 更新预览Outline
    _update_preview_outline(is_over_mergeable)
```

## 6. 完整示例：合成动效

```gdscript
func _play_merge_animation(cell_index: int) -> void:
    if cell_index < 0 or cell_index >= cell_sprites.size():
        return
    var sprite: Control = cell_sprites[cell_index]
    if sprite == null:
        return

    # 重置状态
    sprite.scale = Vector2(1.0, 1.0)
    sprite.modulate = Color.WHITE

    # 缩放动画 (顺序)
    var tween := create_tween()
    tween.set_parallel(false)
    tween.tween_property(sprite, "scale", Vector2(0.8, 0.8), 0.1).from(Vector2(1.0, 1.0))
    tween.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.15)
    tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)

    # 闪烁动画 (并行)
    var tween2 := create_tween()
    tween2.set_parallel(true)
    tween2.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.05)
    tween2.tween_property(sprite, "modulate", Color(1.0, 1.0, 0.5, 1.0), 0.1)
    tween2.tween_property(sprite, "modulate", Color.WHITE, 0.25)
```

## 设计检查清单

- [ ] 设置 `pivot_offset` 为中心点
- [ ] Tween 使用 `set_parallel(false)` 实现顺序动画
- [ ] 动画前重置 `scale` 和 `modulate`
- [ ] 添加调试日志 `print(">>> [Debug] Animation: ...")`
- [ ] 检查目标节点是否有效 `if sprite == null: return`

## 7. Squash & Stretch 攻击动画

### 攻击动画模式
攻击时：x轴1.1 y轴0.9 → x轴0.9 y轴1.1 → 恢复

```gdscript
## 播放攻击动画（squash & stretch）
func _play_attack_animation(cell_index: int) -> void:
    if cell_index < 0 or cell_index >= cell_sprites.size():
        return
    var sprite: Control = cell_sprites[cell_index]
    if sprite == null or not is_instance_valid(sprite):
        return

    # 设置pivot_offset为中心
    if "pivot_offset" in sprite:
        sprite.pivot_offset = Vector2(CELL_SIZE / 2, CELL_SIZE / 2)

    # 重置
    sprite.scale = Vector2(1.0, 1.0)
    sprite.modulate = Color.WHITE

    # 创建动画序列：x轴1.1 y轴0.9 -> x轴0.9 y轴1.1 -> 恢复
    var tween := create_tween()
    tween.set_parallel(false)

    # Phase 1: x拉长 y压缩
    tween.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.1).from(Vector2(1.0, 1.0))
    # Phase 2: x压缩 y拉长
    tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.15)
    # Phase 3: 恢复原尺寸
    tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
```

### 关键点
- `pivot_offset` 必须设置为 `Vector2(CELL_SIZE/2, CELL_SIZE/2)` 确保以中心为原点
- 动画序列：拉伸 → 压缩 → 恢复
- 时间分配：0.1s + 0.15s + 0.1s = 0.35s 总时长

## 8. 子弹系统

### 子弹场景结构
```
BattleBullet (CharacterBody2D)
    ├── CollisionShape2D
    └── Sprite2D
```

### 子弹类型
```gdscript
const BULLET_TYPE_ATTACK: int = 0  # 我方攻击
const BULLET_TYPE_ENEMY: int = 3   # 敌方攻击
const BULLET_TYPE_HEAL: int = 1    # 治疗
const BULLET_TYPE_BLESS: int = 2   # 祝福
```

### 异步回合流程
```
回合开始
    ↓
我方攻击阶段（播放动画 + 发射子弹 + 等待命中）
    ↓
检查敌方阵亡
    ↓
敌方攻击阶段（发射子弹 + 等待命中）
    ↓
检查我方全灭
    ↓
进入下一回合
```

### 发射子弹示例
```gdscript
func _fire_bullet(bullet_type: int, damage: int, source_pos: Vector2, target_pos: Vector2, target_idx: int = -1) -> void:
    var bullet_scene: PackedScene = preload("res://scenes/battle_bullet.tscn")
    var bullet = bullet_scene.instantiate()
    bullet_container.add_child(bullet)
    bullet.setup(bullet_type, damage, target_idx, source_pos, target_pos)
    active_bullets.append(bullet)
```

### 异步等待子弹
```gdscript
func _wait_for_bullets() -> void:
    while active_bullets.size() > 0:
        await get_tree().create_timer(0.05).timeout
```
