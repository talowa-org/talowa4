// Collaborative Content Creation Example
// Demonstrates how to use the collaborative editing system

import '../models/social_feed/collaborative_models.dart';
import '../services/social_feed/collaborative_content_service.dart';
import '../services/social_feed/collaboration_notification_service.dart';
import '../services/social_feed/collaboration_recovery_service.dart';

/// Example: Creating a collaborative post
class CollaborativeContentExample {
  final _collaborativeService = CollaborativeContentService();
  final _notificationService = CollaborationNotificationService();
  final _recoveryService = CollaborationRecoveryService();

  /// Example 1: Create a new collaborative session
  Future<void> createCollaborativeSession() async {
    try {
      // Create session with initial collaborators
      final session = await _collaborativeService.createCollaborativePost(
        initiatorId: 'user123',
        collaboratorIds: ['user456', 'user789'],
        initialContent: 'Let\'s work together on this post!',
        initialTitle: 'Community Update',
      );

      print('✅ Session created: ${session.id}');
      print('Collaborators: ${session.collaborators.length}');

      // Send invitations
      for (final collaborator in session.collaborators) {
        if (collaborator.userId != session.initiatorId) {
          await _notificationService.sendInvitationNotification(
            sessionId: session.id,
            inviterId: session.initiatorId,
            invitedUserId: collaborator.userId,
            sessionTitle: session.currentVersion.title ?? 'Untitled',
          );
        }
      }
    } catch (e) {
      print('❌ Error creating session: $e');
    }
  }

  /// Example 2: Apply text edit with operational transform
  Future<void> applyTextEdit(String sessionId) async {
    try {
      final edit = ContentEdit(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        type: EditType.textInsert,
        position: 10,
        newText: 'important ',
        userId: 'user123',
        timestamp: DateTime.now(),
      );

      await _collaborativeService.applyContentEdit(
        sessionId: sessionId,
        userId: 'user123',
        edit: edit,
      );

      print('✅ Edit applied successfully');
    } catch (e) {
      print('❌ Error applying edit: $e');
    }
  }

  /// Example 3: Listen to real-time updates
  void listenToRealtimeUpdates(String sessionId) {
    _collaborativeService.getEditStream(sessionId).listen(
      (session) {
        print('📡 Session updated:');
        print('  Content: ${session.currentVersion.content}');
        print('  Version: ${session.currentVersion.id}');
        print('  Active collaborators: ${session.collaborators.where((c) => c.isActive).length}');
      },
      onError: (error) {
        print('❌ Stream error: $error');
      },
    );
  }

  /// Example 4: Manage collaborators
  Future<void> manageCollaborators(String sessionId) async {
    try {
      // Invite new collaborator
      await _collaborativeService.inviteCollaborator(
        sessionId: sessionId,
        userId: 'user999',
        role: CollaboratorRole.editor,
      );
      print('✅ Collaborator invited');

      // Update permissions
      await _collaborativeService.updateCollaboratorPermissions(
        sessionId: sessionId,
        userId: 'user999',
        permissions: [
          Permission.view,
          Permission.editContent,
          Permission.addMedia,
        ],
      );
      print('✅ Permissions updated');

      // Remove collaborator
      await _collaborativeService.removeCollaborator(
        sessionId: sessionId,
        userId: 'user999',
      );
      print('✅ Collaborator removed');
    } catch (e) {
      print('❌ Error managing collaborators: $e');
    }
  }

  /// Example 5: Version control
  Future<void> manageVersions(String sessionId) async {
    try {
      // Get version history
      final versions = await _collaborativeService.getVersionHistory(sessionId);
      print('📚 Version history:');
      for (final version in versions) {
        print('  ${version.id}: Edited by ${version.editedBy} at ${version.editedAt}');
      }

      // Revert to previous version
      if (versions.length > 1) {
        await _collaborativeService.revertToVersion(
          sessionId,
          versions[versions.length - 2].id,
        );
        print('✅ Reverted to previous version');
      }
    } catch (e) {
      print('❌ Error managing versions: $e');
    }
  }

  /// Example 6: Add media to collaborative gallery
  Future<void> addMediaToSession(String sessionId) async {
    try {
      await _collaborativeService.addMediaToGallery(
        sessionId: sessionId,
        mediaUrl: 'https://example.com/image.jpg',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );
      print('✅ Media added to gallery');
    } catch (e) {
      print('❌ Error adding media: $e');
    }
  }

  /// Example 7: Publish collaborative post
  Future<void> publishPost(String sessionId) async {
    try {
      final postId = await _collaborativeService.publishCollaborativePost(sessionId);
      print('✅ Post published: $postId');
    } catch (e) {
      print('❌ Error publishing post: $e');
    }
  }

  /// Example 8: Session recovery
  Future<void> recoverSession(String sessionId) async {
    try {
      // Create backup
      await _recoveryService.createBackup(sessionId);
      print('✅ Backup created');

      // Check session health
      final health = await _recoveryService.getSessionHealth(sessionId);
      print('🏥 Session health: $health');

      // Resolve conflicts
      await _recoveryService.resolveConflicts(sessionId);
      print('✅ Conflicts resolved');

      // Reactivate inactive session
      await _recoveryService.recoverInactiveSession(sessionId);
      print('✅ Session reactivated');
    } catch (e) {
      print('❌ Error in recovery: $e');
    }
  }

  /// Example 9: Handle notifications
  Future<void> handleNotifications(String userId) async {
    try {
      // Get notifications
      final notifications = await _notificationService.getNotifications(userId);
      print('📬 Notifications: ${notifications.length}');

      for (final notification in notifications) {
        print('  ${notification['title']}: ${notification['message']}');

        // Mark as read
        await _notificationService.markAsRead(notification['id']);
      }
    } catch (e) {
      print('❌ Error handling notifications: $e');
    }
  }
}

/// Example: Complete workflow
class CompleteCollaborativeWorkflow {
  final _service = CollaborativeContentService();
  final _notificationService = CollaborationNotificationService();

  Future<void> runCompleteWorkflow() async {
    try {
      print('🚀 Starting collaborative workflow...\n');

      // Step 1: Create session
      print('Step 1: Creating collaborative session...');
      final session = await _service.createCollaborativePost(
        initiatorId: 'user123',
        collaboratorIds: ['user456', 'user789'],
        initialContent: 'Draft content',
        initialTitle: 'Team Post',
      );
      print('✅ Session created: ${session.id}\n');

      // Step 2: Send invitations
      print('Step 2: Sending invitations...');
      for (final collaborator in session.collaborators) {
        if (collaborator.userId != session.initiatorId) {
          await _notificationService.sendInvitationNotification(
            sessionId: session.id,
            inviterId: session.initiatorId,
            invitedUserId: collaborator.userId,
            sessionTitle: 'Team Post',
          );
        }
      }
      print('✅ Invitations sent\n');

      // Step 3: Apply edits
      print('Step 3: Applying collaborative edits...');
      final edit1 = ContentEdit(
        id: '1',
        type: EditType.textInsert,
        position: 0,
        newText: 'Hello ',
        userId: 'user123',
        timestamp: DateTime.now(),
      );
      await _service.applyContentEdit(
        sessionId: session.id,
        userId: 'user123',
        edit: edit1,
      );

      final edit2 = ContentEdit(
        id: '2',
        type: EditType.textInsert,
        position: 6,
        newText: 'World! ',
        userId: 'user456',
        timestamp: DateTime.now(),
      );
      await _service.applyContentEdit(
        sessionId: session.id,
        userId: 'user456',
        edit: edit2,
      );
      print('✅ Edits applied\n');

      // Step 4: Add media
      print('Step 4: Adding media...');
      await _service.addMediaToGallery(
        sessionId: session.id,
        mediaUrl: 'https://example.com/image.jpg',
      );
      print('✅ Media added\n');

      // Step 5: Publish
      print('Step 5: Publishing post...');
      final postId = await _service.publishCollaborativePost(session.id);
      print('✅ Post published: $postId\n');

      print('🎉 Workflow completed successfully!');
    } catch (e) {
      print('❌ Workflow error: $e');
    }
  }
}
