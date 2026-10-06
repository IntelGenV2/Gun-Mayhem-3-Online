@echo off
cd /d "%~dp0"
where node >nul 2>&1
if errorlevel 1 (
    echo Install Node.js 20 or newer on this server PC, then run this file again.
    pause
    exit /b 1
)
echo Gun Mayhem 3 Online - friend lobby server
echo Players connect to this PC's address on TCP port 47633 by default.
echo Keep this window open while playing. Press Ctrl+C to stop.
node server.mjs
pause
