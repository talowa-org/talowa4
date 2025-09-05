// Firebase Cloud Function to fix bucket URLs in Firestore
import admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();

async function fixBucketUrls() {
  console.log('🔄 Starting bucket URL migration...');
  
  const badBucket = 'talowa.appspot.com';
  const correctBucket = 'talowa.firebasestorage.app';
  
  let totalFixed = 0;
  
  try {
    // Fix posts collection
    console.log('📝 Fixing posts collection...');
    const postsSnapshot = await db.collection('posts').get();
    
    for (const doc of postsSnapshot.docs) {
      const data = doc.data();
      let needsUpdate = false;
      const updates = {};
      
      // Check imageUrls array
      if (data.imageUrls && Array.isArray(data.imageUrls)) {
        const fixedImageUrls = data.imageUrls.map(url => {
          if (url && url.includes(badBucket)) {
            needsUpdate = true;
            return url.replace(badBucket, correctBucket);
          }
          return url;
        });
        if (needsUpdate) updates.imageUrls = fixedImageUrls;
      }
      
      // Check videoUrls array
      if (data.videoUrls && Array.isArray(data.videoUrls)) {
        const fixedVideoUrls = data.videoUrls.map(url => {
          if (url && url.includes(badBucket)) {
            needsUpdate = true;
            return url.replace(badBucket, correctBucket);
          }
          return url;
        });
        if (needsUpdate) updates.videoUrls = fixedVideoUrls;
      }
      
      // Check documentUrls array
      if (data.documentUrls && Array.isArray(data.documentUrls)) {
        const fixedDocumentUrls = data.documentUrls.map(url => {
          if (url && url.includes(badBucket)) {
            needsUpdate = true;
            return url.replace(badBucket, correctBucket);
          }
          return url;
        });
        if (needsUpdate) updates.documentUrls = fixedDocumentUrls;
      }
      
      // Check legacy mediaUrls array
      if (data.mediaUrls && Array.isArray(data.mediaUrls)) {
        const fixedMediaUrls = data.mediaUrls.map(url => {
          if (url && url.includes(badBucket)) {
            needsUpdate = true;
            return url.replace(badBucket, correctBucket);
          }
          return url;
        });
        if (needsUpdate) updates.mediaUrls = fixedMediaUrls;
      }
      
      if (needsUpdate) {
        await doc.ref.update(updates);
        console.log(`✅ Fixed post: ${doc.id}`);
        totalFixed++;
      }
    }
    
    // Fix stories collection
    console.log('📖 Fixing stories collection...');
    const storiesSnapshot = await db.collection('stories').get();
    
    for (const doc of storiesSnapshot.docs) {
      const data = doc.data();
      let needsUpdate = false;
      const updates = {};
      
      if (data.mediaUrl && data.mediaUrl.includes(badBucket)) {
        updates.mediaUrl = data.mediaUrl.replace(badBucket, correctBucket);
        needsUpdate = true;
      }
      
      if (data.thumbnailUrl && data.thumbnailUrl.includes(badBucket)) {
        updates.thumbnailUrl = data.thumbnailUrl.replace(badBucket, correctBucket);
        needsUpdate = true;
      }
      
      if (needsUpdate) {
        await doc.ref.update(updates);
        console.log(`✅ Fixed story: ${doc.id}`);
        totalFixed++;
      }
    }
    
    // Fix users collection
    console.log('👥 Fixing users collection...');
    const usersSnapshot = await db.collection('users').get();
    
    for (const doc of usersSnapshot.docs) {
      const data = doc.data();
      let needsUpdate = false;
      const updates = {};
      
      if (data.profileImageUrl && data.profileImageUrl.includes(badBucket)) {
        updates.profileImageUrl = data.profileImageUrl.replace(badBucket, correctBucket);
        needsUpdate = true;
      }
      
      if (data.coverImageUrl && data.coverImageUrl.includes(badBucket)) {
        updates.coverImageUrl = data.coverImageUrl.replace(badBucket, correctBucket);
        needsUpdate = true;
      }
      
      if (needsUpdate) {
        await doc.ref.update(updates);
        console.log(`✅ Fixed user: ${doc.id}`);
        totalFixed++;
      }
    }
    
    console.log(`🎉 Migration completed! Fixed ${totalFixed} documents.`);
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
  }
  
  process.exit(0);
}

fixBucketUrls();