@echo off
setlocal
set /p wazuh_input=
powershell.exe -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop'; $p='C:\ProgramData\SOC-Lab\shuffle-response-marker.txt'; if (Test-Path -LiteralPath $p) { if ((Get-Content -LiteralPath $p -Raw).Trim() -ne 'SOC_SHUFFLE_RESPONSE_TEST') { throw 'Unexpected marker content; leaving file untouched.' }; Remove-Item -LiteralPath $p }"
exit /b %errorlevel%
