# 🔥 Firebase OTP Setup Guide for TALOWA

## 🚨 CRITICAL: Required Firebase Console Configuration

The OTP errors you're seeing are due to missing Firebase service configurations. Follow these steps **exactly** to fix all OTP issues:

### 1. Enable Identity Toolkit API

**This is the MOST IMPORTANT step - without this, OTP will NOT work!**

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project: **talowa**
3. Go to **APIs & Services** → **Library**
4. Search for **"Identity Toolkit API"**
5. Click on **Identity Toolkit API**
6. Click **ENABLE**
7. Wait for it to be enabled (may take 1-2 minutes)

### 2. Configure Phone Authentication in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/project/talowa)
2. Click **Authentication** in the left sidebar
3. Click **Sign-in method** tab
4. Find **Phone** in the list
5. Click **Phone** → **Enable**
6. Click **Save**

### 3. Add Authorized Domains for Web

1. Still in **Authentication** → **Sign-in method**
2. Scroll down to **Authorized domains**
3. Make sure these domains are added:
   - `talowa.web.app`
   - `talowa.firebaseapp.com`
   - `localhost` (for testing)

### 4. Configure reCAPTCHA for Web (CRITICAL)

**Phone authentication on web REQUIRES reCAPTCHA verification!**

1. Go to [Google reCAPTCHA Admin Console](https://www.google.com/recaptcha/admin)
2. Click **Create** to add a new site
3. Enter:
   - **Label**: TALOWA OTP Verification
   - **reCAPTCHA type**: reCAPTCHA v2 → "I'm not a robot" Checkbox
   - **Domains**: 
     - `talowa.web.app`
     - `talowa.firebaseapp.com`
     - `localhost` (for testing)
4. Click **Submit**
5. Copy the **Site Key** (you'll need this)

### 5. Update Firebase Project Settings

1. Back in [Firebase Console](https://console.firebase.google.com/project/talowa)
2. Click **Project Settings** (gear icon)
3. Scroll down to **Your apps** section
4. Click on your **Web app** (the one with the web icon)
5. In the **Firebase SDK snippet**, make sure the config includes:
   ```javascript
   const firebaseConfig = {
     apiKey: "AIzaSyBkqk0UpmgGCabHRSQK3V9oH7Dxb5sa9Vk",
     authDomain: "talowa.firebaseapp.com",
     projectId: "talowa",
     storageBucket: "talowa.firebasestorage.app",
     messagingSenderId: "132354679195",
     appId: "1:132354679195:web:bb87ce4dde748e8083013e",
     measurementId: "G-4L640E27ZN"
   };
   ```

### 6. Enable Firebase Authentication API

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **talowa**
3. Go to **APIs & Services** → **Library**
4. Search for **"Firebase Authentication API"**
5. Click **ENABLE** if not already enabled

### 7. Check Billing Account (Important!)

**Phone authentication requires a billing account to be set up:**

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **talowa**
3. Go to **Billing**
4. Make sure a billing account is linked
5. If not, click **Link a billing account** and set one up

### 8. Verify Quotas and Limits

1. In Google Cloud Console, go to **APIs & Services** → **Quotas**
2. Search for **"Identity Toolkit"**
3. Make sure quotas are not exceeded
4. If needed, request quota increases

## 🧪 Testing the Fixed OTP Flow

After completing the above steps:

1. Go to https://talowa.web.app
2. Click **"Join TALOWA Movement"**
3. Enter a valid Indian mobile number (10 digits)
4. Click **"Send OTP"**
5. You should see:
   - reCAPTCHA verification popup (complete it)
   - "OTP sent to +91xxxxxxxxxx" message
   - Actual SMS received on the mobile number
6. Enter the 6-digit OTP received via SMS
7. Click **"Verify OTP"**
8. Continue with the registration form

## 🔧 Technical Implementation Details

### What We Fixed:

1. **Real Firebase Phone Authentication**: Replaced mock OTP with actual Firebase Auth
2. **reCAPTCHA Container**: Added proper reCAPTCHA container in HTML
3. **Error Handling**: Added specific error messages for different failure scenarios
4. **+91 Prefix Handling**: Automatic addition of Indian country code
5. **Complete Registration Form**: All original fields included
6. **Firestore Security Rules**: Updated to allow proper user creation

### Code Changes Made:

1. **web/index.html**: Added reCAPTCHA container
2. **integrated_registration_screen.dart**: Real OTP implementation
3. **hybrid_auth_service.dart**: Complete user profile creation
4. **firestore.rules**: Updated security rules

## 🚨 Common Issues and Solutions

### Issue: "reCAPTCHA verification failed"
**Solution**: Complete steps 4 and 5 above to configure reCAPTCHA properly

### Issue: "Identity Toolkit API not enabled"
**Solution**: Complete step 1 above - this is CRITICAL

### Issue: "Too many requests"
**Solution**: Wait 24 hours or use different phone numbers for testing

### Issue: "Quota exceeded"
**Solution**: Check step 8 above and ensure billing is set up

### Issue: "Invalid phone number"
**Solution**: Use valid Indian mobile numbers (10 digits, no +91 prefix in input)

## ✅ Success Indicators

When everything is working correctly, you should see:

1. **No console errors** related to Firebase Auth
2. **reCAPTCHA popup** appears when sending OTP
3. **Actual SMS received** on the mobile number
4. **"OTP sent to +91xxxxxxxxxx"** success message
5. **Successful OTP verification** and form progression

## 🎯 Final Result

After completing all steps, your TALOWA registration will have:

✅ **Real SMS OTP delivery** to Indian mobile numbers  
✅ **reCAPTCHA verification** for web security  
✅ **Complete registration form** with all required fields  
✅ **Proper error handling** with user-friendly messages  
✅ **Full Firebase integration** with user profile creation  
✅ **Production-ready** OTP authentication system  

The registration flow will work seamlessly for real users! 🚀
