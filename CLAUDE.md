# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Godot 4** game project (v4.6.1, GL Compatibility renderer) with GDScript.

- Main scene: `res://scenes/main_menu.tscn`
- Game board scene: `res://scenes/game_board.tscn` (6x6 grid)
- Scripts: `res://scripts/*.gd`
- Main entry point: `project.godot` → `application/run/main_scene`

## Commands

### Run/Edit

```bash
"C:/Custom/Tools/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe" --path C:/Custom/UnityProjects/AICoding/roll-hhh
```

### Headless Testing (CLI)

```bash
"C:/Custom/Tools/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe" --headless --path <project_path> --script res://scripts/<script_name>.gd
```

### VSCode Debugging

- Launch config: `.vscode/launch.json` → "GDScript: Launch Project"
- F5 starts the Godot editor with debugger

## Architecture

### Scene Structure

```
main_menu.tscn (Control root)
└── VBoxContainer
    ├── TitleLabel (Label)
    ├── StartButton (Button) → _on_start_pressed() → loads game_board.tscn
    └── SettingsButton (Button) → _on_settings_pressed()

game_board.tscn (Control root)
├── CenterContainer
│   └── GridContainer (6x6, populated programmatically)
└── BackButton → _on_back_pressed() → returns to main_menu.tscn
```

### File Organization

```
scripts/      # GDScript scripts
scenes/       # .tscn scene files
test_*.gd     # Test scripts (development only)
```

## Coding Standards

### Node References

```gdscript
# Correct: full path defined in scene
@onready var btn: Button = $VBoxContainer/StartButton

# Wrong: missing intermediate node
@onready var btn: Button = $StartButton
```

### Integer Division Warning

Godot 4 warns on `i / GRID_SIZE`. Suppress with:

```gdscript
@warning_ignore("integer_division")
var row := i / GRID_SIZE
```

### Scene Transitions

```gdscript
get_tree().change_scene_to_file("res://scenes/target.tscn")
```

### Log Format

```
>>> [SceneName] operation description
```

Example:

```gdscript
print(">>> [MainMenu] 开始游戏按钮被点击")
print(">>> [GameBoard] 6x6 棋盘格已生成")
```

## Testing Standards

### Headless Test Script Requirements

- Extend `SceneTree`
- Use `_init()` as entry point
- Use `root.add_child()` to add scenes
- Use `get_node_or_null()` for safe node access
- Use `quit()` to exit

### Debug Checklist

- [ ] Scene file path is correct
- [ ] Node path matches scene structure
- [ ] `@onready` path is relative to scene
- [ ] `_ready()` executes in frame loop only

## Godot 4 Important Rules

### Web Export Path Issue (CRITICAL)

**Problem**: `FileAccess.file_exists("res://...")` returns `false` on Web export even if file exists.

**Solution**: Use `ResourceLoader.exists("res://...")` instead.

```gdscript
# Wrong for Web export
if FileAccess.file_exists(sprite_path):
    tex = load(sprite_path)

# Correct for all platforms including Web
if ResourceLoader.exists(sprite_path):
    tex = load(sprite_path)
```

### Sprite Anchor Settings

**Problem**: Changing anchors from `PRESET_FULL_RECT` to `PRESET_CENTER` causes sprites to disappear when dragging.

**Rule**: TextureRect sprites that should fill/cover their parent cell MUST use `PRESET_FULL_RECT`:

```gdscript
# Correct for cell sprites (fills entire cell)
sprite.set_anchors_preset(Control.PRESET_FULL_RECT)

# Only use PRESET_CENTER for drag preview or floating UI elements
preview.set_anchors_preset(Control.PRESET_CENTER)
```

### Drag & Swap Logic

When dragging character A to cell with character B (different job/level):
1. First find nearest empty cell C for displaced character B
2. If empty cell exists: B moves to C, A moves to B's cell
3. If no empty cell: swap A and B positions

### UI Icon Paths in Scene Files

When adding icons to buttons in `.tscn` files:
1. First add `ext_resource` with Texture2D type
2. Then reference it with `icon = ExtResource("N")`

```gdscript
# In .tscn file
[ext_resource type="Texture2D" path="res://art/sprites/UI/items/close.png" id="5_close"]

[node name="CloseButton" type="Button"]
icon = ExtResource("5_close")
```

## 错题集 (Bug & Solutions)

### 1. 宿舍格子 UI 设计

**问题**: 需求变更导致格子显示异常
- 空格子不应显示加号
- cell_1 应叠加在 cell_0 上（选择框效果），而非替换
- 角色 sprite 需要居中显示

**解决方案**: 重构 `_create_dorm_cell()` 函数
- 使用 PanelContainer 作为容器，而非 TextureButton
- 添加两层 TextureRect：bg(底层 cell_0) + overlay(顶层 cell_1)
- 使用 CenterContainer 包裹 TextureRect 实现角色居中
- 通过 `overlay.visible` 控制选择框显示

```gdscript
# 正确结构
PanelContainer
├── bg (TextureRect, cell_0, 始终显示)
├── overlay (TextureRect, cell_1, 按需显示)
└── center (CenterContainer)
    ├── sprite (TextureRect, 角色)
    └── lv_label (Label, 等级)
```

### 2. 角色移出动画流程

**问题**: 从宿舍关闭到角色飞入棋盘的过程中出现各种问题
- 动画起点错误：使用宿舍面板位置而非宿舍按钮位置
- 角色隐藏：动画结束时 sprite 消失

**根本原因**:
1. `execute_removal()` 返回值未包含目标棋盘索引
2. 动画开始时棋盘 UI 未刷新，texture 为空

**解决方案**:

**Step 1**: 修改 `board_data.gd` 中 `execute_removal()` 返回值
```gdscript
# 返回角色数据数组，包含目标棋盘索引
func execute_removal() -> Array:
    var result: Array = []
    # ... 放置角色 ...
    result.append({"char": ch, "board_index": board_index})
    return result
```

**Step 2**: 修改 `game_board.gd` 中动画逻辑
```gdscript
func _play_dorm_to_board_animation(moved_data: Array, start_pos: Vector2) -> void:
    # 1. 先刷新棋盘显示，加载 texture
    _refresh_board_display()
    
    # 2. 隐藏目标格子的 sprite
    for data in moved_data:
        cell_sprites[board_idx].visible = false
    
    # 3. 播放飞行动画
    # ... 创建动画精灵从 start_pos 飞到目标格子 ...
    
    # 4. 动画结束后恢复显示 + 落地动画
    tween.finished.connect(func():
        cell_sprites[board_idx].visible = true
        _play_land_animation(board_idx)
    )
```

**动画起点**: 使用 `dorm_button.global_position + 按钮中心` 而非 `dorm_panel`

### 3. 弹窗层级遮挡

**问题**: 弹窗显示在商店界面背后，无法交互

**原因**: 弹窗未移到根节点最前面

**解决方案**: `popup_system.gd` 中显示弹窗时调用 `move_child()`
```gdscript
func show(...) -> void:
    # ... 创建弹窗 ...
    get_tree().root.add_child(popup)
    get_tree().root.move_child(popup, get_tree().root.get_child_count() - 1)
```

### 4. 角色 sprite 不居中

**问题**: TextureRect 显示的角色图片位置偏移

**原因**: 使用了错误的 expand_mode 或未正确设置居中

**解决方案**: 使用 CenterContainer 或正确的 stretch_mode
```gdscript
sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
# 或使用 CenterContainer 包裹
```
