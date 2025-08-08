# Utils

This directory contains utility functions, constants, and helper classes.

## Suggested Structure

```
utils/
├── constants.dart         # App constants
├── validators.dart        # Form validation functions
├── helpers.dart          # General helper functions
├── extensions.dart       # Dart extensions
└── themes.dart          # App theme configurations
```

## Example Files

### constants.dart
```dart
class AppConstants {
  static const String appName = 'Talowa';
  static const String version = '1.0.0';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String paymentsCollection = 'payments';
}
```

### validators.dart
```dart
class Validators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }
}
```
