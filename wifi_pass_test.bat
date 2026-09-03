@echo off
title WiFi Password Tester
REM =========================================================
REM  WiFi Password Tester - launcher (Windows)
REM
REM  Chalane ke tarike:
REM    1) Is file par double-click karo  (phir prompts aayenge)
REM    2) Passwords wali .txt file ko IS bat file ke upar
REM       drag-drop kar do  -> file khud padh lega!
REM
REM  Command line se bhi:
REM    wifi_pass_test.bat "MyWiFi" pass1 pass2 pass3
REM    wifi_pass_test.bat "MyWiFi" "C:\folder\passwords.txt"
REM =========================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0wifi_pass_test.ps1" %*

echo.
echo Khatam. Is window ko band karne ke liye koi bhi key dabao...
pause >nul
