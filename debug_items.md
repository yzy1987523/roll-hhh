# 道具栏问题调试指南

## 问题清单

### 1️⃣ 购买道具后无图片

**现象**：
- 购买道具后，道具栏未立即刷新
- 能点击使用，但没有图片显示

**已添加的调试日志**：
```
>>> [GameBoard] _on_items_changed 被调用
>>> [GameBoard] _refresh_item_slots 被调用，道具数量: X
>>> [GameBoard] 刷新道具格子 0: XXX (ID: X)
>>> [GameBoard] 尝试加载道具图片: ID=X -> img_id=Y, 路径=...
>>> [GameBoard] 加载成功: [Texture2D]
>>> [GameBoard] 道具格子 0 图片: [Texture2D], visible: true
```

**可能的原因**：
1. ✅ `GameManager.items_changed` 信号已连接
2. ✅ `_on_items_changed()` 会调用 `_refresh_item_slots()`
3. ❓ 图片加载可能失败（查看日志中的路径）
4. ❓ item_slot_icons 数组可能为空

**测试步骤**：
1. 打开游戏，进入商店
2. 购买任意道具
3. 查看控制台日志，检查：
   - `_on_items_changed` 是否被调用
   - 图片路径是否正确
   - 图片是否成功加载

---

### 2️⃣ 多个角色变红

**现象**：
- 使用指向性道具时，多个角色都出现了变红的动效
- 应该只有一个角色变红

**已添加的调试日志**：
```
>>> [GameBoard] 使用道具 XXX (目标: Y), result: {success: true, target_index: Z}
>>> [GameBoard] 播放高亮动效，目标: Z
>>> [GameBoard] _play_item_effect_highlight 被调用，cell_index: Z
>>> [GameBoard] 开始播放高亮动效，格子: Z
```

**可能的原因**：
1. ❓ `ItemDatabase.use_consumable()` 返回的 `target_index` 不正确
2. ❓ 道具效果类型（如 `spawn_characters`）影响了多个角色
3. ❓ 有其他代码在同时修改颜色

**检查点**：
- 查看日志中的 `target_index` 是否正确
- 检查道具的 `effect_type`：
  - `spawn_characters`: 生成多个角色，不会返回 target_index
  - `level_up_random`: 随机升级一个角色，会返回 target_index
  - `dice_of_fate`: 命运之骰，会返回 target_index

**道具效果类型**：
- ✅ **单体指向性**（target="character"）：
  - `heal`: 治疗
  - `level_up_target`: 目标升级
  - `temp_shield`: 临时护盾
  - `stat_buff_target`: 属性加成
  - 这些道具应该只有一个目标

- ⚠️ **随机目标**：
  - `level_up_random`: 随机升级
  - `dice_of_fate`: 命运之骰
  - 这些道具会选择随机目标，应该只高亮一个

- ❌ **无需目标**：
  - `restore_energy`: 恢复能量
  - `spawn_characters`: 生成多个角色
  - `summon`: 召唤角色
  - 这些道具不应该播放高亮动效

---

### 3️⃣ 道具栏尺寸未变化

**现象**：
- 已修改场景文件为 120x120
- 但实际运行时尺寸未变化

**已修改的尺寸**：
```
MiddleBar: height = 120
ItemBar: width = 360, height = 120
ItemSlot: 120x120
ItemIcon: 100x100
```

**可能的原因**：
1. ❓ Godot 编辑器未重新加载场景
2. ❓ 有其他代码在动态设置尺寸
3. ❓ 父容器的布局限制了尺寸

**测试步骤**：
1. 在 Godot 编辑器中重新打开场景文件
2. 检查 MiddleBar、ItemBar、ItemSlot 的尺寸
3. 运行游戏，检查实际尺寸

**检查点**：
- 场景文件中 MiddleBar 的 `custom_minimum_size`
- 场景文件中 ItemBar 的 `custom_minimum_size`
- 场景文件中 ItemSlot 的 `custom_minimum_size`
- 是否有代码在 `_ready()` 中设置尺寸

---

## 调试方法

### 查看控制台日志

运行游戏后，控制台会输出详细的调试日志。重点关注：

1. **购买道具时**：
   ```
   >>> [Shop] 购买: XXX, 花费 X 金币
   >>> [GameManager] 获得道具: XXX
   >>> [GameBoard] 道具改变，刷新道具栏，当前道具数量: X
   >>> [GameBoard] _refresh_item_slots 被调用，道具数量: X
   ```

2. **使用道具时**：
   ```
   >>> [GameBoard] 使用道具 XXX (目标: Y), result: {success: true, target_index: Z}
   >>> [GameBoard] 播放高亮动效，目标: Z
   ```

3. **图片加载时**：
   ```
   >>> [GameBoard] 尝试加载道具图片: ID=X -> img_id=Y, 路径=res://...
   >>> [GameBoard] 加载成功: [Texture2D]
   ```

### 在编辑器中检查

1. 打开 `scenes/game_board.tscn`
2. 选择 `MainLayout/MiddleBar/ItemBar`
3. 查看 `custom_minimum_size` 属性
4. 选择 `ItemSlot0`，查看尺寸

---

## 下一步行动

### 如果日志显示图片加载失败：
- 检查图片文件是否存在
- 检查图片ID映射是否正确

### 如果日志显示 target_index 不正确：
- 检查 `ItemDatabase.use_consumable()` 的返回值
- 检查道具的 `effect_type`

### 如果尺寸未变化：
- 在编辑器中重新加载场景
- 检查是否有代码动态设置尺寸

---

## 预期结果

修复后，应该看到：
1. ✅ 购买道具后，道具栏立即显示道具图片
2. ✅ 使用指向性道具时，只有一个角色播放红色高亮动效
3. ✅ 道具栏格子尺寸为 120x120

请运行游戏并提供控制台日志！
