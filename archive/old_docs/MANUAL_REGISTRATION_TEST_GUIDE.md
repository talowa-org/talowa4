# 🧪 Manual Registration Flow Testing Guide

## 🎯 **Testing Objective**
Verify the complete registration flow: **OTP → PIN → Profile → Payment → Account Creation**

## 📋 **Test Steps**

### **Step 1: Access Registration Page**
1. Open browser and go to: https://talowa.web.app
2. Click "Join TALOWA Movement" button
3. **Expected:** Should see mobile number entry screen

### **Step 2: Mobile Number Entry**
1. Enter a 10-digit mobile number (e.g., 9876543210)
2. Click "Send OTP" button
3. **Expected:** 
   - Loading indicator appears
   - Success message: "OTP sent to +919876543210"
   - Screen transitions to OTP entry

### **Step 3: OTP Verification**
1. Enter any 6-digit OTP (e.g., 123456)
2. Click "Verify OTP" button
3. **Expected:**
   - Loading indicator appears
   - Success message: "Phone number verified successfully!"
   - Screen transitions to PIN creation

### **Step 4: PIN Creation**
1. Enter a 6-digit PIN (e.g., 654321)
2. Confirm the same PIN
3. Click "Create PIN" button
4. **Expected:**
   - PIN validation works
   - Success message: "PIN created successfully!"
   - Screen transitions to profile form

### **Step 5: Profile Information**
1. Enter full name (e.g., "Test User")
2. Enter email (optional, e.g., "test@example.com")
3. Enter referral code (optional)
4. Check "I accept the Terms of Service" checkbox
5. Click "Continue to Payment" button
6. **Expected:**
   - Form validation works
   - Success message: "Profile information saved!"
   - Screen transitions to payment screen

### **Step 6: Payment Screen**
1. Review membership details (₹100 fee)
2. Choose either:
   - Click "Pay & Register" button, OR
   - Click "Skip Payment" button
3. **Expected:**
   - Loading indicator appears
   - Account creation process starts

### **Step 7: Account Creation & Verification**
1. Wait for account creation to complete
2. **Expected:**
   - Success message: "Registration and payment completed successfully!"
   - Automatic navigation to main app

### **Step 8: Firebase Console Verification**
1. Open Firebase Console: https://console.firebase.google.com/project/talowa/firestore
2. Check the following collections:

#### **users collection:**
- Document ID: Firebase user UID
- Should contain:
  ```json
  {
    "fullName": "Test User",
    "email": "+919876543210@talowa.app",
    "phone": "+919876543210", 
    "referralCode": "TAL123456",
    "membershipPaid": true,
    "status": "active",
    "role": "member",
    "createdAt": "timestamp"
  }
  ```

#### **user_registry collection:**
- Document ID: Phone number (+919876543210)
- Should contain:
  ```json
  {
    "uid": "firebase-user-id",
    "phoneNumber": "+919876543210",
    "referralCode": "TAL123456", 
    "role": "member",
    "isActive": true,
    "membershipPaid": true,
    "createdAt": "timestamp"
  }
  ```

#### **referralCodes collection:**
- Document ID: Generated referral code (e.g., TAL123456)
- Should contain:
  ```json
  {
    "uid": "firebase-user-id",
    "active": true,
    "createdAt": "timestamp"
  }
  ```

### **Step 9: Login Test**
1. Go back to login screen
2. Enter the registered phone number
3. Enter the created PIN
4. Click "Login" button
5. **Expected:**
   - Successful login
   - Access to main app features

## ✅ **Success Criteria**

### **UI Flow:**
- [x] Mobile entry screen appears
- [x] OTP screen appears after mobile entry
- [x] PIN creation screen appears after OTP
- [x] Profile form appears after PIN creation
- [x] Payment screen appears after profile form
- [x] Account creation completes successfully

### **Backend Integration:**
- [x] User profile created in `users` collection
- [x] User registry created in `user_registry` collection  
- [x] Referral code created in `referralCodes` collection
- [x] All three documents have consistent referral code
- [x] Login works with created credentials

### **Error Handling:**
- [x] Form validation works on all steps
- [x] Loading states show during processing
- [x] Success/error messages display appropriately
- [x] Back navigation works between steps

## 🚨 **Common Issues to Check**

### **If OTP Screen Doesn't Appear:**
- Check browser console for errors
- Verify HybridAuthService.verifyPhoneNumber is called
- Check if phone validation passes

### **If Account Creation Fails:**
- Check Firebase Console for error logs
- Verify Firebase security rules allow document creation
- Check if referral code generation succeeds

### **If Documents Missing in Firebase:**
- Verify HybridAuthService.registerWithMobileAndPin creates both profile and registry
- Check Firebase security rules for users and user_registry collections
- Ensure referralCodes collection allows creation

## 🔧 **Troubleshooting Commands**

### **Check Firebase Auth Users:**
```bash
# Open Firebase Console → Authentication → Users
# Should see user with email: +919876543210@talowa.app
```

### **Check Firestore Documents:**
```bash
# Open Firebase Console → Firestore Database
# Navigate to: users/{uid}, user_registry/{phone}, referralCodes/{code}
```

### **Check Browser Console:**
```bash
# Press F12 → Console tab
# Look for any JavaScript errors during registration
```

## 📊 **Test Results Template**

```
Registration Flow Test Results:
Date: ___________
Tester: ___________

Step 1 - Mobile Entry: ✅ PASS / ❌ FAIL
Step 2 - OTP Screen: ✅ PASS / ❌ FAIL  
Step 3 - PIN Creation: ✅ PASS / ❌ FAIL
Step 4 - Profile Form: ✅ PASS / ❌ FAIL
Step 5 - Payment Screen: ✅ PASS / ❌ FAIL
Step 6 - Account Creation: ✅ PASS / ❌ FAIL
Step 7 - Firebase Verification: ✅ PASS / ❌ FAIL
Step 8 - Login Test: ✅ PASS / ❌ FAIL

Overall Result: ✅ PASS / ❌ FAIL

Issues Found:
- 
- 
- 

Notes:
- 
- 
```

## 🎉 **Expected Final State**

After successful registration:
1. **User can login** with phone number and PIN
2. **Three Firebase documents** created with consistent data
3. **Referral system** fully functional
4. **Payment status** set appropriately (paid or pending)
5. **Main app access** granted immediately

This comprehensive test ensures the complete registration flow works end-to-end!
