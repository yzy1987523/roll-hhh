@echo off
chcp 65001 >nul
echo ========================================
echo 商店场景完整测试
echo ========================================
echo.

cd /d "%~dp0"

"C:/Custom/Tools/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" --headless --path "%~dp0" --script res://scripts/test_shop.gd > "%~dp0test_shop.log" 2>&1

type "%~dp0test_shop.log"

echo.
echo ========================================
pause
