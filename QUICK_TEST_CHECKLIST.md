# ✅ Quick Test Checklist - Feed System

**App**: https://talowa.web.app  
**Date**: _______________

---

## 🚀 Quick Test (5 minutes)

### 1. Open App
- [ ] Go to https://talowa.web.app
- [ ] App loads successfully
- [ ] Press F12 to open DevTools

### 2. Navigate to Feed
- [ ] Click "Feed" tab
- [ ] Feed screen appears

### 3. Create Post with Image
- [ ] Click "+" button
- [ ] Type caption: "Test post"
- [ ] Click "Add Media"
- [ ] Select an image
- [ ] Image appears in preview
- [ ] Click "Share"
- [ ] Success message appears

### 4. Verify Post
- [ ] Post appears in feed
- [ ] Image loads correctly (not broken)
- [ ] Caption displays
- [ ] Author name visible

### 5. Check Console
- [ ] Open Console tab (F12)
- [ ] **NO red CORS errors**
- [ ] **NO "blocked by CORS policy"**
- [ ] Image requests show 200 status

---

## ✅ Success Criteria

**PASS** if:
- ✅ All 5 sections complete
- ✅ Image loads correctly
- ✅ NO CORS errors

**FAIL** if:
- ❌ Image shows broken icon
- ❌ CORS errors in console
- ❌ Post doesn't appear

---

## 🎯 Result

**Status**: [ ] PASS [ ] FAIL

**Notes**:
```
_________________________________
_________________________________
_________________________________
```

---

## 📞 If Failed

1. Check `TESTING_GUIDE.md` for detailed troubleshooting
2. Verify CORS: `gcloud storage buckets describe gs://talowa.firebasestorage.app`
3. Check Firebase Console for data
4. Review browser console errors

---

**Tester**: _______________  
**Date**: _______________  
**Time**: _______________
