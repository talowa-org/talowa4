// Message Conflict Resolver for TALOWA
// Implements Task 8: Create offline messaging and synchronization - Conflict Resolution
// Reference: in-app-communication/requirements.md - Requirements 1.2, 8.3

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/message_model.dart';
import '../../models/messaging/conversation_model.dart';
import '../auth_service.dart';
import 'messaging_service.dart';
import 'offline_messaging_service.dart';

class MessageConflictResolver {
  static final MessageConflictResolver _instance = MessageConflictResolver._internal();
  factory MessageConflictResolver() => _instance;
  MessageConflictResolver._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MessagingService _messagingService = MessagingService();
  final OfflineMessagingService _offlineService = OfflineMessagingService();
  
  final StreamController<ConflictResolutionEvent> _resolutionEventsController = 
      StreamController<ConflictResolutionEvent>.broadcast();
  
  // Getters for streams
  Stream<ConflictResolutionEvent> get resolutionEventsStream => _resolutionEventsController.stream;

  /// Detect and resolve message conflicts
  Future<ConflictResolutionResult> detectAndResolveConflicts() async {
    try {
      debugPrint('Starting conflict detection and resolution');
      
      final conflicts = await _detectConflicts();
      if (conflicts.isEmpty) {
        return ConflictResolutionResult(
          success: true,
          message: 'No conflicts detected',
          resolvedConflicts: 0,
          totalConflicts: 0,
        );
      }

      int resolvedCount = 0;
      int failedCount = 0;
      final errors = <String>[];

      for (final conflict in conflicts) {
        try {
          final resolution = await _resolveConflict(conflict);
          if (resolution.success) {
            resolvedCount++;
            await _recordResolution(conflict, resolution);
            
            _resolutionEventsController.add(ConflictResolutionEvent(
              conflictId: conflict.id,
              messageId: conflict.messageId,
              resolutionStrategy: resolution.strategy,
              success: true,
            ));
          } else {
            failedCount++;
            errors.add('Conflict ${conflict.id}: ${resolution.error}');
            
            _resolutionEventsController.add(ConflictResolutionEvent(
              conflictId: conflict.id,
              messageId: conflict.messageId,
              resolutionStrategy: resolution.strategy,
              success: false,
              error: resolution.error,
            ));
          }
        } catch (e) {
          failedCount++;
          errors.add('Conflict ${conflict.id}: $e');
        }
      }

      return ConflictResolutionResult(
        success: failedCount == 0,
        message: 'Resolved $resolvedCount conflicts, $failedCount failed',
        resolvedConflicts: resolvedCount,
        totalConflicts: conflicts.length,
        errors: errors,
      );
    } catch (e) {
      debugPrint('Error in conflict detection and resolution: $e');
      return ConflictResolutionResult(
        success: false,
        message: e.toString(),
        resolvedConflicts: 0,
        totalConflicts: 0,
      );
    }
  }

  /// Detect conflicts between local and remote messages
  Future<List<MessageConflict>> _detectConflicts() async {
    try {
      final conflicts = <MessageConflict>[];
      final currentUser = AuthService.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get local messages that might have conflicts
      final localMessages = await _getLocalMessagesForConflictCheck();
      
      for (final localMessage in localMessages) {
        try {
          // Check if remote version exists and differs
          final remoteMessage = await _getRemoteMessage(localMessage.id);
          
          if (remoteMessage != null) {
            final conflictType = _determineConflictType(localMessage, remoteMessage);
            
            if (conflictType != ConflictType.none) {
              final conflict = MessageConflict(
                id: '${localMessage.id}_${DateTime.now().millisecondsSinceEpoch}',
                messageId: localMessage.id,
                conversationId: localMessage.conversationId ?? '',
                conflictType: conflictType,
                localMessage: localMessage,
                remoteMessage: remoteMessage,
                detectedAt: DateTime.now(),
                severity: _determineConflictSeverity(conflictType),
              );
              
              conflicts.add(conflict);
              await _storeConflict(conflict);
            }
          } else {
            // Message exists locally but not remotely - might be a send failure
            await _handleMissingRemoteMessage(localMessage);
          }
        } catch (e) {
          debugPrint('Error checking conflict for message ${localMessage.id}: $e');
        }
      }

      debugPrint('Detected ${conflicts.length} conflicts');
      return conflicts;
    } catch (e) {
      debugPrint('Error detecting conflicts: $e');
      return [];
    }
  }

  /// Get local messages that need conflict checking
  Future<List<MessageModel>> _getLocalMessagesForConflictCheck() async {
    try {
      final db = await _offlineService.database;
      
      // Get messages that were modified locally or have sync issues
      final result = await db.query(
        'offline_messages',
        where: 'sync_status IN (?, ?, ?)',
        whereArgs: ['pending', 'conflict', 'failed'],
        orderBy: 'created_at DESC',
        limit: 100,
      );

      final messages = <MessageModel>[];
      for (final map in result) {
        try {
          final message = await _messageFromOfflineMap(map);
          messages.add(message);
        } catch (e) {
          debugPrint('Error converting offline message: $e');
        }
      }

      return messages;
    } catch (e) {
      debugPrint('Error getting local messages for conflict check: $e');
      return [];
    }
  }

  /// Get remote message from Firestore
  Future<MessageModel?> _getRemoteMessage(String messageId) async {
    try {
      final doc = await _firestore.collection('messages').doc(messageId).get();
      
      if (doc.exists) {
        return MessageModel.fromFirestore(doc);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting remote message: $e');
      return null;
    }
  }

  /// Determine the type of conflict between local and remote messages
  ConflictType _determineConflictType(MessageModel local, MessageModel remote) {
    // Check for content differences
    if (local.content != remote.content) {
      return ConflictType.contentModified;
    }
    
    // Check for metadata differences
    if (!_mapsEqual(local.metadata, remote.metadata)) {
      return ConflictType.metadataModified;
    }
    
    // Check for media URL differences
    if (!_listsEqual(local.mediaUrls, remote.mediaUrls)) {
      return ConflictType.mediaModified;
    }
    
    // Check for timestamp differences (allowing small variance for network delays)
    final timeDifference = local.sentAt.difference(remote.sentAt).abs();
    if (timeDifference > const Duration(seconds: 30)) {
      return ConflictType.timestampMismatch;
    }
    
    // Check for delivery status differences
    if (local.deliveredAt != remote.deliveredAt || local.readAt != remote.readAt) {
      return ConflictType.statusMismatch;
    }
    
    return ConflictType.none;
  }

  /// Determine conflict severity
  ConflictSeverity _determineConflictSeverity(ConflictType type) {
    switch (type) {
      case ConflictType.contentModified:
        return ConflictSeverity.high;
      case ConflictType.mediaModified:
        return ConflictSeverity.high;
      case ConflictType.metadataModified:
        return ConflictSeverity.medium;
      case ConflictType.timestampMismatch:
        return ConflictSeverity.low;
      case ConflictType.statusMismatch:
        return ConflictSeverity.low;
      case ConflictType.duplicateMessage:
        return ConflictSeverity.medium;
      case ConflictType.orderingConflict:
        return ConflictSeverity.medium;
      default:
        return ConflictSeverity.low;
    }
  }

  /// Resolve a specific conflict
  Future<ConflictResolution> _resolveConflict(MessageConflict conflict) async {
    try {
      debugPrint('Resolving conflict: ${conflict.id} (${conflict.conflictType})');
      
      switch (conflict.conflictType) {
        case ConflictType.contentModified:
          return await _resolveContentConflict(conflict);
        case ConflictType.mediaModified:
          return await _resolveMediaConflict(conflict);
        case ConflictType.metadataModified:
          return await _resolveMetadataConflict(conflict);
        case ConflictType.timestampMismatch:
          return await _resolveTimestampConflict(conflict);
        case ConflictType.statusMismatch:
          return await _resolveStatusConflict(conflict);
        case ConflictType.duplicateMessage:
          return await _resolveDuplicateConflict(conflict);
        case ConflictType.orderingConflict:
          return await _resolveOrderingConflict(conflict);
        default:
          return ConflictResolution(
            success: false,
            strategy: ResolutionStrategy.manual,
            error: 'Unknown conflict type: ${conflict.conflictType}',
          );
      }
    } catch (e) {
      debugPrint('Error resolving conflict: $e');
      return ConflictResolution(
        success: false,
        strategy: ResolutionStrategy.manual,
        error: e.toString(),
      );
    }
  }

  /// Resolve content modification conflicts
  Future<ConflictResolution> _resolveContentConflict(MessageConflict conflict) async {
    try {
      // Strategy: Use remote version (server wins) for content conflicts
      // This prevents data loss and maintains consistency
      
      final remoteMessage = conflict.remoteMessage;
      await _updateLocalMessage(conflict.messageId, {
        'content': remoteMessage.content,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'sync_status': 'synced',
      });

      return ConflictResolution(
        success: true,
        strategy: ResolutionStrategy.remoteWins,
        resolvedMessage: remoteMessage,
      );
    } catch (e) {
      return ConflictResolution(
        success: false,
        strategy: ResolutionStrategy.remoteWins,
        error: e.toString(),
      );
    }
  }

  /// Resolve media modification conflicts
  Future<ConflictResolution> _resolveMediaConflict(MessageConflict conflict) async {
    try {
      // Strategy: Merge media URLs (union of both sets)
      final localUrls = Set<String>.from(conflict.localMessage.mediaUrls);
      final remoteUrls = Set<String>.from(conflict.remoteMessage.mediaUrls);
      final mergedUrls = localUrls.union(remoteUrls).toList();

      await _updateLocalMessage(conflict.messageId, {
        'media_urls': jsonEncode(mergedUrls),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'sync_status': 'synced',
      });

      // Also update remote if local has additional media
      if (localUrls.difference(remoteUrls).isNotEmpty) {
        await _updateRemoteMessage(conflict.messageId, {
          'mediaUrls': mergedUrls,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return ConflictResolution(
        success: true,
        strategy: ResolutionStrategy.merge,
        resolvedMessage: conflict.remoteMessage.copyWith(mediaUrls: mergedUrls),
      );
    } catch (e) {
      return ConflictResolution(
        success: false,
        strategy: ResolutionStrategy.merge,
        error: e.toString(),
      );
    }
  }

  /// Resolve metadata modification conflicts
  Future<ConflictResolution> _resolveMetadataConflict(MessageConflict conflict) async {
    try {
      // Strategy: Merge metadata (remote takes precedence for conflicts)
      final localMetadata = Map<String, dynamic>.from(conflict.localMessage.metadata);
      final remoteMetadata = Map<String, dynamic>.from(conflict.remoteMessage.metadata);
      
      // Merge with remote taking precedence
      final mergedMetadata = <String, dynamic>{...localMetadata, ...remoteMetadata};

      await _updateLocalMessage(conflict.messageId, {
        'metadata': jsonEncode(mergedMetadata),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'sync_status': 'synced',
      });

      return ConflictResolution(
        success: true,
        strategy: ResolutionStrategy.merge,
        resolvedMessage: conflict.remoteMessage.copyWith(metadata: mergedMetadata),
      );
    } catch (e) {
      return ConflictResolution(
        success: false,
        strategy: ResolutionStrategy.merge,
        error: e.toString(),
      );
    }
  }

  /// Resolve timestamp mismatch conflicts
  Future<ConflictResolution> _resolveTimestampConflict(MessageConflict conflict) async {
    try {
      // Strategy: Use remote timestamp (server time is authoritative)
      await _updateLocalMessage(conflict.messageId, {
        'created_at': conflict.remoteMessage.sentAt.millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'sync_status': 'synced',
      });

      return ConflictResolution(
        success: true,
        strategy: ResolutionStrategy.remoteWins,
        resolvedMessage: conflict.remoteMessage,
      );
    } catch (e) {
      return ConflictResolution(
        success: false,
        strategy: ResolutionStrategy.remoteWins,
        error: e.toString(),
      );
    }
  }

  /// Resolve status mismatch conflicts
  Future<ConflictResolution> _resolveStatusConflict(MessageConflict conflict) async {
    try {
      // Strategy: Use remote status (server has authoritative delivery info)
      await _updateLocalMessage(conflict.messageId, {
        'is_delivered': conflict.remoteMessage.deliveredAt != null ? 1 : 0,
        'is_read': conflict.remoteMessage.readAt != null ? 1 : 0,
        'read_by': jsonEncode(conflict.remoteMessage.readBy),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'sync_status': 'synced',
      });

      return ConflictResolution(
        success: true,
        strategy: ResolutionStrategy.remoteWins,
        resolvedMessage: conflict.remoteMessage,
      );
    } catch (e) {
      return ConflictResolution(
        success: false,
        strategy: ResolutionStrategy.remoteWins,
        error: e.toString(),
      );
    }
  }

  /// Resolve duplicate message conflicts
  Future<ConflictResolution> _resolveDuplicateConflict(MessageConflict conflict) async {
    try {
      // Strategy: Keep remote version, delete local duplicate
      await _deleteLocalMessage(conflict.messageId);

      return ConflictResolution(
        success: true,
        strategy: ResolutionStrategy.deleteDuplicate,
        resolvedMessage: conflict.remoteMessage,
      );
    } catch (e) {
      return ConflictResolution(
        success: false,
        strategy: ResolutionStrategy.deleteDuplicate,
        error: e.toString(),
      );
    }
  }

  /// Resolve message ordering conflicts
  Future<ConflictResolution> _resolveOrderingConflict(MessageConflict conflict) async {
    try {
      // Strategy: Re-order based on server timestamps
      // This is handled at the conversation level, not individual messages
      
      await _updateLocalMessage(conflict.messageId, {
        'sync_status': 'synced',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });

      return ConflictResolution(
        success: true,
        strategy: ResolutionStrategy.reorder,
        resolvedMessage: conflict.remoteMessage,
      );
    } catch (e) {
      return ConflictResolution(
        success: false,
        strategy: ResolutionStrategy.reorder,
        error: e.toString(),
      );
    }
  }

  /// Handle missing remote message (local exists but remote doesn't)
  Future<void> _handleMissingRemoteMessage(MessageModel localMessage) async {
    try {
      // This could mean the message failed to send originally
      // Try to resend it or mark it as failed
      
      final db = await _offlineService.database;
      await db.update(
        'offline_messages',
        {
          'sync_status': 'failed',
          'error_message': 'Message not found on server',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [localMessage.id],
      );
    } catch (e) {
      debugPrint('Error handling missing remote message: $e');
    }
  }

  /// Store conflict in database
  Future<void> _storeConflict(MessageConflict conflict) async {
    try {
      final db = await _offlineService.database;
      
      await db.insert('sync_conflicts', {
        'id': conflict.id,
        'message_id': conflict.messageId,
        'conflict_type': conflict.conflictType.toString().split('.').last,
        'local_data': jsonEncode(conflict.localMessage.toMap()),
        'remote_data': jsonEncode(conflict.remoteMessage.toMap()),
        'detected_at': conflict.detectedAt.millisecondsSinceEpoch,
        'is_resolved': 0,
      });
    } catch (e) {
      debugPrint('Error storing conflict: $e');
    }
  }

  /// Record conflict resolution
  Future<void> _recordResolution(MessageConflict conflict, ConflictResolution resolution) async {
    try {
      final db = await _offlineService.database;
      
      await db.update(
        'sync_conflicts',
        {
          'is_resolved': 1,
          'resolved_at': DateTime.now().millisecondsSinceEpoch,
          'resolution_strategy': resolution.strategy.toString().split('.').last,
        },
        where: 'id = ?',
        whereArgs: [conflict.id],
      );
    } catch (e) {
      debugPrint('Error recording resolution: $e');
    }
  }

  /// Update local message in database
  Future<void> _updateLocalMessage(String messageId, Map<String, dynamic> updates) async {
    try {
      final db = await _offlineService.database;
      await db.update(
        'offline_messages',
        updates,
        where: 'id = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      debugPrint('Error updating local message: $e');
      rethrow;
    }
  }

  /// Update remote message in Firestore
  Future<void> _updateRemoteMessage(String messageId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('messages').doc(messageId).update(updates);
    } catch (e) {
      debugPrint('Error updating remote message: $e');
      rethrow;
    }
  }

  /// Delete local message
  Future<void> _deleteLocalMessage(String messageId) async {
    try {
      final db = await _offlineService.database;
      await db.delete(
        'offline_messages',
        where: 'id = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      debugPrint('Error deleting local message: $e');
      rethrow;
    }
  }

  /// Convert offline database map to MessageModel
  Future<MessageModel> _messageFromOfflineMap(Map<String, dynamic> map) async {
    // This would be the same as in OfflineMessagingService
    // Simplified version for this example
    return MessageModel(
      id: map['id'],
      conversationId: map['conversation_id'],
      senderId: map['sender_id'],
      senderName: map['sender_name'],
      content: map['content'],
      messageType: MessageType.values.firstWhere(
        (e) => e.toString() == map['message_type'],
        orElse: () => MessageType.text,
      ),
      mediaUrls: List<String>.from(jsonDecode(map['media_urls'] ?? '[]')),
      sentAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      deliveredAt: (map['is_delivered'] as int) == 1 
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'])
          : null,
      readAt: (map['is_read'] as int) == 1 
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'])
          : null,
      readBy: List<String>.from(jsonDecode(map['read_by'] ?? '[]')),
      isEdited: false,
      isDeleted: false,
      metadata: Map<String, dynamic>.from(jsonDecode(map['metadata'] ?? '{}')),
    );
  }

  /// Check if two maps are equal
  bool _mapsEqual(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.length != map2.length) return false;
    
    for (final key in map1.keys) {
      if (!map2.containsKey(key) || map1[key] != map2[key]) {
        return false;
      }
    }
    
    return true;
  }

  /// Check if two lists are equal
  bool _listsEqual<T>(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    
    return true;
  }

  /// Get conflict statistics
  Future<ConflictStatistics> getConflictStatistics() async {
    try {
      final db = await _offlineService.database;
      
      final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM sync_conflicts');
      final resolvedResult = await db.rawQuery('SELECT COUNT(*) as count FROM sync_conflicts WHERE is_resolved = 1');
      final pendingResult = await db.rawQuery('SELECT COUNT(*) as count FROM sync_conflicts WHERE is_resolved = 0');
      
      return ConflictStatistics(
        totalConflicts: totalResult.first['count'] as int,
        resolvedConflicts: resolvedResult.first['count'] as int,
        pendingConflicts: pendingResult.first['count'] as int,
      );
    } catch (e) {
      debugPrint('Error getting conflict statistics: $e');
      return ConflictStatistics(
        totalConflicts: 0,
        resolvedConflicts: 0,
        pendingConflicts: 0,
      );
    }
  }

  /// Dispose resources
  void dispose() {
    _resolutionEventsController.close();
  }
}

// Data models for conflict resolution

enum ConflictType {
  none,
  contentModified,
  mediaModified,
  metadataModified,
  timestampMismatch,
  statusMismatch,
  duplicateMessage,
  orderingConflict,
}

enum ConflictSeverity {
  low,
  medium,
  high,
}

enum ResolutionStrategy {
  localWins,
  remoteWins,
  merge,
  deleteDuplicate,
  reorder,
  manual,
}

class MessageConflict {
  final String id;
  final String messageId;
  final String conversationId;
  final ConflictType conflictType;
  final MessageModel localMessage;
  final MessageModel remoteMessage;
  final DateTime detectedAt;
  final ConflictSeverity severity;

  MessageConflict({
    required this.id,
    required this.messageId,
    required this.conversationId,
    required this.conflictType,
    required this.localMessage,
    required this.remoteMessage,
    required this.detectedAt,
    required this.severity,
  });
}

class ConflictResolution {
  final bool success;
  final ResolutionStrategy strategy;
  final MessageModel? resolvedMessage;
  final String? error;

  ConflictResolution({
    required this.success,
    required this.strategy,
    this.resolvedMessage,
    this.error,
  });
}

class ConflictResolutionResult {
  final bool success;
  final String message;
  final int resolvedConflicts;
  final int totalConflicts;
  final List<String> errors;

  ConflictResolutionResult({
    required this.success,
    required this.message,
    required this.resolvedConflicts,
    required this.totalConflicts,
    this.errors = const [],
  });
}

class ConflictResolutionEvent {
  final String conflictId;
  final String messageId;
  final ResolutionStrategy resolutionStrategy;
  final bool success;
  final String? error;

  ConflictResolutionEvent({
    required this.conflictId,
    required this.messageId,
    required this.resolutionStrategy,
    required this.success,
    this.error,
  });
}

class ConflictStatistics {
  final int totalConflicts;
  final int resolvedConflicts;
  final int pendingConflicts;

  ConflictStatistics({
    required this.totalConflicts,
    required this.resolvedConflicts,
    required this.pendingConflicts,
  });

  double get resolutionRate => totalConflicts > 0 
      ? (resolvedConflicts / totalConflicts) * 100 
      : 0;
  
  bool get hasConflicts => totalConflicts > 0;
  bool get hasPendingConflicts => pendingConflicts > 0;
}

// Extension methods for MessageModel
extension MessageModelConflict on MessageModel {
  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? content,
    MessageType? messageType,
    List<String>? mediaUrls,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? readAt,
    List<String>? readBy,
    bool? isEdited,
    bool? isDeleted,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      readBy: readBy ?? this.readBy,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'messageType': messageType.toString(),
      'mediaUrls': mediaUrls,
      'sentAt': sentAt.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'readBy': readBy,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'metadata': metadata,
    };
  }

  static MessageModel fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'],
      conversationId: map['conversationId'],
      senderId: map['senderId'],
      senderName: map['senderName'],
      content: map['content'],
      messageType: MessageType.values.firstWhere(
        (e) => e.toString() == map['messageType'],
        orElse: () => MessageType.text,
      ),
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      sentAt: DateTime.parse(map['sentAt']),
      deliveredAt: map['deliveredAt'] != null ? DateTime.parse(map['deliveredAt']) : null,
      readAt: map['readAt'] != null ? DateTime.parse(map['readAt']) : null,
      readBy: List<String>.from(map['readBy'] ?? []),
      isEdited: map['isEdited'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }
}