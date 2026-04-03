# 错题集 (Bug Lessons)

记录开发过程中遇到的问题和解决方案，避免重复犯错。

---

## 2026-04-03: 商店界面修改问题

### 问题1：tscn 文件不支持注释

| 项目 | 内容 |
|------|------|
| **错误现象** | `shop_scene.tscn` 无法解析打开 |
| **错误原因** | 在 tscn 文件中添加了 `#` 注释 |
| **解决方案** | Godot 4 的 tscn 格式不支持注释，必须移除所有 `#` 开头的行 |
| **教训** | tscn/tres 文件是 Godot 的资源格式，不能添加任何注释 |

---

### 问题2：场景切换导致背景被覆盖

| 项目 | 内容 |
|------|------|
| **错误现象** | 商店打开后看不到棋盘界面，背后全是黑色 |
| **错误原因** | 使用 `change_scene_to_file()` 会完全替换当前场景 |
| **解决方案** | 改用 `add_child(shop_scene)` 将商店作为弹窗添加，关闭时用 `queue_free()` 移除 |
| **教训** | 需要保留原场景背景时，应使用 `add_child` 而非场景切换 |

**代码对比：**
```gdscript
# ❌ 错误：会替换整个场景
func _on_shop_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/shop_scene.tscn")

# ✅ 正确：作为弹窗添加
func _on_shop_pressed() -> void:
    var shop_scene := preload("res://scenes/shop_scene.tscn").instantiate()
    add_child(shop_scene)

# 关闭时
func _on_close_pressed() -> void:
    queue_free()  # 移除自己，而不是切换场景
```

---

### 问题3：@onready 节点路径不匹配

| 项目 | 内容 |
|------|------|
| **错误现象** | `Node not found: "ShopWindow/VBox/TitleBar/GoldLabel"` |
| **错误原因** | 场景文件被意外修改，所有节点平铺在根节点下，路径不匹配 |
| **解决方案** | 重新整理场景层级结构，确保 tscn 中的节点层级与脚本 `@onready` 路径一致 |
| **教训** | 修改场景文件后必须检查脚本中的节点路径是否匹配 |

**检查方法：**
1. 在 Godot 编辑器中打开场景
2. 查看 Remote 面板确认节点路径
3. 或直接读取 tscn 文件检查 `parent` 属性

---

### 问题4：格子尺寸随内容变化

| 项目 | 内容 |
|------|------|
| **错误现象** | 格子尺寸随着商品图片变化，不够固定 |
| **错误原因** | 容器未设置 `SIZE_SHRINK_CENTER` 标志，会随子节点扩展 |
| **解决方案** | 为容器添加 `size_flags_horizontal/vertical = SIZE_SHRINK_CENTER` |
| **教训** | 固定尺寸的容器需要设置 `SIZE_SHRINK_CENTER` 防止扩展 |

**代码示例：**
```gdscript
# ❌ 错误：只设置最小尺寸，容器仍会扩展
container.custom_minimum_size = Vector2(200, 200)

# ✅ 正确：同时设置收缩标志
container.custom_minimum_size = Vector2(200, 200)
container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
```

---

### 问题5：商品图片序号不存在

| 项目 | 内容 |
|------|------|
| **错误现象** | 部分商品ID没有对应图片文件 |
| **错误原因** | 商品ID与图片文件名序号不对应 |
| **解决方案** | 创建可用图片ID列表，用取模运算映射 |
| **教训** | 资源引用前应确认资源存在，使用映射表确保安全访问 |

**代码示例：**
```gdscript
# 定义可用资源列表
var available_item_ids := [13, 15, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42]
var available_relic_ids := [4, 5, 6, 7, 8, 9, 20, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45]

# 安全映射
var img_id: int = available_ids[item.id % available_ids.size()]
```

---

### 最终配置参考

商店界面的最终尺寸配置：

| 元素 | 尺寸/值 |
|------|---------|
| 窗口 | 800 x 1200 |
| 格子 | 200 x 200 |
| 商品图片 | 180 x 180 |
| 价格字体 | 40 |
| 商品间隔 | 30 |
| 遮罩透明度 | 60% (Color(0,0,0,0.6)) |

---

## 通用原则总结

### 1. Godot 资源文件规则
- `.tscn` / `.tres` 文件**不支持注释**
- 修改资源文件后必须检查引用是否匹配
- 使用版本控制追踪资源文件变化

### 2. 场景管理
- 弹窗/面板类界面应使用 `add_child` 添加
- 需要保留背景的场景不要用 `change_scene`
- 关闭弹窗用 `queue_free()` 移除

### 3. UI 布局
- 固定尺寸容器必须设置 `SIZE_SHRINK_CENTER`
- 使用 `custom_minimum_size` 设置最小尺寸
- 子节点会撑大父容器，需要设置正确的 size_flags

### 4. 资源安全访问
- 使用映射表确保资源存在
- 加载资源前检查路径有效性
- 提供默认/备用资源防止崩溃

---

*最后更新: 2026-04-03*
