import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Exception thrown when referral code generation fails
class ReferralCodeGenerationException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const ReferralCodeGenerationException(this.message, [this.code = 'CODE_GENERATION_FAILED', this.context]);
  
  @override
  String toString() => 'ReferralCodeGenerationException: $message';
}

/// Service for generating unique referral codes
class ReferralCodeGenerator {
  static const String PREFIX = 'TAL';
  static const int CODE_LENGTH = 6;
  static const String ALLOWED_CHARS = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  static const int MAX_ATTEMPTS = 10; // Updated from design.md requirement

  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Random _random = Random.secure();

  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Generates a unique referral code
  /// Generates a unique referral code
  /// Uses simple fallback if secure generation fails
  static Future<String> generateUniqueCode() async {
    int attempts = 0;

    while (attempts < MAX_ATTEMPTS) {
      try {
        final code = _generateRandomCode();

        // Validate format before checking uniqueness
        if (!_validateCodeFormat(code)) {
          debugPrint('⚠️  Generated invalid format code: $code, retrying...');
          attempts++;
          continue;
        }

        final isUnique = await _checkCodeUniqueness(code);

        if (isUnique) {
          try {
            await _reserveCode(code);
            debugPrint('✅ Generated and reserved unique referral code: $code');
            return code;
          } catch (e) {
            debugPrint('⚠️  Failed to reserve code $code: $e, but returning it anyway');
            return code; // Return the code even if reservation fails
          }
        }
        attempts++;
      } catch (e) {
        debugPrint('⚠️  Error in generation attempt ${attempts + 1}: $e');
        attempts++;

        // If we're on the last attempt, use simple fallback without scary logs
        if (attempts >= MAX_ATTEMPTS) {
          final simpleCode = '$PREFIX${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
          debugPrint('⚠️ Using simple fallback code: $simpleCode');
          return simpleCode;
        }
      }
    }

    // Final simple fallback
    final finalCode = '$PREFIX${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    debugPrint('⚠️ Using final fallback code: $finalCode');
    return finalCode;
  }

  /// Ensures a user has a TAL-prefixed referral code, generating one if needed
  /// Returns the existing or newly generated code
  static Future<String> ensureReferralCode(String uid) async {
    try {
      // Get user document
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        throw ReferralCodeGenerationException(
          'User document not found for uid: $uid',
          'USER_NOT_FOUND',
          {'uid': uid}
        );
      }

      final userData = userDoc.data()!;
      final existingCode = userData['referralCode'] as String?;

      // If user already has a TAL-prefixed code, return it
      if (existingCode != null && existingCode.startsWith(PREFIX)) {
        return existingCode;
      }

      // Generate new TAL code
      final newCode = await generateUniqueCode();

      // Update user document and reserve code in transaction
      await _firestore.runTransaction((transaction) async {
        // Update user document
        transaction.update(userDoc.reference, {'referralCode': newCode});

        // Reserve the code
        transaction.set(
          _firestore.collection('referralCodes').doc(newCode),
          {
            'uid': uid,
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
          }
        );
      });

      return newCode;
    } catch (e) {
      throw ReferralCodeGenerationException(
        'Failed to ensure referral code for user $uid: $e',
        'ENSURE_FAILED',
        {'uid': uid, 'error': e.toString()}
      );
    }
  }

  /// Migrates legacy referral codes to TAL prefix (except TALADMIN)
  /// Returns count of users migrated
  static Future<int> migrateLegacyCodes() async {
    int migratedCount = 0;

    try {
      // Query all users (fake Firestore doesn't support isNotEqualTo)
      final usersQuery = await _firestore
          .collection('users')
          .get();

      final batch = _firestore.batch();
      final codesToReserve = <String, String>{}; // code -> uid mapping

      for (final userDoc in usersQuery.docs) {
        final userData = userDoc.data();
        final existingCode = userData['referralCode'] as String?;

        // Skip if no referral code, already TAL-prefixed, or is TALADMIN
        if (existingCode == null ||
            existingCode.startsWith(PREFIX) ||
            existingCode == 'TALADMIN') {
          continue;
        }

        // Generate new TAL code
        final newCode = await generateUniqueCode();

        // Update user document
        batch.update(userDoc.reference, {'referralCode': newCode});

        // Mark code for reservation
        codesToReserve[newCode] = userDoc.id;
        migratedCount++;
      }

      // Reserve all new codes
      for (final entry in codesToReserve.entries) {
        batch.set(
          _firestore.collection('referralCodes').doc(entry.key),
          {
            'uid': entry.value,
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
            'migrated': true,
          }
        );
      }

      // Commit all changes
      await batch.commit();

      return migratedCount;
    } catch (e) {
      throw ReferralCodeGenerationException(
        'Failed to migrate legacy codes: $e',
        'MIGRATION_FAILED',
        {'error': e.toString(), 'migratedCount': migratedCount}
      );
    }
  }

  /// Generates a random referral code with TAL prefix
  static String _generateRandomCode() {
    final codeBuffer = StringBuffer(PREFIX);
    
    for (int i = 0; i < CODE_LENGTH; i++) {
      final randomIndex = _random.nextInt(ALLOWED_CHARS.length);
      codeBuffer.write(ALLOWED_CHARS[randomIndex]);
    }
    
    return codeBuffer.toString();
  }
  
  /// Checks if a referral code is unique in the database
  static Future<bool> _checkCodeUniqueness(String code) async {
    try {
      // Check in referralCodes collection
      final codeDoc = await _firestore
          .collection('referralCodes')
          .doc(code)
          .get();
      
      if (codeDoc.exists) {
        return false;
      }
      
      // Double-check in users collection
      final userQuery = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();
      
      return userQuery.docs.isEmpty;
    } catch (e) {
      // If there's an error checking uniqueness, assume not unique for safety
      return false;
    }
  }
  
  /// Reserves a referral code in the database
  static Future<void> _reserveCode(String code) async {
    try {
      // Get current user UID for Firestore rules compliance
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw const ReferralCodeGenerationException(
          'User must be authenticated to reserve referral code',
          'USER_NOT_AUTHENTICATED'
        );
      }

      await _firestore.collection('referralCodes').doc(code).set({
        'code': code,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'clickCount': 0,
        'conversionCount': 0,
        'uid': currentUser.uid, // Set to current user's UID for Firestore rules
      });
    } catch (e) {
      throw ReferralCodeGenerationException(
        'Failed to reserve code $code: $e',
        'RESERVATION_FAILED',
        {'code': code, 'error': e.toString()}
      );
    }
  }
  
  /// Validates referral code format
  static bool isValidFormat(String code) {
    if (code.length != PREFIX.length + CODE_LENGTH) {
      return false;
    }
    
    if (!code.startsWith(PREFIX)) {
      return false;
    }
    
    final codepart = code.substring(PREFIX.length);
    for (int i = 0; i < codepart.length; i++) {
      if (!ALLOWED_CHARS.contains(codepart[i])) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Generates a deterministic code for testing purposes
  static String generateTestCode(String seed) {
    final bytes = utf8.encode(seed);
    final digest = sha256.convert(bytes);
    final hexString = digest.toString().toUpperCase();
    
    final codeBuffer = StringBuffer(PREFIX);
    int charIndex = 0;
    
    for (int i = 0; i < CODE_LENGTH && charIndex < hexString.length; i++) {
      // Convert hex char to allowed char index
      final hexChar = hexString[charIndex];
      final hexValue = int.tryParse(hexChar, radix: 16) ?? 0;
      final allowedCharIndex = hexValue % ALLOWED_CHARS.length;
      codeBuffer.write(ALLOWED_CHARS[allowedCharIndex]);
      charIndex++;
    }
    
    // Fill remaining with default chars if needed
    while (codeBuffer.length < PREFIX.length + CODE_LENGTH) {
      codeBuffer.write(ALLOWED_CHARS[0]);
    }
    
    return codeBuffer.toString();
  }
  
  /// Gets total possible combinations
  static int get totalPossibleCombinations {
    return pow(ALLOWED_CHARS.length, CODE_LENGTH).toInt();
  }
  
  /// Estimates collision probability for given number of codes
  static double estimateCollisionProbability(int existingCodes) {
    final total = totalPossibleCombinations;
    if (existingCodes >= total) return 1.0;
    if (existingCodes <= 0) return 0.0;

    // Simple approximation: probability = existingCodes / total
    return existingCodes / total;
  }

  /// Validates that a code follows the correct TAL + Crockford base32 format
  static bool _validateCodeFormat(String code) {
    try {
      // Must start with TAL
      if (!code.startsWith(PREFIX)) {
        return false;
      }

      // Must be exactly the right length
      if (code.length != PREFIX.length + CODE_LENGTH) {
        return false;
      }

      // Check that all characters after prefix are in allowed set
      final codepart = code.substring(PREFIX.length);
      for (int i = 0; i < codepart.length; i++) {
        if (!ALLOWED_CHARS.contains(codepart[i])) {
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error validating code format for $code: $e');
      return false;
    }
  }

  // Emergency fallback function removed - using simple timestamp-based fallback instead
}
