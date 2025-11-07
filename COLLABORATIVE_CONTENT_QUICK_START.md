# Collaborative Content Creation - Quick Start Guide

## 🚀 Quick Start

### 1. Create a Collaborative Session

```dart
import 'package:talowa/services/social_feed/collaborative_content_service.dart';

final service = CollaborativeContentService();

// Create new session
final session = await service.createCollaborativePost(
  initiatorId: currentUserId,
  collaboratorIds: ['user2', 'user3'],
  initialContent: 'Let\'s work together!',
  initialTitle: 'Team Post',
);

print('Session ID: ${session.id}');
```

### 2. Listen to Real-time Updates

```dart
service.getEditStream(sessionId).listen((session) {
  print('Content updated: ${session.currentVersion.content}');
  print('Active users: ${session.collaborators.where((c) => c.isActive).length}');
});
```

### 3. Apply an Edit

```dart
final edit = ContentEdit(
  id: '${DateTime.now().millisecondsSinceEpoch}',
  type: EditType.textInsert,
  position: 10,
  newText: 'Hello ',
  userId: currentUserId,
  timestamp: DateTime.now(),
);

await service.applyContentEdit(
  sessionId: sessionId,
  userId: currentUserId,
  edit: edit,
);
```

### 4. Manage Collaborators

```dart
// Invite collaborator
await service.inviteCollaborator(
  sessionId: sessionId,
  userId: 'newUser',
  role: CollaboratorRole.editor,
);

// Update permissions
await service.updateCollaboratorPermissions(
  sessionId: sessionId,
  userId: 'newUser',
  permissions: [Permission.view, Permission.editContent],
);

// Remove collaborator
await service.removeCollaborator(
  sessionId: sessionId,
  userId: 'newUser',
);
```

### 5. Version Control

```dart
// Get version history
final versions = await service.getVersionHistory(sessionId);

// Revert to previous version
await service.revertToVersion(sessionId, versions[0].id);
```

### 6. Add Media

```dart
await service.addMediaToGallery(
  sessionId: sessionId,
  mediaUrl: 'https://example.com/image.jpg',
  thumbnailUrl: 'https://example.com/thumb.jpg',
);
```

### 7. Publish Post

```dart
final postId = await service.publishCollaborativePost(sessionId);
print('Published post: $postId');
```

## 🎨 Using the UI Widget

```dart
import 'package:talowa/widgets/social_feed/collaborative_editor_widget.dart';

// In your widget tree
CollaborativeEditorWidget(
  sessionId: sessionId,
  onPublish: () {
    // Handle publish completion
    Navigator.pop(context);
  },
)
```

## 🔔 Notifications

```dart
import 'package:talowa/services/social_feed/collaboration_notification_service.dart';

final notificationService = CollaborationNotificationService();

// Send invitation
await notificationService.sendInvitationNotification(
  sessionId: sessionId,
  inviterId: currentUserId,
  invitedUserId: 'user2',
  sessionTitle: 'Team Post',
);

// Get notifications
final notifications = await notificationService.getNotifications(currentUserId);

// Mark as read
await notificationService.markAsRead(notificationId);
```

## 🔧 Session Recovery

```dart
import 'package:talowa/services/social_feed/collaboration_recovery_service.dart';

final recoveryService = CollaborationRecoveryService();

// Create backup
await recoveryService.createBackup(sessionId);

// Check health
final health = await recoveryService.getSessionHealth(sessionId);
print('Session healthy: ${health['healthy']}');

// Resolve conflicts
await recoveryService.resolveConflicts(sessionId);

// Recover session
await recoveryService.recoverInactiveSession(sessionId);
```

## 📋 Common Patterns

### Pattern 1: Complete Workflow

```dart
// 1. Create session
final session = await service.createCollaborativePost(...);

// 2. Send invitations
await notificationService.sendInvitationNotification(...);

// 3. Listen to updates
service.getEditStream(session.id).listen((updated) {
  // Update UI
});

// 4. Apply edits
await service.applyContentEdit(...);

// 5. Add media
await service.addMediaToGallery(...);

// 6. Publish
final postId = await service.publishCollaborativePost(session.id);
```

### Pattern 2: Error Handling

```dart
try {
  await service.applyContentEdit(...);
} catch (e) {
  if (e.toString().contains('permission')) {
    // Handle permission error
  } else if (e.toString().contains('not found')) {
    // Handle session not found
  } else {
    // Handle other errors
  }
}
```

### Pattern 3: Permission Check

```dart
final session = await getSession(sessionId);
final collaborator = session.collaborators.firstWhere(
  (c) => c.userId == currentUserId,
);

if (collaborator.permissions.contains(Permission.editContent)) {
  // User can edit
  await service.applyContentEdit(...);
} else {
  // Show permission denied message
}
```

## 🎯 Best Practices

1. **Always check permissions** before operations
2. **Handle errors gracefully** with try-catch
3. **Create backups** before major changes
4. **Monitor session health** regularly
5. **Clean up listeners** when done
6. **Use operational transforms** for concurrent edits
7. **Notify collaborators** of important changes

## 🐛 Troubleshooting

### Edits not syncing?
- Check network connection
- Verify session is active
- Ensure user has edit permission

### Conflicts occurring?
- Run `resolveConflicts()`
- Check operational transform logic
- Revert to stable version if needed

### Permission denied?
- Verify user is in collaborators list
- Check user's role and permissions
- Ensure session status is active

## 📚 More Information

- Full documentation: `docs/COLLABORATIVE_CONTENT_SYSTEM.md`
- Examples: `lib/examples/collaborative_content_example.dart`
- Models: `lib/models/social_feed/collaborative_models.dart`

---

**Quick Reference Complete** ✅
