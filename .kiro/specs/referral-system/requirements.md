# TALOWA Referral System Requirements

## Introduction

The TALOWA Referral System is a production-ready, two-step referral mechanism designed to drive organic growth for India's largest land rights activism platform. The system follows a clear two-step model: immediate registration with referral code generation, followed by payment-triggered reward activation.

This system is designed to scale to 5+ million users while maintaining data integrity, preventing fraud, and ensuring fair reward distribution across the referral network.

## Requirements

### Requirement 1: Two-Step Referral Model

**User Story:** As a TALOWA platform administrator, I want a two-step referral system that separates registration from payment, so that we can track user acquisition while ensuring role progressions are only activated after payment confirmation.

#### Acceptance Criteria

1. WHEN a user completes registration THEN the system SHALL create their account immediately
2. WHEN a user account is created THEN the system SHALL generate a unique referral code in format "TAL" + 6-digit alphanumeric
3. WHEN a user registers with a referral code THEN the system SHALL record the referral relationship but NOT update counters
4. WHEN a user completes payment THEN the system SHALL activate all referral statistics and check role progressions
5. IF a user has not completed payment THEN their referrals SHALL NOT count toward referrer role progression
6. WHEN payment is successful THEN the system SHALL update the entire referral chain statistics within 30 seconds

### Requirement 2: Referral Code Generation and Management

**User Story:** As a TALOWA user, I want a unique, memorable referral code immediately after registration, so that I can start sharing and inviting others to join the movement.

#### Acceptance Criteria

1. WHEN a user completes registration THEN the system SHALL generate a referral code in format "TAL" + 6-digit alphanumeric
2. WHEN generating referral codes THEN the system SHALL exclude confusing characters (0, O, 1, I, L)
3. WHEN a referral code is generated THEN the system SHALL ensure uniqueness across all 2.1 billion possible combinations
4. WHEN a referral code is created THEN the system SHALL store it in both user profile and dedicated referral lookup collection
5. WHEN displaying referral codes THEN the system SHALL show them in a visually prominent, copy-friendly format
6. IF referral code generation fails THEN the system SHALL retry up to 10 times with different algorithms

### Requirement 3: Universal Referral Link System

**User Story:** As a TALOWA user, I want a single referral link that works across web, Android, and iOS platforms, so that I can share one link regardless of the recipient's device.

#### Acceptance Criteria

1. WHEN a referral link is generated THEN it SHALL use format "https://talowa.web.app/join?ref=TAL8K9M2X"
2. WHEN a user clicks the referral link on web THEN it SHALL open the web application with referral code pre-filled
3. WHEN a user clicks the referral link on Android THEN it SHALL open the Android app if installed, otherwise redirect to Play Store
4. WHEN a user clicks the referral link on iOS THEN it SHALL open the iOS app if installed, otherwise redirect to App Store
5. WHEN the referral link is accessed THEN the system SHALL track the click with timestamp and device information
6. WHEN referral link tracking fails THEN the system SHALL still allow registration to proceed

### Requirement 4: Enhanced Sharing and QR Code System

**User Story:** As a TALOWA user, I want multiple ways to share my referral link including QR codes and social media, so that I can effectively invite others through their preferred communication channels.

#### Acceptance Criteria

1. WHEN a user requests to share their referral THEN the system SHALL provide native sharing options on mobile platforms
2. WHEN generating QR codes THEN the system SHALL create high-quality codes with TALOWA branding
3. WHEN sharing on social media THEN the system SHALL include pre-formatted messages with movement hashtags
4. WHEN sharing on web platforms THEN the system SHALL provide copy-to-clipboard functionality with confirmation
5. WHEN QR code is scanned THEN it SHALL direct to the same universal referral link
6. WHEN sharing fails THEN the system SHALL provide fallback options (copy link, show QR code)

### Requirement 5: Bulletproof Referral Tracking

**User Story:** As a TALOWA platform administrator, I want comprehensive referral tracking that maintains data integrity under high load, so that all referral relationships and role progressions are accurately recorded and processed.

#### Acceptance Criteria

1. WHEN a user registers with a referral code THEN the system SHALL validate the code exists and is active
2. WHEN recording referral relationships THEN the system SHALL store both direct referrer and full upline chain
3. WHEN a referral is recorded THEN the system SHALL use atomic transactions to prevent data corruption
4. WHEN updating referral statistics THEN the system SHALL use batch operations for performance
5. WHEN payment is confirmed THEN the system SHALL update all affected referral counters and check role progressions within 30 seconds
6. IF referral tracking fails THEN the system SHALL log the error and queue for retry without blocking registration

### Requirement 6: Role-Based Progression System

**User Story:** As a TALOWA user, I want to progress through organizational roles based on my referral performance and team size, so that I can take on greater responsibilities and earn recognition within the movement.

#### Acceptance Criteria

1. WHEN a user starts THEN they SHALL have role "Member" with 0 referrals
2. WHEN a user reaches 10 direct paid referrals THEN the system SHALL promote them to "Team Leader"
3. WHEN a user reaches 20 direct paid referrals AND 100 team size THEN the system SHALL promote them to "Coordinator"
4. WHEN a user reaches 40 direct paid referrals AND 700 team size THEN the system SHALL promote them to "Area Coordinator (urban)" OR "Village Coordinator (rural)" based on location
5. WHEN a user reaches 80 direct paid referrals AND 6,000 team size THEN the system SHALL promote them to "Mandal Coordinator"
6. WHEN a user reaches 160 direct paid referrals AND 50,000 team size THEN the system SHALL promote them to "Constituency Coordinator"
7. WHEN a user reaches 320 direct paid referrals AND 500,000 team size THEN the system SHALL promote them to "District Coordinator"
8. WHEN a user reaches 500 direct paid referrals AND 1,000,000 team size THEN the system SHALL promote them to "Zonal Coordinator"
9. WHEN a user reaches 1,000 direct paid referrals AND 3,000,000 team size THEN the system SHALL promote them to "State Coordinator"
10. WHEN role promotion occurs THEN the system SHALL update user permissions and access levels
11. WHEN role promotion happens THEN the system SHALL send congratulatory notification and update profile
12. WHEN calculating team size THEN the system SHALL count all active paid users in the entire downline network

### Requirement 7: Fraud Prevention and Security

**User Story:** As a TALOWA platform administrator, I want robust fraud prevention measures, so that the referral system maintains integrity and prevents abuse or gaming.

#### Acceptance Criteria

1. WHEN detecting multiple registrations from same device THEN the system SHALL flag for manual review
2. WHEN detecting suspicious referral patterns THEN the system SHALL temporarily suspend role progressions pending investigation
3. WHEN a user attempts to refer themselves THEN the system SHALL block the action and show appropriate message
4. WHEN payment verification fails THEN the system SHALL not activate referral statistics or role progressions
5. WHEN fraud is confirmed THEN the system SHALL reverse all related referral statistics and role progressions
6. WHEN suspicious activity is detected THEN the system SHALL log details for security team review

### Requirement 8: Performance and Scalability

**User Story:** As a TALOWA platform administrator, I want the referral system to handle 5+ million users with sub-second response times, so that user experience remains excellent as the platform scales.

#### Acceptance Criteria

1. WHEN processing referral code generation THEN response time SHALL be under 500ms
2. WHEN updating referral statistics THEN batch operations SHALL complete within 30 seconds
3. WHEN querying referral data THEN database queries SHALL use optimized indexes
4. WHEN system load is high THEN referral operations SHALL maintain 99.9% availability
5. WHEN referral chain depth exceeds 10 levels THEN the system SHALL still process updates efficiently
6. WHEN concurrent referral updates occur THEN the system SHALL handle race conditions gracefully

### Requirement 9: Analytics and Reporting

**User Story:** As a TALOWA platform administrator, I want comprehensive referral analytics and reporting, so that I can track growth metrics and optimize the referral program.

#### Acceptance Criteria

1. WHEN generating referral reports THEN the system SHALL show conversion rates by time period
2. WHEN displaying analytics THEN the system SHALL include geographic distribution of referrals
3. WHEN tracking performance THEN the system SHALL measure referral link click-through rates
4. WHEN analyzing growth THEN the system SHALL show viral coefficient and network effects
5. WHEN creating dashboards THEN the system SHALL update metrics in real-time
6. WHEN exporting data THEN the system SHALL provide CSV/Excel formats for further analysis

### Requirement 10: User Experience and Interface

**User Story:** As a TALOWA user, I want an intuitive referral interface that makes sharing easy and tracks my progress clearly, so that I can effectively grow my network and see my impact.

#### Acceptance Criteria

1. WHEN viewing referral dashboard THEN the system SHALL show current referral code prominently
2. WHEN displaying progress THEN the system SHALL show visual progress bars toward next role with both referral and team size requirements
3. WHEN showing referral history THEN the system SHALL list all referred users with payment status
4. WHEN accessing sharing options THEN the system SHALL provide one-tap sharing to popular platforms
5. WHEN viewing achievements THEN the system SHALL display earned badges, milestones, and role progression history
6. WHEN using mobile interface THEN all referral features SHALL be fully accessible and responsive

### Requirement 11: Integration with Payment System

**User Story:** As a TALOWA platform administrator, I want seamless integration between the referral system and payment processing, so that role progressions are automatically activated upon successful payment.

#### Acceptance Criteria

1. WHEN payment is initiated THEN the system SHALL identify any pending referral relationships
2. WHEN payment succeeds THEN the system SHALL trigger referral statistics activation and role progression checks within 30 seconds
3. WHEN payment fails THEN the system SHALL maintain referral relationships in pending state
4. WHEN payment is refunded THEN the system SHALL reverse any activated referral statistics and role progressions
5. WHEN payment webhook is received THEN the system SHALL validate authenticity before processing
6. WHEN payment integration fails THEN the system SHALL queue referral updates for manual processing

### Requirement 12: Enhanced Zero Orphan Users with Geo-Assignment

**User Story:** As a system administrator, I want automatic assignment of orphan users to nearest active leaders based on geographic location, so that all users have proper referral chains and support structure.

#### Acceptance Criteria

1. WHEN a user registers without referral code THEN the system SHALL identify them as potential orphan
2. WHEN orphan is detected THEN the system SHALL find nearest active leader within 50km radius
3. WHEN nearest leader is found THEN the system SHALL automatically assign orphan to that leader
4. IF no leader exists within radius THEN the system SHALL assign orphan to admin
5. WHEN orphan assignment occurs THEN the system SHALL notify both admin and assigned leader
6. WHEN assignment is made THEN the system SHALL create proper parent-child relationship
7. WHEN searching for leaders THEN the system SHALL prioritize by role level (higher roles preferred)
8. WHEN multiple leaders exist at same distance THEN the system SHALL assign to leader with smallest team size
9. WHEN orphan assignment is made THEN the system SHALL update all relevant statistics and counters
10. WHEN leader accepts orphan assignment THEN the system SHALL send welcome message to new team member

### Requirement 13: Notification and Communication

**User Story:** As a TALOWA user, I want to receive notifications about my referral activity and achievements, so that I stay informed about my network growth and role progression.

#### Acceptance Criteria

1. WHEN someone uses my referral code THEN I SHALL receive an immediate notification
2. WHEN my referral completes payment THEN I SHALL receive a confirmation notification about team growth
3. WHEN I achieve role promotion THEN I SHALL receive a congratulatory message with new responsibilities and benefits
4. WHEN referral milestones are reached THEN I SHALL receive achievement notifications and badges
5. WHEN team size milestones are achieved THEN I SHALL receive recognition notifications
6. WHEN notification delivery fails THEN the system SHALL retry through alternative channels

### Requirement 14: Comprehensive Recognition and Retention System

**User Story:** As a user achieving role promotions, I want comprehensive recognition including badges, certificates, and feature unlocks, so that my achievements are properly celebrated and I'm motivated to continue growing.

#### Acceptance Criteria

1. WHEN role promotion occurs THEN the system SHALL generate downloadable promotion certificate
2. WHEN promotion happens THEN the system SHALL display celebration animation and badge
3. WHEN new role is achieved THEN the system SHALL send push notifications to user and team
4. WHEN promotion occurs THEN the system SHALL update profile card with new role and achievements
5. WHEN role changes THEN the system SHALL unlock role-specific app features and permissions
6. WHEN certificates are generated THEN they SHALL be shareable on social media platforms
7. WHEN promotion celebration is displayed THEN it SHALL include confetti animation and achievement sound
8. WHEN certificates are created THEN they SHALL include user photo, achievement date, role details, and digital signature
9. WHEN social sharing occurs THEN it SHALL include branded graphics and movement hashtags
10. WHEN feature unlocks happen THEN the system SHALL provide guided tour of new capabilities
11. WHEN team notifications are sent THEN they SHALL celebrate the leader's achievement and inspire others
12. WHEN profile updates occur THEN they SHALL reflect new role badge, title, and achievement timeline