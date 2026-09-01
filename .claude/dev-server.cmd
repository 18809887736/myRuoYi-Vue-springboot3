@echo off
set NODE_OPTIONS=--openssl-legacy-provider
set port=8081
cd /d "%~dp0..\ruoyi-ui"
call npm run dev
