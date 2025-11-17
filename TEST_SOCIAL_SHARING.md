# Test Social Media Sharing - Quick Guide

## 🎯 Test URL
**https://talowa.web.app**

## ✅ What to Test

### New Feature: Share to Social Media
Users can now share posts to WhatsApp, Instagram, Facebook, Twitter, and more!

## 🧪 Quick Test Steps

### Test 1: Open Share Dialog
1. Go to feed
2. Click **share button** (send icon) on any post
3. **Expected**: Share dialog opens
4. **Look for**: "Share to Social Media" option with purple icon 📱

### Test 2: Share to Social Media (Mobile)
1. Click "Share to Social Media"
2. **Expected**: Native share sheet opens
3. **Should see**: WhatsApp, Instagram, Facebook, etc.
4. Select an app (e.g., WhatsApp)
5. **Expected**: Post content and link appear
6. Send to a contact/group
7. **Expected**: Message sent successfully

### Test 3: Share to Social Media (Web)
1. Click "Share to Social Media"
2. **Expected**: Web share dialog OR clipboard copy
3. If Web Share API supported: Select sharing option
4. If not supported: Content copied to clipboard
5. Paste in social media app
6. **Expected**: Content and link present

### Test 4: Verify Share Content
When sharing, check that the message includes:
- ✅ Author name (e.g., "John Doe shared:")
- ✅ Post content
- ✅ Link to post (https://talowa.web.app/post/...)

**Example**:
```
John Doe shared: Check out this amazing sunset! 🌅

View on TALOWA: https://talowa.web.app/post/abc123
```

## 📱 Platform-Specific Tests

### On Mobile (iOS/Android)
- [ ] Share sheet opens
- [ ] WhatsApp appears in options
- [ ] Instagram appears in options
- [ ] Facebook appears in options
- [ ] Can share to selected app
- [ ] Content includes link

### On Web Browser
- [ ] Share dialog appears
- [ ] Web Share API works (if supported)
- [ ] Fallback to clipboard works
- [ ] Content can be pasted

### On Desktop
- [ ] System share dialog opens
- [ ] Available apps shown
- [ ] Can share successfully

## 🎨 What You Should See

### Updated Share Dialog
```
┌─────────────────────────────────────┐
│         Share Post                  │
├─────────────────────────────────────┤
│  📱 Share to Social Media      ← NEW│
│     WhatsApp, Instagram, Facebook   │
│                                     │
│  🔗 Copy Link                       │
│  📧 Share via Email                 │
│  📤 Share to Feed                   │
└─────────────────────────────────────┘
```

### Native Share Sheet (Mobile)
```
┌─────────────────────────────────────┐
│  Share via                          │
├─────────────────────────────────────┤
│  [WhatsApp] [Instagram] [Facebook]  │
│  [Twitter]  [Telegram]  [Snapchat]  │
│  [Email]    [Messages]  [More...]   │
└─────────────────────────────────────┘
```

## ✨ Supported Platforms

### Mobile Apps You Can Share To
- ✅ WhatsApp
- ✅ Instagram
- ✅ Facebook
- ✅ Twitter
- ✅ Telegram
- ✅ Snapchat
- ✅ LinkedIn
- ✅ Pinterest
- ✅ Reddit
- ✅ TikTok
- ✅ Email
- ✅ SMS
- ✅ Any app with share support

## 📊 Success Criteria

- [ ] "Share to Social Media" option visible
- [ ] Purple icon (📱) displayed
- [ ] Subtitle shows platform names
- [ ] Clicking opens native share sheet
- [ ] Can select WhatsApp/Instagram/etc.
- [ ] Post content and link are shared
- [ ] Success message appears
- [ ] Share is tracked in database

## 🐛 Troubleshooting

### Issue: Share sheet doesn't open
**Try**:
1. Check if you're logged in
2. Hard refresh (Ctrl+Shift+R)
3. Check browser console for errors
4. Try different browser

### Issue: Some apps don't appear
**Reason**: Those apps aren't installed on your device
**Solution**: Install the app you want to share to

### Issue: Web share doesn't work
**Reason**: Browser may not support Web Share API
**Solution**: Content will be copied to clipboard instead

### Issue: Content doesn't include link
**Reason**: Possible formatting issue
**Solution**: Check console for errors, report issue

## 🎯 Expected Behavior

### When You Click "Share to Social Media"
1. **Mobile**: Native share sheet opens with all installed apps
2. **Web**: Web share dialog or clipboard copy
3. **Desktop**: System share dialog opens

### What Gets Shared
```
[Author Name] shared: [Post Content]

View on TALOWA: https://talowa.web.app/post/[postId]
```

### After Sharing
- ✅ Success message appears
- ✅ Share count may increase
- ✅ Share is tracked in database
- ✅ Can share to multiple platforms

## 📸 Screenshots to Take

1. Share dialog with new option
2. Native share sheet on mobile
3. WhatsApp with shared content
4. Instagram with shared content
5. Success message after sharing

## ⚡ Quick Checklist

- [ ] Open share dialog ✅
- [ ] See "Share to Social Media" option ✅
- [ ] Click the option ✅
- [ ] Native share sheet opens ✅
- [ ] Select WhatsApp ✅
- [ ] Content and link appear ✅
- [ ] Send message ✅
- [ ] Success! ✅

## 🎉 Success!

If all tests pass, you can now:
- ✅ Share posts to WhatsApp
- ✅ Share posts to Instagram
- ✅ Share posts to Facebook
- ✅ Share posts to any social media
- ✅ Increase viral reach
- ✅ Engage more users

**Congratulations!** 🎊

---

**Test URL**: https://talowa.web.app
**Feature**: Social Media Sharing
**Status**: Ready to Test ✅
**Date**: November 17, 2025
