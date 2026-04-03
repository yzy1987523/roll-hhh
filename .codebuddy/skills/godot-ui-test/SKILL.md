---
name: godot-ui-test
description: |
  This skill should be used when testing Godot 4.x game UI functionality, including:
  - Adding characters, dormitory operations
  - Popup and tip systems
  - Opening encyclopedia, shop, and other scenes
  - Testing StyleBox/StyleBoxFlat API compatibility
  - Running headless UI interaction tests
  
  Trigger phrases: "test UI", "run UI tests", "test popup", "test dormitory", 
  "test encyclopedia", "test shop", "Godot UI", "headless test"
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

## 测试脚本

### 位置
```
.skills/godot-ui-test/scripts/test_runner.gd
```

### 运行方式

**命令行运行**：
```bash
cd 项目目录
godot --headless --path . --script res://.codebuddy/skills/godot-ui-test/scripts/test_runner.gd
```

**Windows 批处理**：
```bash
.skills/godot-ui-test/scripts/run_test.bat
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
