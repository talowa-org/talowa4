# TALOWA Referral System - PowerShell Test Script
# ===============================================

Write-Host "🚀 TALOWA Referral System - PowerShell Test" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$PROJECT_ID = "talowa"
$REGION = "us-central1"
$BASE_URL = "https://$REGION-$PROJECT_ID.cloudfunctions.net"

Write-Host "📋 Project ID: $PROJECT_ID" -ForegroundColor Yellow
Write-Host "🌍 Region: $REGION" -ForegroundColor Yellow
Write-Host "🔗 Base URL: $BASE_URL" -ForegroundColor Yellow
Write-Host ""

# Step 1: Deploy (if script exists)
Write-Host "🔧 Step 1: Deployment" -ForegroundColor Green
Write-Host "===================" -ForegroundColor Green

if (Test-Path "deploy_referral_fixes.bat") {
    Write-Host "📦 Running deploy_referral_fixes.bat..." -ForegroundColor Yellow
    
    $deployResult = Start-Process -FilePath "deploy_referral_fixes.bat" -Wait -PassThru -NoNewWindow
    
    if ($deployResult.ExitCode -eq 0) {
        Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Deployment had issues (Exit Code: $($deployResult.ExitCode))" -ForegroundColor Yellow
        Write-Host "Continuing with tests..." -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ deploy_referral_fixes.bat not found. Skipping deployment." -ForegroundColor Yellow
}

Write-Host ""

# Step 2: Test function accessibility
Write-Host "🧪 Step 2: Function Accessibility Tests" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green

$functions = @("reserveReferralCode", "applyReferralCode", "getMyReferralStats")

foreach ($func in $functions) {
    Write-Host "Testing $func..." -ForegroundColor Yellow
    
    try {
        $url = "$BASE_URL/$func"
        $response = Invoke-WebRequest -Uri $url -Method POST -ContentType "application/json" -Body "{}" -ErrorAction SilentlyContinue
        
        if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403) {
            Write-Host "✅ $func - DEPLOYED (requires authentication)" -ForegroundColor Green
        } else {
            Write-Host "✅ $func - DEPLOYED (HTTP $($response.StatusCode))" -ForegroundColor Green
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 401 -or $statusCode -eq 403) {
            Write-Host "✅ $func - DEPLOYED (requires authentication)" -ForegroundColor Green
        } elseif ($statusCode -eq 404) {
            Write-Host "❌ $func - NOT FOUND (404)" -ForegroundColor Red
        } else {
            Write-Host "⚠️ $func - Unexpected response ($statusCode)" -ForegroundColor Yellow
        }
    }
}

Write-Host ""

# Step 3: Token generation
Write-Host "🔑 Step 3: ID Token Generation" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green

if (Test-Path "get_test_token.html") {
    Write-Host "🌐 Opening token generator in browser..." -ForegroundColor Yellow
    Start-Process "get_test_token.html"
    Write-Host ""
    Write-Host "📝 Instructions:" -ForegroundColor Cyan
    Write-Host "1. Login with your TALOWA account in the opened browser" -ForegroundColor White
    Write-Host "2. Copy the generated ID token" -ForegroundColor White
    Write-Host "3. Come back here and paste it" -ForegroundColor White
    Write-Host ""
    
    $idToken = Read-Host "Paste your ID token here (or press Enter to skip)"
    
    if ($idToken -and $idToken.Length -gt 50) {
        Write-Host "✅ Token received! (Length: $($idToken.Length) characters)" -ForegroundColor Green
        
        # Step 4: Authenticated tests
        Write-Host ""
        Write-Host "🔐 Step 4: Authenticated Function Tests" -ForegroundColor Green
        Write-Host "======================================" -ForegroundColor Green
        
        # Test reserveReferralCode with auth
        Write-Host "Testing reserveReferralCode with authentication..." -ForegroundColor Yellow
        try {
            $headers = @{
                "Content-Type" = "application/json"
                "Authorization" = "Bearer $idToken"
            }
            
            $response = Invoke-RestMethod -Uri "$BASE_URL/reserveReferralCode" -Method POST -Headers $headers -Body "{}"
            
            if ($response.code) {
                Write-Host "✅ Successfully got referral code: $($response.code)" -ForegroundColor Green
                $referralCode = $response.code
                
                # Test self-referral blocking
                Write-Host "Testing self-referral blocking..." -ForegroundColor Yellow
                try {
                    $selfResponse = Invoke-RestMethod -Uri "$BASE_URL/applyReferralCode" -Method POST -Headers $headers -Body "{`"code`":`"$referralCode`"}"
                    Write-Host "⚠️ Self-referral response: $($selfResponse | ConvertTo-Json)" -ForegroundColor Yellow
                } catch {
                    Write-Host "✅ Self-referral properly blocked!" -ForegroundColor Green
                }
            } else {
                Write-Host "⚠️ Unexpected response format: $($response | ConvertTo-Json)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "❌ Error testing reserveReferralCode: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Test getMyReferralStats with auth
        Write-Host "Testing getMyReferralStats with authentication..." -ForegroundColor Yellow
        try {
            $statsResponse = Invoke-RestMethod -Uri "$BASE_URL/getMyReferralStats" -Method POST -Headers $headers -Body "{}"
            Write-Host "✅ Successfully got referral stats: $($statsResponse | ConvertTo-Json)" -ForegroundColor Green
        } catch {
            Write-Host "❌ Error testing getMyReferralStats: $($_.Exception.Message)" -ForegroundColor Red
        }
        
    } else {
        Write-Host "⚠️ No valid token provided. Skipping authenticated tests." -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ get_test_token.html not found." -ForegroundColor Yellow
    Write-Host "You can get an ID token from your Flutter app console:" -ForegroundColor White
    Write-Host "firebase.auth().currentUser.getIdToken().then(console.log)" -ForegroundColor Gray
}

Write-Host ""

# Step 5: Summary
Write-Host "🎯 Step 5: Summary & Next Steps" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green

Write-Host "✅ Function accessibility tests completed" -ForegroundColor Green
Write-Host "✅ Token generation process available" -ForegroundColor Green

Write-Host ""
Write-Host "🔗 Your referral system functions:" -ForegroundColor Cyan
Write-Host "- $BASE_URL/reserveReferralCode" -ForegroundColor White
Write-Host "- $BASE_URL/applyReferralCode" -ForegroundColor White  
Write-Host "- $BASE_URL/getMyReferralStats" -ForegroundColor White

Write-Host ""
Write-Host "📱 Next steps:" -ForegroundColor Cyan
Write-Host "1. Test in your Flutter app" -ForegroundColor White
Write-Host "2. Register new users with referral codes" -ForegroundColor White
Write-Host "3. Check Firestore console for data" -ForegroundColor White
Write-Host "4. Monitor function logs: firebase functions:log" -ForegroundColor White

Write-Host ""
Write-Host "🎉 Referral system test completed!" -ForegroundColor Green

Read-Host "Press Enter to exit"