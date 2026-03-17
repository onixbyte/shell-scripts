REM This script switches the right-click context menu to Windows 11 style
REM by modifying the registry and restarting Windows Explorer

REM Delete registry entry to enable Windows 11 context menu
reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f

REM Terminate Windows Explorer process
taskkill /f /im explorer.exe

REM Restart Windows Explorer to apply changes
start explorer.exe