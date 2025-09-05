// Message Model for TALOWA
// Reference: in-app-communication/design.md - Message Storage Schema

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class MessageModel {
  final String id;
  final String content;
  final String type;
  final String? mediaUrl;
  final MediaMetadata? mediaMetadata;
  final String senderId;
  final String? recipientId;
  final String? groupId;
  final String encryptionLevel;
  final bool isAnonymous;
  final String? anonymousId;
  final String status;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final List<String> readBy;
  final String? linkedCaseId;
  final String? linkedLandRecordId;
  final String? linkedCampaignId;
  final DateTime timestamp;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String clientMessageId;
  final DeviceInfo? deviceInfo;
  final MessageLocation? location;

  MessageModel({
    required this.id,
    required this.content,
    required this.type,
    this.mediaUrl,
    this.mediaMetadata,
    required this.senderId,
    this.recipientId,
    this.groupId,
    required this.encryptionLevel,
    required this.isAnonymous,
    this.anonymousId,
    required this.status,
    this.deliveredAt,
    this.readAt,
    required this.readBy,
    this.linkedCaseId,
    this.linkedLandRecordId,
    this.linkedCampaignId,
    required this.timestamp,
    this.editedAt,
    this.deletedAt,
    required this.clientMessageId,
    this.deviceInfo,
    this.location,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return MessageModel(
      id: doc.id,
      content: data['content'] ?? '',
      type: data['type'] ?? AppConstants.messageTypeText,
      mediaUrl: data['mediaUrl'],
      mediaMetadata: data['mediaMetadata'] != null 
          ? MediaMetadata.fromMap(data['mediaMetadata'])
          : null,
      senderId: data['senderId'] ?? '',
      recipientId: data['recipientId'],
      groupId: data['groupId'],
      encryptionLevel: data['encryptionLevel'] ?? 'standard',
      isAnonymous: data['isAnonymous'] ?? false,
      anonymousId: data['anonymousId'],
      status: data['status'] ?? 'sent',
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      readBy: List<String>.from(data['readBy'] ?? []),
      linkedCaseId: data['linkedCaseId'],
      linkedLandRecordId: data['linkedLandRecordId'],
      linkedCampaignId: data['linkedCampaignId'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
      clientMessageId: data['clientMessageId'] ?? '',
      deviceInfo: data['deviceInfo'] != null 
          ? DeviceInfo.fromMap(data['deviceInfo'])
          : null,
      location: data['location'] != null 
          ? MessageLocation.fromMap(data['location'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'type': type,
      'mediaUrl': mediaUrl,
      'mediaMetadata': mediaMetadata?.toMap(),
      'senderId': senderId,
      'recipientId': recipientId,
      'groupId': groupId,
      'encryptionLevel': encryptionLevel,
      'isAnonymous': isAnonymous,
      'anonymousId': anonymousId,
      'status': status,
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'readBy': readBy,
      'linkedCaseId': linkedCaseId,
      'linkedLandRecordId': linkedLandRecordId,
      'linkedCampaignId': linkedCampaignId,
      'timestamp': Timestamp.fromDate(timestamp),
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'clientMessageId': clientMessageId,
      'deviceInfo': deviceInfo?.toMap(),
      'location': location?.toMap(),
    };
  }
}

class MediaMetadata {
  final int size;
  final String mimeType;
  final int? duration;
  final MediaDimensions? dimensions;

  MediaMetadata({
    required this.size,
    required this.mimeType,
    this.duration,
    this.dimensions,
  });

  factory MediaMetadata.fromMap(Map<String, dynamic> map) {
    return MediaMetadata(
      size: map['size'] ?? 0,
      mimeType: map['mimeType'] ?? '',
      duration: map['duration'],
      dimensions: map['dimensions'] != null 
          ? MediaDimensions.fromMap(map['dimensions'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'size': size,
      'mimeType': mimeType,
      'duration': duration,
      'dimensions': dimensions?.toMap(),
    };
  }
}

class MediaDimensions {
  final int width;
  final int height;

  MediaDimensions({
    required this.width,
    required this.height,
  });

  factory MediaDimensions.fromMap(Map<String, dynamic> map) {
    return MediaDimensions(
      width: map['width'] ?? 0,
      height: map['height'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'width': width,
      'height': height,
    };
  }
}

class DeviceInfo {
  final String platform;
  final String version;

  DeviceInfo({
    required this.platform,
    required this.version,
  });

  factory DeviceInfo.fromMap(Map<String, dynamic> map) {
    return DeviceInfo(
      platform: map['platform'] ?? '',
      version: map['version'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'platform': platform,
      'version': version,
    };
  }
}

class MessageLocation {
  final double latitude;
  final double longitude;
  final double accuracy;

  MessageLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  factory MessageLocation.fromMap(Map<String, dynamic> map) {
    return MessageLocation(
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      accuracy: (map['accuracy'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
    };
  }
}
