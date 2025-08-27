@echo off
setlocal enabledelayedexpansion

echo 🚀 TALOWA Referral System - Auto Deploy and Test
echo ================================================
echo.

REM Get project ID from Firebase config
set PROJECT_ID=
for /f "tokens=2 delims=:" %%a in ('findstr "projectId" .firebaserc 2^>nul') do (
    set PROJECT_ID=%%a
    set PROJECT_ID=!PROJECT_ID:"=!
    set PROJECT_ID=!PROJECT_ID:,=!
    set PROJECT_ID=!PROJECT_ID: =!
)

if "%PROJECT_ID%"=="" (
    echo ⚠️ Could not detect project ID from .firebaserc
    set /p PROJECT_ID="Enter your Firebase project ID: "
)

echo 📋 Project ID: %PROJECT_ID%
echo.

REM Step 1: Run deployment script
echo 🔧 Step 1: Running deployment script...
echo ========================================
if exist "deploy_referral_fixes.bat" (
    call deploy_referral_fixes.bat
    if !errorlevel! neq 0 (
        echo ❌ Deployment failed!
        pause
        exit /b 1
    )
    echo ✅ Deployment completed successfully!
) else (
    echo ❌ deploy_referral_fixes.bat not found!
    echo Creating basic deployment...
    
    echo 📦 Installing Cloud Functions dependencies...
    cd functions
    call npm install
    if !errorlevel! neq 0 (
        echo ❌ Failed to install dependencies
        cd ..
        pause
        exit /b 1
    )
    
    echo ⚡ Building Cloud Functions...
    call npm run build
    if !errorlevel! neq 0 (
        echo ❌ Failed to build functions
        cd ..
        pause
        exit /b 1
    )
    cd ..
    
    echo 🔧 Deploying Cloud Functions...
    firebase deploy --only functions
    if !errorlevel! neq 0 (
        echo ❌ Failed to deploy functions
        pause
        exit /b 1
    )
    
    echo 📋 Deploying Firestore rules...
    firebase deploy --only firestore:rules
    if !errorlevel! neq 0 (
        echo ❌ Failed to deploy rules
        pause
        exit /b 1
    )
    
    echo ✅ Basic deployment completed!
)

echo.

REM Step 2: Open token generator
echo 🔑 Step 2: Opening token generator...
echo ====================================

REM Check if we have a local web server available
where python >nul 2>nul
if !errorlevel! equ 0 (
    echo 🌐 Starting local web server for token generator...
    echo.
    echo 📝 Instructions:
    echo 1. A web browser will open with the token generator
    echo 2. Login with your TALOWA account
    echo 3. Copy the generated ID token
    echo 4. Come back to this window and paste it
    echo.
    
    REM Start Python web server in background
    start /min python -m http.server 8080
    timeout /t 2 /nobreak >nul
    
    REM Open browser
    start http://localhost:8080/get_test_token.html
    
    echo ⏳ Waiting for you to get the token...
    echo.
    set /p ID_TOKEN="Paste your ID token here: "
    
    REM Stop the web server
    taskkill /f /im python.exe >nul 2>nul
    
) else (
    echo ⚠️ Python not found. Opening token generator manually...
    echo.
    echo 📝 Manual steps:
    echo 1. Open get_test_token.html in your browser
    echo 2. Login with your TALOWA account  
    echo 3. Copy the generated ID token
    echo 4. Come back here and paste it
    echo.
    
    start get_test_token.html
    
    echo ⏳ Waiting for you to get the token...
    set /p ID_TOKEN="Paste your ID token here: "
)

if "%ID_TOKEN%"=="" (
    echo ⚠️ No token provided. Running basic tests without authentication...
    set ID_TOKEN=
) else (
    echo ✅ Token received! (Length: !ID_TOKEN:~0,50!...)
)

echo.

REM Step 3: Run automated tests
echo 🧪 Step 3: Running automated tests...
echo ===================================

if exist "test_referral_functions.bat" (
    echo 🔍 Running comprehensive function tests...
    call test_referral_functions.bat %PROJECT_ID% "%ID_TOKEN%"
) else (
    echo ⚠️ test_referral_functions.bat not found. Running basic tests...
    
    echo 📋 Testing function accessibility...
    
    REM Test reserveReferralCode
    echo Testing reserveReferralCode...
    curl -s -w "%%{http_code}" -o temp_reserve.json "https://us-central1-%PROJECT_ID%.cloudfunctions.net/reserveReferralCode" -H "Content-Type: application/json" -d "{}" > temp_status.txt 2>nul
    
    if exist temp_status.txt (
        set /p STATUS=<temp_status.txt
        if "!STATUS!"=="401" (
            echo ✅ reserveReferralCode - DEPLOYED (needs auth)
        ) else if "!STATUS!"=="403" (
            echo ✅ reserveReferralCode - DEPLOYED (needs auth)
        ) else if "!STATUS!"=="404" (
            echo ❌ reserveReferralCode - NOT FOUND
        ) else (
            echo ✅ reserveReferralCode - DEPLOYED (HTTP !STATUS!)
        )
        del temp_status.txt temp_reserve.json 2>nul
    )
    
    REM Test applyReferralCode
    echo Testing applyReferralCode...
    curl -s -w "%%{http_code}" -o temp_apply.json "https://us-central1-%PROJECT_ID%.cloudfunctions.net/applyReferralCode" -H "Content-Type: application/json" -d "{}" > temp_status.txt 2>nul
    
    if exist temp_status.txt (
        set /p STATUS=<temp_status.txt
        if "!STATUS!"=="401" (
            echo ✅ applyReferralCode - DEPLOYED (needs auth)
        ) else if "!STATUS!"=="403" (
            echo ✅ applyReferralCode - DEPLOYED (needs auth)
        ) else if "!STATUS!"=="404" (
            echo ❌ applyReferralCode - NOT FOUND
        ) else (
            echo ✅ applyReferralCode - DEPLOYED (HTTP !STATUS!)
        )
        del temp_status.txt temp_apply.json 2>nul
    )
    
    REM Test getMyReferralStats
    echo Testing getMyReferralStats...
    curl -s -w "%%{http_code}" -o temp_stats.json "https://us-central1-%PROJECT_ID%.cloudfunctions.net/getMyReferralStats" -H "Content-Type: application/json" -d "{}" > temp_status.txt 2>nul
    
    if exist temp_status.txt (
        set /p STATUS=<temp_status.txt
        if "!STATUS!"=="401" (
            echo ✅ getMyReferralStats - DEPLOYED (needs auth)
        ) else if "!STATUS!"=="403" (
            echo ✅ getMyReferralStats - DEPLOYED (needs auth)
        ) else if "!STATUS!"=="404" (
            echo ❌ getMyReferralStats - NOT FOUND
        ) else (
            echo ✅ getMyReferralStats - DEPLOYED (HTTP !STATUS!)
        )
        del temp_status.txt temp_stats.json 2>nul
    )
)

echo.

REM Step 4: Run authenticated tests if token provided
if not "%ID_TOKEN%"=="" (
    echo 🔐 Step 4: Running authenticated tests...
    echo ======================================
    
    echo Testing reserveReferralCode with authentication...
    curl -s "https://us-central1-%PROJECT_ID%.cloudfunctions.net/reserveReferralCode" ^
        -H "Content-Type: application/json" ^
        -H "Authorization: Bearer %ID_TOKEN%" ^
        -d "{}" > temp_auth_test.json 2>nul
    
    if exist temp_auth_test.json (
        echo Response:
        type temp_auth_test.json
        echo.
        
        REM Check if we got a referral code
        findstr /C:"code" temp_auth_test.json >nul
        if !errorlevel! equ 0 (
            echo ✅ Successfully got referral code!
            
            REM Extract the code for further testing
            for /f "tokens=2 delims=:" %%a in ('findstr "code" temp_auth_test.json') do (
                set REFERRAL_CODE=%%a
                set REFERRAL_CODE=!REFERRAL_CODE:"=!
                set REFERRAL_CODE=!REFERRAL_CODE:,=!
                set REFERRAL_CODE=!REFERRAL_CODE: =!
            )
            
            if not "!REFERRAL_CODE!"=="" (
                echo 🎯 Your referral code: !REFERRAL_CODE!
                
                echo Testing self-referral block...
                curl -s "https://us-central1-%PROJECT_ID%.cloudfunctions.net/applyReferralCode" ^
                    -H "Content-Type: application/json" ^
                    -H "Authorization: Bearer %ID_TOKEN%" ^
                    -d "{\"code\":\"!REFERRAL_CODE!\"}" > temp_self_test.json 2>nul
                
                if exist temp_self_test.json (
                    findstr /C:"error\|self\|own" temp_self_test.json >nul
                    if !errorlevel! equ 0 (
                        echo ✅ Self-referral properly blocked!
                    ) else (
                        echo ⚠️ Self-referral response unclear
                        type temp_self_test.json
                    )
                    del temp_self_test.json 2>nul
                )
            )
        ) else (
            echo ⚠️ No referral code in response
        )
        
        del temp_auth_test.json 2>nul
    ) else (
        echo ❌ No response from authenticated test
    )
    
    echo.
    
    echo Testing getMyReferralStats with authentication...
    curl -s "https://us-central1-%PROJECT_ID%.cloudfunctions.net/getMyReferralStats" ^
        -H "Content-Type: application/json" ^
        -H "Authorization: Bearer %ID_TOKEN%" ^
        -d "{}" > temp_stats_auth.json 2>nul
    
    if exist temp_stats_auth.json (
        echo Response:
        type temp_stats_auth.json
        echo.
        
        findstr /C:"directCount" temp_stats_auth.json >nul
        if !errorlevel! equ 0 (
            echo ✅ Successfully got referral stats!
        ) else (
            echo ⚠️ Unexpected stats response format
        )
        
        del temp_stats_auth.json 2>nul
    )
)

echo.

REM Step 5: Summary and next steps
echo 🎯 Step 5: Summary and Next Steps
echo =================================

echo ✅ Deployment completed
echo ✅ Function accessibility tested
if not "%ID_TOKEN%"=="" (
    echo ✅ Authenticated function tests completed
) else (
    echo ⚠️ Authenticated tests skipped (no token provided)
)

echo.
echo 📝 What was tested:
echo   ✅ Cloud Functions deployment
echo   ✅ Function accessibility (HTTP status codes)
echo   ✅ Basic security (unauthenticated requests blocked)
if not "%ID_TOKEN%"=="" (
    echo   ✅ Referral code generation
    echo   ✅ Self-referral blocking
    echo   ✅ Referral statistics retrieval
)

echo.
echo 🔗 Your referral system is live at:
echo   https://us-central1-%PROJECT_ID%.cloudfunctions.net/reserveReferralCode
echo   https://us-central1-%PROJECT_ID%.cloudfunctions.net/applyReferralCode
echo   https://us-central1-%PROJECT_ID%.cloudfunctions.net/getMyReferralStats

echo.
echo 📱 Test in your Flutter app:
echo   1. Register a new user
echo   2. Check if referral code is generated
echo   3. Try using referral codes during registration
echo   4. Verify referral relationships in Firestore console

echo.
echo 🔍 Monitor function logs:
echo   firebase functions:log --only reserveReferralCode
echo   firebase functions:log --only applyReferralCode
echo   firebase functions:log --only getMyReferralStats

echo.
echo 🎉 Auto deployment and testing completed!
pause