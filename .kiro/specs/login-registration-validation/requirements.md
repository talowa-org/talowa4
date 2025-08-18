# Login & Registration Validation Suite Requirements

**Created**: August 18, 2025  
**Status**: New Specification  
**Priority**: Critical - Production Validation  

## Overview

This specification defines the comprehensive validation suite for the TALOWA login and registration flow, including OTP verification, form submission, optional payment processing, and referral system integration.

## User Stories

### Story 1: New User Registration Flow
**As a** new user  
**I want** to register with my mobile number through OTP verification  
**So that** I can create an account and access the TALOWA platform  

#### Acceptance Criteria
1. **WHEN** I open the app **THEN** I see Login and Register buttons on the landing screen
2. **WHEN** I click Register **THEN** I am prompted to enter my mobile number
3. **WHEN** I enter a valid mobile number **THEN** I receive an OTP for verification
4. **WHEN** I verify the OTP **THEN** my user session is established
5. **WHEN** I complete the registration form **THEN** my account is created with:
   - `status: 'active'`
   - `phoneVerified: true`
   - `profileCompleted: true`
   - `membershipPaid: false`
   - `referralCode` present (starts with TAL, not "Loading")
   - `provisionalRef` set to deep link ref or TALADMIN fallback
6. **WHEN** registration is complete **THEN** I can access the app even without payment

### Story 2: Optional Payment Processing
**As a** newly registered user  
**I want** to optionally complete membership payment  
**So that** I can contribute to the organization (payment is optional and doesn't affect access)  

#### Acceptance Criteria
1. **WHEN** payment is successful **THEN** my profile is updated with:
   - `status: 'active'`
   - `membershipPaid: true`
   - `paidAt` and `paymentRef` set
   - `referredBy` set from `provisionalRef`
   - `referralChain` populated
   - Referrer's `directReferralCount` incremented
   - Ancestors' `totalTeamSize` incremented
   - Role/achievements evaluation triggered
2. **WHEN** payment fails or is skipped **THEN**:
   - `status` remains 'active'
   - `membershipPaid` remains false
   - I can still access and use the app with full membership benefits
   - I can still share my referral code

### Story 3: Existing User Login
**As an** existing user  
**I want** to login with my mobile number and PIN  
**So that** I can access my account  

#### Acceptance Criteria
1. **WHEN** I click Login **THEN** I am prompted for mobile number and PIN
2. **WHEN** I enter `mobilenumber@talowa.com` and my PIN **THEN** I am successfully logged in
3. **WHEN** login is successful **THEN** I have normal access to all app features

### Story 4: Deep Link Referral Auto-fill
**As a** user clicking a referral link  
**I want** the referral code to be automatically filled  
**So that** I don't have to manually enter the code  

#### Acceptance Criteria
1. **WHEN** I open `https://<site>/join?ref=TAL234567` **THEN** the registration form is auto-filled with TAL234567
2. **WHEN** I open `/join/TAL234567` path **THEN** the registration form is auto-filled with TAL234567
3. **WHEN** the referral code is consumed **THEN** the pending code is cleared
4. **WHEN** no ref is provided or ref is invalid **THEN** `provisionalRef` defaults to TALADMIN

### Story 5: Referral Code Policy Compliance
**As a** system administrator  
**I want** all referral codes to follow the TAL prefix policy  
**So that** the referral system maintains consistency  

#### Acceptance Criteria
1. **WHEN** a new user is created **THEN** their `referralCode` must match: TAL + 6 Crockford base32 characters (A–Z,2–7; no 0/O/1/I)
2. **WHEN** the admin user is created **THEN** TALADMIN is allowed as an exception
3. **WHEN** any user profile is checked **THEN** no user should show "Loading" or non-TAL prefix (except TALADMIN)

### Story 6: Real-time Network Updates
**As a** user with referrals  
**I want** to see my network statistics update in real-time  
**So that** I can track my team growth immediately  

#### Acceptance Criteria
1. **WHEN** I add a test referral **THEN** the Network screen updates direct/total counts in real-time
2. **WHEN** counts change **THEN** they increment without manual refresh
3. **WHEN** I view My Network **THEN** data comes from Firestore streams, not mocks

### Story 7: Security Posture Validation
**As a** security-conscious system  
**I want** to prevent unauthorized data manipulation  
**So that** the referral system integrity is maintained  

#### Acceptance Criteria
1. **WHEN** client attempts to write `referredBy`, `referralChain`, counters, `role`, or `status` **THEN** the write is denied
2. **WHEN** user reads their own user document **THEN** the read succeeds
3. **WHEN** unauthorized access is attempted **THEN** proper security rules are enforced

## Validation Test Cases

### Test Case A: Top-level Navigation
**Precondition**: App is launched  
**Steps**:
1. Open app on desktop and mobile
2. Verify Login button is visible and functional
3. Verify Register button is visible and functional

**Expected Result**: PASS if both buttons visible and navigate correctly

### Test Case B: New User Journey (OTP → Form → Payment Optional)

#### B1: OTP Verification
**Steps**:
1. Enter new mobile number
2. Request OTP
3. Verify OTP

**Expected Result**: User session established

#### B2: Form Submission
**Steps**:
1. Submit registration form (name, location, PIN, etc.)
2. Check user document creation

**Expected Result**: 
- `users/{uid}` exists with correct status and fields
- `referralCode` present (TAL prefix, not "Loading")
- User can access app

#### B3: Payment Success Simulation
**Steps**:
1. Simulate successful payment
2. Check profile updates
3. Verify referral chain updates

**Expected Result**: Full activation and referral processing

#### B4: Payment Failure Simulation
**Steps**:
1. Simulate payment failure
2. Check profile remains active
3. Verify full app access retained

**Expected Result**: Active status maintained, full membership benefits accessible

### Test Case C: Existing User Login
**Steps**:
1. Login with `mobilenumber@talowa.com` + PIN
2. Verify successful authentication
3. Check app access

**Expected Result**: Successful login and normal access

### Test Case D: Deep Link Auto-fill
**Steps**:
1. Open referral deep link
2. Check auto-fill functionality
3. Verify fallback to TALADMIN

**Expected Result**: Correct auto-fill and fallback behavior

### Test Case E: Referral Code Policy
**Steps**:
1. Create multiple new users
2. Check referral code format
3. Verify TAL prefix compliance

**Expected Result**: All codes follow TAL + base32 format

### Test Case F: Real-time Network Updates
**Steps**:
1. Add test referral
2. Check Network screen updates
3. Verify real-time data flow

**Expected Result**: Immediate count updates without refresh

### Test Case G: Security Spot Checks
**Steps**:
1. Attempt unauthorized writes
2. Test authorized reads
3. Verify security rule enforcement

**Expected Result**: Proper security enforcement

## Admin Bootstrap Verification

### Precondition Setup
**Admin User Requirements**:
- Email: `+917981828388@talowa.app`
- Phone: `+917981828388`
- Referral Code: `TALADMIN`
- Status: Active and mapped

## Success Criteria

### Individual Test Results
Each test case must return PASS/FAIL with specific notes for failures.

### Overall Flow Validation
**FLOW MATCHES SPEC: YES/NO**

If any test fails:
1. List precise issue(s)
2. Identify suspected module (Auth init, ensureUserProfile, payment finalize, deep link handler, Network streams, rules)
3. Provide smallest code-only fix with file:function reference
4. Apply fix if safe
5. Re-run failed checks
6. Update verdict

## Implementation Notes

### No UI/UX Changes Allowed
- Validation must work with existing UI
- Only registration flow (OTP → FORM → PAYMENT OPTIONAL) changes allowed if required
- All other flows must remain unchanged

### Real Data Requirements
- No mocks allowed for Network screen validation
- Must use actual Firestore streams
- Real-time updates required

### Security Requirements
- Client-side security rule validation
- Server-side data integrity checks
- Proper access control enforcement

## Dependencies

### Required Services
- Firebase Authentication
- Firestore Database
- Payment Processing Service
- Deep Link Handler
- Referral Code Generator
- Network Statistics Service

### Required Collections
- `users`
- `referralCodes`
- `referrals`
- `payments`
- `user_registry`

## Acceptance Definition of Done

- [ ] All test cases (A-G) return PASS
- [ ] Admin bootstrap verified as YES
- [ ] Final verdict: FLOW MATCHES SPEC: YES
- [ ] No security vulnerabilities identified
- [ ] Real-time functionality confirmed
- [ ] Deep link handling working correctly
- [ ] Payment optional flow functioning
- [ ] Referral code policy enforced

---

**Next Steps**: Execute validation suite and document results with specific PASS/FAIL status for each test case.