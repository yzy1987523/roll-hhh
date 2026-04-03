@echo off
chcp 65001 >nul
echo ========================================
echo Godot UI 测试套件
echo ========================================
echo.

echo [1/3] 步骤1: 信号绑定检测
echo ----------------------------------------
"C:/Custom/Tools/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" --headless --path "%~dp0.." --script res://.codebuddy/skills/godot-ui-test/scripts/test_signal_binding.gd
echo.

echo [2/3] 步骤2: UI交互测试
echo ----------------------------------------
"C:/Custom/Tools/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" --headless --path "%~dp0.." --script res://scripts/test_shop.gd
echo.

echo [3/3] 步骤3: 按钮点击测试
echo ----------------------------------------
"C:/Custom/Tools/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" --headless --path "%~dp0.." --script res://scripts/test_shop_button.gd
echo.

echo ========================================
echo 测试完成
echo ========================================
pause
