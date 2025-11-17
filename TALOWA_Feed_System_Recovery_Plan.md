
# 🧩 TALOWA Feed System Recovery & Optimization Plan

## 📌 Overview
This action plan restores full functionality of the **Feed tab** in the TALOWA app (posts, images, text, likes, comments, stories, and shares).  
Environment: **Flutter 3.35.2 (Dart 3.9.0) + Firebase (Firestore, Storage, Cloud Functions)**.

---

## ⚙️ Root Cause Summary

| Problem Area | Root Cause | Impact |
|---------------|-------------|--------|
| **Post Creation** | `_createPost()` method only simulates upload and doesn’t write to Firestore | ❌ No data stored |
| **Media Upload** | Missing `MediaUploadService` | ❌ Images not uploaded |
| **Data Models** | Conflicting models (`PostModel` vs `InstagramPostModel`) | ❌ Data render failure |
| **Stories** | Missing stories UI/service | ❌ Non-functional |
| **Likes/Comments/Shares** | Mismatched collections (`posts` vs `feed_posts`) | ❌ Write failures |
| **Feed Query** | Points to empty collections | ❌ Feed blank |

---

## 🧩 Fix Steps

### 1. Implement `media_upload_service.dart`
```dart
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class MediaUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<String?> uploadFeedImage(File file, String userId) async {
    try {
      final ref = _storage.ref().child('feed_posts').child('$userId_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }
}
```

---

### 2. Fix `_createPost()`
```dart
Future<void> _createPost() async {
  if (_selectedImage == null && _captionController.text.isEmpty) return;

  final userId = FirebaseAuth.instance.currentUser!.uid;
  final imageUrl = _selectedImage != null 
      ? await MediaUploadService.uploadFeedImage(_selectedImage!, userId) 
      : null;

  final postData = {
    'userId': userId,
    'caption': _captionController.text.trim(),
    'mediaUrl': imageUrl ?? '',
    'mediaType': imageUrl != null ? 'image' : 'text',
    'createdAt': FieldValue.serverTimestamp(),
    'likes': 0,
    'comments': 0,
    'shares': 0,
  };

  await FirebaseFirestore.instance.collection('feed_posts').add(postData);
  _captionController.clear();
  setState(() => _selectedImage = null);
}
```

---

### 3. Unify Data Models
Use **only `PostModel`** (remove `InstagramPostModel`).

---

### 4. Fix Feed Query
```dart
Stream<QuerySnapshot> getFeedPosts() {
  return FirebaseFirestore.instance
      .collection('feed_posts')
      .orderBy('createdAt', descending: true)
      .snapshots();
}
```

---

### 5. Firebase Rules
#### Storage
```js
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /feed_posts/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```
#### Firestore
```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /feed_posts/{postId} {
      allow read: if true;
      allow write, update, delete: if request.auth != null && request.auth.uid == request.resource.data.userId;
    }
  }
}
```

---

## 🔍 Validation Commands
```bash
flutter clean
flutter pub get
flutter run -d chrome

firebase deploy --only firestore:rules,firestore:indexes,storage
firebase storage:list --prefix feed_posts/
```

---

## 🕒 Time Estimate
| Step | Task | Time (hrs) |
|------|------|------------|
| Media Upload Service | 2 |
| Post Creation Rewrite | 2 |
| Model Fix | 1 |
| Feed Query + Rules | 1 |
| Stories + Comments Integration | 4–6 |
| **Total** | **6–8 hrs** |

---

**Prepared for:** TALOWA Feed Tab Recovery  
**Author:** GPT-5 (Flutter + Firebase Specialist)  
**Date:** November 2025  
**File:** `TALOWA_Feed_System_Recovery_Plan.md`
