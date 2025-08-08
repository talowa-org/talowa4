# Services

This directory contains service classes for business logic and external integrations.

## Suggested Structure

```
services/
├── auth_service.dart      # Firebase Authentication wrapper
├── firestore_service.dart # Firestore database operations
├── storage_service.dart   # Firebase Storage operations
└── api_service.dart       # External API calls
```

## Firebase Services

The following Firebase services are already configured:

- **Firebase Core** - Initialized in main.dart
- **Firebase Auth** - For user authentication
- **Cloud Firestore** - For database operations

Example service structure:

```dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Authentication methods here
}
```
