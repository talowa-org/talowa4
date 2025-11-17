# 🧪 TALOWA Feed System - Testing Guide

**App URL**: https://talowa.web.app  
**Date**: November 16, 2025  
**Status**: Ready for Testing

---

## 🎯 Testing Objectives

Verify that all Feed system features work correctly:
- ✅ Post creation with images
- ✅ Post creation with text
- ✅ Feed display
- ✅ Image loading (no CORS errors)
- ✅ Likes functionality
- ✅ Comments functionality
- ✅ Shares functionality

---

## 📋 Pre-Testing Checklist

Before you start testing:

- [ ] Open https://talowa.web.app in a modern browser (Chrome, Firefox, Edge)
- [ ] Open Browser DevTools (Press F12)
- [ ] Go to Console tab (to monitor for errors)
- [ ] Clear browser cache (Ctrl+Shift+Delete) for fresh start
- [ ] Ensure you're logged in to the app

---

## 🧪 Test Suite

### Test 1: App Access ✅

**Objective**: Verify app loads correctly

**Steps**:
1. Open https://talowa.web.app
2. Wait for app to load

**Expected Results**:
- ✅ App loads without errors
- ✅ Welcome screen or main screen appears
- ✅ No errors in browser console

**Status**: [ ] Pass [ ] Fail

**Notes**:
```
_________________________________________________
_________________________________________________
```

---

### Test 2: Login/Authentication ✅

**Objective**: Verify you can access the app

**Steps**:
1. If not logged in, complete login process
2. Navigate to main app screen

**Expected Results**:
- ✅ Login successful
- ✅ Main navigation visible
- ✅ Can see tabs (Home, Feed, Messages, Network, More)

**Status**: [ ] Pass [ ] Fail

**Notes**:
```
_________________________________________________
_________________________________________________
```

---

### Test 3: Navigate to Feed Tab ✅

**Objective**: Verify Feed tab is accessible

**Steps**:
1. Click on "Feed" tab in bottom navigation
2. Wait for Feed screen to load

**Expected Results**:
- ✅ Feed screen loads
- ✅ Can see "TALOWA" header
- ✅ Can see "+" button (Create Post)
- ✅ Feed area visible (may be empty if no posts)

**Status**: [ ] Pass [ ] Fail

**Notes**:
```
_________________________________________________
_________________________________________________
```

---

### Test 4: Create Text-Only Post ✅

**Objective**: Verify text post creation works

**Steps**:
1. Click "+" button (Create Post)
2. Enter caption: "Testing text post - [Your Name]"
3. Do NOT add any media
4. Click "Share" button

**Expected Results**:
- ✅ Post creation screen opens
- ✅ Can type in caption field
- ✅ "Share" button becomes active
- ✅ Success message appears: "Post created successfully!"
- ✅ Returns to Feed screen
- ✅ Post appears in feed (may need to refresh)

**Status**: [ ] Pass [ ] Fail

**Notes**:
```
_________________________________________________
_________________________________________________
```

---

### Test 5: Create Post with Single Image ✅ (CRITICAL)

**Objective**: Verify image upload and display works

**Steps**:
1. Click "+" button (Create Post)
2. Enter caption: "Testing image upload - [Your Name]"
3. Click "Add Media" button
4. Select "Choose from Gallery"
5. Select a small image (< 5MB, JPG or PNG)
6. Wait for image to appear in preview
7. Click "Share" button
8. Wait for upload to complete

**Expected Results**:
- ✅ Image picker opens
- ✅ Can select image
- ✅ Image appears in preview
- ✅ Upload progress shown (if visible)
- ✅ Success message: "Post created successfully!"
- ✅ Returns to Feed screen
- ✅ Post appears in feed with image
- ✅ Image loads correctly (not broken icon)
- ✅ **NO CORS errors in console** (Check F12 Console tab)

**Status**: [ ] Pass [ ] Fail

**Console Errors** (if any):
```
_________________________________________________
_________________________________________________
```

**Screenshot**: (Take screenshot if image loads correctly)

---

### Test 6: Create Post with Multiple Images ✅

**Objective**: Verify multiple image upload works

**Steps**:
1. Click "+" button
2. Enter caption: "Testing multiple images"
3. Click "Add Media" and select first image
4. Click "Add Media" again and select second image
5. Click "Add Media" again and select third image
6. Click "Share"

**Expected Results**:
- ✅ Can add multiple images
- ✅ All images appear in preview
- ✅ Upload completes successfully
- ✅ Post appears with all images
- ✅ All images load correctly

**Status**: [ ] Pass [ ] Fail

**Notes**:
```
_________________________________________________
_________________________________________________
```

---

### Test 7: Feed Display ✅

**Objective**: Verify feed displays posts correctly

**Steps**:
1. View the Feed screen
2. Scroll through posts
3. Pull down to refresh

**Expected Results**:
- ✅ Posts display in chronological order (newest first)
- ✅ Images load correctly
- ✅ Captions display correctly
- ✅ Author names visible
- ✅ Timestamps visible
- ✅ Like/comment/share buttons visible
- ✅ Can scroll smoothly
- ✅ Pull-to-refresh works

**Status**: [ ] Pass [ ] Fail

**Notes**:
```
_________________________________________________
_________________________________________________
```

---

### Test 8: Like Functionality ✅

**Objective**: Verify likes work

**Steps**:
1. Find a post in feed
2. Click the heart/like icon
3. Observe like count
4. Click heart icon again to unlike

**Expected Results**:
- ✅ Like icon changes color when clicked
- ✅ Like count increases by 1
- ✅ Unlike works (count decreases)
- ✅ Changes persist after refresh

**Status**: [ ] Pass [ ] Fail

**Notes**:
```
_________________________________________________
_________________________________________________
```

---

### Test 9: Comment Functionality ✅

**Objective**: Verify comments work

**Steps**:
1. Find a post in feed
2. Click comment icon
3. Enter comment: "Test comment"
4. Submit comment
5. View comments

**Expected Results**:
- ✅ Comment screen opens
- ✅ Can type comment
- ✅ Comment submits successfully
- ✅ Comment appears in list
- ✅ Comment count increases

**Status**: [ ] Pass [ ] Fail

**Notes**:
```
_________________________________________________
_________________________________________________
```

---

### Test 10: Share Functionality ✅

**Objective**: Verify shares work

**Steps**:
1. Find a post in feed
2. Click share icon
3. Observe share count

**Expected Results**:
- ✅ Share action triggers
- ✅ Share count increases
- ✅ Share options appear (if implemented)

**Status**: [ ] Pass [ ] Fail

**Notes**:
```
_________________________________________________
_________________________________________________
```

---

### Test 11: CORS Verification ✅ (CRITICAL)

**Objective**: Verify no CORS errors

**Steps**:
1. Open Browser DevTools (F12)
2. Go to Console tab
3. Create a post with image
4. Watch for errors while image loads
5. Check Network tab for failed requests

**Expected Results**:
- ✅ **NO errors containing "CORS"**
- ✅ **NO errors containing "Access-Control-Allow-Origin"**
- ✅ **NO errors containing "blocked by CORS policy"**
- ✅ All image requests show status 200 (OK)

**Status**: [ ] Pass [ ] Fail

**Console Output** (if errors):
```
_________________________________________________
_________________________________________________
```

---

### Test 12: Firebase Console Verification ✅

**Objective**: Verify data is saved to Firebase

**Steps**:
1. Open Firebase Console: https://console.firebase.google.com/project/talowa
2. Go to Firestore Database
3. Check `posts` collection
4. Go to Storage
5. Check `feed_posts/` folder

**Expected Results**:
- ✅ Posts appear in Firestore `posts` collection
- ✅ Post documents have correct fields (authorId, content, imageUrls, etc.)
- ✅ Images appear in Storage `feed_posts/` folder
- ✅ Image URLs are accessible

**Status**: [ ] Pass [ ] Fail

**Notes**:
```
_________________________________________________
_________________________________________________
```

---

## 🐛 Troubleshooting

### Issue: Images Not Loading

**Symptoms**: Broken image icons, CORS errors

**Check**:
1. Open Console (F12)
2. Look for CORS errors
3. Check Network tab for failed image requests

**Solution**:
```bash
# Verify CORS is applied
gcloud storage buckets describe gs://talowa.firebasestorage.app --format="value(cors_config)"
```

**If CORS errors persist**:
- Clear browser cache (Ctrl+Shift+Delete)
- Try incognito mode (Ctrl+Shift+N)
- Wait 5-10 minutes for CDN cache
- Hard refresh (Ctrl+Shift+R)

---

### Issue: Post Creation Fails

**Symptoms**: Error message, post doesn't appear

**Check**:
1. Console for error messages
2. Network tab for failed requests
3. Firebase Console for Firestore errors

**Common Causes**:
- Not authenticated
- File too large (> 10MB)
- Network connectivity
- Firestore rules

---

### Issue: Feed is Empty

**Symptoms**: No posts showing

**Check**:
1. Firebase Console → Firestore → `posts` collection
2. Are there any posts?
3. Console for errors

**Solution**:
- Create a test post
- Pull down to refresh
- Check Firestore rules

---

## 📊 Test Results Summary

### Overall Status

- Total Tests: 12
- Passed: ___
- Failed: ___
- Skipped: ___

### Critical Tests Status

| Test | Status | Notes |
|------|--------|-------|
| Create Post with Image | [ ] Pass [ ] Fail | Most important |
| CORS Verification | [ ] Pass [ ] Fail | Critical for images |
| Feed Display | [ ] Pass [ ] Fail | Core functionality |
| Firebase Data | [ ] Pass [ ] Fail | Backend verification |

---

## ✅ Success Criteria

Your Feed system is working correctly if:

1. ✅ Can create post with image
2. ✅ Image uploads to Firebase Storage
3. ✅ Post appears in feed
4. ✅ Image loads correctly (no broken icons)
5. ✅ NO CORS errors in console
6. ✅ Can like/comment/share
7. ✅ Data appears in Firebase Console

**Minimum for Success**: Tests 1-7 and 11 must pass

---

## 📝 Testing Notes

### Environment
- **Browser**: _________________
- **Browser Version**: _________________
- **Operating System**: _________________
- **Date/Time**: _________________

### Test Session Notes
```
_________________________________________________
_________________________________________________
_________________________________________________
_________________________________________________
```

---

## 🎯 Next Steps After Testing

### If All Tests Pass ✅
1. Celebrate! 🎉
2. Start using the Feed system
3. Monitor for any issues
4. Consider optional enhancements (Stories UI, etc.)

### If Tests Fail ❌
1. Document which tests failed
2. Copy error messages from console
3. Check troubleshooting section
4. Review Firebase Console for data
5. Report issues with details

---

## 📞 Support

If you encounter issues during testing:

1. **Check Console**: F12 → Console tab for errors
2. **Check Network**: F12 → Network tab for failed requests
3. **Check Firebase Console**: Verify data is being saved
4. **Review Documentation**: Check `DEPLOYMENT_COMPLETE.md`

---

## 🚀 Ready to Test!

**Start here**:
1. Open https://talowa.web.app
2. Open DevTools (F12)
3. Follow tests in order
4. Mark each test as Pass/Fail
5. Document any issues

**Good luck with testing!** 🧪

---

**Testing Guide Version**: 1.0  
**Created**: November 16, 2025  
**App Version**: Latest deployment  
**Status**: Ready for Testing
