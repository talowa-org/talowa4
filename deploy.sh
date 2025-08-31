#!/bin/bash

# TALOWA App Deployment Script
# This script builds and deploys the TALOWA Flutter app to Firebase

echo "🚀 TALOWA App Deployment Script"
echo "================================"

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found. Please run this script from the project root."
    exit 1
fi

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Please install it first:"
    echo "   npm install -g firebase-tools"
    exit 1
fi

# Check if user is logged in to Firebase
if ! firebase projects:list &> /dev/null; then
    echo "❌ Not logged in to Firebase. Please login first:"
    echo "   firebase login"
    exit 1
fi

echo "✅ Prerequisites check passed"

# Step 1: Clean and build Flutter web app
echo ""
echo "📱 Step 1: Building Flutter web app..."
flutter clean
flutter pub get
flutter build web --release --no-tree-shake-icons

if [ $? -ne 0 ]; then
    echo "❌ Flutter build failed"
    exit 1
fi

echo "✅ Flutter web build completed"

# Step 2: Build Cloud Functions (if Node.js is available)
echo ""
echo "⚡ Step 2: Building Cloud Functions..."

if command -v npm &> /dev/null; then
    cd functions
    npm install
    npm run build
    cd ..
    echo "✅ Cloud Functions build completed"
else
    echo "⚠️  Node.js not found. Using pre-compiled functions."
    if [ ! -d "functions/lib" ]; then
        echo "❌ No compiled functions found. Please install Node.js and run:"
        echo "   cd functions && npm install && npm run build"
        exit 1
    fi
    echo "✅ Using existing compiled functions"
fi

# Step 3: Deploy to Firebase
echo ""
echo "🚀 Step 3: Deploying to Firebase..."

# Deploy everything
firebase deploy

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Deployment successful!"
    echo ""
    echo "📱 Your app is now live at:"
    echo "   https://talowa.web.app"
    echo ""
    echo "🔧 Firebase Console:"
    echo "   https://console.firebase.google.com/project/talowa"
    echo ""
    echo "✅ Deployment completed successfully!"
else
    echo "❌ Deployment failed"
    exit 1
fi