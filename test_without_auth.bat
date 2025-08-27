@echo off
echo TALOWA Referral System - Test Without Authentication
echo ===================================================
echo.

set PROJECT_ID=talowa
set BASE_URL=https://us-central1-%PROJECT_ID%.cloudfunctions.net

echo Project: %PROJECT_ID%
echo Base URL: %BASE_URL%
echo.

echo Testing function accessibility (no authentication required)
echo ===========================================================
echo.

echo 1. Testing reserveReferralCode...
curl -s -w "HTTP %%{http_code}" -o nul "%BASE_URL%/reserveReferralCode" -H "Content-Type: application/json" -d "{}" 2>nul
echo.

echo 2. Testing applyReferralCode...
curl -s -w "HTTP %%{http_code}" -o nul "%BASE_URL%/applyReferralCode" -H "Content-Type: application/json" -d "{}" 2>nul
echo.

echo 3. Testing getMyReferralStats...
curl -s -w "HTTP %%{http_code}" -o nul "%BASE_URL%/getMyReferralStats" -H "Content-Type: application/json" -d "{}" 2>nul
echo.

echo Expected results:
echo - HTTP 401 or 403 = Function is deployed and requires authentication (GOOD!)
echo - HTTP 404 = Function not found (needs deployment)
echo - HTTP 200 = Function accessible without auth (security issue)
echo.

echo Your referral functions are available at:
echo - %BASE_URL%/reserveReferralCode
echo - %BASE_URL%/applyReferralCode
echo - %BASE_URL%/getMyReferralStats
echo.

echo To get an authentication token:
echo 1. Open get_token_alternatives.html in your browser
echo 2. Use Method 1 (Create Test Account) - easiest option
echo 3. Copy the generated token
echo 4. Run: test_referral_functions.bat %PROJECT_ID% "YOUR_TOKEN"
echo.

pause