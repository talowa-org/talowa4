// Group Model for TALOWA Messaging System
// Reference: in-app-communication/design.md - Group Management Component

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

class GroupModel {
  final String id;
  final String name;
  final String description;
  final GroupType type;
  final GeographicScope location;
  final List<GroupMember> members;
  final int maxMembers;
  final int memberCount;
  final GroupSettings settings;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? avatarUrl;
  final Map<String, dynamic> metadata;

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.location,
    required this.members,
    required this.maxMembers,
    required this.memberCount,
    required this.settings,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
    this.avatarUrl,
    required this.metadata,
  });

  // Convert from Firestore document
  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return GroupModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      type: GroupTypeExtension.fromString(data['type'] ?? 'village'),
      location: GeographicScope.fromMap(data['location'] ?? {}),
      members: (data['members'] as List<dynamic>?)
          ?.map((m) => GroupMember.fromMap(m as Map<String, dynamic>))
          .toList() ?? [],
      maxMembers: data['maxMembers'] ?? 500,
      memberCount: data['memberCount'] ?? 0,
      settings: GroupSettings.fromMap(data['settings'] ?? {}),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      avatarUrl: data['avatarUrl'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'type': type.value,
      'location': location.toMap(),
      'members': members.map((m) => m.toMap()).toList(),
      'maxMembers': maxMembers,
      'memberCount': memberCount,
      'settings': settings.toMap(),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'avatarUrl': avatarUrl,
      'metadata': metadata,
    };
  }

  // Copy with method for updates
  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    GroupType? type,
    GeographicScope? location,
    List<GroupMember>? members,
    int? maxMembers,
    int? memberCount,
    GroupSettings? settings,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      location: location ?? this.location,
      members: members ?? this.members,
      maxMembers: maxMembers ?? this.maxMembers,
      memberCount: memberCount ?? this.memberCount,
      settings: settings ?? this.settings,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  // Get member by user ID
  GroupMember? getMember(String userId) {
    try {
      return members.firstWhere((member) => member.userId == userId);
    } catch (e) {
      return null;
    }
  }

  // Check if user is member
  bool isMember(String userId) {
    return members.any((member) => member.userId == userId);
  }

  // Check if user is coordinator
  bool isCoordinator(String userId) {
    final member = getMember(userId);
    return member?.groupRole == GroupRole.coordinator;
  }

  // Check if user is admin
  bool isAdmin(String userId) {
    final member = getMember(userId);
    return member?.groupRole == GroupRole.admin;
  }

  // Check if user can add members
  bool canAddMembers(String userId) {
    switch (settings.whoCanAddMembers) {
      case GroupPermission.admin:
        return isAdmin(userId);
      case GroupPermission.coordinators:
        return isCoordinator(userId) || isAdmin(userId);
      case GroupPermission.all:
        return isMember(userId);
    }
  }

  // Check if user can send messages
  bool canSendMessages(String userId) {
    switch (settings.whoCanSendMessages) {
      case GroupPermission.admin:
        return isAdmin(userId);
      case GroupPermission.coordinators:
        return isCoordinator(userId) || isAdmin(userId);
      case GroupPermission.all:
        return isMember(userId);
    }
  }

  // Check if user can share media
  bool canShareMedia(String userId) {
    switch (settings.whoCanShareMedia) {
      case GroupPermission.admin:
        return isAdmin(userId);
      case GroupPermission.coordinators:
        return isCoordinator(userId) || isAdmin(userId);
      case GroupPermission.all:
        return isMember(userId);
    }
  }

  @override
  String toString() {
    return 'GroupModel(id: $id, name: $name, type: ${type.value}, members: ${members.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroupModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Group types enum
enum GroupType {
  village,
  mandal,
  district,
  campaign,
  legalCase,
  custom,
}

extension GroupTypeExtension on GroupType {
  String get value {
    switch (this) {
      case GroupType.village:
        return 'village';
      case GroupType.mandal:
        return 'mandal';
      case GroupType.district:
        return 'district';
      case GroupType.campaign:
        return 'campaign';
      case GroupType.legalCase:
        return 'legal_case';
      case GroupType.custom:
        return 'custom';
    }
  }

  String get displayName {
    switch (this) {
      case GroupType.village:
        return 'Village Group';
      case GroupType.mandal:
        return 'Mandal Group';
      case GroupType.district:
        return 'District Group';
      case GroupType.campaign:
        return 'Campaign Group';
      case GroupType.legalCase:
        return 'Legal Case Group';
      case GroupType.custom:
        return 'Custom Group';
    }
  }

  static GroupType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'mandal':
        return GroupType.mandal;
      case 'district':
        return GroupType.district;
      case 'campaign':
        return GroupType.campaign;
      case 'legal_case':
        return GroupType.legalCase;
      case 'custom':
        return GroupType.custom;
      default:
        return GroupType.village;
    }
  }
}

// Geographic scope for groups
class GeographicScope {
  final String level; // village, mandal, district, state
  final String locationId;
  final String locationName;
  final GeographicCoordinates? coordinates;

  GeographicScope({
    required this.level,
    required this.locationId,
    required this.locationName,
    this.coordinates,
  });

  factory GeographicScope.fromMap(Map<String, dynamic> map) {
    return GeographicScope(
      level: map['level'] ?? AppConstants.levelVillage,
      locationId: map['locationId'] ?? '',
      locationName: map['locationName'] ?? '',
      coordinates: map['coordinates'] != null 
          ? GeographicCoordinates.fromMap(map['coordinates'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'level': level,
      'locationId': locationId,
      'locationName': locationName,
      'coordinates': coordinates?.toMap(),
    };
  }
}

// Geographic coordinates
class GeographicCoordinates {
  final double latitude;
  final double longitude;

  GeographicCoordinates({
    required this.latitude,
    required this.longitude,
  });

  factory GeographicCoordinates.fromMap(Map<String, dynamic> map) {
    return GeographicCoordinates(
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

// Group member model
class GroupMember {
  final String userId;
  final String name;
  final String role; // User's TALOWA role
  final GroupRole groupRole;
  final DateTime joinedAt;
  final DateTime? lastReadAt;
  final bool isActive;

  GroupMember({
    required this.userId,
    required this.name,
    required this.role,
    required this.groupRole,
    required this.joinedAt,
    this.lastReadAt,
    required this.isActive,
  });

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? AppConstants.roleMember,
      groupRole: GroupRoleExtension.fromString(map['groupRole'] ?? 'member'),
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastReadAt: (map['lastReadAt'] as Timestamp?)?.toDate(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'role': role,
      'groupRole': groupRole.value,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastReadAt': lastReadAt != null ? Timestamp.fromDate(lastReadAt!) : null,
      'isActive': isActive,
    };
  }

  GroupMember copyWith({
    String? userId,
    String? name,
    String? role,
    GroupRole? groupRole,
    DateTime? joinedAt,
    DateTime? lastReadAt,
    bool? isActive,
  }) {
    return GroupMember(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      role: role ?? this.role,
      groupRole: groupRole ?? this.groupRole,
      joinedAt: joinedAt ?? this.joinedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

// Group roles enum
enum GroupRole {
  member,
  coordinator,
  admin,
}

extension GroupRoleExtension on GroupRole {
  String get value {
    switch (this) {
      case GroupRole.member:
        return 'member';
      case GroupRole.coordinator:
        return 'coordinator';
      case GroupRole.admin:
        return 'admin';
    }
  }

  String get displayName {
    switch (this) {
      case GroupRole.member:
        return 'Member';
      case GroupRole.coordinator:
        return 'Coordinator';
      case GroupRole.admin:
        return 'Admin';
    }
  }

  static GroupRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'coordinator':
        return GroupRole.coordinator;
      case 'admin':
        return GroupRole.admin;
      default:
        return GroupRole.member;
    }
  }
}

// Group settings model
class GroupSettings {
  final GroupPermission whoCanAddMembers;
  final GroupPermission whoCanSendMessages;
  final GroupPermission whoCanShareMedia;
  final int messageRetention; // Days to keep messages
  final bool requireApprovalToJoin;
  final bool allowAnonymousMessages;
  final String encryptionLevel; // 'standard' or 'high_security'

  GroupSettings({
    required this.whoCanAddMembers,
    required this.whoCanSendMessages,
    required this.whoCanShareMedia,
    required this.messageRetention,
    required this.requireApprovalToJoin,
    required this.allowAnonymousMessages,
    required this.encryptionLevel,
  });

  factory GroupSettings.fromMap(Map<String, dynamic> map) {
    return GroupSettings(
      whoCanAddMembers: GroupPermissionExtension.fromString(
        map['whoCanAddMembers'] ?? 'coordinators'
      ),
      whoCanSendMessages: GroupPermissionExtension.fromString(
        map['whoCanSendMessages'] ?? 'all'
      ),
      whoCanShareMedia: GroupPermissionExtension.fromString(
        map['whoCanShareMedia'] ?? 'coordinators'
      ),
      messageRetention: map['messageRetention'] ?? 365,
      requireApprovalToJoin: map['requireApprovalToJoin'] ?? false,
      allowAnonymousMessages: map['allowAnonymousMessages'] ?? false,
      encryptionLevel: map['encryptionLevel'] ?? 'standard',
    );
  }

  factory GroupSettings.defaultSettings() {
    return GroupSettings(
      whoCanAddMembers: GroupPermission.coordinators,
      whoCanSendMessages: GroupPermission.all,
      whoCanShareMedia: GroupPermission.coordinators,
      messageRetention: 365,
      requireApprovalToJoin: false,
      allowAnonymousMessages: false,
      encryptionLevel: 'standard',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'whoCanAddMembers': whoCanAddMembers.value,
      'whoCanSendMessages': whoCanSendMessages.value,
      'whoCanShareMedia': whoCanShareMedia.value,
      'messageRetention': messageRetention,
      'requireApprovalToJoin': requireApprovalToJoin,
      'allowAnonymousMessages': allowAnonymousMessages,
      'encryptionLevel': encryptionLevel,
    };
  }

  GroupSettings copyWith({
    GroupPermission? whoCanAddMembers,
    GroupPermission? whoCanSendMessages,
    GroupPermission? whoCanShareMedia,
    int? messageRetention,
    bool? requireApprovalToJoin,
    bool? allowAnonymousMessages,
    String? encryptionLevel,
  }) {
    return GroupSettings(
      whoCanAddMembers: whoCanAddMembers ?? this.whoCanAddMembers,
      whoCanSendMessages: whoCanSendMessages ?? this.whoCanSendMessages,
      whoCanShareMedia: whoCanShareMedia ?? this.whoCanShareMedia,
      messageRetention: messageRetention ?? this.messageRetention,
      requireApprovalToJoin: requireApprovalToJoin ?? this.requireApprovalToJoin,
      allowAnonymousMessages: allowAnonymousMessages ?? this.allowAnonymousMessages,
      encryptionLevel: encryptionLevel ?? this.encryptionLevel,
    );
  }
}

// Group permissions enum
enum GroupPermission {
  admin,
  coordinators,
  all,
}

extension GroupPermissionExtension on GroupPermission {
  String get value {
    switch (this) {
      case GroupPermission.admin:
        return 'admin';
      case GroupPermission.coordinators:
        return 'coordinators';
      case GroupPermission.all:
        return 'all';
    }
  }

  String get displayName {
    switch (this) {
      case GroupPermission.admin:
        return 'Admin Only';
      case GroupPermission.coordinators:
        return 'Coordinators Only';
      case GroupPermission.all:
        return 'All Members';
    }
  }

  static GroupPermission fromString(String permission) {
    switch (permission.toLowerCase()) {
      case 'admin':
        return GroupPermission.admin;
      case 'all':
        return GroupPermission.all;
      default:
        return GroupPermission.coordinators;
    }
  }
}
