# Social Feed System Design Document

## Overview

The TALOWA Social Feed System is designed as a community-focused social platform that prioritizes local content, coordinator-led communication, and privacy-protected engagement. The system uses a geographic-first approach where content is organized and prioritized based on location relevance and user roles.

## Architecture

### Core Components

1. **FeedService** - Central service managing feed logic and content delivery
2. **PostModel** - Data model for social posts with rich content support
3. **FeedScreen** - Main UI displaying the social feed
4. **PostCreationScreen** - Interface for creating new posts (coordinators only)
5. **PostDetailScreen** - Detailed view of individual posts with comments
6. **ContentModerationService** - Handles content filtering and safety
7. **EngagementService** - Manages likes, comments, shares, and notifications

### Data Flow Architecture

```
User Input → FeedScreen → FeedService → Firestore
                ↓
    Real-time Updates ← Cloud Functions ← Firestore Changes
                ↓
    LocalizationService → UI Updates → User Display
```

## Components and Interfaces

### 1. FeedService

```dart
class FeedService {
  // Core feed operations
  static Future<List<PostModel>> getFeedPosts({
    String? userId,
    GeographicLocation? userLocation,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  });
  
  static Future<PostModel> createPost({
    required String authorId,
    required String content,
    List<String>? imageUrls,
    List<String>? documentUrls,
    List<String>? hashtags,
    PostCategory category,
    GeographicTargeting? targeting,
  });
  
  static Future<void> deletePost(String postId, String userId);
  static Future<void> reportPost(String postId, String reason);
  
  // Engagement operations
  static Future<void> likePost(String postId, String userId);
  static Future<void> unlikePost(String postId, String userId);
  static Future<void> addComment(String postId, CommentModel comment);
  static Future<void> sharePost(String postId, String userId);
  
  // Content discovery
  static Future<List<PostModel>> searchPosts(String query);
  static Future<List<String>> getTrendingHashtags(GeographicLocation location);
  static Future<List<PostModel>> getPostsByHashtag(String hashtag);
  static Future<List<PostModel>> getPostsByCategory(PostCategory category);
}
```

### 2. PostModel

```dart
class PostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorRole;
  final String content;
  final List<String> imageUrls;
  final List<String> documentUrls;
  final List<String> hashtags;
  final PostCategory category;
  final GeographicTargeting targeting;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Engagement data
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isLikedByCurrentUser;
  final List<CommentModel> recentComments;
  
  // Moderation data
  final bool isReported;
  final bool isHidden;
  final String? moderationReason;
  
  // Privacy and access
  final PostVisibility visibility;
  final List<String> allowedRoles;
  final List<String> allowedLocations;
}

enum PostCategory {
  successStory,
  legalUpdate,
  announcement,
  emergency,
  generalDiscussion,
  landRights,
  communityNews,
}

enum PostVisibility {
  public,
  coordinatorsOnly,
  localCommunity,
  directNetwork,
}

class GeographicTargeting {
  final String? village;
  final String? mandal;
  final String? district;
  final String? state;
  final double? radiusKm;
  final GeoPoint? centerPoint;
}
```

### 3. CommentModel

```dart
class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final String? parentCommentId; // For replies
  final int likesCount;
  final bool isLikedByCurrentUser;
  final bool isReported;
  final bool isHidden;
}
```

### 4. FeedScreen UI Structure

```dart
class FeedScreen extends StatefulWidget {
  // Main feed interface with:
  // - Pull-to-refresh functionality
  // - Infinite scroll loading
  // - Real-time updates
  // - Category filters
  // - Search functionality
  // - Post creation FAB (coordinators only)
}

class PostWidget extends StatelessWidget {
  // Individual post display with:
  // - Author information and role badge
  // - Rich content display (text, images, documents)
  // - Hashtag highlighting
  // - Engagement buttons (like, comment, share)
  // - Geographic scope indicator
  // - Timestamp and category badge
}

class PostCreationScreen extends StatefulWidget {
  // Post creation interface with:
  // - Rich text editor
  // - Image picker and preview
  // - Document attachment
  // - Hashtag suggestions
  // - Category selection
  // - Geographic targeting
  // - Privacy settings
}
```

## Data Models

### Firestore Collections

#### Posts Collection (`/posts/{postId}`)
```json
{
  "id": "post_123",
  "authorId": "user_456",
  "authorName": "राम कुमार",
  "authorRole": "village_coordinator",
  "content": "आज हमारे गांव में भूमि सर्वेक्षण का काम शुरू हुआ। #भूमि_अधिकार #सर्वेक्षण",
  "imageUrls": ["gs://talowa/posts/post_123/image1.jpg"],
  "documentUrls": ["gs://talowa/posts/post_123/survey_doc.pdf"],
  "hashtags": ["भूमि_अधिकार", "सर्वेक्षण"],
  "category": "announcement",
  "targeting": {
    "village": "रामपुर",
    "mandal": "सरायकेला",
    "district": "सरायकेला खरसावां",
    "state": "झारखंड"
  },
  "visibility": "localCommunity",
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": null,
  "likesCount": 15,
  "commentsCount": 3,
  "sharesCount": 2,
  "isReported": false,
  "isHidden": false,
  "moderationReason": null
}
```

#### Comments Collection (`/posts/{postId}/comments/{commentId}`)
```json
{
  "id": "comment_789",
  "postId": "post_123",
  "authorId": "user_101",
  "authorName": "सुनीता देवी",
  "content": "बहुत अच्छी खबर है। कब तक पूरा होगा?",
  "createdAt": "2024-01-15T11:15:00Z",
  "parentCommentId": null,
  "likesCount": 2,
  "isReported": false,
  "isHidden": false
}
```

#### Post Engagement Collection (`/posts/{postId}/engagement/{userId}`)
```json
{
  "userId": "user_456",
  "postId": "post_123",
  "liked": true,
  "likedAt": "2024-01-15T10:45:00Z",
  "shared": false,
  "sharedAt": null,
  "viewedAt": "2024-01-15T10:30:00Z"
}
```

## Error Handling

### Content Creation Errors
1. **Image Upload Failures**
   - Retry mechanism with exponential backoff
   - Fallback to text-only post
   - User notification with retry option

2. **Content Validation Errors**
   - Real-time validation feedback
   - Specific error messages for each field
   - Suggestion for corrections

3. **Permission Errors**
   - Clear messaging about role requirements
   - Redirect to appropriate screens
   - Contact coordinator option

### Feed Loading Errors
1. **Network Connectivity Issues**
   - Offline mode with cached content
   - Retry mechanism with user control
   - Data usage optimization

2. **Content Filtering Errors**
   - Graceful degradation
   - Error logging for debugging
   - Fallback to basic feed

## Testing Strategy

### Unit Tests
1. **FeedService Tests**
   - Post creation and validation
   - Feed filtering and sorting
   - Engagement operations
   - Error handling scenarios

2. **PostModel Tests**
   - Data serialization/deserialization
   - Validation logic
   - Geographic targeting logic

### Integration Tests
1. **Feed Flow Tests**
   - End-to-end post creation
   - Feed loading and pagination
   - Real-time updates
   - Offline synchronization

2. **Engagement Tests**
   - Like/unlike operations
   - Comment creation and replies
   - Share functionality
   - Notification delivery

### Widget Tests
1. **FeedScreen Tests**
   - Post display and formatting
   - Infinite scroll behavior
   - Pull-to-refresh functionality
   - Filter and search UI

2. **PostCreationScreen Tests**
   - Form validation
   - Image and document handling
   - Geographic targeting UI
   - Permission-based UI changes

## Performance Considerations

### Feed Loading Optimization
- Implement pagination with 20 posts per page
- Use Firestore composite indexes for efficient queries
- Cache frequently accessed posts locally
- Lazy load images and documents

### Real-time Updates
- Use Firestore real-time listeners efficiently
- Implement connection pooling
- Batch multiple updates together
- Optimize for mobile data usage

### Content Storage
- Compress images before upload
- Use CDN for media delivery
- Implement automatic cleanup of old content
- Optimize document storage and access

## Security Considerations

### Content Security
- Validate all user input on client and server
- Scan uploaded files for malware
- Implement rate limiting for post creation
- Use secure file upload with signed URLs

### Privacy Protection
- Implement role-based access control
- Geographic content filtering
- Anonymous reporting system
- Audit logging for sensitive operations

### Data Protection
- Encrypt sensitive content at rest
- Use HTTPS for all communications
- Implement proper session management
- Regular security audits and updates