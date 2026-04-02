@echo off
set LOGFILE=debug_output.txt
echo Running Godot with debug output...
"c:\Custom\Tools\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --path "c:\Custom\UnityProjects\AICoding\roll-hhh" > %LOGFILE% 2>&1
echo Done. Check %LOGFILE%
pause