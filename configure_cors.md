# Firebase Storage CORS Configuration Guide

## 🎯 **CORS Configuration for TALOWA**

Your Firebase Storage bucket needs CORS configuration to allow media loading from your web app.

### **Bucket Information:**
- **Bucket**: `gs://talowa.firebasestorage.app`
- **Web Domain**: `https://talowa.web.app`
- **Dev Domains**: `http://localhost:8080`, `http://localhost:5000`

### **Method 1: Using Google Cloud Console (Recommended)**

1. **Go to Google Cloud Console**:
   - Visit: https://console.cloud.google.com/storage/browser
   - Select your project: `talowa`

2. **Find Your Bucket**:
   - Look for bucket: `talowa.firebasestorage.app`
   - Click on the bucket name

3. **Configure CORS**:
   - Click on the **"Permissions"** tab
   - Click **"CORS"** in the left sidebar
   - Click **"Edit CORS Configuration"**

4. **Add This CORS Configuration**:
```json
[
  {
    "origin": [
      "https://talowa.web.app",
      "http://localhost:8080",
      "http://localhost:5000",
      "http://127.0.0.1:8080",
      "http://127.0.0.1:5000"
    ],
    "method": [
      "GET",
      "HEAD",
      "PUT",
      "POST",
      "DELETE",
      "OPTIONS"
    ],
    "maxAgeSeconds": 3600,
    "responseHeader": [
      "Content-Type",
      "Access-Control-Allow-Origin",
      "Access-Control-Allow-Methods",
      "Access-Control-Allow-Headers",
      "Access-Control-Allow-Credentials",
      "Cache-Control",
      "Content-Disposition",
      "Content-Encoding",
      "Content-Length",
      "Content-Range",
      "Date",
      "ETag",
      "Expires",
      "Last-Modified",
      "Server",
      "Transfer-Encoding",
      "Vary"
    ]
  }
]
```

5. **Save the Configuration**:
   - Click **"Save"**
   - Wait for the configuration to propagate (may take a few minutes)

### **Method 2: Using Firebase Console**

1. **Go to Firebase Console**:
   - Visit: https://console.firebase.google.com/project/talowa/storage

2. **Check Storage Rules**:
   - Ensure your storage rules allow authenticated read access
   - Rules should already be configured correctly

### **Method 3: Using gsutil (If Available)**

If you have Google Cloud SDK installed:

```bash
gsutil cors set cors.json gs://talowa.firebasestorage.app
```

### **Verification Steps**

After configuring CORS:

1. **Clear Browser Cache**:
   - Hard refresh your app (Ctrl+F5 or Cmd+Shift+R)

2. **Check Browser Console**:
   - Open Developer Tools (F12)
   - Look for CORS errors in the Console tab
   - Should see successful media loading

3. **Test Media Loading**:
   - Upload a test image/video in your app
   - Verify it displays correctly in the feed
   - Check that videos play properly

### **Common Issues & Solutions**

**Issue**: "CORS policy: No 'Access-Control-Allow-Origin' header"
**Solution**: Ensure CORS is configured with your exact domain

**Issue**: "Failed to load media"
**Solution**: Check that user is authenticated and storage rules allow access

**Issue**: "Token expired" errors
**Solution**: Media URLs are automatically refreshed by the app

### **Testing Your Configuration**

1. **Upload Test Media**:
   - Use the app to upload an image or video
   - Check that it appears in Firebase Storage console

2. **Verify URLs**:
   - Media URLs should contain `firebasestorage.googleapis.com`
   - URLs should have `alt=media` parameter
   - URLs should include authentication token

3. **Check Loading**:
   - Images should load without CORS errors
   - Videos should play properly
   - No console errors related to media loading

### **Expected Results**

After proper CORS configuration:
- ✅ Images load and display correctly
- ✅ Videos play without errors
- ✅ No CORS errors in browser console
- ✅ Media uploads work properly
- ✅ Stories media displays correctly

### **Need Help?**

If you continue to have issues:
1. Check the browser console for specific error messages
2. Verify your Firebase project settings
3. Ensure you're logged in to the app
4. Try uploading new media after CORS configuration
