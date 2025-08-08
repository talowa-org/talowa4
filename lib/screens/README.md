# Screens

This directory contains the main screens/pages of the application.

## Current Structure

```
screens/
├── auth/
│   ├── landing_screen.dart    ✅ IMPLEMENTED
│   ├── login_screen.dart      ✅ IMPLEMENTED
│   ├── otp_screen.dart        ✅ IMPLEMENTED
│   ├── register_screen.dart   ✅ IMPLEMENTED
│   └── forgot_password_screen.dart (coming soon)
├── home/
│   └── home_screen.dart       ✅ IMPLEMENTED
├── profile/
│   └── profile_screen.dart    (coming soon)
└── ...
```

## Implemented Screens

### LandingScreen ✅
- **Path**: `lib/screens/auth/landing_screen.dart`
- **Purpose**: Clean welcome screen focused on land ownership empowerment
- **Features**:
  - Logo placeholder (landscape icon in green circle)
  - "Welcome to Talowa" title
  - "Empowering Assigned Land Owners" subtitle
  - Full-width "Get Started" button → navigates to `/login`
  - Centered, minimal design with spacers
  - Ready for logo replacement (see assets/README.md)

### LoginScreen ✅ (Enhanced)
- **Path**: `lib/screens/auth/login_screen.dart`
- **Purpose**: Complete two-step phone authentication with Firebase OTP
- **Features**:
  - **Two-Step Flow**: Phone input → OTP verification in single screen
  - **Step Indicator**: Visual progress indicator showing current step
  - **Enhanced Input Validation**: Regex-based validation for phone and OTP
  - **User Existence Check**: Automatically checks if user exists in Firestore
  - **Smart Routing**:
    - Existing users → Home dashboard
    - New users → Registration screen
  - **Comprehensive Error Handling**: Specific error messages for different Firebase auth errors
  - **reCAPTCHA Error Handling**: Graceful handling of web reCAPTCHA issues
  - **Web Platform Warning**: Visual warning about phone verification limitations on web
  - **Loading States**: Visual feedback during phone verification and OTP verification
  - **Back Navigation**: Easy navigation between phone and OTP steps
  - **Resend OTP**: Option to go back and resend OTP
  - **Professional UI**: Step indicators, proper spacing, and modern design

### OtpScreen ✅
- **Path**: `lib/screens/auth/otp_screen.dart`
- **Purpose**: Complete OTP verification with Firebase and Firestore integration
- **Features**:
  - Receives verification ID and phone number from login screen
  - 6-digit OTP input field with validation
  - Firebase phone credential verification
  - Automatic user creation in Firestore (if new user)
  - User data storage: uid, phone, createdAt, role, referralCode
  - Loading state with spinner during verification
  - Error handling with proper mounted checks
  - Navigation to home screen on success → navigates to `/home`
  - Complete authentication flow

### HomeScreen ✅
- **Path**: `lib/screens/home/home_screen.dart`
- **Purpose**: Main dashboard after successful authentication
- **Features**:
  - Welcome message with user phone number and UID
  - Logout functionality with Firebase sign out
  - Dashboard grid with 4 main sections:
    - My Land (properties management)
    - Payments (transaction tracking)
    - Community (user connections)
    - Settings (account management)
  - Clean, card-based UI design
  - Proper navigation back to landing on logout

### RegisterScreen ✅
- **Path**: `lib/screens/auth/register_screen.dart`
- **Purpose**: Complete user registration with comprehensive profile data collection
- **Features**:
  - **Authentication Check**: Verifies user is logged in before allowing registration
  - **Comprehensive Form**: Full name, DOB, email, address, PIN, referral code
  - **Address Collection**: Detailed address fields (house, street, village/city, mandal, district, state, pincode)
  - **Date Picker**: Interactive date selection for date of birth
  - **Form Validation**: Comprehensive validation for all required fields
  - **Email Validation**: Regex-based email validation for optional email field
  - **PIN Creation**: 6-digit PIN creation with validation
  - **Referral System**: Optional referral code input with helpful guidance
  - **Terms Acceptance**: Checkbox for terms and conditions acceptance
  - **Auto-Generated Data**:
    - Member ID generation (MBR-YYYYMMDD-RANDOM)
    - Referral code generation based on user name
    - Referral link creation
  - **Role Management**: Automatic role assignment (Root Admin vs Member)
  - **Firestore Integration**: Complete user profile storage in Firestore
  - **Payment Integration**: Mock payment dialog for membership fee (₹100)
  - **Smart Navigation**: Automatic routing based on user role
  - **Responsive Design**: Scrollable form with proper spacing and layout
  - **Loading States**: Visual feedback during form submission

## Navigation Flow
```
LandingScreen → [Get Started] → LoginScreen (Phone + OTP) → HomeScreen/RegisterScreen
                                     ↓
                               [User Exists Check]
                                     ↓
                            Existing User → /home
                            New User → /register → [Payment] → /home
```

## Named Routes (main.dart)
- `/login` → LoginScreen (Enhanced two-step flow)
- `/otp` → OtpScreen (Legacy - now integrated into LoginScreen)
- `/home` → HomeScreen
- `/register` → RegisterScreen (Complete registration form)

Each screen should be a StatefulWidget or StatelessWidget that represents a full page in the app.
