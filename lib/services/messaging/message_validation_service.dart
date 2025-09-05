// Message Validation and Sanitization Service for TALOWA
// Implements message validation and sanitization to prevent malicious content
// Requirements: 6.6, 10.2

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../security/audit_logging_service.dart';
import '../auth_service.dart';

class MessageValidationService {
  static final MessageValidationService _instance = MessageValidationService._internal();
  factory MessageValidationService() => _instance;
  MessageValidationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditLoggingService _auditService = AuditLoggingService();
  
  // Validation rules and patterns
  static const int maxMessageLength = 5000;
  static const int maxMediaFiles = 10;
  static const int maxFileSize = 25 * 1024 * 1024; // 25MB
  
  // Malicious patterns to detect and block
  static const List<String> maliciousPatterns = [
    // Script injection patterns
    r'<script[^>]*>.*?</script>',
    r'javascript:',
    r'vbscript:',
    r'data:text/html',
    r'onload\s*=',
    r'onerror\s*=',
    r'onclick\s*=',
    r'onmouseover\s*=',
    
    // SQL injection patterns
    r'union\s+select',
    r'drop\s+table',
    r'delete\s+from',
    r'insert\s+into',
    r'update\s+set',
    
    // Command injection patterns
    r';\s*rm\s+-rf',
    r';\s*cat\s+/etc/passwd',
    r';\s*wget\s+',
    r';\s*curl\s+',
    
    // XSS patterns
    r'eval\s*\(',
    r'document\.cookie',
    r'window\.location',
    r'alert\s*\(',
    r'confirm\s*\(',
    r'prompt\s*\(',
  ];
  
  // Spam patterns
  static const List<String> spamPatterns = [
    r'\b(free|urgent|limited time|act now|guaranteed|winner|congratulations)\b',
    r'\b(click here|visit now|call now|order now|buy now)\b',
    r'\b(money back|risk free|no obligation|special offer)\b',
    r'\b(viagra|cialis|pharmacy|casino|lottery|prize)\b',
  ];
  
  // Inappropriate content patterns
  static const List<String> inappropriatePatterns = [
    r'\b(hate|violence|threat|kill|murder|bomb)\b',
    r'\b(racist|terrorism|extremist|radical)\b',
    r'\b(drugs|cocaine|heroin|marijuana|illegal)\b',
    r'\b(scam|fraud|fake|phishing|malware)\b',
  ];
  
  // Allowed file types
  static const List<String> allowedMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'application/pdf',
    'text/plain',
    'audio/mpeg',
    'audio/wav',
    'audio/ogg',
    'video/mp4',
    'video/webm',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  ];

  /// Validate and sanitize message content
  Future<MessageValidationResult> validateMessage({
    required String content,
    required MessageType messageType,
    List<String>? mediaUrls,
    Map<String, dynamic>? metadata,
    String? userId,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      final effectiveUserId = userId ?? currentUser?.uid ?? 'anonymous';
      
      final issues = <ValidationIssue>[];
      String sanitizedContent = content;
      
      // Basic validation
      if (content.trim().isEmpty && (mediaUrls?.isEmpty ?? true)) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.emptyContent,
          severity: ValidationSeverity.error,
          message: 'Message cannot be empty',
        ));
      }
      
      // Length validation
      if (content.length > maxMessageLength) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.contentTooLong,
          severity: ValidationSeverity.error,
          message: 'Message exceeds maximum length of $maxMessageLength characters',
        ));
      }
      
      // Malicious content detection
      final maliciousIssues = _detectMaliciousContent(content);
      issues.addAll(maliciousIssues);
      
      // Spam detection
      final spamIssues = _detectSpamContent(content);
      issues.addAll(spamIssues);
      
      // Inappropriate content detection
      final inappropriateIssues = _detectInappropriateContent(content);
      issues.addAll(inappropriateIssues);
      
      // Content sanitization
      sanitizedContent = _sanitizeContent(content);
      
      // Media validation
      if (mediaUrls != null && mediaUrls.isNotEmpty) {
        final mediaIssues = await _validateMediaFiles(mediaUrls);
        issues.addAll(mediaIssues);
      }
      
      // Metadata validation
      if (metadata != null) {
        final metadataIssues = _validateMetadata(metadata);
        issues.addAll(metadataIssues);
      }
      
      // Calculate risk score
      final riskScore = _calculateRiskScore(issues);
      
      // Determine if message should be blocked
      final hasBlockingIssues = issues.any((issue) => 
          issue.severity == ValidationSeverity.error ||
          (issue.severity == ValidationSeverity.warning && riskScore > 0.7));
      
      // Log validation results
      await _logValidationResult(
        userId: effectiveUserId,
        content: content,
        messageType: messageType,
        issues: issues,
        riskScore: riskScore,
        blocked: hasBlockingIssues,
      );
      
      return MessageValidationResult(
        isValid: !hasBlockingIssues,
        sanitizedContent: sanitizedContent,
        issues: issues,
        riskScore: riskScore,
        originalLength: content.length,
        sanitizedLength: sanitizedContent.length,
      );
    } catch (e) {
      debugPrint('Error validating message: $e');
      
      // Log validation error
      await _auditService.logSecurityEvent(
        eventType: 'message_validation_error',
        userId: userId ?? 'unknown',
        details: {
          'error': e.toString(),
          'messageType': messageType.toString(),
          'contentLength': content.length,
        },
        sensitivityLevel: SensitivityLevel.medium,
      );
      
      // Return safe default - block the message
      return MessageValidationResult(
        isValid: false,
        sanitizedContent: '',
        issues: [
          ValidationIssue(
            type: ValidationIssueType.validationError,
            severity: ValidationSeverity.error,
            message: 'Message validation failed: ${e.toString()}',
          ),
        ],
        riskScore: 1.0,
        originalLength: content.length,
        sanitizedLength: 0,
      );
    }
  }

  /// Validate file upload
  Future<FileValidationResult> validateFile({
    required String fileName,
    required String mimeType,
    required int fileSize,
    required List<int> fileBytes,
    String? userId,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      final effectiveUserId = userId ?? currentUser?.uid ?? 'anonymous';
      
      final issues = <ValidationIssue>[];
      
      // File size validation
      if (fileSize > maxFileSize) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.fileTooLarge,
          severity: ValidationSeverity.error,
          message: 'File size exceeds maximum allowed size of ${maxFileSize ~/ (1024 * 1024)}MB',
        ));
      }
      
      // MIME type validation
      if (!allowedMimeTypes.contains(mimeType)) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.invalidFileType,
          severity: ValidationSeverity.error,
          message: 'File type $mimeType is not allowed',
        ));
      }
      
      // File extension validation
      final extension = fileName.split('.').last.toLowerCase();
      if (!_isValidFileExtension(extension, mimeType)) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.mismatchedFileType,
          severity: ValidationSeverity.warning,
          message: 'File extension does not match MIME type',
        ));
      }
      
      // File content validation
      final contentIssues = _validateFileContent(fileBytes, mimeType);
      issues.addAll(contentIssues);
      
      // Malware signature detection
      final malwareIssues = _detectMalwareSignatures(fileBytes);
      issues.addAll(malwareIssues);
      
      // Calculate risk score
      final riskScore = _calculateRiskScore(issues);
      
      // Determine if file should be blocked
      final hasBlockingIssues = issues.any((issue) => 
          issue.severity == ValidationSeverity.error);
      
      // Log file validation
      await _logFileValidation(
        userId: effectiveUserId,
        fileName: fileName,
        mimeType: mimeType,
        fileSize: fileSize,
        issues: issues,
        riskScore: riskScore,
        blocked: hasBlockingIssues,
      );
      
      return FileValidationResult(
        isValid: !hasBlockingIssues,
        issues: issues,
        riskScore: riskScore,
        quarantined: riskScore > 0.8,
      );
    } catch (e) {
      debugPrint('Error validating file: $e');
      
      // Log validation error
      await _auditService.logSecurityEvent(
        eventType: 'file_validation_error',
        userId: userId ?? 'unknown',
        details: {
          'error': e.toString(),
          'fileName': fileName,
          'mimeType': mimeType,
          'fileSize': fileSize,
        },
        sensitivityLevel: SensitivityLevel.medium,
      );
      
      // Return safe default - block the file
      return FileValidationResult(
        isValid: false,
        issues: [
          ValidationIssue(
            type: ValidationIssueType.validationError,
            severity: ValidationSeverity.error,
            message: 'File validation failed: ${e.toString()}',
          ),
        ],
        riskScore: 1.0,
        quarantined: true,
      );
    }
  }

  /// Validate group message settings
  Future<GroupValidationResult> validateGroupMessage({
    required String groupId,
    required String content,
    required List<String> recipientIds,
    String? userId,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      final effectiveUserId = userId ?? currentUser?.uid ?? 'anonymous';
      
      final issues = <ValidationIssue>[];
      
      // Group existence validation
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.invalidGroup,
          severity: ValidationSeverity.error,
          message: 'Group does not exist',
        ));
        
        return GroupValidationResult(
          isValid: false,
          issues: issues,
          allowedRecipients: [],
        );
      }
      
      final groupData = groupDoc.data()!;
      final groupMembers = List<String>.from(groupData['memberIds'] ?? []);
      
      // Sender permission validation
      if (!groupMembers.contains(effectiveUserId)) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.unauthorizedSender,
          severity: ValidationSeverity.error,
          message: 'User is not a member of this group',
        ));
      }
      
      // Recipient validation
      final allowedRecipients = <String>[];
      for (final recipientId in recipientIds) {
        if (groupMembers.contains(recipientId)) {
          allowedRecipients.add(recipientId);
        } else {
          issues.add(ValidationIssue(
            type: ValidationIssueType.invalidRecipient,
            severity: ValidationSeverity.warning,
            message: 'Recipient $recipientId is not a group member',
          ));
        }
      }
      
      // Group settings validation
      final groupSettings = groupData['settings'] as Map<String, dynamic>? ?? {};
      
      // Check if user can send messages
      final whoCanSendMessages = groupSettings['whoCanSendMessages'] ?? 'all';
      final userRole = await _getUserRoleInGroup(effectiveUserId, groupId);
      
      if (!_canUserSendMessages(whoCanSendMessages, userRole)) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.insufficientPermissions,
          severity: ValidationSeverity.error,
          message: 'User does not have permission to send messages in this group',
        ));
      }
      
      // Message content validation
      final contentValidation = await validateMessage(
        content: content,
        messageType: MessageType.text,
        userId: effectiveUserId,
      );
      
      issues.addAll(contentValidation.issues);
      
      final hasBlockingIssues = issues.any((issue) => 
          issue.severity == ValidationSeverity.error);
      
      return GroupValidationResult(
        isValid: !hasBlockingIssues,
        issues: issues,
        allowedRecipients: allowedRecipients,
        sanitizedContent: contentValidation.sanitizedContent,
      );
    } catch (e) {
      debugPrint('Error validating group message: $e');
      
      return GroupValidationResult(
        isValid: false,
        issues: [
          ValidationIssue(
            type: ValidationIssueType.validationError,
            severity: ValidationSeverity.error,
            message: 'Group validation failed: ${e.toString()}',
          ),
        ],
        allowedRecipients: [],
      );
    }
  }

  /// Get validation statistics
  Future<ValidationStatistics> getValidationStatistics({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('validation_logs');
      
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      final snapshot = await query.get();
      
      int totalValidations = 0;
      int blockedMessages = 0;
      int maliciousContent = 0;
      int spamContent = 0;
      int inappropriateContent = 0;
      final riskScores = <double>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalValidations++;
        
        if (data['blocked'] == true) {
          blockedMessages++;
        }
        
        final issues = List<Map<String, dynamic>>.from(data['issues'] ?? []);
        for (final issue in issues) {
          final type = issue['type'] as String;
          if (type.contains('malicious')) maliciousContent++;
          if (type.contains('spam')) spamContent++;
          if (type.contains('inappropriate')) inappropriateContent++;
        }
        
        final riskScore = (data['riskScore'] as num?)?.toDouble() ?? 0.0;
        riskScores.add(riskScore);
      }
      
      final averageRiskScore = riskScores.isNotEmpty 
          ? riskScores.reduce((a, b) => a + b) / riskScores.length
          : 0.0;
      
      return ValidationStatistics(
        totalValidations: totalValidations,
        blockedMessages: blockedMessages,
        maliciousContent: maliciousContent,
        spamContent: spamContent,
        inappropriateContent: inappropriateContent,
        averageRiskScore: averageRiskScore,
        blockRate: totalValidations > 0 ? blockedMessages / totalValidations : 0.0,
      );
    } catch (e) {
      debugPrint('Error getting validation statistics: $e');
      return ValidationStatistics(
        totalValidations: 0,
        blockedMessages: 0,
        maliciousContent: 0,
        spamContent: 0,
        inappropriateContent: 0,
        averageRiskScore: 0.0,
        blockRate: 0.0,
      );
    }
  }

  // Private helper methods

  List<ValidationIssue> _detectMaliciousContent(String content) {
    final issues = <ValidationIssue>[];
    
    for (final pattern in maliciousPatterns) {
      final regex = RegExp(pattern, caseSensitive: false, multiLine: true);
      if (regex.hasMatch(content)) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.maliciousContent,
          severity: ValidationSeverity.error,
          message: 'Malicious content pattern detected',
          details: {'pattern': pattern},
        ));
      }
    }
    
    return issues;
  }

  List<ValidationIssue> _detectSpamContent(String content) {
    final issues = <ValidationIssue>[];
    int spamScore = 0;
    
    for (final pattern in spamPatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      if (regex.hasMatch(content)) {
        spamScore++;
      }
    }
    
    // Check for excessive capitalization
    final capsCount = content.replaceAll(RegExp(r'[^A-Z]'), '').length;
    if (capsCount > content.length * 0.5) {
      spamScore++;
    }
    
    // Check for excessive punctuation
    final punctCount = content.replaceAll(RegExp(r'[^!?.]'), '').length;
    if (punctCount > content.length * 0.1) {
      spamScore++;
    }
    
    // Check for repeated characters
    if (RegExp(r'(.)\1{4,}').hasMatch(content)) {
      spamScore++;
    }
    
    if (spamScore >= 2) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.spamContent,
        severity: spamScore >= 3 ? ValidationSeverity.error : ValidationSeverity.warning,
        message: 'Content appears to be spam',
        details: {'spamScore': spamScore},
      ));
    }
    
    return issues;
  }

  List<ValidationIssue> _detectInappropriateContent(String content) {
    final issues = <ValidationIssue>[];
    
    for (final pattern in inappropriatePatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      if (regex.hasMatch(content)) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.inappropriateContent,
          severity: ValidationSeverity.warning,
          message: 'Potentially inappropriate content detected',
          details: {'pattern': pattern},
        ));
      }
    }
    
    return issues;
  }

  String _sanitizeContent(String content) {
    String sanitized = content;
    
    // Remove potential HTML/script tags
    sanitized = sanitized.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Remove potential JavaScript
    sanitized = sanitized.replaceAll(RegExp(r'javascript:', caseSensitive: false), '');
    
    // Remove potential data URLs
    sanitized = sanitized.replaceAll(RegExp(r'data:[^;]*;base64,'), '');
    
    // Normalize whitespace
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return sanitized;
  }

  Future<List<ValidationIssue>> _validateMediaFiles(List<String> mediaUrls) async {
    final issues = <ValidationIssue>[];
    
    if (mediaUrls.length > maxMediaFiles) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.tooManyFiles,
        severity: ValidationSeverity.error,
        message: 'Too many media files (max: $maxMediaFiles)',
      ));
    }
    
    for (final url in mediaUrls) {
      if (!_isValidUrl(url)) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.invalidUrl,
          severity: ValidationSeverity.warning,
          message: 'Invalid media URL: $url',
        ));
      }
    }
    
    return issues;
  }

  List<ValidationIssue> _validateMetadata(Map<String, dynamic> metadata) {
    final issues = <ValidationIssue>[];
    
    // Check metadata size
    final metadataJson = jsonEncode(metadata);
    if (metadataJson.length > 10000) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.metadataTooLarge,
        severity: ValidationSeverity.warning,
        message: 'Metadata is too large',
      ));
    }
    
    // Check for suspicious metadata keys
    final suspiciousKeys = ['script', 'eval', 'function', 'onclick', 'onload'];
    for (final key in metadata.keys) {
      if (suspiciousKeys.any((suspicious) => key.toLowerCase().contains(suspicious))) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.suspiciousMetadata,
          severity: ValidationSeverity.warning,
          message: 'Suspicious metadata key: $key',
        ));
      }
    }
    
    return issues;
  }

  List<ValidationIssue> _validateFileContent(List<int> fileBytes, String mimeType) {
    final issues = <ValidationIssue>[];
    
    // Check file header/magic bytes
    if (fileBytes.length < 16) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.invalidFileContent,
        severity: ValidationSeverity.warning,
        message: 'File is too small or corrupted',
      ));
      return issues;
    }
    
    final header = fileBytes.take(16).toList();
    
    // Validate image files
    if (mimeType.startsWith('image/')) {
      if (!_isValidImageHeader(header, mimeType)) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.invalidFileContent,
          severity: ValidationSeverity.error,
          message: 'File header does not match image type',
        ));
      }
    }
    
    // Check for embedded scripts in files
    final fileString = String.fromCharCodes(fileBytes.take(1000));
    if (fileString.contains('<script') || fileString.contains('javascript:')) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.embeddedScript,
        severity: ValidationSeverity.error,
        message: 'File contains embedded scripts',
      ));
    }
    
    return issues;
  }

  List<ValidationIssue> _detectMalwareSignatures(List<int> fileBytes) {
    final issues = <ValidationIssue>[];
    
    // Check for executable file signatures
    if (_isExecutableFile(fileBytes)) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.executableFile,
        severity: ValidationSeverity.error,
        message: 'File appears to be executable',
      ));
    }
    
    // Check for suspicious patterns in file content
    final fileString = String.fromCharCodes(fileBytes.take(2000));
    
    // Check for suspicious strings
    final suspiciousStrings = ['eval(', 'exec(', 'system(', 'shell_exec(', 'passthru('];
    for (final suspicious in suspiciousStrings) {
      if (fileString.contains(suspicious)) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.suspiciousContent,
          severity: ValidationSeverity.warning,
          message: 'File contains suspicious content: $suspicious',
        ));
      }
    }
    
    return issues;
  }

  double _calculateRiskScore(List<ValidationIssue> issues) {
    double score = 0.0;
    
    for (final issue in issues) {
      switch (issue.severity) {
        case ValidationSeverity.error:
          score += 0.4;
          break;
        case ValidationSeverity.warning:
          score += 0.2;
          break;
        case ValidationSeverity.info:
          score += 0.1;
          break;
      }
    }
    
    return score.clamp(0.0, 1.0);
  }

  bool _isValidFileExtension(String extension, String mimeType) {
    const extensionMap = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'ogg': 'audio/ogg',
      'mp4': 'video/mp4',
      'webm': 'video/webm',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };
    
    return extensionMap[extension] == mimeType;
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  bool _isValidImageHeader(List<int> header, String mimeType) {
    switch (mimeType) {
      case 'image/jpeg':
        return header.length >= 2 && header[0] == 0xFF && header[1] == 0xD8;
      case 'image/png':
        return header.length >= 8 && 
               header[0] == 0x89 && header[1] == 0x50 && 
               header[2] == 0x4E && header[3] == 0x47;
      case 'image/gif':
        return header.length >= 6 && 
               header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46;
      case 'image/webp':
        return header.length >= 12 && 
               header[0] == 0x52 && header[1] == 0x49 && 
               header[2] == 0x46 && header[3] == 0x46;
      default:
        return true; // Allow other types for now
    }
  }

  bool _isExecutableFile(List<int> fileBytes) {
    if (fileBytes.length < 4) return false;
    
    // Check for common executable signatures
    final signatures = [
      [0x4D, 0x5A], // PE executable (Windows)
      [0x7F, 0x45, 0x4C, 0x46], // ELF executable (Linux)
      [0xCF, 0xFA, 0xED, 0xFE], // Mach-O executable (macOS)
      [0xFE, 0xED, 0xFA, 0xCE], // Mach-O executable (macOS, different endian)
    ];
    
    for (final signature in signatures) {
      if (fileBytes.length >= signature.length) {
        bool matches = true;
        for (int i = 0; i < signature.length; i++) {
          if (fileBytes[i] != signature[i]) {
            matches = false;
            break;
          }
        }
        if (matches) return true;
      }
    }
    
    return false;
  }

  Future<String> _getUserRoleInGroup(String userId, String groupId) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (groupDoc.exists) {
        final groupData = groupDoc.data()!;
        final members = groupData['members'] as Map<String, dynamic>? ?? {};
        final memberData = members[userId] as Map<String, dynamic>? ?? {};
        return memberData['role'] ?? 'member';
      }
      return 'member';
    } catch (e) {
      return 'member';
    }
  }

  bool _canUserSendMessages(String whoCanSendMessages, String userRole) {
    switch (whoCanSendMessages) {
      case 'admin':
        return userRole == 'admin';
      case 'coordinators':
        return userRole == 'admin' || userRole == 'coordinator';
      case 'all':
      default:
        return true;
    }
  }

  Future<void> _logValidationResult({
    required String userId,
    required String content,
    required MessageType messageType,
    required List<ValidationIssue> issues,
    required double riskScore,
    required bool blocked,
  }) async {
    try {
      await _firestore.collection('validation_logs').add({
        'userId': userId,
        'messageType': messageType.toString(),
        'contentLength': content.length,
        'issues': issues.map((issue) => issue.toMap()).toList(),
        'riskScore': riskScore,
        'blocked': blocked,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Log security event if blocked
      if (blocked) {
        await _auditService.logSecurityEvent(
          eventType: 'message_blocked',
          userId: userId,
          details: {
            'messageType': messageType.toString(),
            'riskScore': riskScore,
            'issueCount': issues.length,
            'contentLength': content.length,
          },
          sensitivityLevel: SensitivityLevel.medium,
        );
      }
    } catch (e) {
      debugPrint('Error logging validation result: $e');
    }
  }

  Future<void> _logFileValidation({
    required String userId,
    required String fileName,
    required String mimeType,
    required int fileSize,
    required List<ValidationIssue> issues,
    required double riskScore,
    required bool blocked,
  }) async {
    try {
      await _firestore.collection('file_validation_logs').add({
        'userId': userId,
        'fileName': fileName,
        'mimeType': mimeType,
        'fileSize': fileSize,
        'issues': issues.map((issue) => issue.toMap()).toList(),
        'riskScore': riskScore,
        'blocked': blocked,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Log security event if blocked
      if (blocked) {
        await _auditService.logSecurityEvent(
          eventType: 'file_blocked',
          userId: userId,
          details: {
            'fileName': fileName,
            'mimeType': mimeType,
            'fileSize': fileSize,
            'riskScore': riskScore,
            'issueCount': issues.length,
          },
          sensitivityLevel: SensitivityLevel.medium,
        );
      }
    } catch (e) {
      debugPrint('Error logging file validation: $e');
    }
  }
}

// Enums and data models

enum MessageType { text, image, document, voice, video, location }

enum ValidationIssueType {
  emptyContent,
  contentTooLong,
  maliciousContent,
  spamContent,
  inappropriateContent,
  fileTooLarge,
  invalidFileType,
  mismatchedFileType,
  invalidFileContent,
  embeddedScript,
  executableFile,
  suspiciousContent,
  tooManyFiles,
  invalidUrl,
  metadataTooLarge,
  suspiciousMetadata,
  invalidGroup,
  unauthorizedSender,
  invalidRecipient,
  insufficientPermissions,
  validationError,
}

enum ValidationSeverity { info, warning, error }

class ValidationIssue {
  final ValidationIssueType type;
  final ValidationSeverity severity;
  final String message;
  final Map<String, dynamic>? details;

  ValidationIssue({
    required this.type,
    required this.severity,
    required this.message,
    this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString(),
      'severity': severity.toString(),
      'message': message,
      'details': details,
    };
  }
}

class MessageValidationResult {
  final bool isValid;
  final String sanitizedContent;
  final List<ValidationIssue> issues;
  final double riskScore;
  final int originalLength;
  final int sanitizedLength;

  MessageValidationResult({
    required this.isValid,
    required this.sanitizedContent,
    required this.issues,
    required this.riskScore,
    required this.originalLength,
    required this.sanitizedLength,
  });
}

class FileValidationResult {
  final bool isValid;
  final List<ValidationIssue> issues;
  final double riskScore;
  final bool quarantined;

  FileValidationResult({
    required this.isValid,
    required this.issues,
    required this.riskScore,
    required this.quarantined,
  });
}

class GroupValidationResult {
  final bool isValid;
  final List<ValidationIssue> issues;
  final List<String> allowedRecipients;
  final String? sanitizedContent;

  GroupValidationResult({
    required this.isValid,
    required this.issues,
    required this.allowedRecipients,
    this.sanitizedContent,
  });
}

class ValidationStatistics {
  final int totalValidations;
  final int blockedMessages;
  final int maliciousContent;
  final int spamContent;
  final int inappropriateContent;
  final double averageRiskScore;
  final double blockRate;

  ValidationStatistics({
    required this.totalValidations,
    required this.blockedMessages,
    required this.maliciousContent,
    required this.spamContent,
    required this.inappropriateContent,
    required this.averageRiskScore,
    required this.blockRate,
  });
}
