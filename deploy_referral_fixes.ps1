#!/usr/bin/env pwsh

Write-Host "🚀 Deploying TALOWA Referral System Fixes..." -ForegroundColor Green
Write-Host ""

Write-Host "📦 Step 1: Installing Cloud Functions Dependencies..." -ForegroundColor Yellow
Set-Location functions
npm install
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to install Cloud Functions dependencies" -ForegroundColor Red
    Set-Location ..
    Read-Host "Press Enter to exit"
    exit 1
}
Set-Location ..
Write-Host "✅ Cloud Functions dependencies installed" -ForegroundColor Green
Write-Host ""

Write-Host "⚡ Step 2: Building Cloud Functions..." -ForegroundColor Yellow
Set-Location functions
npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to build Cloud Functions" -ForegroundColor Red
    Set-Location ..
    Read-Host "Press Enter to exit"
    exit 1
}
Set-Location ..
Write-Host "✅ Cloud Functions built successfully" -ForegroundColor Green
Write-Host ""

Write-Host "🔧 Step 3: Deploying Cloud Functions..." -ForegroundColor Yellow
firebase deploy --only functions
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to deploy Cloud Functions" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "✅ Cloud Functions deployed successfully" -ForegroundColor Green
Write-Host ""

Write-Host "📋 Step 4: Deploying Firestore Security Rules..." -ForegroundColor Yellow
firebase deploy --only firestore:rules
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to deploy Firestore rules" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "✅ Firestore rules deployed successfully" -ForegroundColor Green
Write-Host ""

Write-Host "📊 Step 5: Deploying Firestore Indexes..." -ForegroundColor Yellow
firebase deploy --only firestore:indexes
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to deploy Firestore indexes" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "✅ Firestore indexes deployed successfully" -ForegroundColor Green
Write-Host ""

Write-Host "🎯 Step 6: Building Flutter Web App..." -ForegroundColor Yellow
flutter build web --release --no-tree-shake-icons
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to build Flutter web app" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "✅ Flutter web app built successfully" -ForegroundColor Green
Write-Host ""

Write-Host "🌐 Step 7: Deploying to Firebase Hosting..." -ForegroundColor Yellow
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to deploy to Firebase Hosting" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "✅ Firebase Hosting deployed successfully" -ForegroundColor Green
Write-Host ""

Write-Host "🎉 All referral system fixes deployed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 What was fixed:" -ForegroundColor Cyan
Write-Host "  ✅ Cloud Functions for server-side referral processing" -ForegroundColor Green
Write-Host "  ✅ Firestore rules allow owners to read their own codes" -ForegroundColor Green
Write-Host "  ✅ Client-side referral code generation eliminated" -ForegroundColor Green
Write-Host "  ✅ Atomic referral relationships with transaction safety" -ForegroundColor Green
Write-Host "  ✅ Permission-denied errors resolved" -ForegroundColor Green
Write-Host "  ✅ User registry creation failures fixed" -ForegroundColor Green
Write-Host "  ✅ Self-referral blocking implemented" -ForegroundColor Green
Write-Host ""
Write-Host "🔗 Your app is live at: https://talowa.web.app" -ForegroundColor Cyan
Write-Host ""
Write-Host "🧪 Test the following scenarios:" -ForegroundColor Yellow
Write-Host "  1. Register without referral code" -ForegroundColor White
Write-Host "  2. Register with valid referral code" -ForegroundColor White
Write-Host "  3. Try to use own referral code (should be blocked)" -ForegroundColor White
Write-Host "  4. Check console for eliminated error messages" -ForegroundColor White
Write-Host ""
Read-Host "Press Enter to exit"