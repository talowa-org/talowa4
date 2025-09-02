# 🚀 DEPLOYMENT GUIDE - Complete Reference

## 📋 Overview

This comprehensive guide covers all aspects of deploying the TALOWA app, including Flutter web builds, Firebase hosting, cloud functions deployment, and production environment setup. This consolidates information from multiple deployment-related documents.

---

## 🏗️ Deployment Architecture

### Deployment Targets
- **Flutter Web** - Progressive Web App (PWA)
- **Firebase Hosting** - Static web hosting
- **Cloud Functions** - Backend serverless functions
- **Firestore** - Database deployment
- **Firebase Auth** - Authentication services

### Environment Structure
```
Production Environment
├── Firebase Hosting (Web App)
├── Cloud Functions (Backend Logic)
├── Firestore Database (Data Storage)
├── Firebase Auth (User Management)
└── Firebase Storage (File Storage)
```

---

## 🔧 Prerequisites & Setup

### Required Tools
```bash
# Flutter SDK
flutter --version  # Should be latest stable

# Firebase CLI
npm install -g firebase-tools
firebase --version

# Node.js (for Cloud Functions)
node --version  # v16 or higher
npm --version

# Git (for version control)
git --version
```

### Firebase Project Setup
```bash
# Login to Firebase
firebase login

# Initialize Firebase in project
firebase init

# Select services:
# - Hosting
# - Functions
# - Firestore
# - Storage
```

---

## 🎯 Build Process

### 1. Flutter Web Build
```bash
# Clean previous builds
flutter clean
flutter pub get

# Build for web (production)
flutter build web --release --web-renderer html

# Build with specific base href (if needed)
flutter build web --release --base-href /talowa/

# Verify build output
ls -la build/web/
```

### 2. PWA Configuration
```javascript
// web/manifest.json
{
  "name": "TALOWA - Land Rights App",
  "short_name": "TALOWA",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#4CAF50",
  "theme_color": "#4CAF50",
  "description": "Secure land rights management platform",
  "orientation": "portrait-primary",
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

### 3. Service Worker Setup
```javascript
// web/sw.js
const CACHE_NAME = 'talowa-v1.0.0';
const urlsToCache = [
  '/',
  '/main.dart.js',
  '/assets/AssetManifest.json',
  '/assets/FontManifest.json'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(urlsToCache))
  );
});
```

---

## 🔥 Firebase Deployment

### 1. Hosting Configuration
```json
// firebase.json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      }
    ]
  },
  "functions": {
    "source": "functions",
    "runtime": "nodejs18"
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "storage": {
    "rules": "storage.rules"
  }
}
```

### 2. Cloud Functions Deployment
```bash
# Navigate to functions directory
cd functions

# Install dependencies
npm install

# Deploy functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:processReferral
```

### 3. Database Rules Deployment
```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Firestore indexes
firebase deploy --only firestore:indexes

# Deploy Storage rules
firebase deploy --only storage
```

### 4. Complete Deployment
```bash
# Deploy everything
firebase deploy

# Deploy with specific project
firebase deploy --project talowa-production

# Deploy with confirmation
firebase deploy --force
```

---

## 🔄 Automated Deployment Scripts

### Windows Batch Script (deploy.bat)
```batch
@echo off
echo Starting TALOWA deployment...

echo Step 1: Cleaning Flutter build
flutter clean
flutter pub get

echo Step 2: Building Flutter web
flutter build web --release --web-renderer html

echo Step 3: Deploying to Firebase
firebase deploy --project talowa-production

echo Step 4: Verifying deployment
firebase hosting:channel:list

echo Deployment completed successfully!
pause
```

### PowerShell Script (deploy.ps1)
```powershell
# TALOWA Deployment Script
Write-Host "Starting TALOWA deployment..." -ForegroundColor Green

# Step 1: Clean and prepare
Write-Host "Cleaning Flutter build..." -ForegroundColor Yellow
flutter clean
flutter pub get

# Step 2: Build for production
Write-Host "Building Flutter web..." -ForegroundColor Yellow
flutter build web --release --web-renderer html

if ($LASTEXITCODE -ne 0) {
    Write-Host "Flutter build failed!" -ForegroundColor Red
    exit 1
}

# Step 3: Deploy to Firebase
Write-Host "Deploying to Firebase..." -ForegroundColor Yellow
firebase deploy --project talowa-production

if ($LASTEXITCODE -eq 0) {
    Write-Host "Deployment successful!" -ForegroundColor Green
} else {
    Write-Host "Deployment failed!" -ForegroundColor Red
    exit 1
}
```

### Bash Script (deploy.sh)
```bash
#!/bin/bash
set -e

echo "🚀 Starting TALOWA deployment..."

# Step 1: Clean build
echo "🧹 Cleaning Flutter build..."
flutter clean
flutter pub get

# Step 2: Build web
echo "🔨 Building Flutter web..."
flutter build web --release --web-renderer html

# Step 3: Deploy
echo "☁️ Deploying to Firebase..."
firebase deploy --project talowa-production

echo "✅ Deployment completed successfully!"
```

---

## 🔧 Environment Configuration

### Production Environment Variables
```bash
# .env.production
FLUTTER_WEB_RENDERER=html
FIREBASE_PROJECT_ID=talowa-production
FIREBASE_API_KEY=your-production-api-key
FIREBASE_AUTH_DOMAIN=talowa-production.firebaseapp.com
FIREBASE_DATABASE_URL=https://talowa-production.firebaseio.com
FIREBASE_STORAGE_BUCKET=talowa-production.appspot.com
```

### Firebase Configuration
```dart
// lib/config/firebase_config.dart
class FirebaseConfig {
  static const String projectId = 'talowa-production';
  static const String apiKey = 'your-production-api-key';
  static const String authDomain = 'talowa-production.firebaseapp.com';
  static const String databaseURL = 'https://talowa-production.firebaseio.com';
  static const String storageBucket = 'talowa-production.appspot.com';
  static const String messagingSenderId = 'your-sender-id';
  static const String appId = 'your-app-id';
}
```

---

## 🛡️ Security & Performance

### Security Headers
```json
// firebase.json hosting headers
"headers": [
  {
    "source": "**",
    "headers": [
      {
        "key": "X-Content-Type-Options",
        "value": "nosniff"
      },
      {
        "key": "X-Frame-Options",
        "value": "DENY"
      },
      {
        "key": "X-XSS-Protection",
        "value": "1; mode=block"
      },
      {
        "key": "Strict-Transport-Security",
        "value": "max-age=31536000; includeSubDomains"
      }
    ]
  }
]
```

### Performance Optimization
```json
// Compression and caching
"headers": [
  {
    "source": "**/*.@(js|css|html)",
    "headers": [
      {
        "key": "Cache-Control",
        "value": "max-age=31536000"
      },
      {
        "key": "Content-Encoding",
        "value": "gzip"
      }
    ]
  }
]
```

---

## 🐛 Common Deployment Issues

### Build Failures
**Problem**: Flutter build fails with errors
**Solutions**:
```bash
# Clear Flutter cache
flutter clean
rm -rf .dart_tool/
flutter pub get

# Update Flutter
flutter upgrade
flutter doctor

# Check for dependency conflicts
flutter pub deps
```

### Firebase Deployment Errors
**Problem**: Firebase deploy fails
**Solutions**:
```bash
# Check Firebase CLI version
firebase --version
npm update -g firebase-tools

# Re-authenticate
firebase logout
firebase login

# Check project configuration
firebase projects:list
firebase use talowa-production
```

### PWA Issues
**Problem**: PWA not installing or working offline
**Solutions**:
- Verify manifest.json configuration
- Check service worker registration
- Test on different browsers
- Clear browser cache and storage

### Performance Issues
**Problem**: Slow loading or poor performance
**Solutions**:
- Enable web renderer optimization
- Implement code splitting
- Optimize assets and images
- Use CDN for static assets

---

## 📊 Monitoring & Analytics

### Deployment Verification
```bash
# Check deployment status
firebase hosting:channel:list

# View deployment history
firebase hosting:releases:list

# Check function logs
firebase functions:log

# Monitor performance
firebase performance:report
```

### Health Checks
```javascript
// Health check endpoint
exports.healthCheck = functions.https.onRequest((req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});
```

---

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow
```yaml
# .github/workflows/deploy.yml
name: Deploy to Firebase

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
    
    - name: Install dependencies
      run: flutter pub get
    
    - name: Build web
      run: flutter build web --release
    
    - name: Deploy to Firebase
      uses: FirebaseExtended/action-hosting-deploy@v0
      with:
        repoToken: '${{ secrets.GITHUB_TOKEN }}'
        firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
        projectId: talowa-production
```

---

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] Code review completed
- [ ] Tests passing
- [ ] Dependencies updated
- [ ] Environment variables configured
- [ ] Firebase project ready

### Build Process
- [ ] Flutter clean executed
- [ ] Dependencies installed
- [ ] Web build successful
- [ ] PWA configuration verified
- [ ] Assets optimized

### Firebase Deployment
- [ ] Hosting deployed
- [ ] Functions deployed
- [ ] Database rules updated
- [ ] Storage rules updated
- [ ] Security rules verified

### Post-Deployment
- [ ] Application accessible
- [ ] Authentication working
- [ ] Database operations functional
- [ ] PWA installation working
- [ ] Performance metrics acceptable

---

## 🚀 Quick Deployment Commands

### One-Click Deployment
```bash
# Windows
ONE_CLICK_SETUP.bat

# Linux/Mac
./deploy.sh

# PowerShell
./deploy.ps1
```

### Emergency Rollback
```bash
# Rollback to previous version
firebase hosting:channel:deploy previous --project talowa-production

# Rollback specific function
firebase functions:delete functionName --project talowa-production
```

---

## 📞 Support & Troubleshooting

### Debug Commands
```bash
# Check deployment status
firebase hosting:channel:list --project talowa-production

# View function logs
firebase functions:log --project talowa-production

# Test locally
firebase serve --project talowa-production

# Validate configuration
firebase projects:list
```

### Emergency Contacts
- **Firebase Support**: Firebase Console → Support
- **Flutter Issues**: GitHub Flutter repository
- **Domain Issues**: Domain registrar support
- **SSL Certificate**: Firebase Hosting support

---

## 📚 Related Documentation

- **[Firebase Configuration](FIREBASE_CONFIGURATION.md)** - Firebase setup and configuration
- **[Security System](SECURITY_SYSTEM.md)** - Security measures and protocols
- **[Troubleshooting Guide](TROUBLESHOOTING_GUIDE.md)** - Common issues and solutions
- **[Testing Guide](TESTING_GUIDE.md)** - Testing procedures and validation

---

**Status**: ✅ Production Ready  
**Last Updated**: January 2025  
**Priority**: Critical (Production System)  
**Maintainer**: DevOps Team