@echo off
echo ========================================
echo 测试: 击败第一个BOSS
echo ========================================
echo.

"C:/Custom/Tools/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe" --headless --path "%~dp0" --script res://scripts/test_first_boss.gd

echo.
echo ========================================
echo 测试完成！
echo ========================================
pause
