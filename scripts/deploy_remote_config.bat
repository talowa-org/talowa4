@echo off
setlocal

REM Deploy Remote Config using template
REM Requires: firebase-tools installed and configured project

set PROJECT=talowa
set TEMPLATE=remoteconfig\rc.template.json

if not exist %TEMPLATE% (
  echo Template %TEMPLATE% not found.
  exit /b 1
)

echo Exporting current Remote Config (backup)
firebase remoteconfig:get --project %PROJECT% > remoteconfig\rc.backup.json || echo (skip backup if fails)

echo Validating and deploying template: %TEMPLATE%
firebase remoteconfig:versions:set --project %PROJECT% --template %TEMPLATE%

endlocal

