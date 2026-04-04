@echo off
chcp 65001 >nul
echo ========================================
echo 教学引导系统测试
echo ========================================
echo.

"C:/Custom/Tools/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" --headless --path "%~dp0" --script res://scripts/test_tutorial.gd

echo.
pause
