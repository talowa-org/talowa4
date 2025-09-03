# 🧪 TALOWA - MANUAL TESTING GUIDE

## 🌐 **Live Application Access**

**URL**: https://talowa.web.app  
**Status**: ✅ Live and Ready for Testing  
**Environment**: Production Firebase Hosting

---

## 🚀 **Getting Started - First Time Access**

### **Step 1: Open the Application**
1. Navigate to: https://talowa.web.app
2. The app will load the welcome/authentication screen
3. You should see the TALOWA branding and login options

### **Step 2: Create Your First Account**
Since this is a fresh deployment, you'll need to create the first user account:

1. **Click "Sign Up" or "Register"**
2. **Fill in the registration form:**
   - Full Name: `Test Admin User`
   - Phone Number: `+1234567890` (use any valid format)
   - Email: `admin@test.com`
   - Date of Birth: Select any date
   - Address: Fill in test address details
   - Referral Code: Leave empty (you'll be the first user)

3. **Complete OTP Verification:**
   - Enter any 6-digit code (like `123456`)
   - The system will accept it in development mode

---

## 👤 **User Account Testing**

### **Regular User Flow**
1. **Registration Process:**
   ```
   Name: John Doe
   Phone: +1987654321
   Email: user@test.com
   Referral Code: [Use the code from first user]
   ```

2. **Login Process:**
   - Use phone number and OTP
   - Test both successful and failed login attempts

3. **Profile Management:**
   - Navigate to Profile tab
   - Update personal information
   - Test address changes
   - Verify data persistence

---

## 🏠 **Home Dashboard Testing**

### **Features to Test:**
1. **Cultural Greeting Card**
   - Verify personalized welcome message
   - Check user name display
   - Test member badge visibility

2. **AI Assistant Widget**
   - Click to expand/collapse
   - Test text input functionality
   - Try voice input (if microphone available)
   - Test sample queries like "Help me navigate"

3. **Daily Motivation Card**
   - Verify motivational content loads
   - Check for cultural relevance
   - Test content rotation (refresh page)

4. **Quick Stats Row**
   - My Referrals: Should show referral count
   - Team Size: Shows network size
   - Land Status: Shows land records count

5. **Service Grid (4 Cards):**
   - **Land Management** (Green): Navigate to land records
   - **Payments** (Blue): View payment history
   - **Community** (Orange): See community members
   - **Profile** (Purple): Access profile settings

6. **Emergency Actions**
   - Test "Report Land Grabbing" button
   - Test "Legal Help" button
   - Verify placeholder dialogs appear

7. **Data Population Button (FAB)**
   - Click the floating action button
   - Test system data fixes and population

---

## 🔗 **Referral System Testing**

### **Test Referral Flow:**
1. **Get Referral Code:**
   - Go to Profile → Referral Information
   - Copy your unique referral code

2. **Create Referred User:**
   - Open new incognito/private browser window
   - Register new user with your referral code
   - Complete registration process

3. **Verify Referral Tracking:**
   - Return to original user account
   - Check Home → Quick Stats → My Referrals
   - Navigate to Network tab to see referred users

4. **Test Referral Rewards:**
   - Check if referral count increases
   - Verify team size updates
   - Test referral statistics accuracy

---

## 👥 **Network/Community Testing**

### **Community Features:**
1. **Member List:**
   - Navigate to Community tab
   - View all registered members
   - Check member roles (Admin/Member)
   - Verify current user highlighting

2. **Community Stats:**
   - Total members count
   - Admin count
   - Regular member count

3. **Member Information:**
   - Phone number masking for privacy
   - Location display
   - Member ID visibility
   - Role badges

---

## 💬 **Messages System Testing**

### **Messaging Features:**
1. **Conversation List:**
   - Navigate to Messages tab
   - View existing conversations
   - Test conversation creation

2. **Message Sending:**
   - Send text messages
   - Test message delivery
   - Verify read receipts

3. **Media Sharing:**
   - Test image uploads
   - Test file attachments
   - Verify media preview

---

## 📱 **Feed/Social Testing**

### **Social Feed Features:**
1. **Post Creation:**
   - Navigate to Feed tab
   - Create new post with text
   - Add images to posts
   - Test post categories

2. **Post Interaction:**
   - Like/unlike posts
   - Comment on posts
   - Share posts
   - Report inappropriate content

3. **Feed Navigation:**
   - Scroll through feed
   - Test infinite loading
   - Filter by categories

---

## 🛡️ **Admin System Testing**

### **Becoming an Admin:**
1. **Auto-Promotion (First User):**
   - The first registered user automatically becomes Root Administrator
   - Check Profile → Role should show "Root Administrator"

2. **Manual Admin Assignment:**
   - Use the Data Population button on Home screen
   - This will ensure proper admin roles are assigned

### **Admin Panel Access:**
1. **Navigate to Admin Features:**
   - Look for Admin menu in navigation
   - Or access via Profile → Admin Panel
   - Should only be visible to admin users

2. **Admin Dashboard:**
   - User management interface
   - Moderation tools
   - System statistics
   - Audit logs

### **Admin Functions to Test:**
1. **User Management:**
   - View all users
   - Promote/demote user roles
   - Suspend/activate accounts
   - View user details

2. **Content Moderation:**
   - Review flagged posts
   - Moderate comments
   - Handle user reports
   - Bulk moderation actions

3. **System Monitoring:**
   - View audit logs
   - Check system health
   - Monitor user activity
   - Review security alerts

---

## 🏞️ **Land Records Testing**

### **Land Management:**
1. **Add Land Record:**
   - Navigate to Land tab from Home
   - Click "Add Land Record"
   - Fill in test data:
     ```
     Survey Number: 123/A
     Area: 2.5 acres
     Location: Test Village, Test District
     Land Type: Agricultural
     ```

2. **View Land Records:**
   - See list of your land records
   - Test filtering and sorting
   - Verify data accuracy

3. **Edit Land Records:**
   - Update existing records
   - Test validation rules
   - Verify changes persist

---

## 💳 **Payment System Testing**

### **Payment Features:**
1. **Payment Status:**
   - Navigate to Payments tab
   - View current membership status
   - Check payment history

2. **Free App Model:**
   - Verify no payment required for basic features
   - Test all features are accessible
   - Check premium feature availability

---

## 🤖 **AI Assistant Testing**

### **AI Features:**
1. **Text Interaction:**
   - Open AI Assistant from Home
   - Type queries like:
     - "Help me navigate the app"
     - "How do I add land records?"
     - "Show me my referral stats"

2. **Voice Interaction:**
   - Test voice input (if microphone available)
   - Speak commands clearly
   - Verify voice-to-text accuracy

3. **Navigation Commands:**
   - "Go to profile"
   - "Show my referrals"
   - "Open messages"

---

## 🔧 **System Features Testing**

### **Navigation Testing:**
1. **Tab Navigation:**
   - Test all bottom navigation tabs
   - Verify smooth transitions
   - Check active tab highlighting

2. **Back Button Behavior:**
   - Test browser back button
   - Verify smart back navigation
   - Check helpful messages on Home tab

3. **Deep Linking:**
   - Test direct URL access to features
   - Verify proper authentication redirects

### **Performance Testing:**
1. **Loading Speed:**
   - Test initial app load time
   - Check data caching effectiveness
   - Verify smooth scrolling

2. **Offline Behavior:**
   - Disconnect internet
   - Test cached data access
   - Verify graceful error handling

---

## 🧪 **Test Scenarios**

### **Scenario 1: New User Journey**
1. Register new account
2. Complete profile setup
3. Explore all main features
4. Add first land record
5. Send first message
6. Create first post

### **Scenario 2: Referral Testing**
1. Get referral code from existing user
2. Register using referral code
3. Verify referral tracking
4. Check referrer's stats update
5. Test referral rewards

### **Scenario 3: Admin Workflow**
1. Access admin panel
2. Review user list
3. Moderate content
4. Check audit logs
5. Perform bulk operations

### **Scenario 4: Content Creation**
1. Create various types of posts
2. Upload different media types
3. Test content moderation
4. Verify content visibility

---

## 🐛 **Common Issues to Check**

### **Authentication Issues:**
- OTP not working → Try different phone formats
- Login failures → Check network connection
- Session timeouts → Re-login required

### **Data Loading Issues:**
- Empty screens → Check internet connection
- Slow loading → Test on different networks
- Missing data → Try refresh or re-login

### **Feature Access Issues:**
- Admin features not visible → Verify admin role
- Restricted features → Check user permissions
- Navigation problems → Clear browser cache

---

## 📊 **Testing Checklist**

### **✅ Basic Functionality**
- [ ] User registration works
- [ ] Login/logout functions
- [ ] Profile management
- [ ] Navigation between tabs
- [ ] Data persistence

### **✅ Core Features**
- [ ] Referral system tracking
- [ ] Land records management
- [ ] Message sending/receiving
- [ ] Post creation/interaction
- [ ] AI assistant responses

### **✅ Admin Features**
- [ ] Admin panel access
- [ ] User management
- [ ] Content moderation
- [ ] Audit log viewing
- [ ] System monitoring

### **✅ Performance**
- [ ] Fast loading times
- [ ] Smooth navigation
- [ ] Responsive design
- [ ] Mobile compatibility
- [ ] Error handling

---

## 📞 **Support & Troubleshooting**

### **If You Encounter Issues:**
1. **Clear Browser Cache:**
   - Ctrl+Shift+R (hard refresh)
   - Clear cookies and cache

2. **Check Browser Console:**
   - F12 → Console tab
   - Look for error messages
   - Screenshot any errors

3. **Test Different Browsers:**
   - Chrome, Firefox, Safari, Edge
   - Mobile browsers
   - Incognito/private mode

4. **Network Issues:**
   - Check internet connection
   - Try different networks
   - Disable VPN if using

### **Firebase Console Monitoring:**
- **URL**: https://console.firebase.google.com/project/talowa/overview
- Monitor real-time usage
- Check function logs
- Review database activity

---

## 🎯 **Success Criteria**

Your testing is successful if:
- ✅ Users can register and login
- ✅ All navigation tabs work
- ✅ Referral system tracks properly
- ✅ Admin features are accessible
- ✅ Data persists across sessions
- ✅ AI assistant responds
- ✅ No critical errors in console

---

**🚀 Ready to Test!**  
Start with the basic user registration and work through each feature systematically. The app is fully functional and ready for comprehensive testing.

**Live URL**: https://talowa.web.app