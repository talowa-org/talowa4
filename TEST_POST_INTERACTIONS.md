# Post Interactions Testing Guide

## Quick Test Checklist

### Prerequisites
- ✅ Firestore rules deployed
- ✅ Web app built and deployed
- ✅ User authenticated in the app

### Test URL
https://talowa.web.app

## Test Scenarios

### 1. Like Functionality Test

**Steps**:
1. Navigate to the feed
2. Find a post
3. Click the heart/like button
4. Verify:
   - ✅ Heart icon fills with color
   - ✅ Like count increases by 1
   - ✅ Animation plays
   - ✅ No console errors

5. Click the heart button again (unlike)
6. Verify:
   - ✅ Heart icon becomes outline
   - ✅ Like count decreases by 1
   - ✅ No console errors

**Expected Result**: Like/unlike works smoothly without permission errors

### 2. Comments Functionality Test

**Steps**:
1. Navigate to the feed
2. Find a post
3. Click the comment button
4. Verify:
   - ✅ Comments bottom sheet opens
   - ✅ Existing comments load (if any)
   - ✅ Empty state shows if no comments

5. Type a comment in the input field
6. Click send button
7. Verify:
   - ✅ Comment appears in the list
   - ✅ Comment count increases
   - ✅ Success message shows
   - ✅ Input field clears

8. Click delete on your own comment
9. Verify:
   - ✅ Confirmation dialog appears
   - ✅ Comment is removed
   - ✅ Comment count decreases

**Expected Result**: Full comment CRUD operations work correctly

### 3. Share Functionality Test

**Steps**:
1. Navigate to the feed
2. Find a post
3. Click the share button
4. Verify:
   - ✅ Share options dialog opens
   - ✅ Multiple share options visible

5. Click "Copy Link"
6. Verify:
   - ✅ Success message shows
   - ✅ Link is in clipboard
   - ✅ Share count increases

7. Click share button again
8. Click "Share via Email"
9. Verify:
   - ✅ Email content copied
   - ✅ Success message shows
   - ✅ Share count increases

10. Click share button again
11. Click "Share to Feed"
12. Verify:
    - ✅ Success message shows
    - ✅ Share count increases

**Expected Result**: All share options work and track shares correctly

### 4. Error Handling Test

**Steps**:
1. Open browser console (F12)
2. Perform like, comment, and share actions
3. Verify:
   - ✅ No permission denied errors
   - ✅ No uncaught exceptions
   - ✅ Proper error messages if network fails

**Expected Result**: No console errors, graceful error handling

### 5. Authentication Test

**Steps**:
1. Log out of the app
2. Try to like a post
3. Verify:
   - ✅ "Please log in" message shows
   - ✅ Action is prevented

4. Try to comment
5. Verify:
   - ✅ "Please log in" message shows
   - ✅ Action is prevented

6. Try to share
7. Verify:
   - ✅ "Please log in" message shows
   - ✅ Action is prevented

**Expected Result**: Unauthenticated users cannot interact with posts

## Console Checks

### Before Fix
You would see:
```
❌ [cloud_firestore/permission-denied] Missing or insufficient permissions
```

### After Fix
You should see:
```
✅ No permission errors
✅ Successful operations logged
```

## Performance Checks

### Like Performance
- Should complete in < 500ms
- No UI lag
- Smooth animation

### Comment Performance
- Comments load in < 1s
- Smooth scrolling
- No lag when typing

### Share Performance
- Share dialog opens instantly
- Share operations complete in < 500ms

## Known Issues to Ignore

1. **Warnings about unused functions in Firestore rules** - These are safe to ignore
2. **Wasm dry run messages** - These are informational only

## Troubleshooting

### If Like Still Fails
1. Check browser console for specific error
2. Verify user is authenticated
3. Check Firestore rules are deployed:
   ```bash
   firebase deploy --only firestore:rules
   ```

### If Comments Don't Load
1. Check network tab for failed requests
2. Verify `post_comments` collection exists
3. Check Firestore rules for comments collection

### If Share Doesn't Work
1. Check clipboard permissions in browser
2. Verify `post_shares` collection exists
3. Check console for errors

## Success Criteria

✅ All like operations work without errors
✅ Comments can be created, viewed, and deleted
✅ Share functionality works with all options
✅ No permission denied errors in console
✅ Proper user feedback for all actions
✅ Authentication checks work correctly

## Reporting Issues

If you encounter any issues:

1. **Check Console**: Open browser console (F12) and look for errors
2. **Check Network**: Look at network tab for failed requests
3. **Check Authentication**: Verify user is logged in
4. **Document Steps**: Note exact steps to reproduce
5. **Screenshot**: Capture any error messages

## Next Steps After Testing

Once all tests pass:
1. ✅ Mark features as production-ready
2. ✅ Update user documentation
3. ✅ Monitor analytics for usage
4. ✅ Gather user feedback
5. ✅ Plan future enhancements

---

**Testing Status**: Ready for Testing
**Last Updated**: November 17, 2025
**Tester**: [Your Name]
**Test Environment**: https://talowa.web.app
