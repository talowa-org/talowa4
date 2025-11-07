// Collaborative Content Service for TALOWA
// Real-time collaborative editing with operational transforms

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/collaborative_models.dart';
import '../auth_service.dart';

class CollaborativeContentService {
  static final CollaborativeContentService _instance =
      CollaborativeContentService._internal();
  factory CollaborativeContentService() => _instance;
  CollaborativeContentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _sessionsCollection = 'collaborative_sessions';

  final Map<String, StreamSubscription> _sessionListeners = {};
  final Map<String, StreamController<CollaborativeSession>>
      _sessionControllers = {};

  /// Create a new collaborative session
  Future<CollaborativeSession> createCollaborativePost({
    required String initiatorId,
    required List<String> collaboratorIds,
    String? initialContent,
    String? initialTitle,
  }) async {
    try {
      final sessionId = _firestore.collection(_sessionsCollection).doc().id;

      // Get initiator info
      final initiatorDoc =
          await _firestore.collection('users').doc(initiatorId).get();
      final initiatorData = initiatorDoc.data() ?? {};

      // Create initial version
      final initialVersion = ContentVersion(
        id: 'v1',
        content: initialContent ?? '',
        title: initialTitle,
        mediaUrls: [],
        editedBy: initiatorId,
        editedAt: DateTime.now(),
        changes: [],
      );

      // Create collaborators list
      final collaborators = <Collaborator>[
        Collaborator(
          userId: initiatorId,
          name: initiatorData['fullName'] ?? 'Unknown',
          avatarUrl: initiatorData['profileImageUrl'],
          role: CollaboratorRole.owner,
          permissions: Permission.values,
          joinedAt: DateTime.now(),
          isActive: true,
        ),
      ];

      // Add other collaborators
      for (final userId in collaboratorIds) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data() ?? {};
        collaborators.add(
          Collaborator(
            userId: userId,
            name: userData['fullName'] ?? 'Unknown',
            avatarUrl: userData['profileImageUrl'],
            role: CollaboratorRole.editor,
            permissions: [
              Permission.view,
              Permission.editContent,
              Permission.addMedia,
            ],
            joinedAt: DateTime.now(),
            isActive: false,
          ),
        );
      }

      final session = CollaborativeSession(
        id: sessionId,
        initiatorId: initiatorId,
        postId: null,
        status: CollaborationStatus.active,
        collaborators: collaborators,
        currentVersion: initialVersion,
        versionHistory: [initialVersion],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .set(session.toFirestore());

      debugPrint('✅ Collaborative session created: $sessionId');
      return session;
    } catch (e) {
      debugPrint('❌ Error creating collaborative session: $e');
      rethrow;
    }
  }

  /// Apply content edit with operational transform
  Future<void> applyContentEdit({
    required String sessionId,
    required String userId,
    required ContentEdit edit,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final sessionDoc = await transaction
            .get(_firestore.collection(_sessionsCollection).doc(sessionId));

        if (!sessionDoc.exists) {
          throw Exception('Session not found');
        }

        final session = CollaborativeSession.fromFirestore(sessionDoc);

        // Verify user has permission
        final collaborator = session.collaborators.firstWhere(
          (c) => c.userId == userId,
          orElse: () => throw Exception('User not a collaborator'),
        );

        if (!collaborator.permissions.contains(Permission.editContent)) {
          throw Exception('User does not have edit permission');
        }

        // Apply operational transform to resolve conflicts
        ContentEdit transformedEdit = edit;
        for (final change in session.currentVersion.changes) {
          transformedEdit = transformedEdit.transform(change);
        }

        // Apply edit to content
        String newContent = session.currentVersion.content;
        switch (transformedEdit.type) {
          case EditType.textInsert:
            newContent = newContent.substring(0, transformedEdit.position) +
                (transformedEdit.newText ?? '') +
                newContent.substring(transformedEdit.position);
            break;
          case EditType.textDelete:
            final endPos = transformedEdit.position +
                (transformedEdit.oldText?.length ?? 0);
            newContent = newContent.substring(0, transformedEdit.position) +
                newContent.substring(endPos);
            break;
          case EditType.textEdit:
            final endPos = transformedEdit.position +
                (transformedEdit.oldText?.length ?? 0);
            newContent = newContent.substring(0, transformedEdit.position) +
                (transformedEdit.newText ?? '') +
                newContent.substring(endPos);
            break;
          default:
            break;
        }

        // Create new version
        final newVersion = ContentVersion(
          id: 'v${session.versionHistory.length + 1}',
          content: newContent,
          title: session.currentVersion.title,
          mediaUrls: session.currentVersion.mediaUrls,
          editedBy: userId,
          editedAt: DateTime.now(),
          changes: [...session.currentVersion.changes, transformedEdit],
        );

        // Update session
        transaction.update(
          _firestore.collection(_sessionsCollection).doc(sessionId),
          {
            'currentVersion': newVersion.toMap(),
            'versionHistory': FieldValue.arrayUnion([newVersion.toMap()]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      });

      debugPrint('✅ Content edit applied to session: $sessionId');
    } catch (e) {
      debugPrint('❌ Error applying content edit: $e');
      rethrow;
    }
  }

  /// Get real-time edit stream for a session
  Stream<CollaborativeSession> getEditStream(String sessionId) {
    if (_sessionControllers.containsKey(sessionId)) {
      return _sessionControllers[sessionId]!.stream;
    }

    final controller = StreamController<CollaborativeSession>.broadcast();
    _sessionControllers[sessionId] = controller;

    final listener = _firestore
        .collection(_sessionsCollection)
        .doc(sessionId)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists) {
          final session = CollaborativeSession.fromFirestore(snapshot);
          controller.add(session);
        }
      },
      onError: (error) {
        debugPrint('❌ Edit stream error: $error');
        controller.addError(error);
      },
    );

    _sessionListeners[sessionId] = listener;
    return controller.stream;
  }

  /// Get version history
  Future<List<ContentVersion>> getVersionHistory(String sessionId) async {
    try {
      final sessionDoc = await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        throw Exception('Session not found');
      }

      final session = CollaborativeSession.fromFirestore(sessionDoc);
      return session.versionHistory;
    } catch (e) {
      debugPrint('❌ Error getting version history: $e');
      return [];
    }
  }

  /// Revert to a specific version
  Future<void> revertToVersion(String sessionId, String versionId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final sessionDoc = await transaction
            .get(_firestore.collection(_sessionsCollection).doc(sessionId));

        if (!sessionDoc.exists) {
          throw Exception('Session not found');
        }

        final session = CollaborativeSession.fromFirestore(sessionDoc);
        final version = session.versionHistory.firstWhere(
          (v) => v.id == versionId,
          orElse: () => throw Exception('Version not found'),
        );

        transaction.update(
          _firestore.collection(_sessionsCollection).doc(sessionId),
          {
            'currentVersion': version.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      });

      debugPrint('✅ Reverted to version: $versionId');
    } catch (e) {
      debugPrint('❌ Error reverting to version: $e');
      rethrow;
    }
  }

  /// Invite collaborator to session
  Future<void> inviteCollaborator({
    required String sessionId,
    required String userId,
    required CollaboratorRole role,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      final newCollaborator = Collaborator(
        userId: userId,
        name: userData['fullName'] ?? 'Unknown',
        avatarUrl: userData['profileImageUrl'],
        role: role,
        permissions: _getPermissionsForRole(role),
        joinedAt: DateTime.now(),
        isActive: false,
      );

      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'collaborators': FieldValue.arrayUnion([newCollaborator.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Collaborator invited: $userId');
    } catch (e) {
      debugPrint('❌ Error inviting collaborator: $e');
      rethrow;
    }
  }

  /// Update collaborator permissions
  Future<void> updateCollaboratorPermissions({
    required String sessionId,
    required String userId,
    required List<Permission> permissions,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final sessionDoc = await transaction
            .get(_firestore.collection(_sessionsCollection).doc(sessionId));

        if (!sessionDoc.exists) {
          throw Exception('Session not found');
        }

        final session = CollaborativeSession.fromFirestore(sessionDoc);
        final collaborators = session.collaborators.map((c) {
          if (c.userId == userId) {
            return Collaborator(
              userId: c.userId,
              name: c.name,
              avatarUrl: c.avatarUrl,
              role: c.role,
              permissions: permissions,
              joinedAt: c.joinedAt,
              isActive: c.isActive,
            );
          }
          return c;
        }).toList();

        transaction.update(
          _firestore.collection(_sessionsCollection).doc(sessionId),
          {
            'collaborators': collaborators.map((c) => c.toMap()).toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      });

      debugPrint('✅ Collaborator permissions updated: $userId');
    } catch (e) {
      debugPrint('❌ Error updating permissions: $e');
      rethrow;
    }
  }

  /// Remove collaborator from session
  Future<void> removeCollaborator({
    required String sessionId,
    required String userId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final sessionDoc = await transaction
            .get(_firestore.collection(_sessionsCollection).doc(sessionId));

        if (!sessionDoc.exists) {
          throw Exception('Session not found');
        }

        final session = CollaborativeSession.fromFirestore(sessionDoc);
        final collaborators =
            session.collaborators.where((c) => c.userId != userId).toList();

        transaction.update(
          _firestore.collection(_sessionsCollection).doc(sessionId),
          {
            'collaborators': collaborators.map((c) => c.toMap()).toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      });

      debugPrint('✅ Collaborator removed: $userId');
    } catch (e) {
      debugPrint('❌ Error removing collaborator: $e');
      rethrow;
    }
  }

  /// Add media to collaborative gallery
  Future<void> addMediaToGallery({
    required String sessionId,
    required String mediaUrl,
    String? thumbnailUrl,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.runTransaction((transaction) async {
        final sessionDoc = await transaction
            .get(_firestore.collection(_sessionsCollection).doc(sessionId));

        if (!sessionDoc.exists) {
          throw Exception('Session not found');
        }

        final session = CollaborativeSession.fromFirestore(sessionDoc);
        final updatedMediaUrls = [
          ...session.currentVersion.mediaUrls,
          mediaUrl
        ];

        final newVersion = ContentVersion(
          id: 'v${session.versionHistory.length + 1}',
          content: session.currentVersion.content,
          title: session.currentVersion.title,
          mediaUrls: updatedMediaUrls,
          editedBy: currentUser.uid,
          editedAt: DateTime.now(),
          changes: session.currentVersion.changes,
        );

        transaction.update(
          _firestore.collection(_sessionsCollection).doc(sessionId),
          {
            'currentVersion': newVersion.toMap(),
            'versionHistory': FieldValue.arrayUnion([newVersion.toMap()]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      });

      debugPrint('✅ Media added to gallery');
    } catch (e) {
      debugPrint('❌ Error adding media: $e');
      rethrow;
    }
  }

  /// Publish collaborative post
  Future<String> publishCollaborativePost(String sessionId) async {
    try {
      final sessionDoc = await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        throw Exception('Session not found');
      }

      final session = CollaborativeSession.fromFirestore(sessionDoc);

      // Create post from session
      final postId = _firestore.collection('posts').doc().id;
      final postData = {
        'id': postId,
        'authorId': session.initiatorId,
        'content': session.currentVersion.content,
        'title': session.currentVersion.title,
        'imageUrls': session.currentVersion.mediaUrls,
        'collaborators':
            session.collaborators.map((c) => c.toMap()).toList(),
        'isCollaborative': true,
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
      };

      await _firestore.collection('posts').doc(postId).set(postData);

      // Update session status
      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'postId': postId,
        'status': CollaborationStatus.completed.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Collaborative post published: $postId');
      return postId;
    } catch (e) {
      debugPrint('❌ Error publishing post: $e');
      rethrow;
    }
  }

  /// Get permissions for role
  List<Permission> _getPermissionsForRole(CollaboratorRole role) {
    switch (role) {
      case CollaboratorRole.owner:
        return Permission.values;
      case CollaboratorRole.editor:
        return [
          Permission.view,
          Permission.editContent,
          Permission.addMedia,
        ];
      case CollaboratorRole.reviewer:
        return [Permission.view];
      case CollaboratorRole.viewer:
        return [Permission.view];
    }
  }

  /// Dispose resources
  void dispose() {
    for (final listener in _sessionListeners.values) {
      listener.cancel();
    }
    for (final controller in _sessionControllers.values) {
      controller.close();
    }
    _sessionListeners.clear();
    _sessionControllers.clear();
  }
}
