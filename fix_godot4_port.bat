@echo off
echo Godot 4 Port Fix Script
echo =======================
echo.
echo This script will apply all necessary Godot 4 compatibility fixes.
echo Make sure to BACK UP your project before running this!
echo.
pause

echo.
echo Step 1: Fixing project.godot translations...
echo (This line gets automatically reverted by some tools)
powershell -Command "(Get-Content 'project.godot') -replace 'translations=PoolStringArray', 'translations=PackedStringArray' | Set-Content 'project.godot'"

echo.
echo Step 2: All other fixes have been applied to the codebase.
echo The main issue is the translations line being reverted.
echo.
echo IMPORTANT: To prevent automatic reversion:
echo 1. Close Godot Editor completely
echo 2. Disable any code formatters/linters that might auto-correct
echo 3. If using VS Code, disable Godot Tools auto-formatting
echo 4. Run the project - it should work now!
echo.
pause
