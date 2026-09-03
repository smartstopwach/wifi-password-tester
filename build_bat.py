#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
WifiTesterApp.bat generator:
wifi_tester_gui.ps1 ko base64 me pack karke ek SINGLE .bat file banata hai
jise user bas double-click kare. Koi dusri file ki zaroorat nahi.
"""
import base64
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PS1 = os.path.join(HERE, "wifi_tester_gui.ps1")
BAT = os.path.join(HERE, "WifiTesterApp.bat")

CHUNK = 6000  # safe under cmd 8191 char line limit

# ps1 ko UTF-8 (BOM ke saath) padho
with open(PS1, "rb") as f:
    ps1_bytes = f.read()

# BOM prepend (agar already nahi)
if not ps1_bytes.startswith(b"\xef\xbb\xbf"):
    ps1_bytes = b"\xef\xbb\xbf" + ps1_bytes

b64 = base64.b64encode(ps1_bytes).decode("ascii")

chunks = [b64[i:i + CHUNK] for i in range(0, len(b64), CHUNK)]

lines = []
lines.append("@echo off")
lines.append("REM ============================================================")
lines.append("REM   WiFi Password Tester  (ek hi file wali APP)")
lines.append("REM   Bas is file par double-click karo - window khulegi.")
lines.append("REM   Koi install nahi, koi folder nahi, koi Python nahi.")
lines.append("REM ============================================================")
lines.append('if "%~1"=="__hidden__" goto :run')
lines.append('powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command "Start-Process -FilePath \'%~f0\' -ArgumentList \'__hidden__\' -WindowStyle Hidden"')
lines.append("exit /b")
lines.append("")
lines.append(":run")
lines.append("setlocal")
lines.append('set "TMPPS=%TEMP%\\wifi_tester_gui.ps1"')
lines.append('set "B64=%TEMP%\\wifi_tester_gui.b64"')

for idx, ch in enumerate(chunks):
    if idx == 0:
        lines.append('>"%B64%" echo ' + ch)
    else:
        lines.append('>>"%B64%" echo ' + ch)

lines.append('certutil -decode "%B64%" "%TMPPS%" >nul 2>&1')
lines.append('del "%B64%" >nul 2>&1')
lines.append('if not exist "%TMPPS%" goto :fail')
lines.append('powershell -NoProfile -ExecutionPolicy Bypass -File "%TMPPS%"')
lines.append('del "%TMPPS%" >nul 2>&1')
lines.append("endlocal")
lines.append("exit /b")
lines.append("")
lines.append(":fail")
lines.append('powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show(\'File ban nahi payi. Antivirus ya SmartScreen ne rok diya ho sakta hai.\', \'WiFi Password Tester\', \'OK\', \'Error\')"')
lines.append("endlocal")
lines.append("exit /b 1")

with open(BAT, "w", newline="", encoding="utf-8") as f:
    f.write("\r\n".join(lines) + "\r\n")

print("Generated:", BAT)
print("Chunks:", len(chunks))
print("Max line length:", max(len(l) for l in lines), "(limit 8191)")
print("Bat size:", os.path.getsize(BAT), "bytes")
