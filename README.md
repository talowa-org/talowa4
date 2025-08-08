# Talowa

A clean Flutter project with Firebase integration ready for development.

## Project Status

This project has been cleaned and prepared for fresh development with the following Firebase services pre-configured:

- **Firebase Core** - Base Firebase functionality
- **Firebase Auth** - Authentication services
- **Cloud Firestore** - NoSQL database

## Firebase Configuration

All Firebase configuration files are preserved and ready to use:

- `lib/firebase_options.dart` - Platform-specific Firebase configuration
- `firebase.json` - Firebase project settings
- `firestore.rules` - Database security rules
- `firestore.indexes.json` - Database indexes
- `android/app/google-services.json` - Android configuration
- `ios/Runner/GoogleService-Info.plist` - iOS configuration

## Getting Started

1. Ensure you have Flutter installed
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to start the app
4. Begin building your features using the pre-configured Firebase services

## Dependencies

- Flutter SDK (>=3.8.1 <4.0.0)
- firebase_core: ^3.15.2
- firebase_auth: ^5.7.0
- cloud_firestore: ^5.6.12

## Project Structure

```
lib/
├── main.dart              # App entry point with Firebase initialization
├── firebase_options.dart  # Firebase configuration
└── (ready for your features)
```
