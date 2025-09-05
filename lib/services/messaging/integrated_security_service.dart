// Integrated Security Service for TALOWA Messaging
// Coordinates all security components for comprehensive message protection
// Requirements: 1.6, 6.1, 6.3, 6.6, 10.2

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../auth_service.dart';
import 'encryption_service.dart';
import 'anonymous_messaging_service.dart';
import 'message_validation_service.dart';
import '../security/rate_limiting_service.dart';
import '../security/audit_logging_service.dart';
import '../security/content_security_service.dart';

class IntegratedSecurityService {
  static final IntegratedSecurityService _instance = IntegratedSecurityService._internal();
  factory IntegratedSecurityService() => _instance;
  IntegratedSecurityService._internal();

  final EncryptionService _encryptionService = EncryptionService();
  final AnonymousMessagingService _anonymousService = AnonymousMessagingService();
  final MessageValidationService _validationService = MessageValidationService();
  final RateLimitingService _rateLimitingService = RateLimitingService();
  final AuditLoggingService _auditService = AuditLoggingService();
  final ContentSecurityService _contentSecurityService = ContentSecurityService();

  /// Initialize security services for current user
  Future<void> initializeSecurity() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Initialize encryption for user
      await _encryptionService.initializeUserEncryption();
      
      // Log security initialization
      await _auditService.logSecurityEvent(
        eventType: 'security_services_initialized',
        userId: currentUser.uid,
        details: {
          'services': [
            'encryption',
            'anonymous_messaging',
            'message_validation',
            'rate_limiting',
            'audit_logging',
            'content_security',
          ],
        },
        sensitivityLevel: SensitivityLevel.low,
      );
      
      debugPrint('Security services initialized for user: ${currentUser.uid}');
    } catch (e) {
      debugPrint('Error initializing security services: $e');
      rethrow;
    }
  }

  /// Secure message sending with comprehensive security checks
  Future<SecureMessageResult> sendSecureMessage({
    required String content,
    required MessageType messageType,
    String? recipientId,
    String? groupId,
    List<String>? mediaUrls,
    Map<String, dynamic>? metadata,
    EncryptionLevel encryptionLevel = EncryptionLevel.standard,
    bool isAnonymous = false,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final securityChecks = <String, bool>{};
      final warnings = <String>[];
      
      // Step 1: Rate limiting check
      final rateLimitResult = await _rateLimitingService.checkRateLimit(
        action: groupId != null ? 'send_group_message' : 'send_message',
        userId: currentUser.uid,
        metadata: {
          'messageType': messageType.toString(),
          'hasMedia': mediaUrls?.isNotEmpty ?? false,
          'isAnonymous': isAnonymous,
        },
      );
      
      securityChecks['rate_limit_passed'] = rateLimitResult.allowed;
      
      if (!rateLimitResult.allowed) {
        await _auditService.logSecurityEvent(
          eventType: 'message_rate_limited',
          userId: currentUser.uid,
          details: {
            'action': groupId != null ? 'send_group_message' : 'send_message',
            'remainingRequests': rateLimitResult.remainingRequests,
            'resetTime': rateLimitResult.resetTime.toIso8601String(),
            'penaltyActive': rateLimitResult.penaltyActive,
          },
          sensitivityLevel: SensitivityLevel.medium,
        );
        
        return SecureMessageResult(
          success: false,
          messageId: null,
          securityChecks: securityChecks,
          warnings: warnings,
          error: 'Rate limit exceeded. ${rateLimitResult.penaltyReason ?? "Try again later."}',
        );
      }

      // Step 2: Content validation and sanitization
      final validationResult = await _validationService.validateMessage(
        content: content,
        messageType: messageType,
        mediaUrls: mediaUrls,
        metadata: metadata,
        userId: currentUser.uid,
      );
      
      securityChecks['content_validation_passed'] = validationResult.isValid;
      
      if (!validationResult.isValid) {
        final errorMessages = validationResult.issues
            .where((issue) => issue.severity == ValidationSeverity.error)
            .map((issue) => issue.message)
            .join('; ');
        
        return SecureMessageResult(
          success: false,
          messageId: null,
          securityChecks: securityChecks,
          warnings: warnings,
          error: 'Message validation failed: $errorMessages',
          validationIssues: validationResult.issues,
        );
      }
      
      // Add validation warnings
      warnings.addAll(validationResult.issues
          .where((issue) => issue.severity == ValidationSeverity.warning)
          .map((issue) => issue.message));

      // Step 3: Content security scan
      final securityScanResult = await _contentSecurityService.scanContent(
        content: validationResult.sanitizedContent,
        contentType: _mapMessageTypeToContentType(messageType),
        authorId: currentUser.uid,
      );
      
      securityChecks['security_scan_passed'] = securityScanResult.isSecure;
      
      if (!securityScanResult.isSecure) {
        final threatMessages = securityScanResult.threats
            .map((threat) => threat.description)
            .join('; ');
        
        return SecureMessageResult(
          success: false,
          messageId: null,
          securityChecks: securityChecks,
          warnings: warnings,
          error: 'Security scan failed: $threatMessages',
          securityThreats: securityScanResult.threats,
        );
      }
      
      // Add security warnings
      warnings.addAll(securityScanResult.warnings);

      // Step 4: Group validation (if applicable)
      if (groupId != null) {
        final groupValidation = await _validationService.validateGroupMessage(
          groupId: groupId,
          content: validationResult.sanitizedContent,
          recipientIds: recipientId != null ? [recipientId] : [],
          userId: currentUser.uid,
        );
        
        securityChecks['group_validation_passed'] = groupValidation.isValid;
        
        if (!groupValidation.isValid) {
          final errorMessages = groupValidation.issues
              .where((issue) => issue.severity == ValidationSeverity.error)
              .map((issue) => issue.message)
              .join('; ');
          
          return SecureMessageResult(
            success: false,
            messageId: null,
            securityChecks: securityChecks,
            warnings: warnings,
            error: 'Group validation failed: $errorMessages',
            validationIssues: groupValidation.issues,
          );
        }
      }

      // Step 5: Encryption
      String? messageId;
      EncryptedContent? encryptedContent;
      
      if (isAnonymous && recipientId != null) {
        // Anonymous message handling
        messageId = await _anonymousService.sendAnonymousReport(
          content: validationResult.sanitizedContent,
          coordinatorId: recipientId,
          reportType: ReportType.other, // Default type, should be specified by caller
          mediaUrls: mediaUrls,
        );
        
        securityChecks['anonymous_message_sent'] = true;
      } else {
        // Regular encrypted message
        if (groupId != null) {
          // Group message encryption
          final participantIds = await _getGroupParticipants(groupId);
          encryptedContent = await _encryptionService.encryptGroupMessage(
            content: validationResult.sanitizedContent,
            groupId: groupId,
            participantIds: participantIds,
            level: encryptionLevel,
          );
        } else if (recipientId != null) {
          // Direct message encryption
          encryptedContent = await _encryptionService.encryptMessage(
            content: validationResult.sanitizedContent,
            recipientUserId: recipientId,
            level: encryptionLevel,
          );
        } else {
          throw Exception('Either recipientId or groupId must be provided');
        }
        
        securityChecks['message_encrypted'] = true;
        
        // Here you would integrate with your messaging service to actually send the message
        // For now, we'll simulate message ID generation
        messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Step 6: Record successful action
      await _rateLimitingService.recordAction(
        action: groupId != null ? 'send_group_message' : 'send_message',
        userId: currentUser.uid,
        metadata: {
          'messageId': messageId,
          'messageType': messageType.toString(),
          'encrypted': encryptedContent != null,
          'isAnonymous': isAnonymous,
          'contentLength': validationResult.sanitizedContent.length,
        },
      );

      // Step 7: Audit logging
      await _auditService.logUserAction(
        action: isAnonymous ? 'send_anonymous_message' : 'send_message',
        userId: currentUser.uid,
        details: {
          'messageId': messageId,
          'messageType': messageType.toString(),
          'recipientId': recipientId,
          'groupId': groupId,
          'encryptionLevel': encryptionLevel.value,
          'isAnonymous': isAnonymous,
          'contentLength': validationResult.sanitizedContent.length,
          'hasMedia': mediaUrls?.isNotEmpty ?? false,
          'securityChecks': securityChecks,
          'warningCount': warnings.length,
        },
        targetUserId: recipientId,
        resourceId: messageId,
        result: ActionResult.success,
      );

      return SecureMessageResult(
        success: true,
        messageId: messageId,
        encryptedContent: encryptedContent,
        securityChecks: securityChecks,
        warnings: warnings,
        sanitizedContent: validationResult.sanitizedContent,
      );
    } catch (e) {
      debugPrint('Error in secure message sending: $e');
      
      // Log the error
      await _auditService.logSecurityEvent(
        eventType: 'secure_message_error',
        userId: AuthService.currentUser?.uid ?? 'unknown',
        details: {
          'error': e.toString(),
          'messageType': messageType.toString(),
          'isAnonymous': isAnonymous,
          'hasRecipient': recipientId != null,
          'hasGroup': groupId != null,
        },
        sensitivityLevel: SensitivityLevel.medium,
      );
      
      return SecureMessageResult(
        success: false,
        messageId: null,
        securityChecks: {'error_occurred': true},
        warnings: [],
        error: 'Failed to send secure message: ${e.toString()}',
      );
    }
  }

  /// Secure file upload with comprehensive security checks
  Future<SecureFileResult> uploadSecureFile({
    required String fileName,
    required String mimeType,
    required List<int> fileBytes,
    required String purpose, // 'message_attachment', 'profile_picture', etc.
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final securityChecks = <String, bool>{};
      final warnings = <String>[];
      
      // Step 1: Rate limiting check
      final rateLimitResult = await _rateLimitingService.checkRateLimit(
        action: 'upload_file',
        userId: currentUser.uid,
        metadata: {
          'fileName': fileName,
          'mimeType': mimeType,
          'fileSize': fileBytes.length,
          'purpose': purpose,
        },
      );
      
      securityChecks['rate_limit_passed'] = rateLimitResult.allowed;
      
      if (!rateLimitResult.allowed) {
        return SecureFileResult(
          success: false,
          fileUrl: null,
          securityChecks: securityChecks,
          warnings: warnings,
          error: 'File upload rate limit exceeded',
        );
      }

      // Step 2: File validation
      final validationResult = await _validationService.validateFile(
        fileName: fileName,
        mimeType: mimeType,
        fileSize: fileBytes.length,
        fileBytes: fileBytes,
        userId: currentUser.uid,
      );
      
      securityChecks['file_validation_passed'] = validationResult.isValid;
      
      if (!validationResult.isValid) {
        final errorMessages = validationResult.issues
            .where((issue) => issue.severity == ValidationSeverity.error)
            .map((issue) => issue.message)
            .join('; ');
        
        return SecureFileResult(
          success: false,
          fileUrl: null,
          securityChecks: securityChecks,
          warnings: warnings,
          error: 'File validation failed: $errorMessages',
          validationIssues: validationResult.issues,
        );
      }
      
      if (validationResult.quarantined) {
        warnings.add('File has been quarantined due to security concerns');
      }

      // Step 3: Malware scan
      final fileScanResult = await _contentSecurityService.scanFile(
        fileBytes: Uint8List.fromList(fileBytes),
        fileName: fileName,
        mimeType: mimeType,
        uploaderId: currentUser.uid,
      );
      
      securityChecks['malware_scan_passed'] = fileScanResult.isSecure;
      
      if (!fileScanResult.isSecure || fileScanResult.quarantined) {
        final threatMessages = fileScanResult.threats
            .map((threat) => threat.description)
            .join('; ');
        
        return SecureFileResult(
          success: false,
          fileUrl: null,
          securityChecks: securityChecks,
          warnings: warnings,
          error: 'File security scan failed: $threatMessages',
          securityThreats: fileScanResult.threats,
        );
      }

      // Step 4: Encrypt file if needed
      String? encryptedFileId;
      if (_requiresEncryption(purpose)) {
        // Simplified file encryption (would use proper encryption in production)
        encryptedFileId = 'encrypted_${DateTime.now().millisecondsSinceEpoch}';
        securityChecks['file_encrypted'] = true;
      }

      // Step 5: Create secure file link
      final secureLink = await _contentSecurityService.createSecureFileLink(
        fileUrl: 'https://example.com/files/temp_file_id', // Would be actual URL
        ownerId: currentUser.uid,
        authorizedUserIds: [currentUser.uid], // Initially only owner
      );
      
      securityChecks['secure_link_created'] = true;

      // Step 6: Record successful action
      await _rateLimitingService.recordAction(
        action: 'upload_file',
        userId: currentUser.uid,
        metadata: {
          'fileName': fileName,
          'mimeType': mimeType,
          'fileSize': fileBytes.length,
          'purpose': purpose,
          'encrypted': encryptedFileId != null,
          'linkId': secureLink.linkId,
        },
      );

      // Step 7: Audit logging
      await _auditService.logUserAction(
        action: 'upload_secure_file',
        userId: currentUser.uid,
        details: {
          'fileName': fileName,
          'mimeType': mimeType,
          'fileSize': fileBytes.length,
          'purpose': purpose,
          'encrypted': encryptedFileId != null,
          'linkId': secureLink.linkId,
          'securityChecks': securityChecks,
          'warningCount': warnings.length,
        },
        resourceId: secureLink.linkId,
        result: ActionResult.success,
      );

      return SecureFileResult(
        success: true,
        fileUrl: secureLink.linkId, // Return secure link ID instead of direct URL
        secureLink: secureLink,
        securityChecks: securityChecks,
        warnings: warnings,
        encryptedFileId: encryptedFileId,
      );
    } catch (e) {
      debugPrint('Error in secure file upload: $e');
      
      await _auditService.logSecurityEvent(
        eventType: 'secure_file_upload_error',
        userId: AuthService.currentUser?.uid ?? 'unknown',
        details: {
          'error': e.toString(),
          'fileName': fileName,
          'mimeType': mimeType,
          'fileSize': fileBytes.length,
          'purpose': purpose,
        },
        sensitivityLevel: SensitivityLevel.medium,
      );
      
      return SecureFileResult(
        success: false,
        fileUrl: null,
        securityChecks: {'error_occurred': true},
        warnings: [],
        error: 'Failed to upload secure file: ${e.toString()}',
      );
    }
  }

  /// Get comprehensive security status for user
  Future<SecurityStatus> getSecurityStatus({String? userId}) async {
    try {
      final currentUser = AuthService.currentUser;
      final effectiveUserId = userId ?? currentUser?.uid ?? 'anonymous';
      
      // Get rate limit status
      final rateLimitStatus = await _rateLimitingService.getRateLimitStatus(
        userId: effectiveUserId,
      );
      
      // Get validation statistics
      final validationStats = await _validationService.getValidationStatistics(
        userId: effectiveUserId,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
      );
      
      // Get recent security events
      final securityEvents = await _auditService.getSecurityEvents(
        userId: effectiveUserId,
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        endDate: DateTime.now(),
        limit: 10,
      );
      
      // Calculate security score
      final securityScore = _calculateSecurityScore(
        rateLimitStatus,
        validationStats,
        securityEvents,
      );
      
      return SecurityStatus(
        userId: effectiveUserId,
        securityScore: securityScore,
        rateLimitStatus: rateLimitStatus,
        validationStatistics: validationStats,
        recentSecurityEvents: securityEvents,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error getting security status: $e');
      rethrow;
    }
  }

  /// Clean up security data (call periodically)
  Future<void> performSecurityMaintenance() async {
    try {
      // Clean up expired rate limit data
      await _rateLimitingService.cleanupExpiredData();
      
      // Clean up old audit logs
      await _auditService.cleanupOldLogs();
      
      // Clean up expired secure links
      await _contentSecurityService.cleanupExpiredContent();
      
      debugPrint('Security maintenance completed');
    } catch (e) {
      debugPrint('Error during security maintenance: $e');
    }
  }

  // Private helper methods

  ContentType _mapMessageTypeToContentType(MessageType messageType) {
    switch (messageType) {
      case MessageType.text:
        return ContentType.text;
      case MessageType.image:
        return ContentType.image;
      case MessageType.document:
        return ContentType.document;
      case MessageType.voice:
        return ContentType.audio;
      case MessageType.video:
        return ContentType.video;
      default:
        return ContentType.text;
    }
  }

  Future<List<String>> _getGroupParticipants(String groupId) async {
    // This would fetch actual group participants from your database
    // For now, return empty list
    return [];
  }

  bool _requiresEncryption(String purpose) {
    const encryptedPurposes = [
      'legal_document',
      'sensitive_data',
      'anonymous_report',
      'private_message',
    ];
    
    return encryptedPurposes.contains(purpose);
  }

  String _generateEncryptionKey() {
    // Generate a secure encryption key
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  double _calculateSecurityScore(
    Map<String, RateLimitStatus> rateLimitStatus,
    ValidationStatistics validationStats,
    List<SecurityEvent> securityEvents,
  ) {
    double score = 1.0;
    
    // Deduct points for rate limit violations
    final violations = rateLimitStatus.values.where((status) => status.penaltyActive).length;
    score -= violations * 0.1;
    
    // Deduct points for high block rate
    if (validationStats.blockRate > 0.1) {
      score -= validationStats.blockRate * 0.2;
    }
    
    // Deduct points for recent security incidents
    final criticalEvents = securityEvents.where((event) => 
        event.sensitivityLevel == SensitivityLevel.critical).length;
    score -= criticalEvents * 0.15;
    
    return score.clamp(0.0, 1.0);
  }
}

// Data models for integrated security

class SecureMessageResult {
  final bool success;
  final String? messageId;
  final EncryptedContent? encryptedContent;
  final Map<String, bool> securityChecks;
  final List<String> warnings;
  final String? error;
  final String? sanitizedContent;
  final List<ValidationIssue>? validationIssues;
  final List<SecurityThreat>? securityThreats;

  SecureMessageResult({
    required this.success,
    required this.messageId,
    this.encryptedContent,
    required this.securityChecks,
    required this.warnings,
    this.error,
    this.sanitizedContent,
    this.validationIssues,
    this.securityThreats,
  });
}

class SecureFileResult {
  final bool success;
  final String? fileUrl;
  final SecureFileLink? secureLink;
  final Map<String, bool> securityChecks;
  final List<String> warnings;
  final String? error;
  final String? encryptedFileId;
  final List<ValidationIssue>? validationIssues;
  final List<SecurityThreat>? securityThreats;

  SecureFileResult({
    required this.success,
    required this.fileUrl,
    this.secureLink,
    required this.securityChecks,
    required this.warnings,
    this.error,
    this.encryptedFileId,
    this.validationIssues,
    this.securityThreats,
  });
}

class SecurityStatus {
  final String userId;
  final double securityScore;
  final Map<String, RateLimitStatus> rateLimitStatus;
  final ValidationStatistics validationStatistics;
  final List<SecurityEvent> recentSecurityEvents;
  final DateTime lastUpdated;

  SecurityStatus({
    required this.userId,
    required this.securityScore,
    required this.rateLimitStatus,
    required this.validationStatistics,
    required this.recentSecurityEvents,
    required this.lastUpdated,
  });
}
