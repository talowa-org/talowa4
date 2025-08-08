# TALOWA Social Feed Implementation Plan
## Instagram-like Feed & Stories Feature

### **📱 New Tab Addition: FEED Tab**

Adding a 6th tab to the navigation:

```
┌─────────────────────────────────────────────────────────────┐
│  🏠      📱      💬      👥      📋      👤                 │
│ Home    Feed   Messages Network  Cases  Profile             │
└─────────────────────────────────────────────────────────────┘
```

### **📱 FEED TAB - Main Interface**

```
┌─────────────────────────────────────┐
│ 📱 TALOWA Feed                      │
│ [🔍 Search] [📊 Trending] [⚙️]       │
├─────────────────────────────────────┤
│ 📖 STORIES (Coordinators Only)      │
│ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐     │
│ │👨‍🌾│ │🏛️│ │⚖️│ │📢│ │👩‍🌾│     │
│ │Ravi│ │DC │ │Law│ │Med│ │Priya│    │
│ └───┘ └───┘ └───┘ └───┘ └───┘     │
├─────────────────────────────────────┤
│ 📰 FEED POSTS                       │
│                                     │
│ 👨‍🌾 Ravi Kumar • Village Coordinator │
│ 📍 Kondapur Village • 2 hours ago   │
│ ┌─────────────────────────────────┐ │
│ │ 🎉 GREAT NEWS! 15 farmers in   │ │
│ │ our village received pattas     │ │
│ │ today! This is the result of    │ │
│ │ our 6-month campaign. 💪        │ │
│ │                                 │ │
│ │ [📷 Photo of celebration]       │ │
│ └─────────────────────────────────┘ │
│ 👍 47 likes • 💬 12 comments        │
│ 📤 23 shares • 🏷️ #PattaSuccess     │
│                                     │
│ 🏛️ District Coordinator Hyderabad   │
│ 📍 Hyderabad District • 4 hours ago │
│ ┌─────────────────────────────────┐ │
│ │ 📢 URGENT: Land grabbing        │ │
│ │ reported in 3 villages. Legal   │ │
│ │ team dispatched. All village    │ │
│ │ coordinators please be alert.   │ │
│ │                                 │ │
│ │ [📍 Location map attached]      │ │
│ └─────────────────────────────────┘ │
│ 🚨 89 reactions • 💬 34 comments    │
│                                     │
│ [Load More Posts...]                │
└─────────────────────────────────────┘
```

### **📖 Stories Feature**

```
┌─────────────────────────────────────┐
│ 📖 Story - Ravi Kumar               │
│ Village Coordinator • Kondapur      │
├─────────────────────────────────────┤
│                                     │
│        [📷 Photo/Video]             │
│                                     │
│     "Village meeting today!         │
│      50+ farmers attending          │
│      discussing patta process"      │
│                                     │
│ ●●●●●○○○○○ 4/10                     │
│                                     │
│ 👁️ 234 views • 2 hours ago          │
├─────────────────────────────────────┤
│ [❤️] [💬] [📤] [📍]                  │
│ React Comment Share Location        │
└─────────────────────────────────────┘
```

## 🔧 **Implementation Strategy**

### **1. Role-Based Posting Permissions**

```typescript
interface PostingPermissions {
  canCreatePosts: boolean;
  canCreateStories: boolean;
  canPin: boolean;
  canModerate: boolean;
  maxPostsPerDay: number;
  requiresApproval: boolean;
}

const rolePermissions: Record<UserRole, PostingPermissions> = {
  'Member': {
    canCreatePosts: false,
    canCreateStories: false,
    canPin: false,
    canModerate: false,
    maxPostsPerDay: 0,
    requiresApproval: false,
  },
  'Village Coordinator': {
    canCreatePosts: true,
    canCreateStories: true,
    canPin: false,
    canModerate: false,
    maxPostsPerDay: 5,
    requiresApproval: false,
  },
  'Mandal Coordinator': {
    canCreatePosts: true,
    canCreateStories: true,
    canPin: true,
    canModerate: true,
    maxPostsPerDay: 10,
    requiresApproval: false,
  },
  'District Coordinator': {
    canCreatePosts: true,
    canCreateStories: true,
    canPin: true,
    canModerate: true,
    maxPostsPerDay: 20,
    requiresApproval: false,
  },
  // ... other roles
};
```

### **2. Content Types & Categories**

```typescript
enum PostType {
  SUCCESS_STORY = 'success_story',
  CAMPAIGN_UPDATE = 'campaign_update',
  LEGAL_UPDATE = 'legal_update',
  EMERGENCY_ALERT = 'emergency_alert',
  MEETING_ANNOUNCEMENT = 'meeting_announcement',
  EDUCATIONAL_CONTENT = 'educational_content',
  MEDIA_COVERAGE = 'media_coverage',
  GOVERNMENT_UPDATE = 'government_update',
}

enum ContentCategory {
  PATTA_SUCCESS = 'patta_success',
  LAND_RIGHTS = 'land_rights',
  LEGAL_AID = 'legal_aid',
  COMMUNITY_BUILDING = 'community_building',
  GOVERNMENT_SCHEMES = 'government_schemes',
  TRAINING_EDUCATION = 'training_education',
}
```

### **3. Feed Algorithm & Prioritization**

```typescript
interface FeedAlgorithm {
  // Priority scoring for posts
  calculatePostScore(post: FeedPost, user: User): number;
  
  // Geographic relevance
  getGeographicRelevance(post: FeedPost, user: User): number;
  
  // Role-based importance
  getRoleBasedPriority(posterRole: UserRole, viewerRole: UserRole): number;
  
  // Engagement-based scoring
  getEngagementScore(post: FeedPost): number;
  
  // Time decay factor
  getTimeFactor(postTime: Date): number;
}

// Example scoring algorithm
function calculateFeedScore(post: FeedPost, viewer: User): number {
  let score = 0;
  
  // Geographic proximity (higher score for local content)
  if (post.location.village === viewer.location.village) score += 50;
  else if (post.location.mandal === viewer.location.mandal) score += 30;
  else if (post.location.district === viewer.location.district) score += 20;
  else if (post.location.state === viewer.location.state) score += 10;
  
  // Role-based priority
  const rolePriority = {
    'District Coordinator': 40,
    'Mandal Coordinator': 30,
    'Village Coordinator': 20,
    'Legal Advisor': 35,
    'Media Coordinator': 25,
  };
  score += rolePriority[post.authorRole] || 0;
  
  // Content type priority
  const contentPriority = {
    'emergency_alert': 100,
    'success_story': 30,
    'legal_update': 25,
    'campaign_update': 20,
  };
  score += contentPriority[post.type] || 0;
  
  // Engagement score
  score += (post.likes * 0.5) + (post.comments * 1) + (post.shares * 2);
  
  // Time decay (newer posts get higher scores)
  const hoursOld = (Date.now() - post.createdAt.getTime()) / (1000 * 60 * 60);
  score *= Math.exp(-hoursOld / 24); // Exponential decay over 24 hours
  
  return score;
}
```

### **4. Database Schema**

```typescript
// Collection: feed_posts
interface FeedPost {
  id: string;
  authorId: string;
  authorName: string;
  authorRole: UserRole;
  authorLocation: GeographicLocation;
  
  // Content
  content: string;
  type: PostType;
  category: ContentCategory;
  hashtags: string[];
  
  // Media
  images: string[];
  videos: string[];
  documents: string[];
  
  // Engagement
  likes: number;
  comments: number;
  shares: number;
  views: number;
  
  // Targeting
  visibility: 'public' | 'state' | 'district' | 'mandal' | 'village';
  targetAudience: string[];
  
  // Metadata
  createdAt: Timestamp;
  updatedAt: Timestamp;
  isPinned: boolean;
  isApproved: boolean;
  moderationStatus: 'pending' | 'approved' | 'rejected';
  
  // Integration
  linkedCampaignId?: string;
  linkedCaseId?: string;
  linkedLandRecordId?: string;
}

// Collection: feed_stories
interface FeedStory {
  id: string;
  authorId: string;
  authorName: string;
  authorRole: UserRole;
  
  // Content
  mediaUrl: string;
  mediaType: 'image' | 'video';
  caption?: string;
  duration: number; // For videos
  
  // Engagement
  views: number;
  reactions: { [userId: string]: string };
  
  // Lifecycle
  createdAt: Timestamp;
  expiresAt: Timestamp; // 24 hours from creation
  isActive: boolean;
}

// Collection: feed_interactions
interface FeedInteraction {
  id: string;
  userId: string;
  postId: string;
  type: 'like' | 'comment' | 'share' | 'view';
  content?: string; // For comments
  timestamp: Timestamp;
}
```

### **5. Content Creation Interface**

```
┌─────────────────────────────────────┐
│ ➕ Create Post                      │
├─────────────────────────────────────┤
│ 📝 CONTENT TYPE                     │
│ ○ Success Story                     │
│ ○ Campaign Update                   │
│ ○ Legal Update                      │
│ ● Meeting Announcement              │
│ ○ Emergency Alert                   │
│ ○ Educational Content               │
├─────────────────────────────────────┤
│ 📝 WRITE YOUR POST                  │
│ ┌─────────────────────────────────┐ │
│ │ 🎉 Village meeting scheduled!   │ │
│ │                                 │ │
│ │ Join us tomorrow at 6 PM in    │ │
│ │ the community hall to discuss   │ │
│ │ patta applications and new      │ │
│ │ government schemes.             │ │
│ │                                 │ │
│ │ Agenda:                         │ │
│ │ • Patta application process     │ │
│ │ • Legal aid updates             │ │
│ │ • Success stories sharing       │ │
│ │                                 │ │
│ │ #VillageMeeting #PattaProcess   │ │
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│ 📷 ADD MEDIA                        │
│ [📷 Photo] [🎥 Video] [📄 Document] │
│                                     │
│ 📍 LOCATION                         │
│ ✅ Kondapur Village Community Hall  │
│                                     │
│ 👥 AUDIENCE                         │
│ ● Village Members (47 people)       │
│ ○ Mandal Members (234 people)       │
│ ○ District Members (2.1K people)    │
│                                     │
│ 🏷️ TAGS & CATEGORIES                │
│ Selected: #VillageMeeting #Patta    │
│ Suggested: #CommunityBuilding       │
├─────────────────────────────────────┤
│ [📤 Post Now] [💾 Save Draft]       │
└─────────────────────────────────────┘
```

### **6. Engagement Features**

```typescript
// Reaction system
interface ReactionSystem {
  reactions: {
    '👍': 'support',
    '❤️': 'love',
    '🎉': 'celebrate',
    '💪': 'strength',
    '🙏': 'gratitude',
    '😢': 'concern',
    '😡': 'anger',
    '🔥': 'urgent',
  };
}

// Comment system with threading
interface Comment {
  id: string;
  postId: string;
  authorId: string;
  content: string;
  parentCommentId?: string; // For replies
  likes: number;
  replies: Comment[];
  createdAt: Timestamp;
}
```

### **7. Moderation & Safety**

```typescript
interface ModerationSystem {
  // Auto-moderation
  detectInappropriateContent(content: string): boolean;
  flagSuspiciousActivity(userId: string, actions: UserAction[]): boolean;
  
  // Manual moderation
  reportPost(postId: string, reason: string, reporterId: string): void;
  reviewReportedContent(postId: string, moderatorId: string): void;
  
  // Content guidelines
  validatePost(post: FeedPost): ValidationResult;
}

// Content guidelines for TALOWA
const contentGuidelines = {
  prohibited: [
    'Hate speech or discrimination',
    'Violence or threats',
    'Misinformation about legal processes',
    'Personal attacks on individuals',
    'Spam or irrelevant content',
  ],
  encouraged: [
    'Success stories and achievements',
    'Educational content about land rights',
    'Community building activities',
    'Legal updates and guidance',
    'Government scheme information',
  ],
};
```

### **8. Analytics & Insights**

```typescript
interface FeedAnalytics {
  // Post performance
  getPostMetrics(postId: string): PostMetrics;
  
  // User engagement
  getUserEngagement(userId: string): EngagementMetrics;
  
  // Content trends
  getTrendingHashtags(): string[];
  getPopularContent(timeframe: string): FeedPost[];
  
  // Geographic insights
  getRegionalEngagement(): RegionalMetrics;
}

interface PostMetrics {
  views: number;
  likes: number;
  comments: number;
  shares: number;
  reach: number;
  engagement_rate: number;
  geographic_distribution: { [location: string]: number };
}
```

## 🎯 **Key Benefits for TALOWA Movement**

### **1. Movement Visibility**
- **Success Stories**: Showcase patta victories and legal wins
- **Real-time Updates**: Keep members informed about campaigns
- **Media Coverage**: Share news articles and TV coverage
- **Government Accountability**: Highlight government actions/inactions

### **2. Community Building**
- **Local Heroes**: Celebrate coordinators and active members
- **Knowledge Sharing**: Educational content about land rights
- **Event Coordination**: Meeting announcements and rally updates
- **Peer Support**: Members can see others facing similar issues

### **3. Engagement & Motivation**
- **Visual Impact**: Photos and videos of protests, meetings, victories
- **Emotional Connection**: Stories create stronger bonds than text
- **Viral Potential**: Important content can spread quickly
- **Recognition**: Coordinators get visibility for their work

### **4. Strategic Communication**
- **Targeted Messaging**: Different content for different regions
- **Crisis Communication**: Emergency alerts with visual evidence
- **Campaign Coordination**: Real-time updates during protests
- **Documentation**: Visual record of movement activities

## 🚀 **Implementation Phases**

### **Phase 1: Basic Feed (Month 1)**
- Simple post creation for coordinators
- Basic feed display with chronological order
- Like and comment functionality
- Image/video upload

### **Phase 2: Stories & Advanced Features (Month 2)**
- Stories feature with 24-hour expiry
- Advanced feed algorithm with geographic relevance
- Hashtags and content categorization
- Share functionality

### **Phase 3: Engagement & Moderation (Month 3)**
- Reaction system beyond likes
- Comment threading and replies
- Content moderation tools
- Analytics dashboard for coordinators

### **Phase 4: Advanced Features (Month 4)**
- Live streaming for events
- Polls and surveys
- Event integration
- Advanced targeting options

This Instagram-like feed would transform TALOWA from just an organizational tool into a powerful social movement platform, creating stronger community bonds and more effective communication across the entire network!