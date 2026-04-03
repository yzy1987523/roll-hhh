@echo off
"C:/Custom/Tools/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" --headless --path "%~dp0" --script res://scripts/test_ui_system.gd > "%~dp0test_ui_out.log" 2>&1
type "%~dp0test_ui_out.log"
