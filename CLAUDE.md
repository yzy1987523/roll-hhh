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
