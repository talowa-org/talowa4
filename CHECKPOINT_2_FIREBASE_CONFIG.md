# 🔥 CHECKPOINT #2 - FIREBASE CONFIGURATION BACKUP

## Firebase Project Details
- **Project ID**: talowa
- **Project Number**: 132354679195
- **Display Name**: TALOWA
- **Hosting URL**: https://talowa.web.app

## Firebase Services Enabled
- ✅ Authentication (Phone verification)
- ✅ Firestore Database
- ✅ Cloud Functions
- ✅ Hosting
- ✅ Storage

## Authentication Configuration
```javascript
// Phone Authentication Settings
- Sign-in method: Phone enabled
- Test phone numbers: None configured
- reCAPTCHA: Enabled for web
- App verification: Disabled for testing
```

## Firestore Database Structure
```
Collections:
├── users/                    # User profiles
│   └── {uid}/
│       ├── id: string
│       ├── fullName: string
│       ├── email: string (phone@talowa.app format)
│       ├── phoneNumber: string (+91 format)
│       ├── referralCode: string (TAL format)
│       ├── referredBy: string
│       ├── role: "member"
│       ├── membershipPaid: boolean
│       ├── address: object
│       ├── createdAt: timestamp
│       └── updatedAt: timestamp
│
├── userRegistry/             # Phone number index
│   └── {phoneNumber}/
│       ├── uid: string
│       ├── email: string
│       ├── role: string
│       ├── state: string
│       ├── district: string
│       ├── mandal: string
│       ├── village: string
│       └── createdAt: timestamp
│
└── referralCodes/           # Referral code tracking
    └── {referralCode}/
        ├── uid: string
        ├── active: boolean
        └── createdAt: timestamp
```

## Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // User registry for phone lookup
    match /userRegistry/{phoneNumber} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == resource.data.uid;
    }
    
    // Referral codes
    match /referralCodes/{code} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

## Firebase Hosting Configuration
```json
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
        "source": "/index.html",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "no-cache, no-store, must-revalidate"
          }
        ]
      },
      {
        "source": "**/*.@(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "public, max-age=31536000"
          }
        ]
      }
    ]
  }
}
```

## Web Firebase Configuration
```javascript
// web/firebase-config.js
const firebaseConfig = {
  apiKey: "AIzaSyBkKQ8PwQqJjJxJxJxJxJxJxJxJxJxJxJx",
  authDomain: "talowa.firebaseapp.com",
  projectId: "talowa",
  storageBucket: "talowa.appspot.com",
  messagingSenderId: "132354679195",
  appId: "1:132354679195:web:xxxxxxxxxxxxxxxxxxxxx"
};

// Initialize Firebase
import { initializeApp } from 'firebase/app';
const app = initializeApp(firebaseConfig);
```

## Cloud Functions Deployed
```
Functions (asia-south1):
├── websocketServer          # Real-time messaging
├── keepWebSocketAlive       # Connection maintenance  
├── cleanupOfflineMessages   # Message cleanup
├── getWebSocketInfo         # Connection info
└── aiRespond               # AI chat responses
```

## Storage Rules
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Indexes Configuration
```json
{
  "indexes": [
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "role", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "users", 
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "referralCode", "order": "ASCENDING"}
      ]
    }
  ]
}
```

## Environment Variables
```
FIREBASE_PROJECT_ID=talowa
FIREBASE_API_KEY=AIzaSyBkKQ8PwQqJjJxJxJxJxJxJxJxJxJxJxJx
RAZORPAY_KEY_ID=rzp_test_1DP5mmOlF5G5ag
```

## Deployment Commands Used
```bash
# Build the app
flutter build web --release --no-tree-shake-icons

# Deploy to Firebase
firebase deploy --only hosting

# Deploy all services
firebase deploy
```

## Restoration Steps for Firebase
1. Ensure Firebase CLI is installed and authenticated
2. Set project: `firebase use talowa`
3. Deploy Firestore rules: `firebase deploy --only firestore:rules`
4. Deploy hosting: `firebase deploy --only hosting`
5. Verify all services are active in Firebase Console
6. Test authentication and database connectivity

---
**Last Updated**: August 23, 2025  
**Status**: ✅ All Firebase services operational
