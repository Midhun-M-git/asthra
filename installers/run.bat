@echo off
setlocal
cd /d "%~dp0\.."

echo ==========================================
echo      ASTHRA - Launching App
echo ==========================================

:: 1. Checks
if not exist "backend\venv\Scripts\activate.bat" (
    echo [ERROR] Virtual environment not found.
    echo Please run 'setup.bat' first!
    pause
    exit /b
)

:: 2. Start Backend
echo.
echo [1/2] Launching Backend...
call backend\venv\Scripts\activate.bat
start "ASTHRA Backend" cmd /k "cd backend && python -m uvicorn app:app --reload --host 0.0.0.0 --port 8000"

:: 3. Start Frontend
echo.
echo [2/2] Launching Frontend...
call flutter run -d chrome

echo.
echo Closing launcher...
pause
