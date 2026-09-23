@echo off
setlocal
set /p wazuh_input=
if not exist "C:\ProgramData\SOC-Lab" mkdir "C:\ProgramData\SOC-Lab"
> "C:\ProgramData\SOC-Lab\shuffle-response-marker.txt" echo SOC_SHUFFLE_RESPONSE_TEST
exit /b
