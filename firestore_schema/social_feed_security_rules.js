// TALOWA Social Feed - Firestore Security Rules
// Comprehensive security rules for social feed functionality

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions for user authentication and roles
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function getUserId() {
      return request.auth.uid;
    }
    
    function getUserData() {
      return get(/databases/$(database)/documents/users/$(getUserId())).data;
    }
    
    function isCoordinator() {
      return isAuthenticated() && 
             getUserData().role != null && 
             (getUserData().role.matches('.*coordinator.*') || 
              getUserData().role.matches('.*admin.*'));
    }
    
    function isPostAuthor(postData) {
      return isAuthenticated() && postData.authorId == getUserId();
    }
    
    function isCommentAuthor(commentData) {
      return isAuthenticated() && commentData.authorId == getUserId();
    }
    
    function canViewPost(postData) {
      // Hidden posts only visible to coordinators and author
      if (postData.isHidden == true) {
        return isCoordinator() || isPostAuthor(postData);
      }
      
      // Check visibility rules
      if (postData.visibility == 'public') {
        return true;
      } else if (postData.visibility == 'coordinatorsOnly') {
        return isCoordinator();
      } else if (postData.visibility == 'localCommunity') {
        // Check if user is in the same geographic area
        let userData = getUserData();
        return userData.district == postData.targeting.district;
      } else if (postData.visibility == 'directNetwork') {
        // For now, allow all authenticated users
        // In production, implement network relationship check
        return isAuthenticated();
      }
      
      return false;
    }
    
    function canCreatePost(postData) {
      // Emergency posts require coordinator role
      if (postData.isEmergency == true) {
        return isCoordinator();
      }
      
      // Some categories require coordinator role
      if (postData.category == 'legalUpdate' || 
          postData.category == 'announcement') {
        return isCoordinator();
      }
      
      // All authenticated users can create general posts
      return isAuthenticated();
    }
    
    function canModifyPost(postData) {
      return isPostAuthor(postData) || isCoordinator();
    }
    
    function isValidPostData(postData) {
      return postData.keys().hasAll(['authorId', 'content', 'category', 'createdAt']) &&
             postData.authorId == getUserId() &&
             postData.content is string &&
             postData.content.size() > 0 &&
             postData.content.size() <= 2000 &&
             postData.category in ['successStory', 'legalUpdate', 'announcement', 
                                   'emergency', 'generalDiscussion', 'landRights', 
                                   'communityNews', 'education', 'healthAndSafety', 'agriculture'] &&
             postData.hashtags is list &&
             postData.hashtags.size() <= 10 &&
             postData.imageUrls is list &&
             postData.imageUrls.size() <= 5 &&
             postData.documentUrls is list &&
             postData.documentUrls.size() <= 3;
    }
    
    function isValidCommentData(commentData) {
      return commentData.keys().hasAll(['authorId', 'content', 'postId', 'createdAt']) &&
             commentData.authorId == getUserId() &&
             commentData.content is string &&
             commentData.content.size() > 0 &&
             commentData.content.size() <= 500;
    }
    
    // Posts collection rules
    match /posts/{postId} {
      // Read rules
      allow read: if isAuthenticated() && canViewPost(resource.data);
      
      // Create rules
      allow create: if isAuthenticated() && 
                       canCreatePost(request.resource.data) &&
                       isValidPostData(request.resource.data);
      
      // Update rules (for engagement counters and moderation)
      allow update: if isAuthenticated() && (
        // Author can update their own posts (limited fields)
        (isPostAuthor(resource.data) && 
         request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['content', 'hashtags', 'imageUrls', 'documentUrls', 'updatedAt'])) ||
        
        // Coordinators can moderate posts
        (isCoordinator() && 
         request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['isHidden', 'moderationReason', 'moderatedAt', 'moderatedBy', 'isPinned'])) ||
        
        // System updates for engagement counters
        request.resource.data.diff(resource.data).affectedKeys()
          .hasOnly(['likesCount', 'commentsCount', 'sharesCount', 'viewsCount'])
      );
      
      // Delete rules
      allow delete: if isAuthenticated() && canModifyPost(resource.data);
      
      // Comments subcollection
      match /comments/{commentId} {
        // Read rules
        allow read: if isAuthenticated() && 
                       canViewPost(get(/databases/$(database)/documents/posts/$(postId)).data) &&
                       (resource.data.isHidden != true || isCoordinator() || isCommentAuthor(resource.data));
        
        // Create rules
        allow create: if isAuthenticated() && 
                         canViewPost(get(/databases/$(database)/documents/posts/$(postId)).data) &&
                         isValidCommentData(request.resource.data);
        
        // Update rules (for moderation)
        allow update: if isAuthenticated() && (
          // Author can update their own comments (limited fields)
          (isCommentAuthor(resource.data) && 
           request.resource.data.diff(resource.data).affectedKeys()
             .hasOnly(['content', 'updatedAt'])) ||
          
          // Coordinators can moderate comments
          (isCoordinator() && 
           request.resource.data.diff(resource.data).affectedKeys()
             .hasOnly(['isHidden', 'moderationReason', 'moderatedAt', 'moderatedBy'])) ||
          
          // System updates for engagement counters
          request.resource.data.diff(resource.data).affectedKeys()
            .hasOnly(['likesCount'])
        );
        
        // Delete rules
        allow delete: if isAuthenticated() && 
                         (isCommentAuthor(resource.data) || isCoordinator());
        
        // Comment engagement subcollection
        match /engagement/{userId} {
          allow read: if isAuthenticated();
          allow write: if isAuthenticated() && userId == getUserId();
        }
      }
      
      // Post engagement subcollection
      match /engagement/{userId} {
        allow read: if isAuthenticated();
        allow write: if isAuthenticated() && userId == getUserId();
      }
    }
    
    // Notifications collection rules
    match /notifications/{notificationId} {
      // Users can only read their own notifications
      allow read: if isAuthenticated() && resource.data.recipientId == getUserId();
      
      // System can create notifications
      allow create: if isAuthenticated();
      
      // Users can update their own notifications (mark as read)
      allow update: if isAuthenticated() && 
                       resource.data.recipientId == getUserId() &&
                       request.resource.data.diff(resource.data).affectedKeys()
                         .hasOnly(['isRead', 'readAt']);
      
      // Users can delete their own notifications
      allow delete: if isAuthenticated() && resource.data.recipientId == getUserId();
    }
    
    // Hashtags collection rules
    match /hashtags/{hashtagId} {
      // Anyone can read hashtags
      allow read: if isAuthenticated();
      
      // System can update hashtag statistics
      allow write: if isAuthenticated();
    }
    
    // Post reports collection rules
    match /post_reports/{reportId} {
      // Users can read reports they created
      allow read: if isAuthenticated() && 
                     (resource.data.reportedBy == getUserId() || isCoordinator());
      
      // Users can create reports
      allow create: if isAuthenticated() && 
                       request.resource.data.reportedBy == getUserId();
      
      // Only coordinators can update reports (review them)
      allow update: if isCoordinator();
      
      // Only coordinators can delete reports
      allow delete: if isCoordinator();
    }
    
    // User analytics collection rules
    match /user_analytics/{userId} {
      // Users can read their own analytics
      allow read: if isAuthenticated() && userId == getUserId();
      
      // System can update analytics
      allow write: if isAuthenticated();
    }
    
    // Users collection rules (existing)
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() && userId == getUserId();
    }
    
    // Default deny rule
    match /{document=**} {
      allow read, write: if false;
    }
  }
}