@echo off
setlocal
cd /d "%~dp0\.."

echo ==========================================
echo      ASTHRA SETUP - Environment Init
echo ==========================================

:: 1. Check Python
echo [1/3] Checking Python...
python --version
if %errorlevel% neq 0 (
    echo [ERROR] Python is not installed or not in PATH.
    pause
    exit /b
)

:: 2. Create Venv
echo.
echo [2/3] Setting up Virtual Environment...
if not exist "backend\venv" (
    echo   - Creating venv in backend/venv...
    python -m venv backend\venv
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to create venv.
        pause
        exit /b
    )
) else (
    echo   - Venv already exists.
)

:: 3. Install Requirements
echo.
echo [3/3] Installing Dependencies...
call backend\venv\Scripts\activate.bat
pip install --upgrade pip
pip install -r backend\requirements.txt

if %errorlevel% neq 0 (
    echo [ERROR] Failed to install requirements.
    pause
) else (
    echo.
    echo [SUCCESS] Setup complete! You can now run the app.
    timeout /t 3
)
