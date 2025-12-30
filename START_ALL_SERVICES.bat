@echo off
echo ========================================
echo   FASHION APP - START ALL SERVICES
echo ========================================
echo.

cd backend

echo [1/2] Starting Node.js Backend (Port 3000)...
start "Node.js Backend" cmd /k "node server.js"

timeout /t 2 /nobreak >nul

echo [2/2] Starting Python ML Service (Port 5000)...
cd python
start "Python ML Service" cmd /k "python fabric_analysis.py"
cd ..

cd ..

echo.
echo ========================================
echo   SERVICES STARTED!
echo ========================================
echo.
echo ✓ Node.js: http://localhost:3000
echo ✓ Python ML: http://localhost:5000
echo.
echo Now run your Flutter app:
echo   flutter run
echo.
echo Keep all terminal windows open!
echo.
pause

