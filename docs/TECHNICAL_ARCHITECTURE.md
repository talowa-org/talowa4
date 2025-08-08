# TALOWA TECHNICAL ARCHITECTURE
## Comprehensive Database Design & API Structure for 5M Users

---

## 🗄️ DATABASE DESIGN

### **Core Database Schema**

#### **1. User Management Collections**

```typescript
// Collection: user_registry (Lightweight for fast lookups)
interface UserRegistry {
  id: string;                    // Document ID: phoneNumber (+919876543210)
  uid: string;                   // Firebase Auth UID
  email: string;                 // Fake email: +919876543210@talowa.app
  phoneNumber: string;           // +919876543210
  role: 'Member' | 'Village Coordinator' | 'Mandal Coordinator' | 'District Coordinator' | 'State Coordinator' | 'Legal Advisor' | 'Media Coordinator' | 'Root Administrator';
  state: string;                 // For geographic partitioning
  district: string;              // For regional queries
  mandal?: string;               // For local coordination
  village?: string;              // For village-level organization
  isActive: boolean;             // Account status
  createdAt: Timestamp;          // Registration date
  lastLoginAt: Timestamp;        // Last activity
  referralCode: string;          // User's unique referral code
  referredBy?: string;           // Who referred this user
  directReferrals: number;       // Count of direct referrals
  teamSize: number;              // Total network size
  membershipPaid: boolean;       // Payment status
  paymentTransactionId?: string; // Payment reference
}

// Collection: users (Complete profiles)
interface UserProfile {
  id: string;                    // Document ID: Firebase Auth UID
  
  // Personal Information
  fullName: string;
  dob?: string;                  // YYYY-MM-DD format
  email?: string;                // Optional real email
  phone: string;                 // +919876543210
  
  // Address Information
  address: {
    houseNo?: string;
    street?: string;
    villageCity: string;
    mandal: string;
    district: string;
    state: string;
    pincode?: string;
  };
  
  // Role & Hierarchy
  role: string;
  currentRoleLevel: number;      // 0=Root Admin, 1=Member, 2=Village, etc.
  
  // Referral Network
  memberId: string;              // MBR-YYYYMMDD-XXXX
  referralCode: string;          // NAMEXXXX
  referralLink: string;          // https://talowa.app/register?ref=CODE
  referredBy?: string;           // Referrer's code
  directReferrals: number;
  teamReferrals: number;
  
  // System Fields
  createdAt: Timestamp;
  updatedAt: Timestamp;
  lastLoginAt: Timestamp;
  
  // Payment Information
  paymentStatus: 'pending' | 'completed' | 'failed';
  membershipPaid: boolean;
  paymentTransactionId?: string;
  paymentCompletedAt?: Timestamp;
  
  // Security & Privacy
  pin: string;                   // Encrypted 6-digit PIN
  securityLevel: 'standard' | 'high_risk';
  pseudonym?: string;            // For high-risk users
  
  // Preferences
  preferences: {
    language: string;
    notifications: {
      push: boolean;
      sms: boolean;
      email: boolean;
    };
    privacy: {
      showLocation: boolean;
      allowDirectContact: boolean;
    };
  };
}
```

#### **2. Geographic Hierarchy Collections**

```typescript
// Collection: states/{stateId}
interface StateData {
  id: string;                    // telangana, andhra_pradesh, etc.
  name: string;                  // "Telangana"
  coordinator?: string;          // State Coordinator UID
  
  // Statistics
  totalMembers: number;
  activeCoordinators: number;
  activeCampaigns: number;
  landRecords: number;
  
  // Administrative
  districts: string[];           // List of district IDs
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

// Collection: states/{stateId}/districts/{districtId}
interface DistrictData {
  id: string;                    // hyderabad, warangal, etc.
  name: string;                  // "Hyderabad"
  stateId: string;               // Parent state
  coordinator?: string;          // District Coordinator UID
  
  // Statistics
  totalMembers: number;
  activeCoordinators: number;
  activeCampaigns: number;
  landRecords: number;
  
  // Administrative
  mandals: string[];             // List of mandal IDs
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

// Collection: states/{stateId}/districts/{districtId}/mandals/{mandalId}
interface MandalData {
  id: string;                    // secunderabad, kukatpally, etc.
  name: string;                  // "Secunderabad"
  districtId: string;            // Parent district
  coordinator?: string;          // Mandal Coordinator UID
  
  // Statistics
  totalMembers: number;
  activeCoordinators: number;
  activeCampaigns: number;
  landRecords: number;
  
  // Administrative
  villages: string[];            // List of village IDs
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

// Collection: states/{stateId}/districts/{districtId}/mandals/{mandalId}/villages/{villageId}
interface VillageData {
  id: string;                    // village_name_id
  name: string;                  // "Village Name"
  mandalId: string;              // Parent mandal
  coordinator?: string;          // Village Coordinator UID
  
  // Statistics
  totalMembers: number;
  landRecords: number;
  activeCampaigns: number;
  
  // Geographic
  coordinates?: {
    latitude: number;
    longitude: number;
  };
  
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

#### **3. Land Records & Legal Collections**

```typescript
// Collection: land_records
interface LandRecord {
  id: string;                    // Auto-generated
  
  // Ownership
  ownerId: string;               // User UID
  ownerPhone: string;            // For quick lookups
  
  // Land Details
  surveyNumber: string;          // Government survey number
  area: number;                  // In acres/hectares
  unit: 'acres' | 'hectares' | 'guntas';
  landType: 'agricultural' | 'residential' | 'commercial' | 'industrial';
  
  // Location
  location: {
    village: string;
    mandal: string;
    district: string;
    state: string;
    coordinates?: {
      latitude: number;
      longitude: number;
    };
  };
  
  // Legal Status
  legalStatus: 'assigned' | 'patta_pending' | 'patta_received' | 'disputed' | 'encroached';
  assignmentDate?: Timestamp;    // When land was assigned
  pattaApplicationDate?: Timestamp;
  pattaReceivedDate?: Timestamp;
  
  // Documents
  documents: {
    assignmentOrder?: string;    // Document URL
    surveySettlement?: string;   // Document URL
    pattaDocument?: string;      // Document URL
    photos: string[];            // Photo URLs
  };
  
  // Issues & Cases
  issues: {
    hasEncroachment: boolean;
    hasDispute: boolean;
    hasLegalCase: boolean;
    description?: string;
  };
  
  // System Fields
  createdAt: Timestamp;
  updatedAt: Timestamp;
  verifiedAt?: Timestamp;
  verifiedBy?: string;           // Verifier UID
}

// Collection: legal_cases
interface LegalCase {
  id: string;                    // Auto-generated
  
  // Case Details
  caseNumber?: string;           // Court case number
  caseType: 'land_dispute' | 'encroachment' | 'patta_application' | 'government_acquisition' | 'other';
  title: string;                 // Brief case title
  description: string;           // Detailed description
  
  // Parties
  plaintiffId: string;           // User UID
  defendants: string[];          // List of defendant names
  
  // Legal Information
  court: string;                 // Court name
  judge?: string;                // Judge name
  lawyer?: string;               // Lawyer name
  lawyerContact?: string;        // Lawyer contact
  
  // Status
  status: 'filed' | 'pending' | 'hearing_scheduled' | 'under_trial' | 'judgment_reserved' | 'won' | 'lost' | 'settled';
  filedDate?: Timestamp;
  lastHearingDate?: Timestamp;
  nextHearingDate?: Timestamp;
  judgmentDate?: Timestamp;
  
  // Related Records
  landRecordIds: string[];       // Related land records
  
  // Documents
  documents: {
    petition?: string;           // Document URL
    evidences: string[];         // Evidence document URLs
    courtOrders: string[];       // Court order URLs
    judgment?: string;           // Final judgment URL
  };
  
  // System Fields
  createdAt: Timestamp;
  updatedAt: Timestamp;
  assignedLawyer?: string;       // Legal Advisor UID
}
```

#### **4. Communication & Campaign Collections**

```typescript
// Collection: campaigns
interface Campaign {
  id: string;                    // Auto-generated
  
  // Campaign Details
  title: string;
  description: string;
  type: 'awareness' | 'protest' | 'legal_action' | 'media_campaign' | 'petition' | 'rally';
  
  // Scope & Targeting
  scope: {
    level: 'village' | 'mandal' | 'district' | 'state' | 'national';
    targetLocations: string[];   // Location IDs
    targetRoles: string[];       // Target user roles
  };
  
  // Organization
  organizerId: string;           // Campaign organizer UID
  coordinators: string[];        // Coordinator UIDs
  participants: string[];        // Participant UIDs
  
  // Timeline
  startDate: Timestamp;
  endDate?: Timestamp;
  
  // Status
  status: 'draft' | 'active' | 'paused' | 'completed' | 'cancelled';
  
  // Metrics
  metrics: {
    participantCount: number;
    engagementRate: number;
    mediaReach: number;
    legalOutcomes: number;
  };
  
  // Resources
  resources: {
    budget?: number;
    documents: string[];         // Resource document URLs
    media: string[];             // Media file URLs
  };
  
  // System Fields
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

// Collection: campaign_updates/{campaignId}/live_updates
interface CampaignUpdate {
  id: string;                    // Auto-generated
  campaignId: string;            // Parent campaign
  
  // Update Details
  message: string;
  type: 'announcement' | 'progress' | 'media' | 'legal' | 'emergency';
  senderId: string;              // Sender UID
  
  // Media
  attachments: {
    images: string[];
    videos: string[];
    documents: string[];
  };
  
  // Targeting
  recipients: string[];          // Specific recipient UIDs (empty = all participants)
  
  // System Fields
  timestamp: Timestamp;
  readBy: string[];              // UIDs of users who read the update
}

// Collection: messages
interface Message {
  id: string;                    // Auto-generated
  
  // Message Details
  content: string;
  type: 'text' | 'image' | 'video' | 'document' | 'voice' | 'location';
  
  // Participants
  senderId: string;              // Sender UID
  recipientId?: string;          // For direct messages
  groupId?: string;              // For group messages
  
  // Security
  encryptionLevel: 'standard' | 'high_security';
  isAnonymous: boolean;
  
  // Media
  mediaUrl?: string;             // Media file URL
  mediaType?: string;            // MIME type
  mediaSize?: number;            // File size in bytes
  
  // Status
  status: 'sent' | 'delivered' | 'read';
  deliveredAt?: Timestamp;
  readAt?: Timestamp;
  
  // System Fields
  timestamp: Timestamp;
  editedAt?: Timestamp;
  deletedAt?: Timestamp;
}
```

#### **5. Analytics & Monitoring Collections**

```typescript
// Collection: user_actions (For analytics)
interface UserAction {
  id: string;                    // Auto-generated
  
  // User Information
  userId: string;                // User UID
  sessionId: string;             // Session identifier
  
  // Action Details
  action: string;                // Action name (login, view_profile, send_message, etc.)
  screen: string;                // Screen/page name
  feature: string;               // Feature used
  
  // Context
  metadata: {
    [key: string]: any;          // Additional action-specific data
  };
  
  // Device & Location
  deviceInfo: {
    platform: string;           // android, ios, web
    version: string;             // App version
    deviceModel?: string;        // Device model
  };
  
  location?: {
    state: string;
    district: string;
    coordinates?: {
      latitude: number;
      longitude: number;
    };
  };
  
  // System Fields
  timestamp: Timestamp;
}

// Collection: performance_metrics
interface PerformanceMetric {
  id: string;                    // Auto-generated
  
  // Metric Details
  operation: string;             // Operation name
  responseTime: number;          // Response time in milliseconds
  success: boolean;              // Operation success status
  errorCode?: string;            // Error code if failed
  
  // Context
  platform: 'web' | 'mobile';
  region: string;                // Geographic region
  userCount: number;             // Number of users affected
  
  // System Fields
  timestamp: Timestamp;
}

// Collection: movement_metrics (Aggregated data)
interface MovementMetrics {
  id: string;                    // Date-based ID (YYYY-MM-DD)
  
  // User Metrics
  totalUsers: number;
  newUsers: number;
  activeUsers: number;
  retainedUsers: number;
  
  // Geographic Distribution
  usersByState: {
    [stateId: string]: number;
  };
  
  // Role Distribution
  usersByRole: {
    [role: string]: number;
  };
  
  // Campaign Metrics
  activeCampaigns: number;
  campaignParticipation: number;
  campaignSuccess: number;
  
  // Legal Metrics
  newLegalCases: number;
  resolvedCases: number;
  pattasReceived: number;
  
  // System Fields
  date: Timestamp;
  calculatedAt: Timestamp;
}
```

---

## 🔌 API STRUCTURE

### **RESTful API Design**

#### **1. Authentication APIs**

```typescript
// POST /api/v1/auth/register
interface RegisterRequest {
  phoneNumber: string;           // 10-digit number
  pin: string;                   // 6-digit PIN
  fullName: string;
  address: {
    villageCity: string;
    mandal: string;
    district: string;
    state: string;
  };
  referralCode?: string;
}

interface RegisterResponse {
  success: boolean;
  message: string;
  user?: {
    uid: string;
    phoneNumber: string;
    memberId: string;
    referralCode: string;
  };
  token?: string;                // JWT token
}

// POST /api/v1/auth/login
interface LoginRequest {
  phoneNumber: string;           // 10-digit number
  pin: string;                   // 6-digit PIN
}

interface LoginResponse {
  success: boolean;
  message: string;
  user?: {
    uid: string;
    phoneNumber: string;
    role: string;
    memberId: string;
  };
  token?: string;                // JWT token
}

// POST /api/v1/auth/verify-phone
interface VerifyPhoneRequest {
  phoneNumber: string;
  otp: string;
}

interface VerifyPhoneResponse {
  success: boolean;
  message: string;
  verified: boolean;
}
```

#### **2. User Management APIs**

```typescript
// GET /api/v1/users/profile
interface GetProfileResponse {
  success: boolean;
  user: UserProfile;
}

// PUT /api/v1/users/profile
interface UpdateProfileRequest {
  fullName?: string;
  email?: string;
  address?: Partial<UserProfile['address']>;
  preferences?: Partial<UserProfile['preferences']>;
}

// GET /api/v1/users/network
interface GetNetworkResponse {
  success: boolean;
  network: {
    directReferrals: UserRegistry[];
    teamSize: number;
    referralTree: {
      level: number;
      users: UserRegistry[];
    }[];
  };
}

// POST /api/v1/users/refer
interface ReferUserRequest {
  phoneNumber: string;
  name: string;
}

interface ReferUserResponse {
  success: boolean;
  message: string;
  referralLink: string;
}
```

#### **3. Geographic & Hierarchy APIs**

```typescript
// GET /api/v1/geography/states
interface GetStatesResponse {
  success: boolean;
  states: StateData[];
}

// GET /api/v1/geography/states/{stateId}/districts
interface GetDistrictsResponse {
  success: boolean;
  districts: DistrictData[];
}

// GET /api/v1/geography/hierarchy/{userId}
interface GetUserHierarchyResponse {
  success: boolean;
  hierarchy: {
    state: StateData;
    district: DistrictData;
    mandal: MandalData;
    village?: VillageData;
    coordinators: {
      village?: UserRegistry;
      mandal?: UserRegistry;
      district?: UserRegistry;
      state?: UserRegistry;
    };
  };
}

// GET /api/v1/coordinators/{level}/{locationId}
interface GetCoordinatorsResponse {
  success: boolean;
  coordinators: UserRegistry[];
  statistics: {
    totalMembers: number;
    activeCampaigns: number;
    landRecords: number;
  };
}
```

#### **4. Land Records APIs**

```typescript
// POST /api/v1/land-records
interface CreateLandRecordRequest {
  surveyNumber: string;
  area: number;
  unit: string;
  landType: string;
  location: LandRecord['location'];
  legalStatus: string;
  documents?: {
    assignmentOrder?: File;
    photos?: File[];
  };
}

// GET /api/v1/land-records
interface GetLandRecordsResponse {
  success: boolean;
  records: LandRecord[];
  pagination: {
    page: number;
    limit: number;
    total: number;
  };
}

// PUT /api/v1/land-records/{recordId}
interface UpdateLandRecordRequest {
  legalStatus?: string;
  documents?: {
    pattaDocument?: File;
    photos?: File[];
  };
  issues?: Partial<LandRecord['issues']>;
}

// POST /api/v1/land-records/{recordId}/report-issue
interface ReportLandIssueRequest {
  issueType: 'encroachment' | 'dispute' | 'government_acquisition';
  description: string;
  evidence?: File[];
  isAnonymous?: boolean;
}
```

#### **5. Legal Case APIs**

```typescript
// POST /api/v1/legal-cases
interface CreateLegalCaseRequest {
  caseType: string;
  title: string;
  description: string;
  defendants: string[];
  court: string;
  landRecordIds: string[];
  documents?: {
    petition?: File;
    evidences?: File[];
  };
}

// GET /api/v1/legal-cases
interface GetLegalCasesResponse {
  success: boolean;
  cases: LegalCase[];
  pagination: {
    page: number;
    limit: number;
    total: number;
  };
}

// PUT /api/v1/legal-cases/{caseId}/status
interface UpdateCaseStatusRequest {
  status: string;
  nextHearingDate?: string;
  notes?: string;
  documents?: File[];
}

// GET /api/v1/legal-cases/{caseId}/timeline
interface GetCaseTimelineResponse {
  success: boolean;
  timeline: {
    date: string;
    event: string;
    description: string;
    documents?: string[];
  }[];
}
```

#### **6. Campaign APIs**

```typescript
// POST /api/v1/campaigns
interface CreateCampaignRequest {
  title: string;
  description: string;
  type: string;
  scope: Campaign['scope'];
  startDate: string;
  endDate?: string;
  resources?: {
    budget?: number;
    documents?: File[];
  };
}

// GET /api/v1/campaigns
interface GetCampaignsResponse {
  success: boolean;
  campaigns: Campaign[];
  filters: {
    active: number;
    completed: number;
    byType: { [type: string]: number };
  };
}

// POST /api/v1/campaigns/{campaignId}/join
interface JoinCampaignResponse {
  success: boolean;
  message: string;
  role: 'participant' | 'coordinator';
}

// POST /api/v1/campaigns/{campaignId}/updates
interface CreateCampaignUpdateRequest {
  message: string;
  type: string;
  attachments?: File[];
  recipients?: string[];
}

// GET /api/v1/campaigns/{campaignId}/analytics
interface GetCampaignAnalyticsResponse {
  success: boolean;
  analytics: {
    participantCount: number;
    engagementRate: number;
    geographicReach: string[];
    mediaImpact: number;
    timeline: {
      date: string;
      participants: number;
      engagement: number;
    }[];
  };
}
```

#### **7. Communication APIs**

```typescript
// POST /api/v1/messages
interface SendMessageRequest {
  recipientId?: string;          // For direct messages
  groupId?: string;              // For group messages
  content: string;
  type: 'text' | 'image' | 'document';
  mediaFile?: File;
  isAnonymous?: boolean;
}

// GET /api/v1/messages/conversations
interface GetConversationsResponse {
  success: boolean;
  conversations: {
    id: string;
    type: 'direct' | 'group';
    participants: UserRegistry[];
    lastMessage: Message;
    unreadCount: number;
  }[];
}

// GET /api/v1/messages/conversations/{conversationId}
interface GetMessagesResponse {
  success: boolean;
  messages: Message[];
  pagination: {
    page: number;
    limit: number;
    total: number;
  };
}

// POST /api/v1/notifications/send
interface SendNotificationRequest {
  recipients: string[];          // User UIDs or 'all'
  title: string;
  message: string;
  type: 'info' | 'warning' | 'emergency';
  scope?: {
    level: string;
    locations: string[];
  };
  channels: ('push' | 'sms' | 'email')[];
}
```

#### **8. Analytics APIs**

```typescript
// GET /api/v1/analytics/dashboard
interface GetDashboardAnalyticsResponse {
  success: boolean;
  analytics: {
    userMetrics: {
      totalUsers: number;
      activeUsers: number;
      newUsers: number;
      retentionRate: number;
    };
    campaignMetrics: {
      activeCampaigns: number;
      successRate: number;
      participation: number;
    };
    legalMetrics: {
      activeCases: number;
      resolvedCases: number;
      pattasReceived: number;
    };
    geographicDistribution: {
      [state: string]: number;
    };
  };
}

// GET /api/v1/analytics/reports/{reportType}
interface GetReportResponse {
  success: boolean;
  report: {
    title: string;
    generatedAt: string;
    data: any;
    charts: {
      type: string;
      data: any;
    }[];
  };
}

// POST /api/v1/analytics/custom-report
interface GenerateCustomReportRequest {
  reportType: string;
  dateRange: {
    startDate: string;
    endDate: string;
  };
  filters: {
    states?: string[];
    roles?: string[];
    campaigns?: string[];
  };
  metrics: string[];
}
```

---

## 🔐 SECURITY & MIDDLEWARE

### **Authentication Middleware**

```typescript
interface AuthMiddleware {
  // JWT token validation
  validateToken(token: string): Promise<{
    valid: boolean;
    userId?: string;
    role?: string;
    permissions?: string[];
  }>;
  
  // Role-based access control
  requireRole(roles: string[]): (req: Request, res: Response, next: NextFunction) => void;
  
  // Permission-based access control
  requirePermission(permission: string): (req: Request, res: Response, next: NextFunction) => void;
  
  // Rate limiting
  rateLimit(options: {
    windowMs: number;
    max: number;
    message: string;
  }): (req: Request, res: Response, next: NextFunction) => void;
}
```

### **Data Validation Schemas**

```typescript
// Input validation using Joi or similar
const phoneNumberSchema = Joi.string()
  .pattern(/^[6-9]\d{9}$/)
  .required()
  .messages({
    'string.pattern.base': 'Phone number must be a valid 10-digit Indian mobile number'
  });

const pinSchema = Joi.string()
  .pattern(/^\d{6}$/)
  .required()
  .messages({
    'string.pattern.base': 'PIN must be exactly 6 digits'
  });

const addressSchema = Joi.object({
  villageCity: Joi.string().min(2).max(100).required(),
  mandal: Joi.string().min(2).max(100).required(),
  district: Joi.string().min(2).max(100).required(),
  state: Joi.string().min(2).max(100).required(),
  pincode: Joi.string().pattern(/^\d{6}$/).optional()
});
```

---

## 📊 PERFORMANCE OPTIMIZATION

### **Database Indexing Strategy**

```javascript
// Firestore indexes for optimal query performance
const indexes = [
  // User registry indexes
  {
    collection: 'user_registry',
    fields: [
      { field: 'phoneNumber', order: 'ASCENDING' },
      { field: 'isActive', order: 'ASCENDING' }
    ]
  },
  {
    collection: 'user_registry',
    fields: [
      { field: 'state', order: 'ASCENDING' },
      { field: 'district', order: 'ASCENDING' },
      { field: 'role', order: 'ASCENDING' }
    ]
  },
  
  // Land records indexes
  {
    collection: 'land_records',
    fields: [
      { field: 'ownerId', order: 'ASCENDING' },
      { field: 'legalStatus', order: 'ASCENDING' }
    ]
  },
  {
    collection: 'land_records',
    fields: [
      { field: 'location.state', order: 'ASCENDING' },
      { field: 'location.district', order: 'ASCENDING' },
      { field: 'createdAt', order: 'DESCENDING' }
    ]
  },
  
  // Campaign indexes
  {
    collection: 'campaigns',
    fields: [
      { field: 'status', order: 'ASCENDING' },
      { field: 'scope.level', order: 'ASCENDING' },
      { field: 'startDate', order: 'DESCENDING' }
    ]
  }
];
```

### **Caching Strategy**

```typescript
interface CacheStrategy {
  // Redis cache for frequently accessed data
  userProfileCache: {
    ttl: 1800; // 30 minutes
    keyPattern: 'user:profile:{userId}';
  };
  
  geographicDataCache: {
    ttl: 3600; // 1 hour
    keyPattern: 'geo:{level}:{locationId}';
  };
  
  campaignDataCache: {
    ttl: 300; // 5 minutes
    keyPattern: 'campaign:{campaignId}';
  };
  
  analyticsCache: {
    ttl: 900; // 15 minutes
    keyPattern: 'analytics:{reportType}:{dateRange}';
  };
}
```

This comprehensive technical architecture provides a solid foundation for scaling to 5 million users while maintaining performance, security, and reliability. The database design is optimized for the specific needs of the land rights movement, and the API structure provides all necessary endpoints for the mobile and web applications.

**What specific aspect of this technical architecture would you like me to elaborate on or modify?** 🚀