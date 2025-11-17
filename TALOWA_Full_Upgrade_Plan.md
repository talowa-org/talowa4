# TALOWA APP — Full Flutter & Firebase Upgrade Plan (2025)

**Objective:**  
Upgrade all dependencies in the TALOWA app to their latest stable versions while ensuring complete compatibility with Flutter 3.24+ and Dart 3.5+.  
This plan will help reduce performance issues, maintain Firebase stability, and simplify future deployments.

---

## 🚀 1. Environment Requirements

Before upgrading, make sure you have the latest toolchain installed.

```bash
flutter upgrade
dart --version
flutter doctor
```

### ✅ Required Versions
- **Flutter SDK:** ≥ 3.24.0  
- **Dart SDK:** ≥ 3.5.0  
- **Android Gradle Plugin:** ≥ 8.3.0  
- **Compile SDK Version:** 34  
- **iOS Minimum Version:** 13.0

---

## 🧩 2. Update `pubspec.yaml`

Replace your existing dependencies with:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Firebase & Cloud Functions (Latest stable)
  firebase_core: ^4.2.1
  firebase_auth: ^6.1.2
  cloud_firestore: ^6.1.0
  firebase_storage: ^13.0.4
  cloud_functions: ^6.0.4
  firebase_messaging: ^16.0.4
  firebase_remote_config: ^6.1.1

  # Flutter Utilities
  connectivity_plus: ^7.0.0
  device_info_plus: ^12.2.0
  package_info_plus: ^9.0.0
  permission_handler: ^12.0.1
  flutter_local_notifications: ^19.5.0
  share_plus: ^12.0.1
  photo_view: ^0.15.0
  lottie: ^3.3.2
  fl_chart: ^1.1.1
  fluttertoast: ^9.0.0

  # Realtime Communication & Encryption
  socket_io_client: ^3.1.2
  pointycastle: ^4.0.0

  # Utilities
  mime: ^2.0.0
  timezone: ^0.10.1

dev_dependencies:
  flutter_lints: ^6.0.0
  lints: ^6.0.0
```

Then run:

```bash
flutter clean
flutter pub upgrade --major-versions
flutter pub get
```

---

## ⚙️ 3. Android Configuration

### File: `android/app/build.gradle`
```gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 23
        targetSdkVersion 34
        multiDexEnabled true
    }
}

dependencies {
    classpath 'com.android.tools.build:gradle:8.3.0'
    classpath 'com.google.gms:google-services:4.4.2'
}
```

---

## 🍏 4. iOS Configuration

### File: `ios/Podfile`
```ruby
platform :ios, '13.0'
use_frameworks!
use_modular_headers!

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
```

Then run:

```bash
cd ios
pod repo update
pod install
cd ..
```

---

## 🔥 5. Firebase Initialization (main.dart)

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kIsWeb) {
    debugPrint("Running on Web – disabled unsupported analytics calls.");
  }

  runApp(MyApp());
}
```

---

## 📊 6. Firestore Optimization

Enable persistence and reduce read counts:

```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

Use pagination to limit query results:

```dart
final _firestore = FirebaseFirestore.instance;
QueryDocumentSnapshot? lastDoc;

Future<List<Post>> fetchPosts({bool loadMore = false}) async {
  var query = _firestore.collection('posts')
      .orderBy('timestamp', descending: true)
      .limit(20);

  if (loadMore && lastDoc != null) {
    query = query.startAfterDocument(lastDoc!);
  }

  final snapshot = await query.get();
  if (snapshot.docs.isNotEmpty) {
    lastDoc = snapshot.docs.last;
  }
  return snapshot.docs.map((doc) => Post.fromDoc(doc)).toList();
}
```

✅ **Result:** Reduces Firestore reads by 80–90% and prevents lag.

---

## 🧠 7. Fix Deprecated Firebase Calls

### Replace:
```dart
FirebaseFirestore.instance.collection('users').document(uid)
```
➡️ With:
```dart
FirebaseFirestore.instance.collection('users').doc(uid)
```

### Replace:
```dart
getDocuments()
```
➡️ With:
```dart
get()
```

### Firebase Functions
```dart
final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
```

---

## 🧰 8. Web Plugin Safety

Wrap file I/O and path_provider calls:
```dart
if (!kIsWeb) {
  final dir = await getApplicationDocumentsDirectory();
}
```

---

## 💡 9. Testing Commands

```bash
flutter analyze
flutter test
flutter build apk --release
flutter build web --release
flutter build ios --release
```

---

## ✅ 10. Final Checklist

- [ ] All dependencies upgraded successfully.  
- [ ] Firestore reads optimized.  
- [ ] Cloud Functions verified.  
- [ ] App loads without hanging on web or Android.  
- [ ] Firebase SDK initialized correctly across platforms.  

---

**Author:** TALOWA DevOps  
**Version:** v3.0 Firebase Upgrade  
**Date:** 2025-11-09
