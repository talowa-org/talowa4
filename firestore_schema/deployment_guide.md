# Firestore Database Schema Deployment Guide

## Overview
This guide provides step-by-step instructions for deploying the TALOWA Social Feed Firestore database schema, including collections, indexes, and security rules.

## Prerequisites

1. **Firebase CLI installed**
   ```bash
   npm install -g firebase-tools
   ```

2. **Firebase project initialized**
   ```bash
   firebase login
   firebase init firestore
   ```

3. **Project configuration**
   - Ensure your Firebase project has Firestore enabled
   - Verify you have appropriate permissions to deploy

## Deployment Steps

### 1. Deploy Security Rules

Copy the security rules to your Firebase project:

```bash
# Copy security rules to firestore.rules
cp firestore_schema/social_feed_security_rules.js firestore.rules

# Deploy security rules
firebase deploy --only firestore:rules
```

### 2. Deploy Firestore Indexes

Copy the indexes configuration:

```bash
# Copy indexes to firestore.indexes.json
cp firestore_schema/firestore_indexes.json firestore.indexes.json

# Deploy indexes
firebase deploy --only firestore:indexes
```

### 3. Initialize Collections (Optional)

Create initial collection documents if needed:

```javascript
// Run this in Firebase Console or through Admin SDK
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

// Create initial hashtags collection
await db.collection('hashtags').doc('initial').set({
  tag: 'भूमि_अधिकार',
  normalizedTag: 'भूमि_अधिकार',
  usageCount: 0,
  lastUsed: admin.firestore.FieldValue.serverTimestamp(),
  trending: false,
  trendingScore: 0,
  relatedTags: [],
  geographic: {
    districts: [],
    states: []
  }
});
```

### 4. Verify Deployment

Check that everything is deployed correctly:

```bash
# Check security rules
firebase firestore:rules:get

# Check indexes status
firebase firestore:indexes

# Test security rules (optional)
firebase emulators:start --only firestore
```

## Configuration Files

### firestore.rules
```javascript
// This file should contain the content from social_feed_security_rules.js
rules_version = '2';
service cloud.firestore {
  // ... (copy content from social_feed_security_rules.js)
}
```

### firestore.indexes.json
```json
{
  "indexes": [
    // ... (copy content from firestore_indexes.json)
  ]
}
```

## Testing the Schema

### 1. Security Rules Testing

Create test cases to verify security rules:

```javascript
// Test authenticated user can create posts
const testData = {
  authorId: 'test_user_123',
  content: 'Test post content',
  category: 'generalDiscussion',
  hashtags: ['test'],
  imageUrls: [],
  documentUrls: [],
  visibility: 'public',
  targeting: {
    village: 'TestVillage',
    district: 'TestDistrict',
    state: 'TestState'
  },
  createdAt: new Date(),
  isHidden: false,
  isEmergency: false
};

// This should succeed for authenticated users
await db.collection('posts').add(testData);
```

### 2. Index Performance Testing

Test query performance with indexes:

```javascript
// Test geographic filtering query
const posts = await db.collection('posts')
  .where('isHidden', '==', false)
  .where('targeting.district', '==', 'TestDistrict')
  .orderBy('createdAt', 'desc')
  .limit(20)
  .get();

// Test hashtag query
const hashtagPosts = await db.collection('posts')
  .where('hashtags', 'array-contains', 'भूमि_अधिकार')
  .where('isHidden', '==', false)
  .orderBy('createdAt', 'desc')
  .limit(20)
  .get();
```

## Monitoring and Maintenance

### 1. Index Monitoring

Monitor index usage and performance:

```bash
# Check index usage in Firebase Console
# Navigate to Firestore > Usage tab
# Monitor query performance and costs
```

### 2. Security Rules Monitoring

Monitor security rule violations:

```bash
# Check Firebase Console > Firestore > Rules tab
# Monitor denied requests and adjust rules as needed
```

### 3. Data Validation

Regularly validate data integrity:

```javascript
// Check for orphaned comments
const orphanedComments = await db.collectionGroup('comments')
  .where('postId', '==', 'non_existent_post')
  .get();

// Check for invalid user references
const invalidPosts = await db.collection('posts')
  .where('authorId', '==', null)
  .get();
```

## Backup and Recovery

### 1. Automated Backups

Set up automated backups:

```bash
# Enable automatic backups in Firebase Console
# Navigate to Firestore > Backups
# Configure daily backups with retention policy
```

### 2. Export Data

Export data for compliance or migration:

```bash
# Export entire database
gcloud firestore export gs://your-bucket-name/firestore-backup

# Export specific collections
gcloud firestore export gs://your-bucket-name/posts-backup \
  --collection-ids=posts,comments
```

## Troubleshooting

### Common Issues

1. **Index Creation Failures**
   - Check for conflicting indexes
   - Verify field names match exactly
   - Ensure proper permissions

2. **Security Rule Errors**
   - Test rules in Firebase Console simulator
   - Check for syntax errors
   - Verify helper function logic

3. **Query Performance Issues**
   - Add missing composite indexes
   - Optimize query patterns
   - Consider denormalization for frequently accessed data

### Performance Optimization

1. **Query Optimization**
   - Use pagination with `limit()` and `startAfter()`
   - Minimize array-contains queries
   - Cache frequently accessed data

2. **Write Optimization**
   - Batch related writes together
   - Use transactions for consistency
   - Implement proper retry logic

3. **Read Optimization**
   - Use real-time listeners selectively
   - Implement proper offline caching
   - Consider using Cloud Functions for aggregations

## Security Best Practices

1. **Rule Validation**
   - Test all security rules thoroughly
   - Use least privilege principle
   - Regularly audit rule effectiveness

2. **Data Protection**
   - Encrypt sensitive data at application level
   - Implement proper user authentication
   - Monitor for suspicious activity

3. **Access Control**
   - Implement role-based access control
   - Use geographic restrictions appropriately
   - Audit user permissions regularly

## Support and Documentation

- [Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Security Rules Documentation](https://firebase.google.com/docs/firestore/security/get-started)
- [Firestore Indexes Documentation](https://firebase.google.com/docs/firestore/query-data/indexing)
- [Firebase CLI Documentation](https://firebase.google.com/docs/cli)