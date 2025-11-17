# ⚡ QUICK DEPLOY GUIDE - Feed System Fixes

## 🚀 3-Step Deployment

### Step 1: Deploy Firebase Rules (2 minutes)
```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

### Step 2: Apply CORS Configuration (1 minute)
```bash
gsutil cors set cors.json gs://talowa.appspot.com
```
*Requires Google Cloud SDK: https://cloud.google.com/sdk/docs/install*

### Step 3: Build & Deploy App (5 minutes)
```bash
flutter clean
flutter pub get
flutter build web --no-tree-shake-icons
firebase deploy --only hosting
```

---

## ✅ Quick Test

1. Open https://talowa.web.app
2. Go to Feed tab
3. Click "+" button
4. Add image and caption
5. Click "Share"
6. **SUCCESS**: Post appears with image!

---

## 🐛 Quick Fix

**Images not loading?**
```bash
gsutil cors set cors.json gs://talowa.appspot.com
```

**Post creation fails?**
```bash
firebase deploy --only firestore:rules
```

---

## 📁 What Was Fixed

- ✅ Post creation (was placeholder, now real)
- ✅ Image upload (was missing, now works)
- ✅ Stories service (was missing, now complete)
- ✅ Firebase rules (enhanced security)

---

## 🎯 Files Changed

**Created**:
- `lib/services/media/media_upload_service.dart`
- `lib/services/stories/stories_service.dart`

**Modified**:
- `lib/screens/post_creation/instagram_post_creation_screen.dart`
- `firestore.rules`
- `storage.rules`

---

## ⏱️ Total Time: ~10 minutes

**Ready? Run this:**
```bash
deploy_feed_fixes.bat
```
