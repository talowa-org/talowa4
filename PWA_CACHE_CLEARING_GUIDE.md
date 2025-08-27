# 🧹 PWA Cache Clearing Guide - TALOWA

## 🎯 **Purpose**: Fix "Unexpected token '<'" Error

The white screen with "Uncaught SyntaxError: Unexpected token '<' at main.dart.js:1" means the browser is getting HTML instead of JavaScript when requesting main.dart.js. This is typically caused by cached service workers or browser cache serving old content.

---

## 🔧 **Complete Cache Clearing Process**

### **Step 1: Open Browser Developer Tools**
- **Chrome/Edge**: Press `F12` or `Ctrl+Shift+I`
- **Firefox**: Press `F12` or `Ctrl+Shift+I`
- **Safari**: Press `Cmd+Option+I`

### **Step 2: Unregister Service Workers**
1. Go to **Application** tab (Chrome/Edge) or **Storage** tab (Firefox)
2. In the left sidebar, click **Service Workers**
3. Look for any entries related to `talowa.web.app`
4. Click **Unregister** for each service worker
5. Verify the list is empty

### **Step 3: Clear All Site Data**
1. Still in **Application** tab
2. In the left sidebar, click **Storage** (under Application)
3. Click **Clear site data** button
4. Confirm the action
5. Wait for "Site data cleared" message

### **Step 4: Clear Browser Cache (Alternative Method)**
**Chrome/Edge**:
1. Press `Ctrl+Shift+Delete`
2. Select "All time" for time range
3. Check "Cached images and files"
4. Click "Clear data"

**Firefox**:
1. Press `Ctrl+Shift+Delete`
2. Select "Everything" for time range
3. Check "Cache"
4. Click "Clear Now"

### **Step 5: Hard Reload**
- **Windows**: `Ctrl+Shift+R`
- **Mac**: `Cmd+Shift+R`
- **Alternative**: Hold `Shift` and click the reload button

### **Step 6: Verify Fix**
1. Navigate to https://talowa.web.app
2. Check browser console (F12 → Console tab)
3. Should see no "Unexpected token '<'" errors
4. App should load past the white screen

---

## 🔍 **Verification Steps**

### **Test Direct File Access**
Open these URLs directly in browser tabs:

1. **Main JavaScript Bundle**:
   - URL: https://talowa.web.app/main.dart.js
   - **Expected**: Minified JavaScript code (starts with something like `(function(){`)
   - **Wrong**: HTML content (starts with `<!DOCTYPE html>`)

2. **Flutter Bootstrap**:
   - URL: https://talowa.web.app/flutter.js
   - **Expected**: JavaScript code
   - **Wrong**: HTML content

3. **Manifest File**:
   - URL: https://talowa.web.app/manifest.json
   - **Expected**: JSON content with app metadata
   - **Wrong**: HTML content

4. **Icons**:
   - URL: https://talowa.web.app/icons/Icon-192.png
   - **Expected**: PNG image displays
   - **Wrong**: 404 error or HTML content

---

## 🚨 **Troubleshooting Common Issues**

### **Issue 1: Still Getting HTML for main.dart.js**
**Symptoms**: Direct access to main.dart.js shows HTML
**Causes**:
- Firebase hosting configuration incorrect
- Build output not deployed properly
- CDN/proxy cache not cleared

**Solutions**:
1. Check firebase.json has `"public": "build/web"`
2. Verify main.dart.js exists in build/web/ locally
3. Redeploy: `firebase deploy --only hosting`
4. Wait 5-10 minutes for CDN propagation

### **Issue 2: Service Worker Won't Unregister**
**Symptoms**: Service worker keeps reappearing
**Solutions**:
1. Close all tabs with talowa.web.app
2. Clear browser data completely
3. Restart browser
4. Try incognito/private mode

### **Issue 3: App Still Shows White Screen**
**Symptoms**: No console errors but app doesn't load
**Solutions**:
1. Check for JavaScript errors in console
2. Verify Firebase configuration
3. Test in different browser
4. Check network tab for failed requests

### **Issue 4: Icons Don't Load**
**Symptoms**: Broken icon images or 404 errors
**Solutions**:
1. Verify icons exist in build/web/icons/
2. Check file sizes are > 0 bytes
3. Test direct icon URLs
4. Redeploy if needed

---

## 📱 **Mobile Browser Cache Clearing**

### **Chrome Mobile (Android)**
1. Open Chrome menu (⋮)
2. Settings → Privacy and security
3. Clear browsing data
4. Select "All time"
5. Check "Cached images and files"
6. Clear data

### **Safari Mobile (iOS)**
1. Settings app → Safari
2. Clear History and Website Data
3. Confirm action
4. Restart Safari app

### **Firefox Mobile**
1. Open Firefox menu
2. Settings → Data Management
3. Clear private data
4. Select all options
5. Clear data

---

## 🔄 **Alternative Cache Clearing Methods**

### **Method 1: Incognito/Private Mode**
- **Chrome**: `Ctrl+Shift+N`
- **Firefox**: `Ctrl+Shift+P`
- **Safari**: `Cmd+Shift+N`
- **Edge**: `Ctrl+Shift+N`

Test the app in private mode to bypass all cache.

### **Method 2: Different Browser**
Try accessing https://talowa.web.app in a completely different browser to isolate cache issues.

### **Method 3: Network Tab Debugging**
1. Open DevTools → Network tab
2. Check "Disable cache" checkbox
3. Reload the page
4. Look for any red (failed) requests
5. Check if main.dart.js returns correct content type

---

## ✅ **Success Indicators**

### **Console Should Show**:
```
✅ No "Unexpected token '<'" errors
✅ No 404 errors for main.dart.js
✅ No service worker registration errors
✅ Firebase initialization messages
✅ Flutter app startup messages
```

### **Network Tab Should Show**:
```
✅ main.dart.js: Status 200, Type: application/javascript
✅ flutter.js: Status 200, Type: application/javascript
✅ manifest.json: Status 200, Type: application/json
✅ Icons: Status 200, Type: image/png
```

### **Visual Indicators**:
```
✅ App loads past white screen
✅ TALOWA interface appears
✅ No loading spinner stuck forever
✅ Interactive elements work
```

---

## 🕐 **Cache Propagation Times**

### **Local Browser Cache**: Immediate
### **Firebase Hosting CDN**: 5-10 minutes
### **ISP Cache**: 15-30 minutes
### **Corporate Proxy**: 1-24 hours

If the fix doesn't work immediately, wait 10 minutes and try again.

---

## 📞 **Support Checklist**

If cache clearing doesn't resolve the issue:

1. **Verify Build Output**:
   - Check `build/web/main.dart.js` exists locally
   - File size should be > 1MB (minified Flutter app)

2. **Check Firebase Configuration**:
   - `firebase.json` has correct `"public": "build/web"`
   - No conflicting rewrite rules

3. **Test Different Networks**:
   - Try mobile data vs WiFi
   - Test from different locations

4. **Browser Compatibility**:
   - Test in Chrome, Firefox, Safari, Edge
   - Check for browser-specific issues

---

**Last Updated**: August 26, 2025  
**Status**: Ready for testing  
**Live URL**: https://talowa.web.app