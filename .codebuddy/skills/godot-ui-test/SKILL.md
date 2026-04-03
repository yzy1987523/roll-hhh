---
name: godot-ui-test
description: |
  This skill should be used when testing Godot 4.x game UI functionality, including:
  - Adding characters, dormitory operations
  - Popup and tip systems
  - Opening encyclopedia, shop, and other scenes
  - Testing StyleBox/StyleBoxFlat API compatibility
  - Running headless UI interaction tests
  - **Signal binding detection** - 检测 UI 按钮是否绑定了信号
  
  Trigger phrases: "test UI", "run UI tests", "test popup", "test dormitory", 
  "test encyclopedia", "test shop", "test signal binding", "check button binding",
  "Godot UI", "headless test"
---

# Godot UI 交互测试

## 概述

此 Skill 提供 Godot 4.x 游戏 UI 功能的自动化测试能力，特别适用于在 headless 模式下验证 UI 代码路径。

## 核心功能

1. **组件检查**：验证 GameManager、TipManager、PopupSystem 等 Autoload 是否正常
2. **数据操作**：测试添加角色、宿舍存入/取出
3. **UI 交互**：模拟按钮点击、面板刷新
4. **场景切换**：测试打开图鉴、商店等场景
5. **StyleBox 兼容性**：检测 `border_width_all` 等 Godot 3.x → 4.x 迁移问题
6. **信号绑定检测**：检测按钮是否正确绑定了 pressed 等信号

## 测试脚本

### 信号绑定检测（测试前必运行）
```
.skills/godot-ui-test/scripts/test_signal_binding.gd
```

### UI 交互测试
```
.skills/godot-ui-test/scripts/test_runner.gd
```

### 商店测试
```
scripts/test_shop.gd
scripts/test_shop_button.gd
```

### 运行方式

**命令行运行**：
```bash
cd 项目目录
# 信号绑定检测（必先运行）
godot --headless --path . --script res://.codebuddy/skills/godot-ui-test/scripts/test_signal_binding.gd

# UI交互测试
godot --headless --path . --script res://.codebuddy/skills/godot-ui-test/scripts/test_runner.gd

# 商店测试
godot --headless --path . --script res://scripts/test_shop.gd
```

**Windows 批处理**：
```bash
# 运行所有测试（推荐）
.skills/godot-ui-test/scripts/run_test.bat

# 单独运行
test_shop.bat
```

## 测试覆盖

| 功能 | 说明 |
|------|------|
| Autoload 检查 | GameManager, TipManager, PopupSystem |
| 添加角色 | 创建 CharacterData 并放置到棋盘 |
| 宿舍操作 | 存入宿舍、取出、标记移除 |
| 面板刷新 | 调用 `_on_dorm_pressed`, `_refresh_dorm_panel` |
| 图鉴/商店 | 模拟场景切换按钮 |
| 弹窗系统 | PopupSystem.show_popup |
| 提示系统 | TipManager.show_tip |

## 关键测试模式

### 1. 直接调用私有方法（推荐）

当需要触发特定 UI 代码路径时，直接调用私有方法：

```gdscript
# 打开宿舍面板
board._on_dorm_pressed()
await process_frame

# 再次打开以刷新
board._on_dorm_pressed()
# 这会触发 _refresh_dorm_panel()
```

### 2. 信号模拟

```gdscript
# 查找并触发按钮信号
var btn: Button = board.find_child("DormButton", true, false)
btn.pressed.emit()
```

### 3. 数据层 + UI 层组合

```gdscript
# 数据操作
bd.board_to_dormitory(position)

# 触发 UI 刷新
board._on_dorm_pressed()
```

## 信号绑定检测

在测试 UI 功能前，应先检测按钮是否正确绑定了信号。

### 检测脚本

```
.skills/godot-ui-test/scripts/test_signal_binding.gd
```

### 运行方式

```bash
godot --headless --path . --script res://.codebuddy/skills/godot-ui-test/scripts/test_signal_binding.gd
```

### 输出示例

```
========================================
UI 信号绑定检测
========================================

>>> 检测 shop_scene.tscn...
  ✅ ShopScene/RefreshButton: 已绑定 (1 个连接)
  ✅ ShopScene/CloseButton: 已绑定 (1 个连接)
  ✅ ShopScene/ItemSlot_0: 已绑定 (1 个连接)
  ❌ ShopScene/SomeButton: 未绑定!

>>> 检测 GameBoard...
  ✅ GameBoard/DormButton: 已绑定

========================================
信号绑定检测结果
========================================
  已绑定: 10
  未绑定: 1
  总计: 11

⚠ 以下按钮未绑定信号:
  - ShopScene/SomeButton
========================================
```

### 常见绑定问题

#### 问题：按钮在编辑器中连线了但运行时无反应

**原因**：GDScript 中使用了 `@onready` 但信号未在 `_ready()` 中连接

**检测方法**：
```gdscript
# 在 _ready() 中检查按钮是否有连接
func _ready() -> void:
    var btn = $Path/To/Button
    var connections = btn.get_signal_connection_list("pressed")
    print("连接数: %d" % connections.size())
```

#### 问题：tscn 中有 Button 节点但代码中未连接

**原因**：按钮是动态创建的或忘记连接信号

**解决方案**：
```gdscript
# 方法1：在 _ready() 中手动连接
func _ready() -> void:
    var btn = $Path/To/Button
    btn.pressed.connect(_on_button_pressed)

# 方法2：在 tscn 编辑器中通过 Inspector -> Node 面板连接
# 方法3：使用 auto-connection (Godot 4.x 支持)
```

### Godot 4.x 信号连接方式

```gdscript
# 方式1: pressed.connect() (推荐)
btn.pressed.connect(_on_btn_pressed)

# 方式2: 使用 @export 引用 + 连接
@export var my_button: Button
func _ready() -> void:
    my_button.pressed.connect(_on_my_button)

# 方式3: 在 tscn 的 Inspector 中手动连接
# Node -> Signals -> pressed -> Connect
```

## 常见问题

### Q: 为什么数据层测试通过但 UI 测试失败？

**原因**：UI 代码路径不同

| 层级 | 测试方式 | 示例 |
|------|----------|------|
| 数据层 | 直接调用 `bd.board_to_dormitory()` | ✅ 能测到 |
| UI 层 | 需要 `board._refresh_dorm_panel()` | ❌ 可能漏测 |

**解决方案**：使用直接调用私有方法的方式

```gdscript
# 直接调用，确保 UI 代码路径被执行
board._on_dorm_pressed()
```

### Q: `border_width_all` 错误如何测试？

**原因**：`border_width_all` 是 Godot 3.x API，4.x 已移除

**需要检查的文件位置**：
- `encyclopedia_scene.gd`
- `game_board.gd`

**正确写法**（Godot 4.x）：
```gdscript
style.border_width_left = 3
style.border_width_right = 3
style.border_width_top = 3
style.border_width_bottom = 3
```

**错误写法**（Godot 3.x）：
```gdscript
style.border_width_all = 3  # ❌ 不存在
```

### Q: Headless 模式下信号不触发？

**原因**：某些信号在 `process_frame` 调用后可能未完成初始化

**解决方案**：
1. 增加 `await process_frame` 次数
2. 直接调用目标方法而非信号

```gdscript
# 替代方式
board._on_dorm_pressed()  # 直接调用，而非信号
```

## 扩展测试

如需添加新测试，编辑 `test_runner.gd`：

```gdscript
# 添加新测试函数
func run_new_tests() -> void:
    print("\n>>> [新测试] xxx...")
    # 测试代码...
    _passed += 1
```

## 商店测试

专门的商店场景测试脚本：`scripts/test_shop.gd`

### 测试覆盖

| 功能 | 说明 |
:|------|------|
| 场景结构检查 | GoldLabel, ItemContainer, RelicContainer, CloseButton, RefreshButton |
| 商品系统 | 检查商店商品数量、随机生成 |
| 金币设置 | 测试设置任意金币金额 |
| 有钱购买道具 | 购买流程、金币扣除、物品添加 |
| 有钱购买遗物 | 遗物购买、唯一性检查 |
| 没钱购买 | 金币不足时阻止购买 |
| 关闭按钮 | 场景切换回游戏棋盘 |
| 刷新功能 | 重新随机生成商品 |

### 运行商店测试

```bash
# Windows
test_shop.bat

# 或命令行
godot --headless --path . --script res://scripts/test_shop.gd
```

### 测试输出示例

```
========================================
商店场景完整测试
========================================

>>> [测试5] 测试有钱购买道具...
  商品: Energy Potion, 价格: 15
  购买前金币: 500
  ✅ 购买弹窗已显示
  ✅ 弹窗标题正确
  ✅ 购买成功，金币已扣除
  ✅ 道具已添加

>>> [测试8] 测试没钱购买...
  目标商品: Double Sacrifice Seal, 价格: 300
  当前金币: 1
  ✅ 确认金币不足
  ✅ 没钱未购买，金币未扣除

========================================
商店测试结果
========================================
  通过: 18
  失败: 0
  总计: 18

🎉 所有商店测试通过!
========================================
```

## 输出示例

```
========================================
Godot UI交互测试
========================================

>>> [测试1] 检查核心组件...
  ✅ GameManager: true
  ✅ TipManager: true
  ✅ PopupSystem: true

>>> [测试4] 打开宿舍面板...
  ✅ _on_dorm_pressed() 已调用

========================================
测试结果
========================================
  通过: 13
  失败: 0
  总计: 13

🎉 所有测试通过!
========================================
```
