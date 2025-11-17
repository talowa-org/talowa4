# Firebase Firestore Indexes Setup

## Required Indexes for TALOWA Social Feed

### Automatic Index Creation

When you run the app and see index errors in the console, Firebase provides direct links to create the required indexes. Follow these steps:

1. **Open Firebase Console** → Firestore → Indexes tab
2. **Click on each "create index" link** that appears in your browser console errors
3. **Press "Create"** for every missing index
4. **Wait ~10 minutes** for indexing to complete

### Manual Index Creation

If you prefer to create indexes manually, here are the required composite indexes:

#### Posts Collection

1. **Posts by timestamp (descending)**
   - Collection: `posts`
   - Fields:
     - `createdAt` (Descending)
   - Query scope: Collection

2. **Posts by category and timestamp**
   - Collection: `posts`
   - Fields:
     - `category` (Ascending)
     - `createdAt` (Descending)
   - Query scope: Collection

3. **Posts by location and timestamp**
   - Collection: `posts`
   - Fields:
     - `location` (Ascending)
     - `createdAt` (Descending)
   - Query scope: Collection

4. **Posts by author and timestamp**
   - Collection: `posts`
   - Fields:
     - `authorId` (Ascending)
     - `createdAt` (Descending)
   - Query scope: Collection

#### Comments Subcollection

1. **Comments by timestamp**
   - Collection: `posts/{postId}/comments`
   - Fields:
     - `createdAt` (Descending)
   - Query scope: Collection group

#### Likes Subcollection

1. **Likes by user**
   - Collection: `posts/{postId}/likes`
   - Fields:
     - `userId` (Ascending)
     - `createdAt` (Descending)
   - Query scope: Collection group

### Common Index Errors and Solutions

#### Error: `The query requires an index`

**Solution:** Click the provided link in the error message to create the index automatically.

Example error:
```
[cloud_firestore/failed-precondition] The query requires an index. 
You can create it here: https://console.firebase.google.com/...
```

#### Error: `400 (Bad Request)`

**Cause:** Missing index or incorrect query structure.

**Solution:** 
1. Check the console for the specific index requirement
2. Create the index using the provided link
3. Wait for index creation to complete (~10 minutes)

### Verification

After creating indexes, verify they are active:

1. Go to Firebase Console → Firestore → Indexes
2. Check that all indexes show status: **Enabled**
3. If status is **Building**, wait for completion
4. Refresh your app and test the queries

### Index Creation via Firebase CLI (Optional)

You can also create indexes using the Firebase CLI:

```bash
firebase deploy --only firestore:indexes
```

This requires a `firestore.indexes.json` file in your project root.

### Performance Tips

- **Single-field indexes** are created automatically
- **Composite indexes** must be created manually or via error links
- **Collection group queries** require special indexes
- Indexes improve query performance but increase storage costs slightly

### Troubleshooting

If indexes are not working:

1. **Clear browser cache** and reload
2. **Wait 10-15 minutes** after index creation
3. **Check index status** in Firebase Console
4. **Verify query structure** matches index fields
5. **Check Firestore rules** allow the query

### Support

For more information, see:
- [Firebase Indexing Documentation](https://firebase.google.com/docs/firestore/query-data/indexing)
- [Firestore Query Best Practices](https://firebase.google.com/docs/firestore/best-practices)
