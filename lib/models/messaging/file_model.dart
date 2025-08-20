// File Model for TALOWA Messaging System
// Implements secure file sharing with encryption and access control
// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5

import 'package:cloud_firestore/cloud_firestore.dart';

class FileModel {
  final String id;
  final String originalName;
  final String fileName;
  final String mimeType;
  final int size;
  final String downloadUrl;
  final String? thumbnailUrl;
  final String uploadedBy;
  final DateTime uploadedAt;
  final bool isEncrypted;
  final String? encryptionKey;
  final String accessLevel; // 'public', 'group', 'private'
  final List<String> authorizedUsers;
  final DateTime? expiresAt;
  final String? linkedCaseId;
  final String? linkedLandRecordId;
  final List<String> tags;
  final FileMetadata metadata;
  final SecurityScanResult? scanResult;
  final GpsLocation? gpsLocation;

  FileModel({
    required this.id,
    required this.originalName,
    required this.fileName,
    required this.mimeType,
    required this.size,
    required this.downloadUrl,
    this.thumbnailUrl,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.isEncrypted,
    this.encryptionKey,
    required this.accessLevel,
    required this.authorizedUsers,
    this.expiresAt,
    this.linkedCaseId,
    this.linkedLandRecordId,
    required this.tags,
    required this.metadata,
    this.scanResult,
    this.gpsLocation,
  });

  factory FileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return FileModel(
      id: doc.id,
      originalName: data['originalName'] ?? '',
      fileName: data['fileName'] ?? '',
      mimeType: data['mimeType'] ?? '',
      size: data['size'] ?? 0,
      downloadUrl: data['downloadUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      uploadedBy: data['uploadedBy'] ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isEncrypted: data['isEncrypted'] ?? false,
      encryptionKey: data['encryptionKey'],
      accessLevel: data['accessLevel'] ?? 'private',
      authorizedUsers: List<String>.from(data['authorizedUsers'] ?? []),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      linkedCaseId: data['linkedCaseId'],
      linkedLandRecordId: data['linkedLandRecordId'],
      tags: List<String>.from(data['tags'] ?? []),
      metadata: FileMetadata.fromMap(data['metadata'] ?? {}),
      scanResult: data['scanResult'] != null 
          ? SecurityScanResult.fromMap(data['scanResult'])
          : null,
      gpsLocation: data['gpsLocation'] != null 
          ? GpsLocation.fromMap(data['gpsLocation'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'originalName': originalName,
      'fileName': fileName,
      'mimeType': mimeType,
      'size': size,
      'downloadUrl': downloadUrl,
      'thumbnailUrl': thumbnailUrl,
      'uploadedBy': uploadedBy,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'isEncrypted': isEncrypted,
      'encryptionKey': encryptionKey,
      'accessLevel': accessLevel,
      'authorizedUsers': authorizedUsers,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'linkedCaseId': linkedCaseId,
      'linkedLandRecordId': linkedLandRecordId,
      'tags': tags,
      'metadata': metadata.toMap(),
      'scanResult': scanResult?.toMap(),
      'gpsLocation': gpsLocation?.toMap(),
    };
  }

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isImage => mimeType.startsWith('image/');
  bool get isDocument => mimeType.startsWith('application/') || mimeType == 'text/plain';
  bool get isAudio => mimeType.startsWith('audio/');
  bool get isVideo => mimeType.startsWith('video/');
}

class FileMetadata {
  final int? duration; // For audio/video files
  final int? width; // For images/videos
  final int? height; // For images/videos
  final String? codec; // For audio/video files
  final int? bitrate; // For audio/video files
  final String? cameraModel; // For photos
  final DateTime? dateTaken; // For photos
  final Map<String, dynamic> exifData; // For photos

  FileMetadata({
    this.duration,
    this.width,
    this.height,
    this.codec,
    this.bitrate,
    this.cameraModel,
    this.dateTaken,
    required this.exifData,
  });

  factory FileMetadata.fromMap(Map<String, dynamic> map) {
    return FileMetadata(
      duration: map['duration'],
      width: map['width'],
      height: map['height'],
      codec: map['codec'],
      bitrate: map['bitrate'],
      cameraModel: map['cameraModel'],
      dateTaken: map['dateTaken'] != null 
          ? DateTime.parse(map['dateTaken'])
          : null,
      exifData: Map<String, dynamic>.from(map['exifData'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'duration': duration,
      'width': width,
      'height': height,
      'codec': codec,
      'bitrate': bitrate,
      'cameraModel': cameraModel,
      'dateTaken': dateTaken?.toIso8601String(),
      'exifData': exifData,
    };
  }
}

class SecurityScanResult {
  final bool isClean;
  final DateTime scannedAt;
  final String scanEngine;
  final List<String> threats;
  final String scanId;

  SecurityScanResult({
    required this.isClean,
    required this.scannedAt,
    required this.scanEngine,
    required this.threats,
    required this.scanId,
  });

  factory SecurityScanResult.fromMap(Map<String, dynamic> map) {
    return SecurityScanResult(
      isClean: map['isClean'] ?? true,
      scannedAt: DateTime.parse(map['scannedAt']),
      scanEngine: map['scanEngine'] ?? '',
      threats: List<String>.from(map['threats'] ?? []),
      scanId: map['scanId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isClean': isClean,
      'scannedAt': scannedAt.toIso8601String(),
      'scanEngine': scanEngine,
      'threats': threats,
      'scanId': scanId,
    };
  }
}

class GpsLocation {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final DateTime? timestamp;

  GpsLocation({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.timestamp,
  });

  factory GpsLocation.fromMap(Map<String, dynamic> map) {
    return GpsLocation(
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      altitude: map['altitude']?.toDouble(),
      accuracy: map['accuracy']?.toDouble(),
      timestamp: map['timestamp'] != null 
          ? DateTime.parse(map['timestamp'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'timestamp': timestamp?.toIso8601String(),
    };
  }
}