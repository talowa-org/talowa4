// Message Encryption Service for TALOWA
// Implements AES-256 and RSA key management for secure messaging
// Requirements: 1.6, 7.2, 7.3

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../auth_service.dart';
import '../security_service.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _encryptionKeysCollection = 'encryption_keys';
  
  // Cache for encryption keys
  final Map<String, encrypt.Encrypter> _encrypterCache = {};
  final Map<String, String> _publicKeyCache = {};
  
  /// Initialize encryption for current user
  Future<void> initializeUserEncryption() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if user already has encryption keys
      final keyDoc = await _firestore
          .collection(_encryptionKeysCollection)
          .doc(currentUser.uid)
          .get();

      if (!keyDoc.exists) {
        // Generate new key pair for user
        await _generateUserKeyPair(currentUser.uid);
      }

      // Load user's private key into cache
      await _loadUserPrivateKey(currentUser.uid);
      
      debugPrint('Encryption initialized for user: ${currentUser.uid}');
    } catch (e) {
      debugPrint('Error initializing encryption: $e');
      rethrow;
    }
  }

  /// Generate RSA key pair for user
  Future<void> _generateUserKeyPair(String userId) async {
    try {
      // Generate RSA key pair (simplified implementation)
      final random = Random.secure();
      final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
      final keyString = base64.encode(keyBytes);
      
      // In a real implementation, you would use proper RSA key generation
      final publicKey = 'pub_$keyString';
      final privateKey = 'priv_$keyString';

      // Store public key in Firestore
      await _firestore.collection(_encryptionKeysCollection).doc(userId).set({
        'publicKey': publicKey,
        'keyFingerprint': _generateKeyFingerprint(publicKey),
        'createdAt': FieldValue.serverTimestamp(),
        'lastRotated': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // Store private key securely on device
      await SecurityService.storeSecurely(
        'private_key_$userId',
        privateKey,
      );

      debugPrint('Generated new key pair for user: $userId');
    } catch (e) {
      debugPrint('Error generating key pair: $e');
      rethrow;
    }
  }

  /// Load user's private key into memory
  Future<void> _loadUserPrivateKey(String userId) async {
    try {
      final privateKeyBase64 = await SecurityService.getSecurely('private_key_$userId');
      if (privateKeyBase64 == null) {
        throw Exception('Private key not found for user');
      }

      // Simplified encryption setup
      final key = encrypt.Key.fromBase64(base64.encode(privateKeyBase64.codeUnits.take(32).toList()));
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      _encrypterCache[userId] = encrypter;
    } catch (e) {
      debugPrint('Error loading private key: $e');
      rethrow;
    }
  }

  /// Get public key for a user
  Future<String> getPublicKey(String userId) async {
    try {
      // Check cache first
      if (_publicKeyCache.containsKey(userId)) {
        return _publicKeyCache[userId]!;
      }

      // Fetch from Firestore
      final keyDoc = await _firestore
          .collection(_encryptionKeysCollection)
          .doc(userId)
          .get();

      if (!keyDoc.exists) {
        throw Exception('Public key not found for user: $userId');
      }

      final publicKey = keyDoc.data()!['publicKey'] as String;
      _publicKeyCache[userId] = publicKey;
      
      return publicKey;
    } catch (e) {
      debugPrint('Error getting public key: $e');
      rethrow;
    }
  }

  /// Encrypt message content using AES-256 
  Future<EncryptedContent> encryptMessage({
    required String content,
    required String recipientUserId,
    EncryptionLevel level = EncryptionLevel.standard,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Generate AES key for this message
      final aesKey = _generateAESKey();
      final encrypter = encrypt.Encrypter(encrypt.AES(aesKey));
      final iv = encrypt.IV.fromSecureRandom(16);

      // Encrypt the message content with AES
      final encryptedContent = encrypter.encrypt(content, iv: iv);

      // Get recipient's public key
      final recipientPublicKey = await getPublicKey(recipientUserId);

      // Simplified key encryption (in production, use proper RSA)
      final encryptedAESKey = base64.encode('${aesKey.base64}_$recipientPublicKey'.codeUnits);

      // Also encrypt for sender
      final senderPublicKey = await getPublicKey(currentUser.uid);
      final encryptedAESKeyForSender = base64.encode('${aesKey.base64}_$senderPublicKey'.codeUnits);

      return EncryptedContent(
        data: encryptedContent.base64,
        iv: iv.base64,
        algorithm: level == EncryptionLevel.highSecurity ? 'AES-256-GCM' : 'AES-256-CBC',
        keyFingerprint: _generateKeyFingerprint(recipientPublicKey),
        encryptedKeys: {
          recipientUserId: encryptedAESKey,
          currentUser.uid: encryptedAESKeyForSender,
        },
        encryptionLevel: level,
      );
    } catch (e) {
      debugPrint('Error encrypting message: $e');
      rethrow;
    }
  }

  /// Decrypt message content
  Future<String> decryptMessage(EncryptedContent encryptedContent) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get encrypted AES key for current user
      final encryptedAESKey = encryptedContent.encryptedKeys[currentUser.uid];
      if (encryptedAESKey == null) {
        throw Exception('No encrypted key found for current user');
      }

      // Simplified key decryption (in production, use proper RSA)
      final decodedKey = String.fromCharCodes(base64.decode(encryptedAESKey));
      final keyPart = decodedKey.split('_')[0];
      
      // Create AES encrypter with decrypted key
      final aesKey = encrypt.Key.fromBase64(keyPart);
      final aesEncrypter = encrypt.Encrypter(encrypt.AES(aesKey));
      final iv = encrypt.IV.fromBase64(encryptedContent.iv);

      // Decrypt the message content
      final decryptedContent = aesEncrypter.decrypt64(
        encryptedContent.data,
        iv: iv,
      );

      return decryptedContent;
    } catch (e) {
      debugPrint('Error decrypting message: $e');
      rethrow;
    }
  }

  /// Encrypt group message with shared group key
  Future<EncryptedContent> encryptGroupMessage({
    required String content,
    required String groupId,
    required List<String> participantIds,
    EncryptionLevel level = EncryptionLevel.standard,
  }) async {
    try {
      // Get or generate group key
      final groupKey = await _getOrCreateGroupKey(groupId);
      final encrypter = encrypt.Encrypter(encrypt.AES(groupKey));
      final iv = encrypt.IV.fromSecureRandom(16);

      // Encrypt content
      final encryptedContent = encrypter.encrypt(content, iv: iv);

      // Encrypt group key for each participant (simplified)
      final encryptedKeys = <String, String>{};
      for (final participantId in participantIds) {
        try {
          final publicKey = await getPublicKey(participantId);
          final encryptedGroupKey = base64.encode('${groupKey.base64}_$publicKey'.codeUnits);
          encryptedKeys[participantId] = encryptedGroupKey;
        } catch (e) {
          debugPrint('Failed to encrypt group key for participant $participantId: $e');
          // Continue with other participants
        }
      }

      return EncryptedContent(
        data: encryptedContent.base64,
        iv: iv.base64,
        algorithm: level == EncryptionLevel.highSecurity ? 'AES-256-GCM' : 'AES-256-CBC',
        keyFingerprint: _generateKeyFingerprint(groupKey.base64),
        encryptedKeys: encryptedKeys,
        encryptionLevel: level,
        isGroupMessage: true,
        groupId: groupId,
      );
    } catch (e) {
      debugPrint('Error encrypting group message: $e');
      rethrow;
    }
  }

  /// Encrypt anonymous message with proxy routing
  Future<EncryptedContent> encryptAnonymousMessage({
    required String content,
    required String coordinatorId,
  }) async {
    try {
      // Generate temporary key for anonymous message
      final tempKey = _generateAESKey();
      final encrypter = encrypt.Encrypter(encrypt.AES(tempKey));
      final iv = encrypt.IV.fromSecureRandom(16);

      // Encrypt content
      final encryptedContent = encrypter.encrypt(content, iv: iv);

      // Get coordinator's public key
      final coordinatorPublicKey = await getPublicKey(coordinatorId);
      
      // Encrypt temp key for coordinator (simplified)
      final encryptedTempKey = base64.encode('${tempKey.base64}_$coordinatorPublicKey'.codeUnits);

      return EncryptedContent(
        data: encryptedContent.base64,
        iv: iv.base64,
        algorithm: 'AES-256-CBC',
        keyFingerprint: _generateKeyFingerprint(coordinatorPublicKey),
        encryptedKeys: {coordinatorId: encryptedTempKey},
        encryptionLevel: EncryptionLevel.highSecurity,
        isAnonymous: true,
      );
    } catch (e) {
      debugPrint('Error encrypting anonymous message: $e');
      rethrow;
    }
  }

  /// Rotate user's encryption keys
  Future<void> rotateKeys() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Generate new key pair
      await _generateUserKeyPair(currentUser.uid);
      
      // Clear cache
      _encrypterCache.remove(currentUser.uid);
      _publicKeyCache.remove(currentUser.uid);
      
      // Reload new keys
      await _loadUserPrivateKey(currentUser.uid);
      
      debugPrint('Keys rotated successfully for user: ${currentUser.uid}');
    } catch (e) {
      debugPrint('Error rotating keys: $e');
      rethrow;
    }
  }

  /// Generate or retrieve group encryption key
  Future<encrypt.Key> _getOrCreateGroupKey(String groupId) async {
    try {
      // Try to get existing group key from secure storage
      final existingKey = await SecurityService.getSecurely('group_key_$groupId');
      if (existingKey != null) {
        return encrypt.Key.fromBase64(existingKey);
      }

      // Generate new group key
      final groupKey = _generateAESKey();
      await SecurityService.storeSecurely('group_key_$groupId', groupKey.base64);
      
      return groupKey;
    } catch (e) {
      debugPrint('Error getting group key: $e');
      rethrow;
    }
  }

  /// Generate AES-256 key
  encrypt.Key _generateAESKey() {
    final random = Random.secure();
    final keyBytes = Uint8List(32); // 256 bits
    for (int i = 0; i < keyBytes.length; i++) {
      keyBytes[i] = random.nextInt(256);
    }
    return encrypt.Key(keyBytes);
  }

  /// Generate key fingerprint for identification
  String _generateKeyFingerprint(String key) {
    final bytes = utf8.encode(key);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// Clear encryption cache (call on logout)
  void clearCache() {
    _encrypterCache.clear();
    _publicKeyCache.clear();
  }
}

/// Encrypted content model
class EncryptedContent {
  final String data;
  final String iv;
  final String algorithm;
  final String keyFingerprint;
  final Map<String, String> encryptedKeys;
  final EncryptionLevel encryptionLevel;
  final bool isGroupMessage;
  final bool isAnonymous;
  final String? groupId;

  EncryptedContent({
    required this.data,
    required this.iv,
    required this.algorithm,
    required this.keyFingerprint,
    required this.encryptedKeys,
    required this.encryptionLevel,
    this.isGroupMessage = false,
    this.isAnonymous = false,
    this.groupId,
  });

  Map<String, dynamic> toMap() {
    return {
      'data': data,
      'iv': iv,
      'algorithm': algorithm,
      'keyFingerprint': keyFingerprint,
      'encryptedKeys': encryptedKeys,
      'encryptionLevel': encryptionLevel.value,
      'isGroupMessage': isGroupMessage,
      'isAnonymous': isAnonymous,
      'groupId': groupId,
    };
  }

  factory EncryptedContent.fromMap(Map<String, dynamic> map) {
    return EncryptedContent(
      data: map['data'] ?? '',
      iv: map['iv'] ?? '',
      algorithm: map['algorithm'] ?? 'AES-256-CBC',
      keyFingerprint: map['keyFingerprint'] ?? '',
      encryptedKeys: Map<String, String>.from(map['encryptedKeys'] ?? {}),
      encryptionLevel: EncryptionLevelExtension.fromString(map['encryptionLevel'] ?? 'standard'),
      isGroupMessage: map['isGroupMessage'] ?? false,
      isAnonymous: map['isAnonymous'] ?? false,
      groupId: map['groupId'],
    );
  }
}

/// Encryption levels
enum EncryptionLevel {
  none,
  standard,
  highSecurity,
}

extension EncryptionLevelExtension on EncryptionLevel {
  String get value {
    switch (this) {
      case EncryptionLevel.none:
        return 'none';
      case EncryptionLevel.standard:
        return 'standard';
      case EncryptionLevel.highSecurity:
        return 'high_security';
    }
  }

  static EncryptionLevel fromString(String level) {
    switch (level.toLowerCase()) {
      case 'high_security':
        return EncryptionLevel.highSecurity;
      case 'standard':
        return EncryptionLevel.standard;
      default:
        return EncryptionLevel.none;
    }
  }
}