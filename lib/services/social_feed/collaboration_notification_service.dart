// Collaboration Notification Service for TALOWA
// Handles notifications for collaborative editing activities

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CollaborationNotificationService {
  static final CollaborationNotificationService _instance =
      CollaborationNotificationService._internal();
  factory CollaborationNotificationService() => _instance;
  CollaborationNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _notificationsCollection = 'collaboration_notifications';

  /// Send invitation notification
  Future<void> sendInvitationNotification({
    required String sessionId,
    required String inviterId,
    required String invitedUserId,
    required String sessionTitle,
  }) async {
    try {
      final inviterDoc =
          await _firestore.collection('users').doc(inviterId).get();
      final inviterName = inviterDoc.data()?['fullName'] ?? 'Someone';

      await _firestore.collection(_notificationsCollection).add({
        'type': 'collaboration_invitation',
        'sessionId': sessionId,
        'inviterId': inviterId,
        'inviterName': inviterName,
        'recipientId': invitedUserId,
        'title': 'Collaboration Invitation',
        'message': '$inviterName invited you to collaborate on "$sessionTitle"',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Invitation notification sent');
    } catch (e) {
      debugPrint('❌ Error sending invitation notification: $e');
    }
  }

  /// Send edit notification
  Future<void> sendEditNotification({
    required String sessionId,
    required String editorId,
    required List<String> collaboratorIds,
    required String editType,
  }) async {
    try {
      final editorDoc =
          await _firestore.collection('users').doc(editorId).get();
      final editorName = editorDoc.data()?['fullName'] ?? 'Someone';

      for (final collaboratorId in collaboratorIds) {
        if (collaboratorId != editorId) {
          await _firestore.collection(_notificationsCollection).add({
            'type': 'collaboration_edit',
            'sessionId': sessionId,
            'editorId': editorId,
            'editorName': editorName,
            'recipientId': collaboratorId,
            'title': 'Content Updated',
            'message': '$editorName made changes to the collaborative post',
            'editType': editType,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      debugPrint('✅ Edit notifications sent');
    } catch (e) {
      debugPrint('❌ Error sending edit notification: $e');
    }
  }

  /// Send publish notification
  Future<void> sendPublishNotification({
    required String sessionId,
    required String publisherId,
    required List<String> collaboratorIds,
    required String postId,
  }) async {
    try {
      final publisherDoc =
          await _firestore.collection('users').doc(publisherId).get();
      final publisherName = publisherDoc.data()?['fullName'] ?? 'Someone';

      for (final collaboratorId in collaboratorIds) {
        await _firestore.collection(_notificationsCollection).add({
          'type': 'collaboration_published',
          'sessionId': sessionId,
          'postId': postId,
          'publisherId': publisherId,
          'publisherName': publisherName,
          'recipientId': collaboratorId,
          'title': 'Post Published',
          'message':
              '$publisherName published the collaborative post you worked on',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('✅ Publish notifications sent');
    } catch (e) {
      debugPrint('❌ Error sending publish notification: $e');
    }
  }

  /// Get notifications for user
  Future<List<Map<String, dynamic>>> getNotifications(String userId,
      {int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection(_notificationsCollection)
          .where('recipientId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection(_notificationsCollection)
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }
}
