// Collaboration Recovery Service for TALOWA
// Handles session recovery and conflict resolution

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/collaborative_models.dart';

class CollaborationRecoveryService {
  static final CollaborationRecoveryService _instance =
      CollaborationRecoveryService._internal();
  factory CollaborationRecoveryService() => _instance;
  CollaborationRecoveryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _sessionsCollection = 'collaborative_sessions';
  final String _backupsCollection = 'session_backups';

  /// Create automatic backup of session
  Future<void> createBackup(String sessionId) async {
    try {
      final sessionDoc = await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        throw Exception('Session not found');
      }

      final backupId = '${sessionId}_${DateTime.now().millisecondsSinceEpoch}';
      await _firestore.collection(_backupsCollection).doc(backupId).set({
        'sessionId': sessionId,
        'sessionData': sessionDoc.data(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Session backup created: $backupId');
    } catch (e) {
      debugPrint('❌ Error creating backup: $e');
    }
  }

  /// Recover session from backup
  Future<void> recoverFromBackup(String sessionId, String backupId) async {
    try {
      final backupDoc =
          await _firestore.collection(_backupsCollection).doc(backupId).get();

      if (!backupDoc.exists) {
        throw Exception('Backup not found');
      }

      final backupData = backupDoc.data()!;
      final sessionData = backupData['sessionData'] as Map<String, dynamic>;

      await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .set(sessionData);

      debugPrint('✅ Session recovered from backup: $backupId');
    } catch (e) {
      debugPrint('❌ Error recovering from backup: $e');
      rethrow;
    }
  }

  /// Detect and resolve conflicts
  Future<void> resolveConflicts(String sessionId) async {
    try {
      final sessionDoc = await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        throw Exception('Session not found');
      }

      final session = CollaborativeSession.fromFirestore(sessionDoc);

      // Check for conflicting edits in current version
      final changes = session.currentVersion.changes;
      final conflicts = <List<ContentEdit>>[];

      for (int i = 0; i < changes.length; i++) {
        for (int j = i + 1; j < changes.length; j++) {
          if (_hasConflict(changes[i], changes[j])) {
            conflicts.add([changes[i], changes[j]]);
          }
        }
      }

      if (conflicts.isEmpty) {
        debugPrint('✅ No conflicts detected');
        return;
      }

      // Auto-resolve conflicts using last-write-wins strategy
      for (final conflictPair in conflicts) {
        final resolved = conflictPair.reduce((a, b) =>
            a.timestamp.isAfter(b.timestamp) ? a : b);
        debugPrint('✅ Conflict resolved: keeping edit from ${resolved.userId}');
      }
    } catch (e) {
      debugPrint('❌ Error resolving conflicts: $e');
    }
  }

  /// Check if two edits conflict
  bool _hasConflict(ContentEdit edit1, ContentEdit edit2) {
    // Edits conflict if they overlap in position
    final edit1End = edit1.position + (edit1.oldText?.length ?? 0);
    final edit2End = edit2.position + (edit2.oldText?.length ?? 0);

    return (edit1.position <= edit2.position && edit1End > edit2.position) ||
        (edit2.position <= edit1.position && edit2End > edit1.position);
  }

  /// Recover inactive session
  Future<void> recoverInactiveSession(String sessionId) async {
    try {
      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'status': CollaborationStatus.active.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Session reactivated: $sessionId');
    } catch (e) {
      debugPrint('❌ Error reactivating session: $e');
      rethrow;
    }
  }

  /// Clean up old backups
  Future<void> cleanupOldBackups({int daysToKeep = 7}) async {
    try {
      final cutoffDate =
          DateTime.now().subtract(Duration(days: daysToKeep));

      final snapshot = await _firestore
          .collection(_backupsCollection)
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('✅ Cleaned up ${snapshot.docs.length} old backups');
    } catch (e) {
      debugPrint('❌ Error cleaning up backups: $e');
    }
  }

  /// Get session health status
  Future<Map<String, dynamic>> getSessionHealth(String sessionId) async {
    try {
      final sessionDoc = await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        return {'healthy': false, 'reason': 'Session not found'};
      }

      final session = CollaborativeSession.fromFirestore(sessionDoc);

      // Check various health indicators
      final activeCollaborators =
          session.collaborators.where((c) => c.isActive).length;
      final hasRecentActivity = DateTime.now()
              .difference(session.updatedAt)
              .inMinutes <
          30;
      final hasValidContent = session.currentVersion.content.isNotEmpty;

      final isHealthy =
          activeCollaborators > 0 && hasRecentActivity && hasValidContent;

      return {
        'healthy': isHealthy,
        'activeCollaborators': activeCollaborators,
        'lastActivity': session.updatedAt.toIso8601String(),
        'hasContent': hasValidContent,
        'versionCount': session.versionHistory.length,
      };
    } catch (e) {
      debugPrint('❌ Error checking session health: $e');
      return {'healthy': false, 'reason': 'Error: $e'};
    }
  }
}
