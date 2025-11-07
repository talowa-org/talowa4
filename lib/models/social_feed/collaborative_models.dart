// Collaborative Content Creation Models for TALOWA
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a collaborative editing session
class CollaborativeSession {
  final String id;
  final String initiatorId;
  final String? postId;
  final CollaborationStatus status;
  final List<Collaborator> collaborators;
  final ContentVersion currentVersion;
  final List<ContentVersion> versionHistory;
  final DateTime createdAt;
  final DateTime updatedAt;

  CollaborativeSession({
    required this.id,
    required this.initiatorId,
    this.postId,
    required this.status,
    required this.collaborators,
    required this.currentVersion,
    required this.versionHistory,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CollaborativeSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CollaborativeSession(
      id: doc.id,
      initiatorId: data['initiatorId'] ?? '',
      postId: data['postId'],
      status: CollaborationStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CollaborationStatus.active,
      ),
      collaborators: (data['collaborators'] as List<dynamic>?)
              ?.map((c) => Collaborator.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
      currentVersion: ContentVersion.fromMap(
          data['currentVersion'] as Map<String, dynamic>),
      versionHistory: (data['versionHistory'] as List<dynamic>?)
              ?.map((v) => ContentVersion.fromMap(v as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'initiatorId': initiatorId,
      'postId': postId,
      'status': status.name,
      'collaborators': collaborators.map((c) => c.toMap()).toList(),
      'currentVersion': currentVersion.toMap(),
      'versionHistory': versionHistory.map((v) => v.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

/// Represents a collaborator in a session
class Collaborator {
  final String userId;
  final String name;
  final String? avatarUrl;
  final CollaboratorRole role;
  final List<Permission> permissions;
  final DateTime joinedAt;
  final bool isActive;

  Collaborator({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.role,
    required this.permissions,
    required this.joinedAt,
    required this.isActive,
  });

  factory Collaborator.fromMap(Map<String, dynamic> map) {
    return Collaborator(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      avatarUrl: map['avatarUrl'],
      role: CollaboratorRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => CollaboratorRole.viewer,
      ),
      permissions: (map['permissions'] as List<dynamic>?)
              ?.map((p) => Permission.values.firstWhere(
                    (e) => e.name == p,
                    orElse: () => Permission.view,
                  ))
              .toList() ??
          [],
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'avatarUrl': avatarUrl,
      'role': role.name,
      'permissions': permissions.map((p) => p.name).toList(),
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isActive': isActive,
    };
  }
}

/// Represents a version of content
class ContentVersion {
  final String id;
  final String content;
  final String? title;
  final List<String> mediaUrls;
  final String editedBy;
  final DateTime editedAt;
  final List<ContentEdit> changes;

  ContentVersion({
    required this.id,
    required this.content,
    this.title,
    required this.mediaUrls,
    required this.editedBy,
    required this.editedAt,
    required this.changes,
  });

  factory ContentVersion.fromMap(Map<String, dynamic> map) {
    return ContentVersion(
      id: map['id'] ?? '',
      content: map['content'] ?? '',
      title: map['title'],
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      editedBy: map['editedBy'] ?? '',
      editedAt: (map['editedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      changes: (map['changes'] as List<dynamic>?)
              ?.map((c) => ContentEdit.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'title': title,
      'mediaUrls': mediaUrls,
      'editedBy': editedBy,
      'editedAt': Timestamp.fromDate(editedAt),
      'changes': changes.map((c) => c.toMap()).toList(),
    };
  }
}

/// Represents a single edit operation
class ContentEdit {
  final String id;
  final EditType type;
  final int position;
  final String? oldText;
  final String? newText;
  final String userId;
  final DateTime timestamp;

  ContentEdit({
    required this.id,
    required this.type,
    required this.position,
    this.oldText,
    this.newText,
    required this.userId,
    required this.timestamp,
  });

  factory ContentEdit.fromMap(Map<String, dynamic> map) {
    return ContentEdit(
      id: map['id'] ?? '',
      type: EditType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => EditType.textEdit,
      ),
      position: map['position'] ?? 0,
      oldText: map['oldText'],
      newText: map['newText'],
      userId: map['userId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'position': position,
      'oldText': oldText,
      'newText': newText,
      'userId': userId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  /// Apply operational transform
  ContentEdit transform(ContentEdit other) {
    if (timestamp.isBefore(other.timestamp)) return this;
    int adjustedPosition = position;
    if (other.type == EditType.textInsert && other.position <= position) {
      adjustedPosition += (other.newText?.length ?? 0);
    } else if (other.type == EditType.textDelete && other.position < position) {
      adjustedPosition -= (other.oldText?.length ?? 0);
      if (adjustedPosition < other.position) adjustedPosition = other.position;
    }
    return ContentEdit(
      id: id,
      type: type,
      position: adjustedPosition,
      oldText: oldText,
      newText: newText,
      userId: userId,
      timestamp: timestamp,
    );
  }
}

enum CollaborationStatus { active, paused, completed, cancelled }
enum CollaboratorRole { owner, editor, reviewer, viewer }
enum Permission { view, editContent, addMedia, inviteCollaborators, publish }
enum EditType { textInsert, textDelete, textEdit, mediaAdd, mediaRemove }
