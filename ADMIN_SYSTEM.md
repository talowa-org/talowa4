# TALOWA Admin System Upgrade (Top 1% Developer Approach)

Implement a secure, enterprise-grade Admin System for the TALOWA app, replacing all current temporary/development shortcuts.

## 🔑 Requirements

### 1. Authentication & Security
- Replace hardcoded PIN with **Firebase Auth + Custom Claims**.
- PIN should be kept only as a **secondary factor (2FA)** for quick access, not primary auth.
- Drop all **dev-only backdoors** and **default bootstrap PINs** after first setup.
- Enforce **MFA (OTP or hardware key)** for sensitive admin actions.
- Add **session timeout + re-authentication** for risky actions (ban/delete/export).

### 2. Role-Based Access Control (RBAC)
- Create tiered admin roles with Firebase Custom Claims:
  - **super_admin** → full system control
  - **moderator** → content moderation only
  - **regional_admin** → scoped access by state/district
  - **auditor** → read-only access to logs
- Enforce these roles both in **Firestore rules** and **Flutter UI navigation**.
- Only `super_admin` can assign or revoke admin roles.

### 3. Admin Dashboard
- Expand dashboard to include:
  - Referral funnel stats
  - Growth charts (user onboarding trends)
  - Real-time active events
  - Direct vs team referral performance
- Add **predictive insights** (fraud detection, inactive clusters).
- Implement **push alerts** (Firebase Cloud Messaging + email) for suspicious activity.

### 4. Content Moderation
- Fully build out `moderation_actions_screen`:
  - Ban/unban workflows
  - Bulk restrictions
  - Escalation queue
- Add **AI-assisted moderation** (auto-flag content for review).
- Every moderation action must log to `transparency_logs` (immutable audit trail).

### 5. Data & Security
- Centralize referral and user management in **Cloud Functions only**.
- Enforce strict **Firestore rules**:
  - Only admins can access moderation collections
  - Normal users cannot modify `role` or `referral` fields
- Add **full audit logging** for every admin action:
  - Who acted
  - What action
  - Target
  - Timestamp

### 6. Admin Access UX
- Remove all hidden **tap-to-reveal** logins and developer shortcuts.
- Provide a dedicated `/admin` route guarded by claims.
- If user has no valid role claim, redirect to “Unauthorized”.
- Ensure persistent login across restarts, but enforce idle timeout → PIN + MFA re-auth.

### 7. Long-Term Vision
- Build a **separate lightweight Admin PWA** to isolate admin flows from the end-user app.
- This will improve security, scalability, and team management for admins.

---

## 📌 Deliverables
- Cloud Functions:
  - `assignAdminRole(uid, role)`
  - `logAdminAction()`
  - `flagSuspiciousReferrals()`
- Updated Firestore Security Rules (strict RBAC enforcement).
- Flutter Admin UI updates:
  - Role-guarded `/admin` route
  - Expanded dashboard
  - Complete moderation screen
- Admin Alerts (FCM + email)
- Removal of dev-only backdoors

---

## ✅ Testing Checklist
1. Normal users cannot access `/admin`.
2. Only `super_admin` can assign/revoke roles.
3. PIN works only as secondary factor, not as standalone login.
4. Moderation actions show up in `transparency_logs`.
5. Referral and role data cannot be modified from client side.
6. Session timeout + re-auth works for sensitive actions.
7. Push alerts trigger correctly on suspicious events.

---

**Implement this Admin System step by step, starting with:**
1. Firebase Custom Claims (`assignAdminRole` Cloud Function)
2. Firestore Rules update for RBAC
3. Flutter login flow update (PIN as 2FA only, not primary)
4. Remove hidden tap-to-reveal login

READY FOR PRODUCTION
Default Admin Credentials:

Email: admin@talowa.com
Password: TalowaAdmin2024!
Default PIN: 1234 (MUST CHANGE IMMEDIATELY)
