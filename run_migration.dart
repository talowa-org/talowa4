// URL Migration Script - Fix Firebase Storage bucket names in Firestore
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';
import 'lib/services/migration/url_migration_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    print('ðŸ”¥ Firebase initialized successfully');
    
    // Run URL migration
    print('ðŸ”„ Starting URL migration...');
    final migrationService = UrlMigrationService.instance;
    final result = await migrationService.runCompleteMigration();
    
    if (result.success) {
      print('âœ… Migration completed successfully!');
      print('ðŸ“Š Total documents migrated: ${result.totalMigrated}');
      
      result.collectionResults.forEach((collection, collectionResult) {
        print('   - $collection: ${collectionResult.migratedDocuments} documents');
      });
    } else {
      print('âŒ Migration failed: ${result.error}');
    }
    
  } catch (e) {
    print('âŒ Error: $e');
  }
  
  print('ðŸ Migration script completed');
}
