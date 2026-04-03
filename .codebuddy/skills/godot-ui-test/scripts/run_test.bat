@echo off
setlocal EnableDelayedExpansion

set "PROJECT_DIR=%~dp0..\..\"
set "GODOT=C:\Custom\Tools\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe"
set "SCRIPT=res://.codebuddy/skills/godot-ui-test/scripts/test_runner.gd"

cd /d "%PROJECT_DIR%"

echo ========================================
echo Godot UI交互测试
echo ========================================
echo.

"%GODOT%" --headless --path "%PROJECT_DIR%" --script "%SCRIPT%" 2>&1 | Tee-Object -FilePath "test_ui_out.log"

echo.
echo ========================================
echo 测试完成，查看 test_ui_out.log 获取详情
echo ========================================
