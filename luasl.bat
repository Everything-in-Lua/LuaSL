@echo off
setlocal
set SCRIPT_DIR=%~dp0
lua "%SCRIPT_DIR%luasl.lua" %*
