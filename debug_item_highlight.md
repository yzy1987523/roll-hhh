# 道具使用高亮问题分析

## 问题现象
使用指向性道具时，多个角色都出现了变红的动态，应该只有一个。

## 可能的原因

### 1️⃣ 拖拽状态冲突

**关键代码**：
```gdscript
# Line 1242-1246
for target_index in merge_targets:
    cell_highlight_effects[target_index].visible = true
    cell_highlight_effects[target_index].modulate = Color(1, 1, 1, 0.5)
```

**问题**：
- 如果在道具使用时 `is_dragging = true`，会显示多个合成目标的高亮
- `cell_highlight_effects` 会显示在多个格子上

**检查点**：
- 使用道具时，`is_dragging` 是否为 `true`？
- `merge_targets` 数组是否包含多个索引？

---

### 2️⃣ Tween 动画冲突

**关键代码**：
```gdscript
# Line 2222-2228
var tween := create_tween()
tween.set_parallel(false)
tween.tween_property(sprite, "modulate", Color(2.0, 0.3, 0.3, 1.0), 0.25)
tween.tween_property(sprite, "modulate", original_modulate, 0.25)
```

**问题**：
- 如果之前的 Tween 还在运行，可能会冲突
- `_refresh_board_display()` 不会重置 `modulate` 属性

**检查点**：
- 使用道具前，是否有其他 Tween 在运行？
- 使用道具后，`_refresh_board_display()` 是否重置了颜色？

---

### 3️⃣ 高亮效果节点

**关键代码**：
```gdscript
# Line 1196-1197
for i in range(BoardData.BOARD_SLOTS):
    cell_highlight_effects[i].visible = false
```

**问题**：
- `_refresh_board_display()` 会隐藏所有 `cell_highlight_effects`
- 但道具使用的高亮是在 `_refresh_board_display()` 之后调用的

**调用顺序**：
```gdscript
# Line 2162-2167
_refresh_board_display()  # 隐藏所有高亮
_play_item_effect_highlight(affected_target)  # 播放高亮
```

---

### 4️⃣ cell_highlight_effects vs cell_sprites

**两个不同的高亮系统**：

1. **cell_highlight_effects**：
   - 用于拖拽时的合成目标高亮
   - Line 1246: `modulate = Color(1, 1, 1, 0.5)` (白色半透明)
   - Line 1250: `modulate = Color(1, 0.6, 0.6, 1.0)` (偏红色)

2. **cell_sprites + cell_rects**：
   - 用于道具使用效果高亮
   - Line 2226: `modulate = Color(2.0, 0.3, 0.3, 1.0)` (红色)
   - Line 2232: `modulate = Color(1.5, 0.2, 0.2, 1.0)` (红色)

**问题**：
- 如果 `cell_highlight_effects` 被显示，会叠加在高亮动效上
- 如果 `merge_targets` 包含多个索引，会显示多个高亮

---

## 调试方法

### 添加更多日志

在 `_play_item_effect_highlight()` 中添加：
```gdscript
print(">>> [GameBoard] is_dragging: %s" % is_dragging)
print(">>> [GameBoard] merge_targets: %s" % merge_targets)
print(">>> [GameBoard] cell_highlight_effects visible count: %d" % cell_highlight_effects.filter(func(e): return e.visible).size())
```

### 检查调用堆栈

在 `_play_item_effect_highlight()` 中添加：
```gdscript
print(">>> [GameBoard] 调用堆栈: %s" % get_stack())
```

---

## 可能的解决方案

### 方案1: 确保不在拖拽状态

```gdscript
func _play_item_effect_highlight(cell_index: int) -> void:
    # 强制结束拖拽状态
    if is_dragging:
        is_dragging = false
        merge_targets.clear()
        _update_merge_highlights()
    
    # 播放高亮动效
    ...
```

### 方案2: 使用独立的高亮节点

创建专门用于道具效果的高亮节点，不影响拖拽高亮。

### 方案3: 在播放高亮前隐藏所有高亮效果

```gdscript
func _play_item_effect_highlight(cell_index: int) -> void:
    # 隐藏所有高亮效果
    for i in range(BoardData.BOARD_SLOTS):
        cell_highlight_effects[i].visible = false
    
    # 播放高亮动效
    ...
```

---

## 测试步骤

1. 运行游戏
2. 购买一个指向性道具（如治疗药水）
3. 使用道具，选择目标
4. 查看控制台日志：
   - `is_dragging` 的值
   - `merge_targets` 的内容
   - `cell_highlight_effects visible count` 的数量
5. 观察哪些格子变红了

---

## 预期结果

- `is_dragging` 应该为 `false`
- `merge_targets` 应该为空
- `cell_highlight_effects visible count` 应该为 0
- 只有 `cell_index` 指定的格子变红

如果发现 `is_dragging = true` 或 `merge_targets` 不为空，就找到了问题根源！
