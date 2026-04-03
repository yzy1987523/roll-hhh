@echo off
chcp 65001 >nul
echo ========================================
echo UI 信号绑定检测
echo ========================================
echo.

"C:/Custom/Tools/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" --headless --path "%~dp0" --script res://.codebuddy/skills/godot-ui-test/scripts/test_signal_binding.gd

echo.
pause
