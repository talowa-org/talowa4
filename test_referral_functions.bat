@echo off
setlocal enabledelayedexpansion

REM TALOWA Referral System Function Testing Script (Windows)
REM 
REM This script tests the three core Cloud Functions:
REM - reserveReferralCode
REM - applyReferralCode  
REM - getMyReferralStats
REM
REM Usage: test_referral_functions.bat [PROJECT_ID] [ID_TOKEN]

REM Configuration
set PROJECT_ID=%1
if "%PROJECT_ID%"=="" set PROJECT_ID=talowa-app

set ID_TOKEN=%2
set REGION=us-central1
set BASE_URL=https://%REGION%-%PROJECT_ID%.cloudfunctions.net

echo.
echo 🚀 Testing TALOWA Referral System Cloud Functions
echo Project: %PROJECT_ID%
echo Region: %REGION%
echo Base URL: %BASE_URL%
echo.

REM Check if ID_TOKEN is provided
if "%ID_TOKEN%"=="" (
    echo ⚠️ No ID_TOKEN provided. You'll need a Firebase Auth token to test authenticated functions.
    echo ⚠️ Get one from your app's console: firebase.auth().currentUser.getIdToken()
    echo ⚠️ Usage: %0 PROJECT_ID ID_TOKEN
    echo.
)

echo 📋 Test 1: Checking function accessibility...
echo.

REM Test function accessibility
call :check_function reserveReferralCode
call :check_function applyReferralCode
call :check_function getMyReferralStats

echo.

REM Test with authentication if token provided
if not "%ID_TOKEN%"=="" (
    echo 📋 Test 2: Testing authenticated function calls...
    echo.
    
    echo Testing reserveReferralCode...
    curl -s "%BASE_URL%/reserveReferralCode" ^
        -H "Content-Type: application/json" ^
        -H "Authorization: Bearer %ID_TOKEN%" ^
        -d "{}" > temp_response.json 2>nul
    
    if exist temp_response.json (
        echo Response:
        type temp_response.json
        echo.
        
        REM Extract referral code (basic parsing)
        findstr /C:"code" temp_response.json > nul
        if !errorlevel! equ 0 (
            echo ✅ reserveReferralCode - Got response with code field
        ) else (
            echo ❌ reserveReferralCode - No code field in response
        )
        
        del temp_response.json 2>nul
    ) else (
        echo ❌ reserveReferralCode - No response received
    )
    
    echo.
    
    echo Testing getMyReferralStats...
    curl -s "%BASE_URL%/getMyReferralStats" ^
        -H "Content-Type: application/json" ^
        -H "Authorization: Bearer %ID_TOKEN%" ^
        -d "{}" > temp_stats.json 2>nul
    
    if exist temp_stats.json (
        echo Response:
        type temp_stats.json
        echo.
        
        findstr /C:"directCount" temp_stats.json > nul
        if !errorlevel! equ 0 (
            echo ✅ getMyReferralStats - Got valid stats response
        ) else (
            echo ⚠️ getMyReferralStats - Unexpected response format
        )
        
        del temp_stats.json 2>nul
    ) else (
        echo ❌ getMyReferralStats - No response received
    )
    
    echo.
    
) else (
    echo ⚠️ Skipping authenticated tests (no ID_TOKEN provided)
    echo.
)

echo 📋 Test 3: Testing code format validation...
echo.

REM Test code formats
call :test_code_format "TAL123ABC" "Valid format"
call :test_code_format "TAL2A3B4C" "Valid format"
call :test_code_format "TALXYZ123" "Valid format"
call :test_code_format "tal123abc" "Invalid (lowercase)"
call :test_code_format "TAL12" "Invalid (too short)"
call :test_code_format "TAL123ABCD" "Invalid (too long)"
call :test_code_format "ABC123DEF" "Invalid (no TAL prefix)"

echo.

echo 📋 Test 4: Testing basic security...
echo.

echo Testing unauthenticated access (should fail)...
curl -s -w "%%{http_code}" -o temp_unauth.json "%BASE_URL%/reserveReferralCode" ^
    -H "Content-Type: application/json" ^
    -d "{}" > temp_status.txt 2>nul

if exist temp_status.txt (
    set /p STATUS=<temp_status.txt
    if "!STATUS!"=="401" (
        echo ✅ Unauthenticated access properly blocked (HTTP 401)
    ) else if "!STATUS!"=="403" (
        echo ✅ Unauthenticated access properly blocked (HTTP 403)
    ) else (
        echo ❌ Unauthenticated access not properly blocked (HTTP !STATUS!)
    )
    del temp_status.txt 2>nul
    del temp_unauth.json 2>nul
) else (
    echo ❌ Could not test unauthenticated access
)

echo.

echo 🎯 Test Summary:
echo ✅ Function deployment check completed
if not "%ID_TOKEN%"=="" (
    echo ✅ Authenticated function tests completed
) else (
    echo ⚠️ Authenticated tests skipped (provide ID_TOKEN to run)
)
echo ✅ Code format validation completed
echo ✅ Basic security check completed

echo.
echo 📝 Next steps:
echo 1. Get a Firebase Auth ID token from your app
echo 2. Run: %0 %PROJECT_ID% YOUR_ID_TOKEN
echo 3. Test with multiple users to verify referral relationships
echo 4. Check Firestore console for proper data structure

echo.
echo 🔗 Useful commands:
echo # Get project info:
echo firebase projects:list
echo.
echo # Check function logs:
echo firebase functions:log --only reserveReferralCode
echo.
echo # Deploy functions:
echo firebase deploy --only functions

goto :end

:check_function
set func_name=%1
set url=%BASE_URL%/%func_name%

echo Checking %func_name%...

REM Make a simple request to check if function exists
curl -s -w "%%{http_code}" -o temp_check.json "%url%" ^
    -H "Content-Type: application/json" ^
    -d "{}" > temp_code.txt 2>nul

if exist temp_code.txt (
    set /p HTTP_CODE=<temp_code.txt
    if "!HTTP_CODE!"=="404" (
        echo ❌ %func_name% - NOT FOUND (404)
    ) else if "!HTTP_CODE!"=="401" (
        echo ✅ %func_name% - DEPLOYED (needs auth)
    ) else if "!HTTP_CODE!"=="403" (
        echo ✅ %func_name% - DEPLOYED (needs auth)
    ) else (
        echo ✅ %func_name% - DEPLOYED (HTTP !HTTP_CODE!)
    )
    del temp_code.txt 2>nul
    del temp_check.json 2>nul
) else (
    echo ❌ %func_name% - CONNECTION FAILED
)
goto :eof

:test_code_format
set code=%~1
set description=%~2

REM Basic format validation (simplified for batch)
echo %code% | findstr /R "^TAL[23456789ABCDEFGHJKMNPQRSTUVWXYZ][23456789ABCDEFGHJKMNPQRSTUVWXYZ][23456789ABCDEFGHJKMNPQRSTUVWXYZ][23456789ABCDEFGHJKMNPQRSTUVWXYZ][23456789ABCDEFGHJKMNPQRSTUVWXYZ][23456789ABCDEFGHJKMNPQRSTUVWXYZ]" > nul
if !errorlevel! equ 0 (
    echo ✅ Code format: %code% - VALID
) else (
    echo ⚠️ Code format: %code% - %description%
)
goto :eof

:end
pause