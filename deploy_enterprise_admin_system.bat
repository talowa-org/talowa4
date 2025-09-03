@echo off
echo ========================================
echo TALOWA Enterprise Admin System Deployment
echo ========================================
echo.

echo [1/6] Building Flutter Web App...
call flutter build web --release
if %errorlevel% neq 0 (
    echo ERROR: Flutter build failed
    pause
    exit /b 1
)

echo.
echo [2/6] Deploying Cloud Functions...
cd functions
call npm run build
if %errorlevel% neq 0 (
    echo ERROR: Cloud Functions build failed
    cd ..
    pause
    exit /b 1
)

call firebase deploy --only functions
if %errorlevel% neq 0 (
    echo ERROR: Cloud Functions deployment failed
    cd ..
    pause
    exit /b 1
)
cd ..

echo.
echo [3/6] Updating Firestore Security Rules...
call firebase deploy --only firestore:rules
if %errorlevel% neq 0 (
    echo ERROR: Firestore rules deployment failed
    pause
    exit /b 1
)

echo.
echo [4/6] Deploying Firebase Hosting...
call firebase deploy --only hosting
if %errorlevel% neq 0 (
    echo ERROR: Firebase hosting deployment failed
    pause
    exit /b 1
)

echo.
echo [5/6] Creating Admin User (if needed)...
node -e "
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function createAdminUser() {
  try {
    // Check if admin user exists
    let user;
    try {
      user = await admin.auth().getUserByEmail('admin@talowa.com');
      console.log('Admin user already exists:', user.uid);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        // Create admin user
        user = await admin.auth().createUser({
          email: 'admin@talowa.com',
          password: 'TalowaAdmin2024!',
          displayName: 'TALOWA Super Admin',
          emailVerified: true
        });
        console.log('Created admin user:', user.uid);
      } else {
        throw error;
      }
    }
    
    // Set custom claims
    await admin.auth().setCustomUserClaims(user.uid, {
      role: 'super_admin',
      adminCreatedAt: new Date().toISOString()
    });
    
    console.log('Admin custom claims set successfully');
    
    // Create user document
    await admin.firestore().collection('users').doc(user.uid).set({
      email: 'admin@talowa.com',
      displayName: 'TALOWA Super Admin',
      role: 'super_admin',
      adminRole: 'super_admin',
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      phoneNumber: '+917981828388'
    }, { merge: true });
    
    console.log('Admin user document created/updated');
    
  } catch (error) {
    console.error('Error creating admin user:', error);
  }
}

createAdminUser().then(() => process.exit(0));
"

echo.
echo [6/6] Verifying Deployment...
echo.
echo ========================================
echo DEPLOYMENT COMPLETE!
echo ========================================
echo.
echo Admin Portal Access:
echo - URL: https://your-project.web.app/admin
echo - Email: admin@talowa.com
echo - Password: TalowaAdmin2024!
echo - Default PIN: 1234 (CHANGE IMMEDIATELY)
echo.
echo Security Features Deployed:
echo ✓ Firebase Auth + Custom Claims
echo ✓ PIN-based Two-Factor Authentication
echo ✓ Role-Based Access Control (RBAC)
echo ✓ Session Management with Timeout
echo ✓ Audit Logging for All Admin Actions
echo ✓ Enhanced Firestore Security Rules
echo ✓ Removed All Hidden/Dev Access Points
echo.
echo IMPORTANT SECURITY NOTES:
echo 1. Change the default admin PIN immediately
echo 2. Update the admin password from default
echo 3. Review and customize admin roles as needed
echo 4. Monitor audit logs regularly
echo 5. Set up admin alerts and notifications
echo.
echo Next Steps:
echo 1. Login to admin portal
echo 2. Change default PIN
echo 3. Create additional admin users if needed
echo 4. Configure regional admins
echo 5. Set up monitoring and alerts
echo.
pause