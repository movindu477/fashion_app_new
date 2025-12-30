@echo off
echo Starting Backend Services...
echo.

echo [1/2] Starting Node.js Server on port 3000...
start "Node.js Backend" cmd /k "node server.js"

timeout /t 2 /nobreak >nul

echo [2/2] Starting Python ML Service on port 5000...
cd python
start "Python ML Service" cmd /k "python fabric_analysis.py"
cd ..

echo.
echo ===================================
echo Backend Services Started!
echo ===================================
echo - Node.js: http://localhost:3000
echo - Python ML: http://localhost:5000
echo.
echo Keep these windows open while testing.
echo Press any key to close this window (services will keep running)...
pause >nul

