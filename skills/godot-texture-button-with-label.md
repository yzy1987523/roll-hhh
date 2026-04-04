# Godot 图片按钮叠加文字制作技巧

## 适用场景
当需要在图片按钮上叠加显示文字时，使用TextureButton + Label子节点的方式。

## 场景文件结构

### TextureButton 父节点
```gdscript
[node name="EndTurnButton" type="TextureButton" parent="..."]
# 按钮尺寸（根据需求设置）
custom_minimum_size = Vector2(216, 216)

# 按钮背景图片
texture_normal = ExtResource("18_endbtn")

# 布局模式
layout_mode = 2

# 垂直居中（SIZE_SHRINK_CENTER = 4）
size_flags_vertical = 4

# 图片拉伸模式（5 = KEEP_ASPECT_CENTERED）
stretch_mode = 5
```

### Label 子节点
```gdscript
[node name="Label" type="Label" parent="MainLayout/DetailActionBar/EndTurnButton"]
# 使用FULL_RECT预设填满父节点
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

# 文字样式
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_font_sizes/font_size = 28
text = "结束回合"

# 文字居中对齐
horizontal_alignment = 1
vertical_alignment = 1
```

## GDScript 代码规范

### 变量声明
```gdscript
# 正确：声明为 TextureButton 类型
@onready var end_turn_button: TextureButton = $MainLayout/DetailActionBar/EndTurnButton

# 错误：不能声明为 Button 类型
# @onready var end_turn_button: Button = $MainLayout/DetailActionBar/EndTurnButton
```

### 访问文字节点
```gdscript
# 如果需要修改文字，访问Label子节点
@onready var end_turn_label: Label = $MainLayout/DetailActionBar/EndTurnButton/Label

func update_button_text():
    end_turn_label.text = "新的文字"
```

## 常见错误

### ❌ 错误：TextureButton没有text属性
```gdscript
# 这会导致运行时错误
end_turn_button.text = "结束回合"  # Invalid assignment
```

### ✅ 正确：通过Label节点设置文字
```gdscript
# 通过Label子节点设置
end_turn_label.text = "结束回合"
```

## 技术要点

1. **TextureButton vs Button**
   - Button：自带文字属性，但背景样式有限
   - TextureButton：使用图片作为背景，无text属性，需Label子节点

2. **Label锚点设置**
   - anchors_preset = 15（PRESET_FULL_RECT）：填满父节点
   - 确保文字跟随按钮尺寸变化

3. **文字居中**
   - horizontal_alignment = 1（CENTER）
   - vertical_alignment = 1（CENTER）
   - Label填满按钮区域，文字在Label内居中

4. **按钮尺寸**
   - custom_minimum_size：设置最小尺寸
   - stretch_mode = 5：保持图片比例居中显示

## 实例应用

- 回合结束按钮：endBtn.png + "结束回合"
- 关闭按钮：close.png + "关闭"
- 确认按钮：confirm.png + "确认"
- 取消按钮：cancel.png + "取消"

## 对比方案

| 方案 | 优点 | 缺点 |
|------|------|------|
| TextureButton + Label | 灵活控制图片和文字 | 需要两个节点 |
| Button + Icon | 单节点，简单 | 图标位置受限 |
| TextureButton + 自绘文字 | 单节点 | 无法动态修改文字 |

## 最佳实践

1. 使用唯一ID标识节点
   ```gdscript
   unique_id = 945550930
   ```

2. 文字颜色与背景对比度要够
   ```gdscript
   theme_override_colors/font_color = Color(1, 1, 1, 1)  # 白色文字
   ```

3. 字体大小要适中
   ```gdscript
   theme_override_font_sizes/font_size = 28  # 根据按钮尺寸调整
   ```

4. 考虑多语言支持
   ```gdscript
   func update_language():
       end_turn_label.text = LocalizationSystem.get_text("button.end_turn")
   ```
