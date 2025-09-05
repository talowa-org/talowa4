import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SimpleUrlMigration {
  static const String oldBucket = 'talowa.appspot.com';
  static const String newBucket = 'talowa.firebasestorage.app';
  
  static Future<void> runMigration() async {
    if (kDebugMode) {
      print('ðŸ”„ Starting simple URL migration...');
    }
    
    final firestore = FirebaseFirestore.instance;
    int totalFixed = 0;
    
    try {
      // Fix posts collection
      if (kDebugMode) {
        print('ðŸ“ Fixing posts collection...');
      }
      
      final postsQuery = await firestore.collection('posts').get();
      
      for (final doc in postsQuery.docs) {
        final data = doc.data();
        bool needsUpdate = false;
        final Map<String, dynamic> updates = {};
        
        // Fix imageUrls
        if (data['imageUrls'] != null && data['imageUrls'] is List) {
          final List<String> imageUrls = List<String>.from(data['imageUrls']);
          final List<String> fixedImageUrls = imageUrls.map((url) {
            if (url.contains(oldBucket)) {
              needsUpdate = true;
              return url.replaceAll(oldBucket, newBucket);
            }
            return url;
          }).toList();
          
          if (needsUpdate) {
            updates['imageUrls'] = fixedImageUrls;
          }
        }
        
        // Fix videoUrls
        if (data['videoUrls'] != null && data['videoUrls'] is List) {
          final List<String> videoUrls = List<String>.from(data['videoUrls']);
          final List<String> fixedVideoUrls = videoUrls.map((url) {
            if (url.contains(oldBucket)) {
              needsUpdate = true;
              return url.replaceAll(oldBucket, newBucket);
            }
            return url;
          }).toList();
          
          if (needsUpdate) {
            updates['videoUrls'] = fixedVideoUrls;
          }
        }
        
        // Fix documentUrls
        if (data['documentUrls'] != null && data['documentUrls'] is List) {
          final List<String> documentUrls = List<String>.from(data['documentUrls']);
          final List<String> fixedDocumentUrls = documentUrls.map((url) {
            if (url.contains(oldBucket)) {
              needsUpdate = true;
              return url.replaceAll(oldBucket, newBucket);
            }
            return url;
          }).toList();
          
          if (needsUpdate) {
            updates['documentUrls'] = fixedDocumentUrls;
          }
        }
        
        // Fix legacy mediaUrls
        if (data['mediaUrls'] != null && data['mediaUrls'] is List) {
          final List<String> mediaUrls = List<String>.from(data['mediaUrls']);
          final List<String> fixedMediaUrls = mediaUrls.map((url) {
            if (url.contains(oldBucket)) {
              needsUpdate = true;
              return url.replaceAll(oldBucket, newBucket);
            }
            return url;
          }).toList();
          
          if (needsUpdate) {
            updates['mediaUrls'] = fixedMediaUrls;
          }
        }
        
        if (needsUpdate) {
          await doc.reference.update(updates);
          totalFixed++;
          if (kDebugMode) {
            print('âœ… Fixed post: ${doc.id}');
          }
        }
      }
      
      // Fix stories collection
      if (kDebugMode) {
        print('ðŸ“– Fixing stories collection...');
      }
      
      final storiesQuery = await firestore.collection('stories').get();
      
      for (final doc in storiesQuery.docs) {
        final data = doc.data();
        bool needsUpdate = false;
        final Map<String, dynamic> updates = {};
        
        if (data['mediaUrl'] != null && data['mediaUrl'].toString().contains(oldBucket)) {
          updates['mediaUrl'] = data['mediaUrl'].toString().replaceAll(oldBucket, newBucket);
          needsUpdate = true;
        }
        
        if (data['thumbnailUrl'] != null && data['thumbnailUrl'].toString().contains(oldBucket)) {
          updates['thumbnailUrl'] = data['thumbnailUrl'].toString().replaceAll(oldBucket, newBucket);
          needsUpdate = true;
        }
        
        if (needsUpdate) {
          await doc.reference.update(updates);
          totalFixed++;
          if (kDebugMode) {
            print('âœ… Fixed story: ${doc.id}');
          }
        }
      }
      
      // Fix users collection
      if (kDebugMode) {
        print('ðŸ‘¥ Fixing users collection...');
      }
      
      final usersQuery = await firestore.collection('users').get();
      
      for (final doc in usersQuery.docs) {
        final data = doc.data();
        bool needsUpdate = false;
        final Map<String, dynamic> updates = {};
        
        if (data['profileImageUrl'] != null && data['profileImageUrl'].toString().contains(oldBucket)) {
          updates['profileImageUrl'] = data['profileImageUrl'].toString().replaceAll(oldBucket, newBucket);
          needsUpdate = true;
        }
        
        if (data['coverImageUrl'] != null && data['coverImageUrl'].toString().contains(oldBucket)) {
          updates['coverImageUrl'] = data['coverImageUrl'].toString().replaceAll(oldBucket, newBucket);
          needsUpdate = true;
        }
        
        if (needsUpdate) {
          await doc.reference.update(updates);
          totalFixed++;
          if (kDebugMode) {
            print('âœ… Fixed user: ${doc.id}');
          }
        }
      }
      
      if (kDebugMode) {
        print('ðŸŽ‰ Migration completed! Fixed $totalFixed documents.');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('âŒ Migration failed: $e');
      }
      rethrow;
    }
  }
}
