# TALOWA Social Feed - Firestore Database Schema

## Collection Structure

### 1. Posts Collection (`/posts/{postId}`)

```json
{
  "id": "post_123",
  "authorId": "user_456",
  "authorName": "राम कुमार",
  "authorRole": "village_coordinator",
  "authorAvatarUrl": "https://storage.googleapis.com/talowa/avatars/user_456.jpg",
  "content": "आज हमारे गांव में भूमि सर्वेक्षण का काम शुरू हुआ। सभी किसान भाई अपने दस्तावेज तैयार रखें। #भूमि_अधिकार #सर्वेक्षण #रामपुर_गांव",
  "imageUrls": [
    "https://storage.googleapis.com/talowa/posts/post_123/image1.jpg",
    "https://storage.googleapis.com/talowa/posts/post_123/image2.jpg"
  ],
  "documentUrls": [
    "https://storage.googleapis.com/talowa/posts/post_123/survey_notice.pdf"
  ],
  "hashtags": ["भूमि_अधिकार", "सर्वेक्षण", "रामपुर_गांव"],
  "category": "announcement",
  "targeting": {
    "village": "रामपुर",
    "mandal": "सरायकेला",
    "district": "सरायकेला खरसावां",
    "state": "झारखंड",
    "scope": "village"
  },
  "visibility": "localCommunity",
  "allowedRoles": [],
  "allowedLocations": ["रामपुर"],
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": null,
  "likesCount": 15,
  "commentsCount": 3,
  "sharesCount": 2,
  "viewsCount": 45,
  "isReported": false,
  "isHidden": false,
  "moderationReason": null,
  "moderatedAt": null,
  "moderatedBy": null,
  "isPinned": false,
  "isEmergency": false
}
```

### 2. Comments Subcollection (`/posts/{postId}/comments/{commentId}`)

```json
{
  "id": "comment_789",
  "postId": "post_123",
  "authorId": "user_101",
  "authorName": "सुनीता देवी",
  "authorRole": "member",
  "authorAvatarUrl": "https://storage.googleapis.com/talowa/avatars/user_101.jpg",
  "content": "बहुत अच्छी खबर है। कब तक पूरा होगा सर्वेक्षण?",
  "createdAt": "2024-01-15T11:15:00Z",
  "updatedAt": null,
  "parentCommentId": null,
  "likesCount": 2,
  "replies": [],
  "isReported": false,
  "isHidden": false,
  "moderationReason": null,
  "moderatedAt": null,
  "moderatedBy": null
}
```

### 3. Post Engagement Subcollection (`/posts/{postId}/engagement/{userId}`)

```json
{
  "userId": "user_456",
  "postId": "post_123",
  "liked": true,
  "likedAt": "2024-01-15T10:45:00Z",
  "shared": false,
  "sharedAt": null,
  "viewedAt": "2024-01-15T10:30:00Z",
  "viewDuration": 15000
}
```

### 4. Comment Engagement Subcollection (`/posts/{postId}/comments/{commentId}/engagement/{userId}`)

```json
{
  "userId": "user_789",
  "commentId": "comment_789",
  "liked": true,
  "likedAt": "2024-01-15T11:20:00Z"
}
```

### 5. Notifications Collection (`/notifications/{notificationId}`)

```json
{
  "id": "notification_456",
  "recipientId": "user_123",
  "actorId": "user_456",
  "actorName": "राम कुमार",
  "actorAvatarUrl": "https://storage.googleapis.com/talowa/avatars/user_456.jpg",
  "type": "post_liked",
  "message": "राम कुमार ने आपकी पोस्ट को पसंद किया: \"आज हमारे गांव में भूमि सर्वेक्षण...\"",
  "postId": "post_123",
  "commentId": null,
  "isRead": false,
  "createdAt": "2024-01-15T10:45:00Z",
  "readAt": null
}
```

### 6. Hashtags Collection (`/hashtags/{hashtagId}`)

```json
{
  "id": "hashtag_123",
  "tag": "भूमि_अधिकार",
  "normalizedTag": "भूमि_अधिकार",
  "usageCount": 156,
  "lastUsed": "2024-01-15T10:30:00Z",
  "trending": true,
  "trendingScore": 45.6,
  "relatedTags": ["सर्वेक्षण", "जमीन_की_समस्या", "किसान_अधिकार"],
  "geographic": {
    "districts": ["सरायकेला खरसावां", "पूर्वी सिंहभूम"],
    "states": ["झारखंड"]
  }
}
```

### 7. Post Reports Collection (`/post_reports/{reportId}`)

```json
{
  "id": "report_789",
  "postId": "post_123",
  "reportedBy": "user_456",
  "reporterName": "अनिल कुमार",
  "reason": "inappropriate_content",
  "description": "यह पोस्ट गलत जानकारी फैला रही है",
  "status": "pending",
  "reviewedBy": null,
  "reviewedAt": null,
  "action": null,
  "createdAt": "2024-01-15T12:00:00Z"
}
```

### 8. User Analytics Collection (`/user_analytics/{userId}`)

```json
{
  "userId": "user_123",
  "totalPosts": 25,
  "totalLikes": 156,
  "totalComments": 89,
  "totalShares": 34,
  "totalViews": 1250,
  "averageEngagement": 11.16,
  "engagementRate": 0.224,
  "topHashtags": ["भूमि_अधिकार", "किसान_अधिकार", "जमीन_की_समस्या"],
  "mostEngagedPost": "post_456",
  "lastActive": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T10:30:00Z"
}
```

## Composite Indexes

### Required Firestore Indexes

1. **Posts Feed Query**
   ```
   Collection: posts
   Fields: isHidden (Ascending), targeting.district (Ascending), createdAt (Descending)
   ```

2. **Category-based Posts**
   ```
   Collection: posts
   Fields: category (Ascending), isHidden (Ascending), createdAt (Descending)
   ```

3. **Emergency Posts**
   ```
   Collection: posts
   Fields: isEmergency (Ascending), createdAt (Descending)
   ```

4. **User Posts**
   ```
   Collection: posts
   Fields: authorId (Ascending), createdAt (Descending)
   ```

5. **Hashtag Posts**
   ```
   Collection: posts
   Fields: hashtags (Array), isHidden (Ascending), createdAt (Descending)
   ```

6. **Geographic Posts**
   ```
   Collection: posts
   Fields: targeting.state (Ascending), targeting.district (Ascending), createdAt (Descending)
   ```

7. **Post Comments**
   ```
   Collection: posts/{postId}/comments
   Fields: isHidden (Ascending), createdAt (Ascending)
   ```

8. **User Notifications**
   ```
   Collection: notifications
   Fields: recipientId (Ascending), isRead (Ascending), createdAt (Descending)
   ```

9. **Trending Hashtags**
   ```
   Collection: hashtags
   Fields: trending (Ascending), trendingScore (Descending)
   ```

10. **Post Reports**
    ```
    Collection: post_reports
    Fields: status (Ascending), createdAt (Descending)
    ```

## Data Validation Rules

### Post Document Validation
- `content`: Required, string, max 2000 characters
- `authorId`: Required, string, must match authenticated user
- `category`: Required, enum value
- `hashtags`: Array of strings, max 10 items
- `imageUrls`: Array of strings, max 5 items
- `documentUrls`: Array of strings, max 3 items
- `visibility`: Required, enum value
- `targeting`: Object with geographic information

### Comment Document Validation
- `content`: Required, string, max 500 characters
- `authorId`: Required, string, must match authenticated user
- `postId`: Required, string, must reference existing post
- `parentCommentId`: Optional, string, must reference existing comment

### Engagement Document Validation
- `userId`: Required, string, must match authenticated user
- `postId`: Required, string, must reference existing post
- `liked`: Boolean
- `shared`: Boolean
- `viewedAt`: Timestamp

## Performance Considerations

### Query Optimization
1. **Limit Query Results**: Always use `.limit()` for pagination
2. **Use Composite Indexes**: Create indexes for common query patterns
3. **Avoid Array Queries**: Minimize `array-contains` queries
4. **Cache Frequently Accessed Data**: Use client-side caching

### Storage Optimization
1. **Denormalize User Data**: Store author name/avatar in posts
2. **Aggregate Counters**: Use separate documents for counts
3. **Archive Old Data**: Move old posts to separate collections
4. **Compress Images**: Store optimized image URLs

### Real-time Optimization
1. **Selective Listeners**: Only listen to necessary documents
2. **Batch Operations**: Group related writes together
3. **Connection Pooling**: Reuse Firestore connections
4. **Offline Support**: Enable offline persistence

## Security Considerations

### Data Access Patterns
1. **User-based Access**: Users can only modify their own content
2. **Role-based Permissions**: Coordinators have additional privileges
3. **Geographic Filtering**: Content visibility based on location
4. **Moderation Controls**: Coordinators can hide/remove content

### Privacy Protection
1. **Selective Data Exposure**: Only expose necessary user information
2. **Anonymous Reporting**: Allow anonymous content reporting
3. **Data Encryption**: Encrypt sensitive content at rest
4. **Audit Logging**: Log all moderation actions

## Backup and Recovery

### Backup Strategy
1. **Daily Backups**: Automated daily collection backups
2. **Point-in-time Recovery**: Enable PITR for critical collections
3. **Cross-region Replication**: Replicate to multiple regions
4. **Export Procedures**: Regular data export for compliance

### Disaster Recovery
1. **Multi-region Setup**: Deploy across multiple regions
2. **Failover Procedures**: Automated failover mechanisms
3. **Data Integrity Checks**: Regular consistency validation
4. **Recovery Testing**: Periodic disaster recovery drills