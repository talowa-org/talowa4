// Content Security Service for TALOWA
// Implements Task 18: Add security and content safety

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ContentSecurityService {
  static final ContentSecurityService _instance = ContentSecurityService._internal();
  factory ContentSecurityService() => _instance;
  ContentSecurityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Security configuration
  static const String encryptionKey = 'TALOWA_SECURE_KEY_2024'; // In production, use secure key management
  static const int maxFileSize = 50 * 1024 * 1024; // 50MB
  static const Duration contentExpirationTime = Duration(days: 30);
  
  // Malware detection patterns
  static const List<String> suspiciousPatterns = [
    r'<script[^>]*>.*?</script>',
    r'javascript:',
    r'vbscript:',
    r'onload\s*=',
    r'onerror\s*=',
    r'onclick\s*=',
    r'eval\s*\(',
    r'document\.cookie',
    r'window\.location',
  ];

  // Inappropriate content patterns
  static const List<String> inappropriatePatterns = [
    // Add patterns for inappropriate content detection
    r'\b(spam|scam|fraud|fake)\b',
    r'\b(hate|violence|threat)\b',
    r'\b(illegal|criminal|drugs)\b',
  ];

  /// Encrypt sensitive content
  String encryptContent(String content) {
    try {
      final key = utf8.encode(encryptionKey);
      final bytes = utf8.encode(content);
      
      // Simple XOR encryption (in production, use AES)
      final encrypted = <int>[];
      for (int i = 0; i < bytes.length; i++) {
        encrypted.add(bytes[i] ^ key[i % key.length]);
      }
      
      return base64.encode(encrypted);
    } catch (e) {
      debugPrint('Error encrypting content: $e');
      return content; // Return original if encryption fails
    }
  }

  /// Decrypt sensitive content
  String decryptContent(String encryptedContent) {
    try {
      final key = utf8.encode(encryptionKey);
      final encrypted = base64.decode(encryptedContent);
      
      // Simple XOR decryption (in production, use AES)
      final decrypted = <int>[];
      for (int i = 0; i < encrypted.length; i++) {
        decrypted.add(encrypted[i] ^ key[i % key.length]);
      }
      
      return utf8.decode(decrypted);
    } catch (e) {
      debugPrint('Error decrypting content: $e');
      return encryptedContent; // Return original if decryption fails
    }
  }

  /// Scan content for security threats
  Future<SecurityScanResult> scanContent({
    required String content,
    required ContentType contentType,
    String? authorId,
  }) async {
    try {
      final threats = <SecurityThreat>[];
      final warnings = <String>[];
      
      // Check for malware patterns
      final malwareThreats = _scanForMalware(content);
      threats.addAll(malwareThreats);
      
      // Check for inappropriate content
      final inappropriateThreats = _scanForInappropriateContent(content);
      threats.addAll(inappropriateThreats);
      
      // Check content length and structure
      final structuralIssues = _validateContentStructure(content, contentType);
      warnings.addAll(structuralIssues);
      
      // Check for spam patterns
      final spamScore = _calculateSpamScore(content);
      if (spamScore > 0.7) {
        threats.add(SecurityThreat(
          type: ThreatType.spam,
          severity: ThreatSeverity.medium,
          description: 'Content appears to be spam',
          confidence: spamScore,
        ));
      }
      
      // Log security scan
      await _logSecurityScan(
        content: content,
        contentType: contentType,
        authorId: authorId,
        threats: threats,
        warnings: warnings,
      );
      
      return SecurityScanResult(
        isSecure: threats.isEmpty,
        threats: threats,
        warnings: warnings,
        scanTimestamp: DateTime.now(),
        contentHash: _generateContentHash(content),
      );
    } catch (e) {
      debugPrint('Error scanning content: $e');
      return SecurityScanResult(
        isSecure: false,
        threats: [
          SecurityThreat(
            type: ThreatType.scanError,
            severity: ThreatSeverity.high,
            description: 'Security scan failed: $e',
            confidence: 1.0,
          ),
        ],
        warnings: [],
        scanTimestamp: DateTime.now(),
        contentHash: _generateContentHash(content),
      );
    }
  }

  /// Scan file for malware and security threats
  Future<FileScanResult> scanFile({
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
    String? uploaderId,
  }) async {
    try {
      final threats = <SecurityThreat>[];
      final warnings = <String>[];
      
      // Check file size
      if (fileBytes.length > maxFileSize) {
        threats.add(SecurityThreat(
          type: ThreatType.oversizedFile,
          severity: ThreatSeverity.medium,
          description: 'File size exceeds maximum allowed size',
          confidence: 1.0,
        ));
      }
      
      // Check file type
      final allowedTypes = _getAllowedMimeTypes();
      if (!allowedTypes.contains(mimeType)) {
        threats.add(SecurityThreat(
          type: ThreatType.unauthorizedFileType,
          severity: ThreatSeverity.high,
          description: 'File type not allowed: $mimeType',
          confidence: 1.0,
        ));
      }
      
      // Check for embedded malware signatures
      final malwareSignatures = _scanFileForMalware(fileBytes);
      threats.addAll(malwareSignatures);
      
      // Check file metadata
      final metadataIssues = _validateFileMetadata(fileName, mimeType);
      warnings.addAll(metadataIssues);
      
      // Generate file hash for tracking
      final fileHash = _generateFileHash(fileBytes);
      
      // Check against known malicious file hashes
      final isKnownThreat = await _checkAgainstThreatDatabase(fileHash);
      if (isKnownThreat) {
        threats.add(SecurityThreat(
          type: ThreatType.knownMalware,
          severity: ThreatSeverity.critical,
          description: 'File matches known malware signature',
          confidence: 1.0,
        ));
      }
      
      // Log file scan
      await _logFileScan(
        fileName: fileName,
        mimeType: mimeType,
        fileSize: fileBytes.length,
        fileHash: fileHash,
        uploaderId: uploaderId,
        threats: threats,
        warnings: warnings,
      );
      
      return FileScanResult(
        isSecure: threats.isEmpty,
        threats: threats,
        warnings: warnings,
        fileHash: fileHash,
        scanTimestamp: DateTime.now(),
        quarantined: threats.any((t) => t.severity == ThreatSeverity.critical),
      );
    } catch (e) {
      debugPrint('Error scanning file: $e');
      return FileScanResult(
        isSecure: false,
        threats: [
          SecurityThreat(
            type: ThreatType.scanError,
            severity: ThreatSeverity.high,
            description: 'File scan failed: $e',
            confidence: 1.0,
          ),
        ],
        warnings: [],
        fileHash: _generateFileHash(fileBytes),
        scanTimestamp: DateTime.now(),
        quarantined: true,
      );
    }
  }

  /// Create secure file sharing link with expiration
  Future<SecureFileLink> createSecureFileLink({
    required String fileUrl,
    required String ownerId,
    required List<String> authorizedUserIds,
    Duration? expirationTime,
  }) async {
    try {
      final linkId = _generateSecureId();
      final expiresAt = DateTime.now().add(expirationTime ?? contentExpirationTime);
      
      // Encrypt file URL
      final encryptedUrl = encryptContent(fileUrl);
      
      // Create secure link document
      await _firestore.collection('secure_file_links').doc(linkId).set({
        'encryptedUrl': encryptedUrl,
        'ownerId': ownerId,
        'authorizedUserIds': authorizedUserIds,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'accessCount': 0,
        'maxAccess': 100, // Maximum number of accesses
        'isActive': true,
      });
      
      return SecureFileLink(
        linkId: linkId,
        encryptedUrl: encryptedUrl,
        ownerId: ownerId,
        authorizedUserIds: authorizedUserIds,
        expiresAt: expiresAt,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error creating secure file link: $e');
      rethrow;
    }
  }

  /// Access secure file link
  Future<String?> accessSecureFileLink({
    required String linkId,
    required String userId,
  }) async {
    try {
      final linkDoc = await _firestore.collection('secure_file_links').doc(linkId).get();
      
      if (!linkDoc.exists) {
        throw Exception('Secure link not found');
      }
      
      final linkData = linkDoc.data()!;
      
      // Check if link is active
      if (!(linkData['isActive'] as bool? ?? false)) {
        throw Exception('Secure link is no longer active');
      }
      
      // Check expiration
      final expiresAt = (linkData['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        // Deactivate expired link
        await _firestore.collection('secure_file_links').doc(linkId).update({
          'isActive': false,
        });
        throw Exception('Secure link has expired');
      }
      
      // Check authorization
      final authorizedUserIds = List<String>.from(linkData['authorizedUserIds'] ?? []);
      final ownerId = linkData['ownerId'] as String;
      
      if (userId != ownerId && !authorizedUserIds.contains(userId)) {
        // Log unauthorized access attempt
        await _logSecurityEvent(
          eventType: 'unauthorized_file_access',
          userId: userId,
          details: {'linkId': linkId},
        );
        throw Exception('Unauthorized access to secure link');
      }
      
      // Check access count
      final accessCount = linkData['accessCount'] as int? ?? 0;
      final maxAccess = linkData['maxAccess'] as int? ?? 100;
      
      if (accessCount >= maxAccess) {
        await _firestore.collection('secure_file_links').doc(linkId).update({
          'isActive': false,
        });
        throw Exception('Secure link access limit exceeded');
      }
      
      // Increment access count
      await _firestore.collection('secure_file_links').doc(linkId).update({
        'accessCount': FieldValue.increment(1),
        'lastAccessedAt': FieldValue.serverTimestamp(),
        'lastAccessedBy': userId,
      });
      
      // Decrypt and return URL
      final encryptedUrl = linkData['encryptedUrl'] as String;
      return decryptContent(encryptedUrl);
    } catch (e) {
      debugPrint('Error accessing secure file link: $e');
      return null;
    }
  }

  /// Validate user permissions for content access
  Future<bool> validateContentAccess({
    required String contentId,
    required String userId,
    required ContentAccessType accessType,
  }) async {
    try {
      // Get content document
      final contentDoc = await _firestore.collection('posts').doc(contentId).get();
      
      if (!contentDoc.exists) {
        return false;
      }
      
      final contentData = contentDoc.data()!;
      final authorId = contentData['authorId'] as String;
      
      // Author always has access
      if (userId == authorId) {
        return true;
      }
      
      // Check content visibility and permissions
      final visibility = contentData['visibility'] as String? ?? 'public';
      
      switch (visibility) {
        case 'public':
          return true;
        case 'network':
          return await _isInUserNetwork(userId, authorId);
        case 'private':
          return false;
        default:
          return false;
      }
    } catch (e) {
      debugPrint('Error validating content access: $e');
      return false;
    }
  }

  /// Clean up expired secure links and content
  Future<void> cleanupExpiredContent() async {
    try {
      final now = Timestamp.now();
      
      // Clean up expired secure links
      final expiredLinksQuery = await _firestore
          .collection('secure_file_links')
          .where('expiresAt', isLessThan: now)
          .where('isActive', isEqualTo: true)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in expiredLinksQuery.docs) {
        batch.update(doc.reference, {'isActive': false});
      }
      
      await batch.commit();
      
      debugPrint('Cleaned up ${expiredLinksQuery.docs.length} expired secure links');
    } catch (e) {
      debugPrint('Error cleaning up expired content: $e');
    }
  }

  // Private helper methods

  List<SecurityThreat> _scanForMalware(String content) {
    final threats = <SecurityThreat>[];
    
    for (final pattern in suspiciousPatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      if (regex.hasMatch(content)) {
        threats.add(SecurityThreat(
          type: ThreatType.maliciousCode,
          severity: ThreatSeverity.high,
          description: 'Suspicious code pattern detected: $pattern',
          confidence: 0.8,
        ));
      }
    }
    
    return threats;
  }

  List<SecurityThreat> _scanForInappropriateContent(String content) {
    final threats = <SecurityThreat>[];
    
    for (final pattern in inappropriatePatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      if (regex.hasMatch(content)) {
        threats.add(SecurityThreat(
          type: ThreatType.inappropriateContent,
          severity: ThreatSeverity.medium,
          description: 'Inappropriate content detected',
          confidence: 0.6,
        ));
      }
    }
    
    return threats;
  }

  List<String> _validateContentStructure(String content, ContentType contentType) {
    final warnings = <String>[];
    
    // Check content length
    if (content.length > 10000) {
      warnings.add('Content is very long and may impact performance');
    }
    
    // Check for excessive special characters
    final specialCharCount = content.replaceAll(RegExp(r'[a-zA-Z0-9\s]'), '').length;
    if (specialCharCount > content.length * 0.3) {
      warnings.add('Content contains many special characters');
    }
    
    return warnings;
  }

  double _calculateSpamScore(String content) {
    double score = 0.0;
    
    // Check for excessive capitalization
    final capsCount = content.replaceAll(RegExp(r'[^A-Z]'), '').length;
    if (capsCount > content.length * 0.5) {
      score += 0.3;
    }
    
    // Check for repeated characters
    if (RegExp(r'(.)\1{4,}').hasMatch(content)) {
      score += 0.2;
    }
    
    // Check for excessive punctuation
    final punctCount = content.replaceAll(RegExp(r'[^!?.]'), '').length;
    if (punctCount > content.length * 0.1) {
      score += 0.2;
    }
    
    // Check for spam keywords
    final spamKeywords = ['free', 'urgent', 'limited time', 'act now', 'guaranteed'];
    for (final keyword in spamKeywords) {
      if (content.toLowerCase().contains(keyword)) {
        score += 0.1;
      }
    }
    
    return score.clamp(0.0, 1.0);
  }

  List<String> _getAllowedMimeTypes() {
    return [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
      'application/pdf',
      'text/plain',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    ];
  }

  List<SecurityThreat> _scanFileForMalware(Uint8List fileBytes) {
    final threats = <SecurityThreat>[];
    
    // Check for suspicious file headers
    final header = fileBytes.take(16).toList();
    
    // Check for executable file signatures
    if (_isExecutableFile(header)) {
      threats.add(SecurityThreat(
        type: ThreatType.executableFile,
        severity: ThreatSeverity.high,
        description: 'File appears to be executable',
        confidence: 0.9,
      ));
    }
    
    // Check for embedded scripts in images
    final fileString = String.fromCharCodes(fileBytes.take(1000));
    if (fileString.contains('<script') || fileString.contains('javascript:')) {
      threats.add(SecurityThreat(
        type: ThreatType.embeddedScript,
        severity: ThreatSeverity.high,
        description: 'File contains embedded scripts',
        confidence: 0.8,
      ));
    }
    
    return threats;
  }

  bool _isExecutableFile(List<int> header) {
    // Check for common executable file signatures
    final signatures = [
      [0x4D, 0x5A], // PE executable (Windows)
      [0x7F, 0x45, 0x4C, 0x46], // ELF executable (Linux)
      [0xCF, 0xFA, 0xED, 0xFE], // Mach-O executable (macOS)
    ];
    
    for (final signature in signatures) {
      if (header.length >= signature.length) {
        bool matches = true;
        for (int i = 0; i < signature.length; i++) {
          if (header[i] != signature[i]) {
            matches = false;
            break;
          }
        }
        if (matches) return true;
      }
    }
    
    return false;
  }

  List<String> _validateFileMetadata(String fileName, String mimeType) {
    final warnings = <String>[];
    
    // Check file extension vs MIME type consistency
    final extension = fileName.split('.').last.toLowerCase();
    final expectedMimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
    };
    
    if (expectedMimeTypes.containsKey(extension) &&
        expectedMimeTypes[extension] != mimeType) {
      warnings.add('File extension does not match MIME type');
    }
    
    return warnings;
  }

  String _generateContentHash(String content) {
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _generateFileHash(Uint8List fileBytes) {
    final digest = sha256.convert(fileBytes);
    return digest.toString();
  }

  String _generateSecureId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 1000 + (timestamp % 1000)).toString();
    return sha256.convert(utf8.encode(random)).toString().substring(0, 16);
  }

  Future<bool> _checkAgainstThreatDatabase(String fileHash) async {
    try {
      // In production, this would check against a real threat database
      final knownThreats = [
        // Add known malicious file hashes
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      ];
      
      return knownThreats.contains(fileHash);
    } catch (e) {
      debugPrint('Error checking threat database: $e');
      return false;
    }
  }

  Future<bool> _isInUserNetwork(String userId, String authorId) async {
    try {
      // Check if users are in the same network (simplified implementation)
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final authorDoc = await _firestore.collection('users').doc(authorId).get();
      
      if (!userDoc.exists || !authorDoc.exists) {
        return false;
      }
      
      // Check if they share the same geographic area or referral network
      final userLocation = userDoc.data()?['address'];
      final authorLocation = authorDoc.data()?['address'];
      
      if (userLocation != null && authorLocation != null) {
        return userLocation['districtCode'] == authorLocation['districtCode'];
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking user network: $e');
      return false;
    }
  }

  Future<void> _logSecurityScan({
    required String content,
    required ContentType contentType,
    String? authorId,
    required List<SecurityThreat> threats,
    required List<String> warnings,
  }) async {
    try {
      await _firestore.collection('security_logs').add({
        'type': 'content_scan',
        'contentType': contentType.toString(),
        'authorId': authorId,
        'contentHash': _generateContentHash(content),
        'threatsFound': threats.length,
        'warningsFound': warnings.length,
        'threats': threats.map((t) => t.toMap()).toList(),
        'warnings': warnings,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging security scan: $e');
    }
  }

  Future<void> _logFileScan({
    required String fileName,
    required String mimeType,
    required int fileSize,
    required String fileHash,
    String? uploaderId,
    required List<SecurityThreat> threats,
    required List<String> warnings,
  }) async {
    try {
      await _firestore.collection('security_logs').add({
        'type': 'file_scan',
        'fileName': fileName,
        'mimeType': mimeType,
        'fileSize': fileSize,
        'fileHash': fileHash,
        'uploaderId': uploaderId,
        'threatsFound': threats.length,
        'warningsFound': warnings.length,
        'threats': threats.map((t) => t.toMap()).toList(),
        'warnings': warnings,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging file scan: $e');
    }
  }

  Future<void> _logSecurityEvent({
    required String eventType,
    required String userId,
    required Map<String, dynamic> details,
  }) async {
    try {
      await _firestore.collection('security_events').add({
        'eventType': eventType,
        'userId': userId,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': null, // Would be populated in production
        'userAgent': null, // Would be populated in production
      });
    } catch (e) {
      debugPrint('Error logging security event: $e');
    }
  }
}

// Data models for security

enum ContentType { text, image, document, video, audio }
enum ContentAccessType { read, write, delete, share }
enum ThreatType { 
  maliciousCode, 
  inappropriateContent, 
  spam, 
  executableFile, 
  embeddedScript, 
  oversizedFile, 
  unauthorizedFileType, 
  knownMalware, 
  scanError 
}
enum ThreatSeverity { low, medium, high, critical }

class SecurityThreat {
  final ThreatType type;
  final ThreatSeverity severity;
  final String description;
  final double confidence;

  SecurityThreat({
    required this.type,
    required this.severity,
    required this.description,
    required this.confidence,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString(),
      'severity': severity.toString(),
      'description': description,
      'confidence': confidence,
    };
  }
}

class SecurityScanResult {
  final bool isSecure;
  final List<SecurityThreat> threats;
  final List<String> warnings;
  final DateTime scanTimestamp;
  final String contentHash;

  SecurityScanResult({
    required this.isSecure,
    required this.threats,
    required this.warnings,
    required this.scanTimestamp,
    required this.contentHash,
  });
}

class FileScanResult {
  final bool isSecure;
  final List<SecurityThreat> threats;
  final List<String> warnings;
  final String fileHash;
  final DateTime scanTimestamp;
  final bool quarantined;

  FileScanResult({
    required this.isSecure,
    required this.threats,
    required this.warnings,
    required this.fileHash,
    required this.scanTimestamp,
    required this.quarantined,
  });
}

class SecureFileLink {
  final String linkId;
  final String encryptedUrl;
  final String ownerId;
  final List<String> authorizedUserIds;
  final DateTime expiresAt;
  final DateTime createdAt;

  SecureFileLink({
    required this.linkId,
    required this.encryptedUrl,
    required this.ownerId,
    required this.authorizedUserIds,
    required this.expiresAt,
    required this.createdAt,
  });
}
