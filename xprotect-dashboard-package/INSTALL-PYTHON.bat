@echo off
echo.
echo =============================================
echo   Installera Python-paket
echo =============================================
echo.
echo Installerar rapportlab, flask och andra...
echo.

cd /d "%~dp0python"

echo.
echo 1. Uppdaterar pip...
python.exe -m ensurepip --upgrade
python.exe -m pip install --upgrade pip

echo.
echo 2. Installerar paket...
python.exe -m pip install flask==3.0.0 --no-warn-script-location
python.exe -m pip install reportlab==4.0.7 --no-warn-script-location
python.exe -m pip install jinja2==3.1.2 --no-warn-script-location
python.exe -m pip install markupsafe==2.1.3 --no-warn-script-location
python.exe -m pip install werkzeug==3.0.1 --no-warn-script-location
python.exe -m pip install itsdangerous==2.1.2 --no-warn-script-location
python.exe -m pip install pyyaml==6.0.1 --no-warn-script-location
python.exe -m pip install Pillow==10.1.0 --no-warn-script-location
python.exe -m pip install click==8.1.7 --no-warn-script-location

echo.
echo.
echo =============================================
echo   Installation klar!
echo =============================================
echo.
echo Nu kan du kora START.bat
echo.
pause
