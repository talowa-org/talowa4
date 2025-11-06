// Network Models for TALOWA Network System
// Comprehensive network and referral data models
import 'package:cloud_firestore/cloud_firestore.dart';

class NetworkData {
  final String id;
  final String userId;
  final String userName;
  final String? userRole;
  final String? userAvatarUrl;
  final int level;
  final int directReferrals;
  final int totalTeamSize;
  final double totalEarnings;
  final DateTime joinedAt;
  final bool isActive;
  final List<String> referralIds;
  final Map<String, dynamic>? metadata;

  NetworkData({
    required this.id,
    required this.userId,
    required this.userName,
    this.userRole,
    this.userAvatarUrl,
    this.level = 1,
    this.directReferrals = 0,
    this.totalTeamSize = 0,
    this.totalEarnings = 0.0,
    required this.joinedAt,
    this.isActive = true,
    this.referralIds = const [],
    this.metadata,
  });

  factory NetworkData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return NetworkData(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown User',
      userRole: data['userRole'],
      userAvatarUrl: data['userAvatarUrl'],
      level: data['level'] ?? 1,
      directReferrals: data['directReferrals'] ?? 0,
      totalTeamSize: data['totalTeamSize'] ?? 0,
      totalEarnings: (data['totalEarnings'] ?? 0.0).toDouble(),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      referralIds: List<String>.from(data['referralIds'] ?? []),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'userAvatarUrl': userAvatarUrl,
      'level': level,
      'directReferrals': directReferrals,
      'totalTeamSize': totalTeamSize,
      'totalEarnings': totalEarnings,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isActive': isActive,
      'referralIds': referralIds,
      'metadata': metadata,
    };
  }

  NetworkData copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userRole,
    String? userAvatarUrl,
    int? level,
    int? directReferrals,
    int? totalTeamSize,
    double? totalEarnings,
    DateTime? joinedAt,
    bool? isActive,
    List<String>? referralIds,
    Map<String, dynamic>? metadata,
  }) {
    return NetworkData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      level: level ?? this.level,
      directReferrals: directReferrals ?? this.directReferrals,
      totalTeamSize: totalTeamSize ?? this.totalTeamSize,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      joinedAt: joinedAt ?? this.joinedAt,
      isActive: isActive ?? this.isActive,
      referralIds: referralIds ?? this.referralIds,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkData && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class TeamMember {
  final String id;
  final String userId;
  final String name;
  final String? role;
  final String? avatarUrl;
  final String? email;
  final String? phone;
  final int level;
  final DateTime joinedAt;
  final bool isActive;
  final String? referredBy;
  final int directReferrals;
  final double earnings;
  final Map<String, dynamic>? metadata;

  TeamMember({
    required this.id,
    required this.userId,
    required this.name,
    this.role,
    this.avatarUrl,
    this.email,
    this.phone,
    this.level = 1,
    required this.joinedAt,
    this.isActive = true,
    this.referredBy,
    this.directReferrals = 0,
    this.earnings = 0.0,
    this.metadata,
  });

  factory TeamMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return TeamMember(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? 'Unknown User',
      role: data['role'],
      avatarUrl: data['avatarUrl'],
      email: data['email'],
      phone: data['phone'],
      level: data['level'] ?? 1,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      referredBy: data['referredBy'],
      directReferrals: data['directReferrals'] ?? 0,
      earnings: (data['earnings'] ?? 0.0).toDouble(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'role': role,
      'avatarUrl': avatarUrl,
      'email': email,
      'phone': phone,
      'level': level,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isActive': isActive,
      'referredBy': referredBy,
      'directReferrals': directReferrals,
      'earnings': earnings,
      'metadata': metadata,
    };
  }

  TeamMember copyWith({
    String? id,
    String? userId,
    String? name,
    String? role,
    String? avatarUrl,
    String? email,
    String? phone,
    int? level,
    DateTime? joinedAt,
    bool? isActive,
    String? referredBy,
    int? directReferrals,
    double? earnings,
    Map<String, dynamic>? metadata,
  }) {
    return TeamMember(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      level: level ?? this.level,
      joinedAt: joinedAt ?? this.joinedAt,
      isActive: isActive ?? this.isActive,
      referredBy: referredBy ?? this.referredBy,
      directReferrals: directReferrals ?? this.directReferrals,
      earnings: earnings ?? this.earnings,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TeamMember && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}