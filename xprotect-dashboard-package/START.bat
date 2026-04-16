@echo off
cd /d "%~dp0"
cd app
echo.
echo =============================================
echo   XProtect Dashboard
echo =============================================
echo.
echo Startar servern...
echo.
echo Oppna webblasare och ga till:
echo   http://localhost:5000
echo.
..\python\python.exe app.py
pause
