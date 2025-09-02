# 🔧 TROUBLESHOOTING GUIDE - Complete Reference

## 📋 Overview

This comprehensive troubleshooting guide consolidates solutions for all common issues, errors, and problems encountered in the TALOWA app. It covers authentication issues, deployment problems, performance issues, and system-specific troubleshooting across all features.

---

## 🚨 Emergency Quick Fixes

### App Won't Start
```bash
# Quick fix sequence
flutter clean
flutter pub get
flutter run

# If still failing
rm -rf .dart_tool/
flutter doctor
flutter upgrade
```

### Authentication Completely Broken
```bash
# Reset authentication
firebase auth:clear --project talowa-production
node fix_user_roles.js
flutter run --debug
```

### Deployment Failed
```bash
# Emergency rollback
firebase hosting:channel:deploy previous --project talowa-production

# Quick redeploy
flutter clean && flutter build web --release && firebase deploy
```

---

## 🔐 Authentication Issues

### OTP Not Received
**Symptoms**: Users not receiving SMS verification codes
**Causes**: 
- Phone number format issues
- Firebase SMS quota exceeded
- Network connectivity problems
- Carrier blocking

**Solutions**:
```bash
# Check Firebase SMS quota
firebase functions:log --project talowa-production | grep "SMS"

# Test with different phone number
# Verify phone number format: +91XXXXXXXXXX

# Check Firebase Auth configuration
firebase auth:test --project talowa-production
```

**Code Fix**:
```dart
// Ensure proper phone number formatting
String formatPhoneNumber(String phone) {
  if (!phone.startsWith('+91')) {
    phone = '+91' + phone.replaceAll(RegExp(r'[^\d]'), '');
  }
  return phone;
}
```

### Registration Fails
**Symptoms**: User registration process doesn't complete
**Causes**:
- Missing required fields
- Firestore permission issues
- Network timeouts
- Validation errors

**Solutions**:
```dart
// Debug registration process
try {
  await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
  
  // Check if user document creation succeeds
  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    // user data
  });
} catch (e) {
  print('Registration error: $e');
  // Handle specific error types
}
```

### Users Logged Out Unexpectedly
**Symptoms**: Users randomly logged out of app
**Causes**:
- Token expiration
- Session management issues
- Firebase configuration problems

**Solutions**:
```dart
// Implement proper session persistence
FirebaseAuth.instance.authStateChanges().listen((User? user) {
  if (user == null) {
    // User logged out - redirect to login
    Navigator.pushReplacementNamed(context, '/welcome');
  } else {
    // User logged in - ensure proper navigation
    Navigator.pushReplacementNamed(context, '/main');
  }
});
```

### Role Assignment Problems
**Symptoms**: Users don't have proper roles or permissions
**Solutions**:
```bash
# Run role fix service
node fix_user_roles.js

# Manual role assignment in Firebase Console
# Or use the data population button in the app
```

---

## 🚀 Deployment Issues

### Flutter Build Fails
**Symptoms**: `flutter build web` command fails
**Common Errors & Solutions**:

**Error**: "Target of URI doesn't exist"
```bash
flutter clean
flutter pub get
flutter pub deps
# Check for missing dependencies
```

**Error**: "Web renderer not found"
```bash
flutter build web --release --web-renderer html
# Force HTML renderer
```

**Error**: "Out of memory"
```bash
# Increase memory for build
export NODE_OPTIONS="--max-old-space-size=4096"
flutter build web --release
```

### Firebase Deployment Fails
**Symptoms**: `firebase deploy` command fails

**Error**: "Authentication Error"
```bash
firebase logout
firebase login
firebase use talowa-production
```

**Error**: "Hosting: Deploy Error"
```bash
# Check firebase.json configuration
# Ensure build/web directory exists
ls -la build/web/
firebase deploy --debug
```

**Error**: "Functions Deploy Failed"
```bash
cd functions
npm install
npm audit fix
cd ..
firebase deploy --only functions
```

### PWA Not Working
**Symptoms**: App doesn't install as PWA or work offline
**Solutions**:
```javascript
// Check manifest.json
{
  "name": "TALOWA",
  "short_name": "TALOWA",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#4CAF50",
  "theme_color": "#4CAF50"
}

// Verify service worker registration
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/sw.js');
}
```

---

## 🔗 Referral System Issues

### Referral Codes Not Working
**Symptoms**: Referral codes not generating or not being recognized
**Solutions**:
```bash
# Check referral system consistency
node check_referral_consistency.js

# Fix referral data issues
node fix_referral_data.js

# Test referral system
node test_referral_system.js
```

### Duplicate Referral Codes
**Symptoms**: Multiple users have the same referral code
**Solutions**:
```javascript
// Run duplicate code fix
const fixDuplicateCodes = async () => {
  const users = await db.collection('users').get();
  const codes = new Map();
  
  for (const doc of users.docs) {
    const code = doc.data().referralCode;
    if (codes.has(code)) {
      // Generate new code for duplicate
      const newCode = generateUniqueCode();
      await doc.ref.update({ referralCode: newCode });
    } else {
      codes.set(code, doc.id);
    }
  }
};
```

### Referral Tracking Not Working
**Symptoms**: Successful referrals not being recorded
**Solutions**:
```bash
# Check Cloud Functions logs
firebase functions:log --project talowa-production

# Verify Firestore rules allow referral writes
firebase firestore:rules:get

# Test referral processing manually
node test_referral_processing.js
```

---

## 🏠 Home Tab Issues

### Home Screen Not Loading
**Symptoms**: Home screen shows loading spinner indefinitely
**Solutions**:
```dart
// Check data loading in home screen
Future<void> _loadHomeData() async {
  try {
    // Load user data
    final userData = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .get();
    
    if (userData.exists) {
      setState(() {
        this.userData = userData.data();
        isLoading = false;
      });
    }
  } catch (e) {
    print('Home data loading error: $e');
    setState(() {
      isLoading = false;
    });
  }
}
```

### AI Assistant Not Responding
**Symptoms**: AI assistant widget not working or responding
**Solutions**:
```dart
// Check AI assistant configuration
class AIAssistantConfig {
  static const String apiKey = 'your-openai-api-key';
  static const String baseUrl = 'https://api.openai.com/v1';
  
  static bool get isConfigured => apiKey.isNotEmpty;
}

// Test AI assistant connectivity
Future<void> testAIConnection() async {
  try {
    final response = await http.post(
      Uri.parse('${AIAssistantConfig.baseUrl}/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${AIAssistantConfig.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [{'role': 'user', 'content': 'test'}],
      }),
    );
    
    if (response.statusCode == 200) {
      print('AI Assistant connected successfully');
    } else {
      print('AI Assistant connection failed: ${response.statusCode}');
    }
  } catch (e) {
    print('AI Assistant error: $e');
  }
}
```

### Service Cards Not Navigating
**Symptoms**: Tapping service cards doesn't navigate to sub-screens
**Solutions**:
```dart
// Check navigation implementation
void _navigateToService(String service) {
  switch (service) {
    case 'land':
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => LandScreen(),
      ));
      break;
    case 'payments':
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => PaymentsScreen(),
      ));
      break;
    // Add other cases
  }
}
```

---

## 🧭 Navigation Issues

### Bottom Navigation Not Working
**Symptoms**: Tab switching not working or tabs not displaying
**Solutions**:
```dart
// Check bottom navigation implementation
class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    HomeScreen(),
    FeedScreen(),
    NetworkScreen(),
    MessagesScreen(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          // Navigation items
        ],
      ),
    );
  }
}
```

### Back Button Not Working
**Symptoms**: Back button doesn't behave as expected
**Solutions**:
```dart
// Implement WillPopScope for custom back behavior
WillPopScope(
  onWillPop: () async {
    SmartBackNavigationService.handleBackPress(context);
    return false; // Prevent default back behavior
  },
  child: Scaffold(
    // Screen content
  ),
)
```

### Deep Links Not Working
**Symptoms**: Shared links don't open correct screens
**Solutions**:
```dart
// Check deep link configuration
void _handleDeepLink(String link) {
  final uri = Uri.parse(link);
  
  // Log for debugging
  print('Handling deep link: $link');
  print('Path: ${uri.path}');
  print('Query parameters: ${uri.queryParameters}');
  
  // Handle different link types
  switch (uri.path) {
    case '/main':
      final tab = int.tryParse(uri.queryParameters['tab'] ?? '0') ?? 0;
      Navigator.pushReplacementNamed(context, '/main');
      // Set tab after navigation
      break;
    // Handle other paths
  }
}
```

---

## 💾 Data & Performance Issues

### App Running Slowly
**Symptoms**: App lag, slow loading, poor performance
**Solutions**:
```bash
# Profile app performance
flutter run --profile

# Check for memory leaks
flutter run --debug
# Use Flutter Inspector to check widget tree

# Optimize images
# Compress images before uploading
# Use appropriate image formats (WebP for web)
```

**Code Optimizations**:
```dart
// Implement lazy loading
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ListTile(
      title: Text(items[index].title),
    );
  },
)

// Use const constructors where possible
const Text('Static text')

// Implement proper caching
class CacheService {
  static final Map<String, dynamic> _cache = {};
  static const Duration cacheValidity = Duration(hours: 1);
  
  static Future<T?> getCached<T>(String key) async {
    final cached = _cache[key];
    if (cached != null && 
        DateTime.now().difference(cached['timestamp']) < cacheValidity) {
      return cached['data'] as T;
    }
    return null;
  }
}
```

### Database Connection Issues
**Symptoms**: Firestore operations failing or timing out
**Solutions**:
```dart
// Implement retry logic
Future<T> retryOperation<T>(Future<T> Function() operation, {int maxRetries = 3}) async {
  for (int i = 0; i < maxRetries; i++) {
    try {
      return await operation();
    } catch (e) {
      if (i == maxRetries - 1) rethrow;
      await Future.delayed(Duration(seconds: math.pow(2, i).toInt()));
    }
  }
  throw Exception('Max retries exceeded');
}

// Use with Firestore operations
final userData = await retryOperation(() => 
  FirebaseFirestore.instance.collection('users').doc(uid).get()
);
```

### Memory Issues
**Symptoms**: App crashes with out of memory errors
**Solutions**:
```dart
// Dispose controllers properly
@override
void dispose() {
  _textController.dispose();
  _animationController.dispose();
  _streamSubscription?.cancel();
  super.dispose();
}

// Use weak references for large objects
WeakReference<LargeObject> _largeObjectRef = WeakReference(largeObject);

// Implement image caching
CachedNetworkImage(
  imageUrl: imageUrl,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
  memCacheWidth: 300, // Limit memory usage
  memCacheHeight: 300,
)
```

---

## 🔧 Development Environment Issues

### Flutter Doctor Issues
**Common Issues & Solutions**:

**Android SDK not found**:
```bash
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools
```

**iOS development setup (macOS)**:
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

**Flutter version conflicts**:
```bash
flutter channel stable
flutter upgrade
flutter doctor -v
```

### IDE Issues
**VS Code Flutter extension not working**:
1. Restart VS Code
2. Reload Flutter extension
3. Check Flutter and Dart SDK paths
4. Run "Flutter: Reload" command

**Android Studio issues**:
1. Invalidate caches and restart
2. Check Flutter plugin installation
3. Verify SDK paths in settings
4. Update Android Studio and plugins

---

## 📱 Platform-Specific Issues

### Web-Specific Issues
**CORS errors**:
```javascript
// Add to web/index.html
<meta name="referrer" content="no-referrer">

// Configure Firebase hosting headers
"headers": [
  {
    "source": "**",
    "headers": [
      {
        "key": "Access-Control-Allow-Origin",
        "value": "*"
      }
    ]
  }
]
```

**Service Worker issues**:
```javascript
// Clear service worker cache
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(function(registrations) {
    for(let registration of registrations) {
      registration.unregister();
    }
  });
}
```

### Mobile-Specific Issues
**Permissions not working**:
```dart
// Check and request permissions
Future<bool> checkPermissions() async {
  final status = await Permission.camera.status;
  if (status.isDenied) {
    final result = await Permission.camera.request();
    return result.isGranted;
  }
  return status.isGranted;
}
```

---

## 🔍 Debugging Tools & Commands

### Flutter Debugging
```bash
# Debug mode with verbose logging
flutter run --debug --verbose

# Profile mode for performance testing
flutter run --profile

# Release mode testing
flutter run --release

# Analyze code for issues
flutter analyze

# Run tests
flutter test

# Check dependencies
flutter pub deps
```

### Firebase Debugging
```bash
# Check Firebase project status
firebase projects:list

# View Firestore rules
firebase firestore:rules:get

# Check function logs
firebase functions:log --project talowa-production

# Test functions locally
firebase emulators:start

# Deploy with debug info
firebase deploy --debug
```

### Network Debugging
```bash
# Test API endpoints
curl -X GET "https://api.example.com/test"

# Check DNS resolution
nslookup talowa-app.web.app

# Test Firebase connectivity
firebase auth:test --project talowa-production
```

---

## 📊 Monitoring & Logging

### Error Tracking Setup
```dart
// Initialize Crashlytics
await Firebase.initializeApp();
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

// Log custom errors
FirebaseCrashlytics.instance.recordError(
  error,
  stackTrace,
  reason: 'Custom error description',
);

// Set user context
FirebaseCrashlytics.instance.setUserIdentifier(userId);
```

### Performance Monitoring
```dart
// Track custom traces
final trace = FirebasePerformance.instance.newTrace('custom_trace');
await trace.start();

// Your code here

await trace.stop();

// Monitor HTTP requests
final httpMetric = FirebasePerformance.instance
    .newHttpMetric('https://api.example.com', HttpMethod.Get);

await httpMetric.start();
final response = await http.get(url);
httpMetric.responseCode = response.statusCode;
await httpMetric.stop();
```

---

## 🆘 Emergency Procedures

### Complete System Reset
```bash
# 1. Backup current state
firebase firestore:export gs://backup-bucket/backup-$(date +%Y%m%d)

# 2. Reset authentication
firebase auth:clear --project talowa-production

# 3. Reset app state
flutter clean
rm -rf .dart_tool/
flutter pub get

# 4. Redeploy from scratch
flutter build web --release
firebase deploy --project talowa-production

# 5. Restore data if needed
firebase firestore:import gs://backup-bucket/backup-YYYYMMDD
```

### Data Recovery
```bash
# List available backups
gsutil ls gs://backup-bucket/

# Restore from backup
firebase firestore:import gs://backup-bucket/backup-YYYYMMDD

# Verify data integrity
node validate_data_integrity.js
```

---

## 📞 Getting Help

### Internal Resources
1. **Check Documentation** - Review relevant system documentation
2. **Search Logs** - Check Firebase Console and app logs
3. **Test Environment** - Reproduce issue in development
4. **Code Review** - Review recent changes that might cause issues

### External Resources
1. **Flutter Documentation** - https://flutter.dev/docs
2. **Firebase Documentation** - https://firebase.google.com/docs
3. **Stack Overflow** - Search for similar issues
4. **GitHub Issues** - Check Flutter and Firebase repositories

### Emergency Contacts
- **Firebase Support** - Firebase Console → Support
- **Flutter Issues** - GitHub Flutter repository
- **Critical Issues** - Escalate to senior developers

---

## 📚 Related Documentation

- **[Authentication System](AUTHENTICATION_SYSTEM.md)** - Authentication troubleshooting
- **[Deployment Guide](DEPLOYMENT_GUIDE.md)** - Deployment procedures
- **[Firebase Configuration](FIREBASE_CONFIGURATION.md)** - Firebase setup
- **[Testing Guide](TESTING_GUIDE.md)** - Testing procedures

---

**Status**: ✅ Comprehensive Guide  
**Last Updated**: January 2025  
**Priority**: Critical (Support System)  
**Maintainer**: DevOps & Support Team