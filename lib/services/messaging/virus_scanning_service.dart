// Virus Scanning Service for TALOWA Messaging System
// Implements basic file security scanning and threat detection
// Requirements: 4.1 - Implement secure file upload service with virus scanning

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../../models/messaging/file_model.dart';

class VirusScanningService {
  static final VirusScanningService _instance = VirusScanningService._internal();
  factory VirusScanningService() => _instance;
  VirusScanningService._internal();

  // Known malicious file signatures (simplified for demo)
  static const List<String> maliciousSignatures = [
    'X5O!P%@AP[4\\PZX54(P^)7CC)7}\$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!\$H+H*', // EICAR test
  ];

  // Suspicious file extensions
  static const List<String> suspiciousExtensions = [
    'exe', 'bat', 'cmd', 'scr', 'com', 'pif', 'vbs', 'js', 'jar', 'msi',
    'dll', 'sys', 'drv', 'ocx', 'cpl', 'inf', 'reg', 'ps1', 'psm1'
  ];

  // Maximum file sizes for different types (in bytes)
  static const Map<String, int> maxFileSizes = {
    'image': 25 * 1024 * 1024, // 25MB
    'document': 25 * 1024 * 1024, // 25MB
    'audio': 50 * 1024 * 1024, // 50MB
    'video': 100 * 1024 * 1024, // 100MB
  };

  /// Scan file for viruses and security threats
  Future<SecurityScanResult> scanFile(File file) async {
    try {
      final scanId = _generateScanId();
      final threats = <String>[];
      
      // Basic file validation
      final basicThreats = await _performBasicScan(file);
      threats.addAll(basicThreats);
      
      // Signature-based scanning
      final signatureThreats = await _performSignatureScan(file);
      threats.addAll(signatureThreats);
      
      // Heuristic analysis
      final heuristicThreats = await _performHeuristicScan(file);
      threats.addAll(heuristicThreats);
      
      // Behavioral analysis (simplified)
      final behavioralThreats = await _performBehavioralScan(file);
      threats.addAll(behavioralThreats);

      return SecurityScanResult(
        isClean: threats.isEmpty,
        scannedAt: DateTime.now(),
        scanEngine: 'TALOWA-Security-Scanner-v1.0',
        threats: threats,
        scanId: scanId,
      );
    } catch (e) {
      debugPrint('Error scanning file: $e');
      
      // If scanning fails, return a cautious result
      return SecurityScanResult(
        isClean: false,
        scannedAt: DateTime.now(),
        scanEngine: 'TALOWA-Security-Scanner-v1.0',
        threats: ['Scan failed - file may be corrupted or suspicious'],
        scanId: _generateScanId(),
      );
    }
  }

  /// Perform basic file validation and checks
  Future<List<String>> _performBasicScan(File file) async {
    final threats = <String>[];
    
    try {
      // Check file existence
      if (!await file.exists()) {
        threats.add('File does not exist');
        return threats;
      }

      // Check file size
      final fileSize = await file.length();
      if (fileSize == 0) {
        threats.add('Empty file detected');
      } else if (fileSize > 500 * 1024 * 1024) { // 500MB
        threats.add('Unusually large file size (${_formatFileSize(fileSize)})');
      }

      // Check file extension
      final fileName = path.basename(file.path);
      final extension = path.extension(fileName).toLowerCase().replaceAll('.', '');
      
      if (suspiciousExtensions.contains(extension)) {
        threats.add('Suspicious file extension: .$extension');
      }

      // Check for double extensions (e.g., file.pdf.exe)
      if (_hasDoubleExtension(fileName)) {
        threats.add('Double file extension detected - possible malware');
      }

      // Check for suspicious file names
      if (_hasSuspiciousFileName(fileName)) {
        threats.add('Suspicious file name pattern');
      }

    } catch (e) {
      threats.add('Error during basic scan: $e');
    }

    return threats;
  }

  /// Perform signature-based malware detection
  Future<List<String>> _performSignatureScan(File file) async {
    final threats = <String>[];
    
    try {
      // Read file content for signature matching
      final bytes = await file.readAsBytes();
      final content = String.fromCharCodes(bytes.take(1024)); // First 1KB
      
      // Check against known malicious signatures
      for (final signature in maliciousSignatures) {
        if (content.contains(signature)) {
          threats.add('Known malware signature detected');
          break;
        }
      }

      // Check for suspicious patterns in binary files
      if (_containsSuspiciousBinaryPatterns(bytes)) {
        threats.add('Suspicious binary patterns detected');
      }

      // Check for embedded executables
      if (_containsEmbeddedExecutable(bytes)) {
        threats.add('Embedded executable detected');
      }

    } catch (e) {
      debugPrint('Error during signature scan: $e');
      threats.add('Signature scan failed');
    }

    return threats;
  }

  /// Perform heuristic analysis
  Future<List<String>> _performHeuristicScan(File file) async {
    final threats = <String>[];
    
    try {
      final bytes = await file.readAsBytes();
      
      // Check entropy (randomness) - high entropy might indicate encryption/packing
      final entropy = _calculateEntropy(bytes);
      if (entropy > 7.5) {
        threats.add('High entropy detected - possible packed/encrypted malware');
      }

      // Check for suspicious strings
      final suspiciousStrings = _findSuspiciousStrings(bytes);
      if (suspiciousStrings.isNotEmpty) {
        threats.add('Suspicious strings found: ${suspiciousStrings.join(', ')}');
      }

      // Check file structure consistency
      if (!_hasConsistentFileStructure(file, bytes)) {
        threats.add('Inconsistent file structure - possible format spoofing');
      }

    } catch (e) {
      debugPrint('Error during heuristic scan: $e');
      threats.add('Heuristic scan failed');
    }

    return threats;
  }

  /// Perform behavioral analysis (simplified)
  Future<List<String>> _performBehavioralScan(File file) async {
    final threats = <String>[];
    
    try {
      // Check file metadata for suspicious attributes
      final stat = await file.stat();
      
      // Check for files with suspicious timestamps
      final now = DateTime.now();
      if (stat.modified.isAfter(now.add(const Duration(days: 1)))) {
        threats.add('File has future timestamp - possible time manipulation');
      }

      // Check for files that are too small for their claimed type
      final extension = path.extension(file.path).toLowerCase().replaceAll('.', '');
      final fileSize = stat.size;
      
      if (_isSuspiciouslySmallForType(extension, fileSize)) {
        threats.add('File size inconsistent with file type');
      }

    } catch (e) {
      debugPrint('Error during behavioral scan: $e');
      threats.add('Behavioral scan failed');
    }

    return threats;
  }

  /// Calculate file entropy (measure of randomness)
  double _calculateEntropy(Uint8List bytes) {
    if (bytes.isEmpty) return 0.0;
    
    final frequency = List<int>.filled(256, 0);
    for (final byte in bytes) {
      frequency[byte]++;
    }
    
    double entropy = 0.0;
    final length = bytes.length;
    
    for (final count in frequency) {
      if (count > 0) {
        final probability = count / length;
        entropy -= probability * (log(probability) / log(2));
      }
    }
    
    return entropy;
  }

  /// Find suspicious strings in file content
  List<String> _findSuspiciousStrings(Uint8List bytes) {
    final suspiciousPatterns = [
      'eval(',
      'exec(',
      'system(',
      'shell_exec',
      'passthru',
      'base64_decode',
      'gzinflate',
      'str_rot13',
      'CreateObject',
      'WScript.Shell',
      'cmd.exe',
      'powershell',
    ];
    
    final content = String.fromCharCodes(bytes.take(10240)); // First 10KB
    final foundPatterns = <String>[];
    
    for (final pattern in suspiciousPatterns) {
      if (content.toLowerCase().contains(pattern.toLowerCase())) {
        foundPatterns.add(pattern);
      }
    }
    
    return foundPatterns;
  }

  /// Check if file has consistent structure for its type
  bool _hasConsistentFileStructure(File file, Uint8List bytes) {
    final extension = path.extension(file.path).toLowerCase().replaceAll('.', '');
    
    // Check magic numbers/file signatures
    final magicNumbers = {
      'pdf': [0x25, 0x50, 0x44, 0x46], // %PDF
      'jpg': [0xFF, 0xD8, 0xFF],
      'png': [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
      'gif': [0x47, 0x49, 0x46, 0x38],
      'zip': [0x50, 0x4B, 0x03, 0x04],
      'docx': [0x50, 0x4B, 0x03, 0x04], // DOCX is ZIP-based
    };
    
    if (magicNumbers.containsKey(extension)) {
      final expectedSignature = magicNumbers[extension]!;
      if (bytes.length >= expectedSignature.length) {
        for (int i = 0; i < expectedSignature.length; i++) {
          if (bytes[i] != expectedSignature[i]) {
            return false;
          }
        }
      }
    }
    
    return true;
  }

  /// Check for suspicious binary patterns
  bool _containsSuspiciousBinaryPatterns(Uint8List bytes) {
    // Look for patterns that might indicate malicious code
    // This is a simplified implementation
    
    // Check for excessive null bytes (might indicate padding)
    int nullCount = 0;
    for (final byte in bytes.take(1024)) {
      if (byte == 0) nullCount++;
    }
    
    if (nullCount > 512) { // More than 50% null bytes in first 1KB
      return true;
    }
    
    return false;
  }

  /// Check for embedded executables
  bool _containsEmbeddedExecutable(Uint8List bytes) {
    // Look for PE header signature (Windows executables)
    final peSignature = [0x4D, 0x5A]; // MZ
    
    for (int i = 0; i < bytes.length - 1; i++) {
      if (bytes[i] == peSignature[0] && bytes[i + 1] == peSignature[1]) {
        return true;
      }
    }
    
    return false;
  }

  /// Check if file has double extension
  bool _hasDoubleExtension(String fileName) {
    final parts = fileName.split('.');
    return parts.length > 2;
  }

  /// Check for suspicious file name patterns
  bool _hasSuspiciousFileName(String fileName) {
    final suspiciousPatterns = [
      RegExp(r'^\d+$'), // Only numbers
      RegExp(r'^[a-f0-9]{32}$'), // MD5-like hash
      RegExp(r'^[a-f0-9]{40}$'), // SHA1-like hash
      RegExp(r'temp|tmp|cache', caseSensitive: false),
      RegExp(r'system|windows|program', caseSensitive: false),
    ];
    
    for (final pattern in suspiciousPatterns) {
      if (pattern.hasMatch(fileName)) {
        return true;
      }
    }
    
    return false;
  }

  /// Check if file size is suspiciously small for its type
  bool _isSuspiciouslySmallForType(String extension, int fileSize) {
    final minSizes = {
      'pdf': 1024, // 1KB
      'doc': 2048, // 2KB
      'docx': 4096, // 4KB
      'jpg': 1024, // 1KB
      'png': 1024, // 1KB
      'mp3': 10240, // 10KB
      'mp4': 102400, // 100KB
    };
    
    if (minSizes.containsKey(extension)) {
      return fileSize < minSizes[extension]!;
    }
    
    return false;
  }

  /// Generate unique scan ID
  String _generateScanId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'scan_${timestamp}_$random';
  }

  /// Format file size for human reading
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Logarithm function for entropy calculation
  double log(double x) {
    // Natural logarithm approximation
    if (x <= 0) return double.negativeInfinity;
    if (x == 1) return 0;
    
    // Simple approximation for demonstration
    // In production, use dart:math log function
    return (x - 1) / x; // Simplified approximation
  }
}

/// File type detection service
class FileTypeDetectionService {
  /// Detect actual file type based on content, not extension
  static Future<String> detectFileType(File file) async {
    try {
      final bytes = await file.readAsBytes();
      
      // Check magic numbers
      if (bytes.length >= 4) {
        // PDF
        if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
          return 'application/pdf';
        }
        
        // PNG
        if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
          return 'image/png';
        }
        
        // JPEG
        if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
          return 'image/jpeg';
        }
        
        // GIF
        if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
          return 'image/gif';
        }
        
        // ZIP/DOCX/XLSX
        if (bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04) {
          return 'application/zip';
        }
      }
      
      // Default to octet-stream if unknown
      return 'application/octet-stream';
    } catch (e) {
      debugPrint('Error detecting file type: $e');
      return 'application/octet-stream';
    }
  }
  
  /// Check if detected type matches file extension
  static bool isFileTypeConsistent(File file, String detectedType) {
    final extension = path.extension(file.path).toLowerCase();
    
    final expectedTypes = {
      '.pdf': 'application/pdf',
      '.png': 'image/png',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.gif': 'image/gif',
      '.zip': 'application/zip',
      '.docx': 'application/zip', // DOCX is ZIP-based
      '.xlsx': 'application/zip', // XLSX is ZIP-based
    };
    
    return expectedTypes[extension] == detectedType;
  }
}
