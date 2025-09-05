#!/usr/bin/env dart

import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:talowa/services/referral/referral_migration_service.dart';

/// Script to migrate from two-step to simplified referral system
Future<void> main(List<String> args) async {
  print('ðŸš€ TALOWA Referral System Migration');
  print('=====================================');
  print('Migrating from two-step to simplified one-step referral system...\n');

  try {
    // Initialize Firebase
    print('ðŸ“± Initializing Firebase...');
    await Firebase.initializeApp();
    print('âœ… Firebase initialized successfully\n');

    // Check if user wants to proceed
    if (args.isEmpty || !args.contains('--confirm')) {
      print('âš ï¸  WARNING: This will migrate ALL users to the simplified referral system.');
      print('   This action cannot be undone.');
      print('   To proceed, run: dart scripts/migrate_referral_system.dart --confirm\n');
      exit(1);
    }

    // Step 1: Verify current state
    print('ðŸ” Verifying current migration state...');
    final verificationResult = await ReferralMigrationService.verifyMigration();
    print('Current state:');
    print('  - Total users: ${verificationResult['totalUsers']}');
    print('  - Already migrated: ${verificationResult['migratedUsers']}');
    print('  - Pending referrals: ${verificationResult['pendingReferrals']}');
    print('  - Users without referral code: ${verificationResult['usersWithoutReferralCode']}\n');

    if (verificationResult['migrationComplete'] == true) {
      print('âœ… Migration already complete! All users are on simplified system.');
      exit(0);
    }

    // Step 2: Run migration
    print('ðŸ”„ Starting migration process...');
    final migrationResult = await ReferralMigrationService.migrateAllUsers();

    if (migrationResult['success'] == true) {
      print('âœ… Migration completed successfully!');
      print('Results:');
      print('  - Total users processed: ${migrationResult['totalUsers']}');
      print('  - Successfully migrated: ${migrationResult['migratedUsers']}');
      print('  - Errors: ${migrationResult['errorCount']}');
      
      if (migrationResult['errorCount'] > 0) {
        print('  - Sample errors:');
        for (final error in migrationResult['errors']) {
          print('    â€¢ $error');
        }
      }
    } else {
      print('âŒ Migration failed: ${migrationResult['error']}');
      exit(1);
    }

    // Step 3: Fix any issues
    if (migrationResult['errorCount'] > 0) {
      print('\nðŸ”§ Attempting to fix migration issues...');
      final fixResult = await ReferralMigrationService.fixMigrationIssues();
      
      if (fixResult['success'] == true) {
        print('âœ… Fixed ${fixResult['fixedUsers']} users');
      } else {
        print('âŒ Failed to fix issues: ${fixResult['error']}');
      }
    }

    // Step 4: Update all statistics
    print('\nðŸ“Š Updating all referral statistics...');
    final statsResult = await ReferralMigrationService.updateAllStatistics();
    
    if (statsResult['success'] == true) {
      print('âœ… Updated statistics for ${statsResult['updatedUsers']} users');
      if (statsResult['errorCount'] > 0) {
        print('âš ï¸  ${statsResult['errorCount']} users had statistics update errors');
      }
    } else {
      print('âŒ Failed to update statistics: ${statsResult['error']}');
    }

    // Step 5: Final verification
    print('\nðŸ” Final verification...');
    final finalVerification = await ReferralMigrationService.verifyMigration();
    
    print('Final state:');
    print('  - Total users: ${finalVerification['totalUsers']}');
    print('  - Migrated users: ${finalVerification['migratedUsers']}');
    print('  - Migration percentage: ${finalVerification['migrationPercentage']}%');
    print('  - Pending referrals: ${finalVerification['pendingReferrals']}');
    print('  - Users without referral code: ${finalVerification['usersWithoutReferralCode']}');
    
    if (finalVerification['migrationComplete'] == true) {
      print('\nðŸŽ‰ MIGRATION COMPLETED SUCCESSFULLY!');
      print('All users are now on the simplified one-step referral system.');
    } else {
      print('\nâš ï¸  Migration partially completed. Some issues may need manual resolution.');
    }

  } catch (e) {
    print('âŒ Migration failed with error: $e');
    exit(1);
  }
}
