# 📱 FEED SYSTEM - Complete Reference

## 📋 Overview

The TALOWA app's Feed System provides a social platform for users to share content, view community posts, interact with stories, and engage with the agricultural community. This system includes post creation, content feeds, story features, and social interactions designed specifically for the agricultural and land rights community.

---

## 🏗️ System Architecture

### Core Components
- **Social Feed** - Main content stream with posts and updates
- **Post Creation** - Rich content creation with media support
- **Stories System** - Temporary content sharing (24-hour expiry)
- **Content Interaction** - Likes, comments, and sharing
- **Content Moderation** - Community guidelines enforcement
- **Media Management** - Image and video handling

### Data Flow
```
Content Creation → Moderation → Feed Distribution → User Interaction → Analytics
```

---

## 🔧 Implementation Details

### Key Files
```
lib/screens/feed/
├── feed_screen.dart              # Main feed display
├── post_creation_screen.dart     # Create new posts
├── post_detail_screen.dart       # Individual post view
├── stories_screen.dart           # Stories viewer
└── feed_settings_screen.dart     # Feed preferences

lib/services/
├── feed_service.dart             # Feed data management
├── post_service.dart             # Post operations
├── story_service.dart            # Stories functionality
├── content_moderation_service.dart # Content filtering
└── media_service.dart            # Media upload/processing

lib/widgets/feed/
├── post_widget.dart              # Individual post display
├── story_widget.dart             # Story display component
├── feed_item_widget.dart         # Feed item container
├── post_creation_widget.dart     # Post creation form
└── media_picker_widget.dart      # Media selection
```

### Database Schema
```javascript
// Firestore Collections
posts/{postId} {
  authorId: string,               // Post author user ID
  content: string,                // Post text content
  mediaUrls: array,               // Attached media URLs
  hashtags: array,                // Post hashtags
  mentions: array,                // Mentioned users
  likes: number,                  // Like count
  comments: number,               // Comment count
  shares: number,                 // Share count
  visibility: string,             // public, friends, private
  location: object,               // Geographic location
  createdAt: timestamp,
  updatedAt: timestamp,
  isActive: boolean,              // Moderation status
  reportCount: number             // Report count for moderation
}

stories/{storyId} {
  authorId: string,               // Story author
  mediaUrl: string,               // Story media (image/video)
  caption: string,                // Story caption
  viewers: array,                 // Users who viewed
  createdAt: timestamp,
  expiresAt: timestamp,           // 24 hours from creation
  isActive: boolean
}

comments/{commentId} {
  postId: string,                 // Parent post
  authorId: string,               // Comment author
  content: string,                // Comment text
  likes: number,                  // Comment likes
  replies: array,                 // Reply comment IDs
  createdAt: timestamp,
  isActive: boolean
}

feed_interactions/{interactionId} {
  userId: string,                 // User who interacted
  postId: string,                 // Target post
  type: string,                   // like, comment, share, report
  createdAt: timestamp
}
```

---

## 🎯 Features & Functionality

### 1. Social Feed Display
- **Chronological Feed** - Latest posts first with pagination
- **Personalized Content** - Algorithm-based content relevance
- **Rich Media Support** - Images, videos, and documents
- **Interactive Elements** - Like, comment, share buttons
- **User Profiles** - Author information and profile links
- **Content Filtering** - Hide inappropriate or reported content

### 2. Post Creation System
- **Rich Text Editor** - Formatted text with styling options
- **Media Attachment** - Multiple image/video uploads
- **Hashtag Support** - Automatic hashtag detection and linking
- **User Mentions** - @username mentions with notifications
- **Location Tagging** - Geographic location attachment
- **Privacy Controls** - Public, friends-only, or private posts
- **Draft Saving** - Save posts as drafts for later

### 3. Stories Feature
- **24-Hour Expiry** - Temporary content sharing
- **Media Stories** - Image and video stories
- **Story Viewer** - Full-screen story viewing experience
- **View Tracking** - See who viewed your stories
- **Story Highlights** - Save important stories permanently
- **Story Reactions** - Quick emoji reactions

### 4. Content Interaction
- **Like System** - Heart-based appreciation system
- **Comment Threading** - Nested comment conversations
- **Share Functionality** - Share posts to other platforms
- **Save Posts** - Bookmark posts for later viewing
- **Report Content** - Community moderation reporting
- **Block Users** - Hide content from specific users

### 5. Content Moderation
- **Automated Filtering** - AI-based inappropriate content detection
- **Community Reporting** - User-driven content reporting
- **Admin Review** - Manual review of reported content
- **Content Removal** - Remove violating content
- **User Warnings** - Progressive discipline system
- **Appeal Process** - Content removal appeal system

---

## 🔄 User Flows

### Creating a Post
1. **Access Feed Tab** - Navigate to Feed section
2. **Tap Create Button** - Open post creation interface
3. **Add Content** - Enter text, add media, hashtags
4. **Set Privacy** - Choose visibility settings
5. **Add Location** (optional) - Tag geographic location
6. **Preview Post** - Review content before posting
7. **Publish** - Share with community

### Viewing Feed Content
1. **Open Feed Tab** - Access main feed screen
2. **Scroll Through Posts** - Browse chronological content
3. **Interact with Posts** - Like, comment, share
4. **View User Profiles** - Tap on author names/avatars
5. **Access Post Details** - Tap for full post view
6. **Manage Interactions** - Edit/delete own comments

### Stories Interaction
1. **View Story Indicators** - See available stories at top
2. **Tap Story Circle** - Open story viewer
3. **Navigate Stories** - Swipe through story sequence
4. **React to Stories** - Send quick emoji reactions
5. **Create Own Story** - Add to your story collection
6. **Manage Story Privacy** - Control who can view

---

## 🎨 UI/UX Design

### Feed Layout
- **Card-based Design** - Individual post cards with shadows
- **Infinite Scroll** - Seamless content loading
- **Pull-to-Refresh** - Manual feed refresh capability
- **Floating Action Button** - Quick post creation access
- **Story Bar** - Horizontal story indicators at top

### Post Design Elements
- **Author Header** - Profile picture, name, timestamp
- **Content Area** - Text content with proper typography
- **Media Gallery** - Responsive image/video display
- **Interaction Bar** - Like, comment, share buttons
- **Engagement Metrics** - Like and comment counts

### Color Scheme
- **Primary Green** - TALOWA brand color for interactions
- **Content Background** - White cards on light grey background
- **Text Hierarchy** - Dark grey for content, light grey for metadata
- **Action Colors** - Red for likes, blue for shares, green for saves

---

## 🛡️ Security & Content Safety

### Content Moderation
```dart
class ContentModerationService {
  static Future<bool> moderateContent(String content, List<String> mediaUrls) async {
    // Check for inappropriate text content
    final textResult = await _checkTextContent(content);
    
    // Check media content
    final mediaResult = await _checkMediaContent(mediaUrls);
    
    // Apply community guidelines
    return textResult && mediaResult;
  }
  
  static Future<void> reportContent(String postId, String reason, String reporterId) async {
    await FirebaseFirestore.instance.collection('content_reports').add({
      'postId': postId,
      'reason': reason,
      'reporterId': reporterId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Auto-hide content if multiple reports
    await _checkReportThreshold(postId);
  }
}
```

### Privacy Controls
- **Post Visibility** - Public, friends, private options
- **Profile Privacy** - Control who can see your posts
- **Block/Unblock** - User blocking functionality
- **Content Filtering** - Hide sensitive content
- **Data Protection** - GDPR-compliant data handling

---

## 🔧 Configuration & Setup

### Feed Algorithm Configuration
```dart
class FeedConfig {
  static const int postsPerPage = 10;
  static const int maxMediaPerPost = 5;
  static const int maxPostLength = 2000;
  static const Duration storyExpiry = Duration(hours: 24);
  
  // Content scoring weights
  static const Map<String, double> engagementWeights = {
    'like': 1.0,
    'comment': 2.0,
    'share': 3.0,
    'save': 2.5,
  };
}
```

### Media Upload Settings
```dart
class MediaConfig {
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxVideoSize = 50 * 1024 * 1024; // 50MB
  static const Duration maxVideoDuration = Duration(minutes: 5);
  
  static const List<String> allowedImageTypes = [
    'image/jpeg', 'image/png', 'image/gif'
  ];
  
  static const List<String> allowedVideoTypes = [
    'video/mp4', 'video/mov', 'video/avi'
  ];
}
```

---

## 🐛 Common Issues & Solutions

### Feed Not Loading
**Problem**: Feed content not displaying or loading slowly
**Solutions**:
- Check internet connectivity
- Verify Firestore security rules
- Clear app cache and restart
- Check for API rate limiting
- Review pagination implementation

### Media Upload Failures
**Problem**: Images or videos not uploading
**Solutions**:
- Check file size limits
- Verify supported file formats
- Test network connection stability
- Review Firebase Storage rules
- Check device storage permissions

### Content Not Appearing
**Problem**: Posted content not visible in feed
**Solutions**:
- Check content moderation status
- Verify post privacy settings
- Review user blocking status
- Check for shadow banning
- Validate post creation timestamp

### Performance Issues
**Problem**: Feed scrolling lag or app crashes
**Solutions**:
- Implement image lazy loading
- Optimize media compression
- Add pagination limits
- Cache frequently accessed content
- Profile memory usage

---

## 📊 Analytics & Monitoring

### Key Metrics
```dart
class FeedAnalytics {
  static void trackPostCreation(String postType, int mediaCount) {
    FirebaseAnalytics.instance.logEvent(
      name: 'post_created',
      parameters: {
        'post_type': postType,
        'media_count': mediaCount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }
  
  static void trackEngagement(String postId, String engagementType) {
    FirebaseAnalytics.instance.logEvent(
      name: 'post_engagement',
      parameters: {
        'post_id': postId,
        'engagement_type': engagementType,
      },
    );
  }
  
  static void trackFeedView(int postsViewed, Duration timeSpent) {
    FirebaseAnalytics.instance.logEvent(
      name: 'feed_session',
      parameters: {
        'posts_viewed': postsViewed,
        'time_spent_seconds': timeSpent.inSeconds,
      },
    );
  }
}
```

### Performance Monitoring
- **Feed Load Time** - Time to display initial content
- **Post Engagement Rate** - Likes, comments, shares per post
- **Content Creation Rate** - Posts created per user per day
- **Story View Rate** - Story completion rates
- **Content Report Rate** - Moderation effectiveness metrics

---

## 🚀 Recent Improvements

### Enhanced Feed Experience ✅ **IMPLEMENTED**
- **Improved Loading** - Faster content loading with pagination
- **Better Media Handling** - Optimized image and video display
- **Enhanced Interactions** - Smoother like, comment, share actions
- **Story Integration** - Seamless story viewing experience

### Content Moderation ✅ **ENHANCED**
- **Automated Filtering** - AI-powered content screening
- **Community Reporting** - User-driven moderation system
- **Admin Tools** - Enhanced moderation dashboard
- **Appeal Process** - Fair content review system

### Performance Optimizations ✅ **COMPLETED**
- **Lazy Loading** - Load content as needed
- **Image Compression** - Automatic media optimization
- **Caching Strategy** - Smart content caching
- **Memory Management** - Reduced memory footprint

---

## 🔮 Future Enhancements

### Planned Features
1. **Live Streaming** - Real-time video broadcasting
2. **Advanced Filters** - Content filtering by topics, location
3. **Collaborative Posts** - Multi-author content creation
4. **Event Integration** - Link posts to community events
5. **Marketplace Integration** - Buy/sell within feed posts

### Advanced Features
1. **AI Content Suggestions** - Personalized content recommendations
2. **Voice Posts** - Audio content sharing
3. **AR Filters** - Augmented reality post enhancements
4. **Translation Services** - Multi-language content support
5. **Offline Reading** - Download posts for offline viewing

---

## 📞 Support & Troubleshooting

### Debug Commands
```bash
# Test feed functionality
flutter run --debug

# Check Firestore rules
firebase firestore:rules:get

# Monitor feed performance
flutter run --profile

# Test media upload
node test_media_upload.js
```

### Common Debug Steps
1. **Check Network Connection** - Verify internet connectivity
2. **Review Firestore Rules** - Ensure proper read/write permissions
3. **Test Media Permissions** - Verify camera and storage access
4. **Clear App Cache** - Reset cached content
5. **Check User Authentication** - Verify user login status

---

## 📋 Testing Procedures

### Manual Testing Checklist
- [ ] Feed loads with recent posts
- [ ] Post creation works with text and media
- [ ] Like, comment, share functions work
- [ ] Stories display and expire correctly
- [ ] Content moderation filters inappropriate content
- [ ] Media uploads successfully
- [ ] Privacy settings function properly
- [ ] Reporting system works

### Automated Testing
```dart
group('Feed System Tests', () {
  testWidgets('Feed displays posts correctly', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: FeedScreen()));
    await tester.pumpAndSettle();
    
    // Verify feed components
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(PostWidget), findsWidgets);
  });
  
  testWidgets('Post creation flow', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: PostCreationScreen()));
    
    // Test post creation
    await tester.enterText(find.byType(TextField), 'Test post content');
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    
    // Verify post creation
    expect(find.text('Post created successfully'), findsOneWidget);
  });
});
```

---

## 📚 Related Documentation

- **[Navigation System](NAVIGATION_SYSTEM.md)** - Feed tab navigation
- **[Authentication System](AUTHENTICATION_SYSTEM.md)** - User authentication for posting
- **[Network System](NETWORK_SYSTEM.md)** - Community connections and feed
- **[Admin System](ADMIN_SYSTEM.md)** - Content moderation tools
- **[Security System](SECURITY_SYSTEM.md)** - Content safety measures

---

**Status**: ✅ Fully Functional  
**Last Updated**: January 2025  
**Priority**: High (Core Social Feature)  
**Maintainer**: Social Features Team