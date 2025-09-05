import 'package:flutter/foundation.dart';
import 'admin/admin_bootstrap_service.dart';
import 'referral/referral_code_generator.dart';

/// Service to bootstrap the application with admin user and migrate legacy data
class BootstrapService {
  static bool _isBootstrapped = false;
  
  /// Bootstrap the application - should be called once on app startup
  static Future<void> bootstrap() async {
    if (_isBootstrapped) return;
    
    try {
      debugPrint('Starting application bootstrap...');
      
      // Step 1: Bootstrap admin user
      debugPrint('Bootstrapping admin user...');
      final adminUid = await AdminBootstrapService.bootstrapAdmin();
      debugPrint('Admin user bootstrapped with UID: $adminUid');
      
      // Step 2: Migrate legacy referral codes
      debugPrint('Migrating legacy referral codes...');
      final migratedCount = await ReferralCodeGenerator.migrateLegacyCodes();
      debugPrint('Migrated $migratedCount legacy referral codes to TAL prefix');
      
      _isBootstrapped = true;
      debugPrint('Application bootstrap completed successfully');
      
    } catch (e) {
      debugPrint('Bootstrap failed: $e');
      // Don't throw - app should still work even if bootstrap fails
    }
  }
  
  /// Check if bootstrap has been completed
  static bool get isBootstrapped => _isBootstrapped;
  
  /// Force re-bootstrap (for testing purposes)
  static void reset() {
    _isBootstrapped = false;
  }
}

